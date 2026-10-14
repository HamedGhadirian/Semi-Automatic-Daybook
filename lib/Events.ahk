;================================================================================
; Panel events
;================================================================================
DragPanel:
    if (!Ghost() && !PanelLocked)
        PostMessage, 0xA1, 2, , , ahk_id %PanelHwnd%    ; WM_NCLBUTTONDOWN, HTCAPTION
Return

; SaveIni() writes the position as well as the flag, so locking pins the spot
; the panel is standing on at the moment you press it.
LockClick:
    PanelLocked := !PanelLocked
    SaveIni()
    SetLockBtn()
Return

ModeClick:
    SetPanelMode(PanelMode = 0 ? 1 : 0)
Return

TopClick:
    ToggleOnTop()
Return

ToggleMissed:
    OpenMissed := !OpenMissed
    SaveIni()
    Relayout()
Return

ToggleToday:
    OpenToday := !OpenToday
    SaveIni()
    Relayout()
Return

ToggleLong:
    OpenLong := !OpenLong
    SaveIni()
    Relayout()
Return

ToggleStats:
    OpenStats := !OpenStats
    SaveIni()
    Relayout()
Return

ToggleHabits:
    OpenHabits := !OpenHabits
    SaveIni()
    Relayout()
Return

AddClick:
    QuickAdd("T")
Return

JrnHdrClick:
    JrnShow()
Return

LongAddClick:
    QuickAdd("L")
Return

HabAddClick:
    QuickAdd("H")
Return

; One click is the whole interaction: tick today off, or take it back. There is
; no cross and no note box - a habit you did not do today is simply not ticked,
; and tomorrow it asks again.
HabChkClick:
    HabitToggle(HabRow[SubStr(A_GuiControl, 7)])
Return

BreakClick:
    ToggleBreak()
Return

RowChkClick:
    RowAction(SubStr(A_GuiControl, 7), "done")
Return

RowXClick:
    RowAction(SubStr(A_GuiControl, 5), "failed")
Return

; only on a MISSED row: back onto Today's list
RowGoClick:
    if ((goTask := RowTask[SubStr(A_GuiControl, 6)]) && Tasks[goTask].list = "M")
        MissToToday(goTask)
Return

; Right-click anywhere on a row.
;
; This used to read A_GuiControl and pick the row out of the control's name.
; That quietly broke the moment RowTxt lost its g-label: without one a Static
; has no SS_NOTIFY, so it reports HTTRANSPARENT and the right-click is delivered
; to the PANEL instead of the label. A_GuiControl came back empty and the menu
; never opened - except directly on the tick box or the cross, which still had
; g-labels. Hence "sometimes it works".
;
; Hit-testing the pointer against the row rectangles has no such dependency: it
; works over the text, the glyphs and the empty part of the card alike.
PnlContextMenu:
    ctxCard := CardUnderCursor()
    if (ctxCard) {
        ctx := Cards[ctxCard]
        if (ctx.kind = "H" && HabRow[ctx.pool])
            HabMenu(HabRow[ctx.pool])
        else if (ctx.kind = "T" && RowTask[ctx.pool])
            RowMenu(RowTask[ctx.pool])
    }
Return

; Minimised from the taskbar, and back. While it is down nothing lays it out
; (see the end of Relayout), so it is laid out once on the way back up - by
; then it is where it will be, so the room below it is measured right.
PnlSize:
    if (A_EventInfo = 1)
        PanelWasMin := 1
    else if (PanelWasMin) {
        PanelWasMin := 0
        Relayout()
    }
Return

; Which card the pointer is over, as an index into Cards, or 0. Every card on
; the panel is in that one list whatever section it came from, so this answers
; for a habit exactly the way it answers for a task.
CardUnderCursor() {
    global PanelHwnd, Cards, RowH
    WinGetPos, px, py, , , ahk_id %PanelHwnd%
    if (px = "")
        return 0
    CoordMode, Mouse, Screen
    MouseGetPos, , my
    ry := my - py
    for k, card in Cards
        if (ry >= card.y && ry < card.y + RowH)
            return k
    return 0
}

RowAction(n, status) {
    i := RowTask[n]
    if (!i || !Tasks[i])
        return
    ; A MISSED task is not ticked or crossed where it stands - the tick asks
    ; which day, the cross asks before it drops. See Missed.ahk.
    if (Tasks[i].list = "M") {
        if (status = "done")
            MissDidMenu(i)
        else
            MissDropAsk(i, RowY[n])
        return
    }
    if (Tasks[i].status = status) {          ; clicking the same mark undoes it
        ; Inside the grace window nothing was written, so nothing is. Past it
        ; the mark is on disk, and the honest thing is to say it was taken back
        ; - otherwise the journal says done about a task that is open again.
        if (!CancelMark("T", i))
            Journal(Chr(0x21BA) " reopened: " Tasks[i].text)
        SetStatus(i, "open")
        return
    }
    ; Tick, then cross, on the SAME task inside the grace window: that is one
    ; decision corrected, not two, so the tick is dropped rather than written.
    ; A pending "add" is kept - the task still exists, only its mark changed.
    if (PendMarkKind = "T" && PendMarkTask = i
        && (PendMarkStatus = "done" || PendMarkStatus = "failed"))
        CancelMark("T", i)
    else
        CommitMark()                         ; a different row was still pending
    SetStatus(i, status)
    PendMark("T", i, status)
    OpenNote(i, status, RowY[n])
}

; A tick or a cross is NOT written to the journal at the moment you click it.
;
; The journal is append-only, which is what makes it crash-proof and safe to
; edit in Obsidian - but it also means a misclick is permanent, and unticking
; cannot take it back. So the line is held for MarkDelayMs first: undo inside
; that window and nothing is ever written. Past it the record stands, because by
; then it was a decision rather than a slip.
;
; Esc on the note box deliberately does NOT commit early. It only means "no
; note"; the grace period keeps running, so Esc is still undoable.
; Start the clock on one. Only ever one thing is pending at a time, so whoever
; calls this has already flushed or cancelled whatever was there before.
PendMark(kind, i, status) {
    global PendMarkKind, PendMarkTask, PendMarkStatus, MarkDelayMs
    PendMarkKind := kind, PendMarkTask := i, PendMarkStatus := status
    SetTimer, MarkTick, % -MarkDelayMs
}

CommitMark() {
    if (!PendMarkTask)
        return
    kind := PendMarkKind, i := PendMarkTask, st := PendMarkStatus
    PendMarkKind := "", PendMarkTask := 0, PendMarkStatus := ""
    SetTimer, MarkTick, Off
    if (kind = "H") {
        h := Habits[i]
        ; unticked again inside the window, or deleted: it never happened
        if (!h || !HabitDidToday(h))
            return
        Journal(Chr(0x2713) " habit: " h.text "   " Chr(0x00B7) " " h.streak " in a row")
        return
    }
    if (!Tasks[i])                  ; deleted inside the window: it never happened
        return
    t := Tasks[i]
    ; built from the task as it stands NOW, which is what lets a rename inside
    ; the window correct the line before it is ever written
    if (st = "add")
        Journal("+ added: " t.text ((t.list = "L") ? "   [long term]" : ""))
    else if (st = "unplanned")
        Journal(Chr(0x2713) " (unplanned) " t.text)
    else if (t.status = st)         ; changed its mind in the meantime: drop it
        Journal((st = "done" ? Chr(0x2713) : Chr(0x2717)) " " t.text)
}

; True if there WAS one to cancel, which is how a caller tells "undone inside
; the grace window, so write nothing" from "undone later, so say so".
CancelMark(kind, i) {
    global PendMarkKind, PendMarkTask, PendMarkStatus
    if (PendMarkKind != kind || PendMarkTask != i)
        return false
    PendMarkKind := "", PendMarkTask := 0, PendMarkStatus := ""
    SetTimer, MarkTick, Off
    return true
}

RowMenu(i) {
    global MenuTask
    MenuTask := i
    Menu, Row, Add, placeholder, MenuNoop     ; so DeleteAll cannot fail first time
    Menu, Row, DeleteAll
    Menu, Row, Add, Rename, MenuRename
    ; a MISSED task's note is asked for by its buttons, about the day it missed
    if (Tasks[i].list != "M")
        Menu, Row, Add, % (TaskNote(Tasks[i], CurDay) != "" ? "Edit note" : "Add a note"), MenuNote
    Menu, Row, Add, % (Tasks[i].list = "L" ? "Move to Today" : "Move to Long term"), MenuMove
    Menu, Row, Add, Delete, MenuDelete
    Menu, Row, Show
}

; Right-click a habit. Deleting one throws its streak away, which is a real
; loss, so it lives in a menu rather than beside the tick box.
HabMenu(i) {
    global MenuHabit
    MenuHabit := i
    Menu, Hab, Add, placeholder, MenuNoop     ; so DeleteAll cannot fail first time
    Menu, Hab, DeleteAll
    Menu, Hab, Add, Edit habit..., MenuHabEdit
    Menu, Hab, Add, Rename, MenuHabRename
    Menu, Hab, Add, Delete habit, MenuHabDelete
    Menu, Hab, Show
}

MenuHabEdit:
    HabEdShow(MenuHabit)
Return

MenuHabRename:
    StartHabitRename(MenuHabit)
Return

MenuHabDelete:
    HabitDelete(MenuHabit)
Return

MenuNoop:
Return

MenuRename:
    StartRename(MenuTask)
Return

MenuNote:
    EditNote(MenuTask)
Return

MenuMove:
    Tasks[MenuTask].list := (Tasks[MenuTask].list = "L") ? "T" : "L"
    SaveState()
    Refresh()
Return

MenuDelete:
    DeleteTask(MenuTask)
Return

; Opacity, and the row under the pointer. Polled rather than driven by
; WM_MOUSEMOVE, because the message that matters - the mouse LEAVING - never
; arrives, and in click-through mode no mouse messages arrive at all.
HoverCheck() {
    global Hot, HotCard
    if (!PanelVisible) {
        HoverTip(0)
        return
    }
    WinGetPos, px, py, pw, ph, ahk_id %PanelHwnd%
    if (px = "")
        return
    CoordMode, Mouse, Screen
    MouseGetPos, mx, my
    ; inside the rectangle AND not under another window - a panel buried under
    ; your app must not light up, or tip, for a pointer that is on that app
    inside := (mx >= px && mx <= px + pw && my >= py && my <= py + ph)
           && WindowSeenAt(PanelHwnd, mx, my)

    if (inside != Hot) {
        Hot := inside
        ; SOLID does not move at all, DIM comes forward, GHOST retreats
        a := !inside ? RestAlpha() : HotAlpha()
        WinSet, Transparent, %a%, ahk_id %PanelHwnd%
    }

    want := (inside && !Ghost()) ? CardUnderCursor() : 0
    if (want != HotCard) {
        was := HotCard
        HotCard := want                ; set first: OnErase reads it when painting
        InvalidateCard(was)
        InvalidateCard(want)
    }
    ; A dot says which day it is and what a click will do - the dots are
    ; buttons, and nothing else on the panel says so.
    tipKey := want
    if (inside && !Ghost() && IsObject(dot := DotAt(mx - px, my - py)))
        tipKey := "dot" dot.hab "|" dot.day
    HoverTip(tipKey)
}

; "Thu 24 Sep - missed. Click to mark it done."
DotHint(i, day) {
    global Habits
    h := Habits[i]
    if (!h)
        return ""
    today := LogicalDay()
    FormatTime, when, % StrReplace(day, "-"), ddd d MMM
    if (day = today)
        when := "today"
    st := HabitDayState(h, day, today)
    what := (st = "done") ? "done" : (st = "rest") ? "rest day"
          : (st = "todo") ? "not done yet" : (st = "off") ? "not needed" : "missed"
    act := HabitDid(h, day) ? "Click to take it back." : "Click to mark it done."
    return when " " Chr(0x2014) " " what ". " act "`nRight-click for the calendar."
}

; The whole name of a row that does not fit, and the task's note for today if
; it has one, once the pointer has rested on it for half a second - long enough
; that sweeping across the panel does not flicker a trail of tips behind it.
; A name that fits is not repeated: a tip saying exactly what the row already
; says is noise. Laid directly under the row, so it reads as part of it.
HoverTip(card) {
    global Cards, PanelHwnd, RowH, RowTask, CurDay
    static last := 0, since := 0, shown := false, up := false
    if (card != last) {
        if (shown)
            ToolTip, , , , 7
        last := card, since := A_TickCount, shown := false, up := false
        return
    }
    if (up)
        TipToFront()
    if (!card || shown || A_TickCount - since < 500)
        return
    shown := true                        ; asked once per rest, fits or not
    if (SubStr(card, 1, 3) = "dot") {
        StringSplit, dk, card, |
        tip := DotHint(SubStr(dk1, 4), dk2)
        if (tip != "") {
            CoordMode, ToolTip, Screen
            MouseGetPos, mx, my
            ToolTip, %tip%, % mx + 12, % my + 18, 7
            up := true
            TipToFront()
        }
        return
    }
    c := Cards[card]
    ctrl := (c.kind = "H" ? "HabTxt" : "RowTxt") c.pool
    GuiControlGet, hwnd, Panel:Hwnd, %ctrl%
    GuiControlGet, text, Panel:, %ctrl%
    GuiControlGet, p, Panel:Pos, %ctrl%
    tip := (text != "" && TextWidth(hwnd, text) > pW) ? text : ""
    if (c.kind = "T" && (t := Tasks[RowTask[c.pool]])) {
        ; a MISSED row says since when, and what its three buttons do
        if (t.list = "M")
            tip .= (tip != "" ? "`n" : "") "missed " MissSinceText(t.since) "   "
                .  Chr(0x2713) " did it   " Chr(0x2715) " drop   " Chr(0x2193) " to today"
        note := TaskNote(t, CurDay)
        if (note != "")
            tip .= (tip != "" ? "`n" : "") Chr(0x270E) " " WrapText(note, 60)
    }
    if (tip = "")
        return
    WinGetPos, wx, wy, , , ahk_id %PanelHwnd%
    CoordMode, ToolTip, Screen
    ToolTip, %tip%, % wx + pX, % wy + c.y + RowH, 7
    up := true
    TipToFront()
}

; Keep the tip in front of the panel. Both are topmost windows while the panel
; is on top, and between two topmost windows the one raised last wins - so a
; Relayout's Gui,Show, landing while a tip is up, would lift the panel over the
; tip that is laid across it. Asked again on every poll while the tip is up:
; HWND_TOPMOST, without moving, sizing or activating it (0x13).
TipToFront() {
    pid := DllCall("GetCurrentProcessId")
    if (tip := WinExist("ahk_class tooltips_class32 ahk_pid " pid))
        DllCall("SetWindowPos", "Ptr", tip, "Ptr", -1
            , "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x13)
}

; Break text into lines of about n characters at spaces. A tooltip does not
; wrap by itself, and a long note would otherwise be one line across the screen.
WrapText(s, n) {
    out := "", line := ""
    Loop, Parse, s, %A_Space%
    {
        if (line != "" && StrLen(line) + 1 + StrLen(A_LoopField) > n)
            out .= line "`n", line := A_LoopField
        else
            line .= (line != "" ? " " : "") A_LoopField
    }
    return out line
}

; How wide a line of text comes out in a control's own font, in pixels.
TextWidth(hwnd, text) {
    hdc  := DllCall("GetDC", "ptr", hwnd, "ptr")
    font := DllCall("SendMessage", "ptr", hwnd, "uint", 0x31, "ptr", 0, "ptr", 0, "ptr")   ; WM_GETFONT
    old  := DllCall("SelectObject", "ptr", hdc, "ptr", font, "ptr")
    VarSetCapacity(size, 8, 0)
    DllCall("GetTextExtentPoint32W", "ptr", hdc, "wstr", text, "int", StrLen(text), "ptr", &size)
    DllCall("SelectObject", "ptr", hdc, "ptr", old)
    DllCall("ReleaseDC", "ptr", hwnd, "ptr", hdc)
    return NumGet(size, 0, "int")
}

TogglePanel() {
    global PanelVisible
    if (PanelVisible && PanelIsMin())
        ShowPanel()                     ; minimised: the key brings it back
    else if (PanelVisible) {
        SaveIni()
        Gui, Panel:Hide
        PanelVisible := 0
    } else
        ShowPanel()
}

; Win+F6: hidden -> SOLID -> DIM -> GHOST -> hidden, one step a press. Coming
; back from hidden always lands on SOLID, the mode you can read and click.
CyclePanel() {
    global PanelVisible, PanelMode
    if (PanelVisible && PanelIsMin()) {
        ShowPanel()                     ; minimised: back as it was, mode and all
    } else if (!PanelVisible) {
        PanelMode := 0
        SetTrayMode()
        ShowPanel()                     ; applies the mode on its way up
        SaveIni()
    } else if (PanelMode = 2) {
        TogglePanel()
    } else {
        SetPanelMode(PanelMode + 1)
    }
}

