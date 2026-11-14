;================================================================================
; Panel events
;================================================================================
#Requires AutoHotkey v2.0

; SaveIni() writes the position as well as the flag, so locking pins the spot
; the panel is standing on at the moment you press it.
ToggleLock() {
    global PanelLocked
    PanelLocked := !PanelLocked
    SaveIni()
    SetLockBtn()
}

; A heading was clicked: that section opens or closes.
ToggleOpen(which) {
    global OpenMissed, OpenToday, OpenShort, OpenLong, OpenStats, OpenHabits
    switch which {
        case "OpenMissed": OpenMissed := !OpenMissed
        case "OpenToday":  OpenToday := !OpenToday
        case "OpenShort":  OpenShort := !OpenShort
        case "OpenLong":   OpenLong := !OpenLong
        case "OpenStats":  OpenStats := !OpenStats
        case "OpenHabits": OpenHabits := !OpenHabits
    }
    SaveIni()
    Relayout()
}

; One click is the whole interaction: tick today off, or take it back. There is
; no cross and no note box - a habit you did not do today is simply not ticked,
; and tomorrow it asks again.
HabChkClick(n, *) {
    if (i := At(HabRow, n))
        HabitToggle(i)
}

; A short word beside the pointer, gone by itself - for a click that did
; something other than you might expect.
FreezeSay(msg) {
    CoordMode("ToolTip", "Screen")
    CoordMode("Mouse", "Screen")
    MouseGetPos(&mx, &my)
    ToolTip(msg, mx + 12, my + 18, 8)
    SetTimer(FreezeSayOff, -2800)
}

FreezeSayOff() {
    ToolTip(, , , 8)
}

; only on a MISSED row: back onto Today's list
RowGoClick(n, *) {
    i := At(RowTask, n)
    if (i && (t := TaskAt(i)) && t.list = "M")
        MissToToday(i)
}

; Right-click anywhere on a row.
;
; Hit-testing the pointer against the row rectangles, rather than asking which
; control was clicked: the name has no click handler, so it is transparent to
; the mouse and the right-click lands on the panel itself. This works over the
; text, the glyphs and the empty part of the card alike.
PnlContextMenu(*) {
    k := CardUnderCursor()
    if (!k)
        return
    card := Cards[k]
    if (card.kind = "H" && At(HabRow, card.pool))
        HabMenu(HabRow[card.pool])
    else if (card.kind = "T" && At(RowTask, card.pool))
        RowMenu(RowTask[card.pool])
}

; Minimised from the taskbar, and back. While it is down nothing lays it out
; (see the end of Relayout), so it is laid out once on the way back up - by
; then it is where it will be, so the room below it is measured right.
PnlSize(gui, minMax, w, h) {
    global PanelWasMin
    if (minMax = -1)
        PanelWasMin := 1
    else if (PanelWasMin) {
        PanelWasMin := 0
        Relayout()
    }
}

; Which card the pointer is over, as an index into Cards, or 0. Every card on
; the panel is in that one list whatever section it came from, so this answers
; for a habit exactly the way it answers for a task.
CardUnderCursor() {
    try WinGetPos(&px, &py, , , PanelHwnd)
    catch
        return 0
    CoordMode("Mouse", "Screen")
    MouseGetPos(, &my)
    ry := my - py
    for k, card in Cards
        if (ry >= card.y && ry < card.y + RowH)
            return k
    return 0
}

; The tick box. On a dropped task it shows the cross, and a click takes the
; drop back - the box undoes whatever mark it shows.
RowAction(n, status, *) {
    i := At(RowTask, n)
    t := TaskAt(i)
    if (!t)
        return
    if (status = "done" && t.status = "failed")
        status := "failed"
    TaskMark(i, status, At(RowY, n))
}

; Tick (done) or drop (failed) a task, or - the same mark again - take it back.
; The tick box and the right-click menu's "Drop" both come here.
TaskMark(i, status, y := 0) {
    t := TaskAt(i)
    if (!t)
        return
    ; A MISSED task is not ticked or dropped where it stands - the tick asks
    ; which day, a drop asks before it happens. See Missed.ahk.
    if (t.list = "M") {
        if (status = "done")
            MissDidMenu(i)
        else
            MissDropAsk(i, y)
        return
    }
    if (t.status = status) {                 ; the same mark again undoes it
        ; Inside the grace window nothing was written, so nothing is. Past it
        ; the mark is on disk, and the honest thing is to say it was taken back
        ; - otherwise the log says done about a task that is open again.
        if (!CancelMark("T", i))
            Journal(Chr(0x21BA) " reopened: " t.text)
        SetStatus(i, "open")
        return
    }
    ; Tick, then drop, on the SAME task inside the grace window: that is one
    ; decision corrected, not two, so the tick is dropped rather than written.
    ; A pending "add" is kept - the task still exists, only its mark changed.
    if (PendMarkKind = "T" && PendMarkTask = i
        && (PendMarkStatus = "done" || PendMarkStatus = "failed"))
        CancelMark("T", i)
    else
        CommitMark()                         ; a different row was still pending
    SetStatus(i, status)
    PendMark("T", i, status)
    OpenNote(i, status, y)
}

; A tick or a cross is NOT written to the log at the moment you click it.
;
; The log is append-only, which is what makes it crash-proof - but it also
; means a misclick is permanent, and unticking cannot take it back. So the
; line is held for MarkDelayMs first: undo inside that window and nothing is
; ever written. Past it the record stands, because by then it was a decision
; rather than a slip.
;
; Esc on the note box deliberately does NOT commit early. It only means "no
; note"; the grace period keeps running, so Esc is still undoable.
; Start the clock on one. Only ever one thing is pending at a time, so whoever
; calls this has already flushed or cancelled whatever was there before.
PendMark(kind, i, status) {
    global PendMarkKind, PendMarkTask, PendMarkStatus
    PendMarkKind := kind, PendMarkTask := i, PendMarkStatus := status
    SetTimer(MarkTick, -MarkDelayMs)
}

CommitMark() {
    global PendMarkKind, PendMarkTask, PendMarkStatus
    if (!PendMarkTask)
        return
    kind := PendMarkKind, i := PendMarkTask, st := PendMarkStatus
    PendMarkKind := "", PendMarkTask := 0, PendMarkStatus := ""
    SetTimer(MarkTick, 0)
    if (kind = "H") {
        h := HabitAt(i)
        ; unticked again inside the window, or deleted: it never happened
        if (!h || !HabitDidToday(h))
            return
        Journal(Chr(0x2713) " habit: " h.text "   " Chr(0x00B7) " " h.streak " in a row")
        return
    }
    t := TaskAt(i)
    if (!t)                         ; deleted inside the window: it never happened
        return
    ; built from the task as it stands NOW, which is what lets a rename inside
    ; the window correct the line before it is ever written
    if (st = "add")
        Journal("+ added: " t.text ((t.list = "L") ? "   [long term]"
              : (t.list = "S") ? "   [short term" (t.due != "" ? ", due " t.due : "") "]" : ""))
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
    SetTimer(MarkTick, 0)
    return true
}

; The menus are made again each time, and kept until the next one: a menu
; freed before its click arrives loses the click.
RowMenu(i) {
    global MenuTask
    static m := ""
    t := TaskAt(i)
    if (!t)
        return
    MenuTask := i
    m := Menu()
    m.Add("Rename", (*) => StartRename(MenuTask))
    ; a MISSED task's note is asked for by its buttons, about the day it missed
    if (t.list != "M")
        m.Add((TaskNote(t, CurDay) != "" ? "Edit note" : "Add a note"), (*) => EditNote(MenuTask))
    ; Where it can go. Short term needs a day, so it opens the calendar first and
    ; the task only moves once one is picked.
    l := t.list
    m.Add((l = "S") ? "Change the deadline..." : "Move to Short term..."
        , (*) => (TaskAt(MenuTask) ? DuePick("move", "", Tasks[MenuTask].id) : 0))
    if (l = "L" || l = "S")
        m.Add("Move to Today", (*) => TaskMoveTo(MenuTask, "T"))
    if (l != "L")
        m.Add("Move to Long term", (*) => TaskMoveTo(MenuTask, "L"))
    ; Two ways to be rid of a task, and they are not the same. Drop keeps a
    ; record - the day's note shows it crossed, with why - and Delete keeps
    ; none, for a task that should never have been there.
    m.Add()
    if (t.status = "failed")
        m.Add("Undo the drop", (*) => TaskMark(MenuTask, "failed"))
    else
        m.Add("Drop - it won't happen...", (*) => TaskMark(MenuTask, "failed", RowYOf(MenuTask)))
    m.Add("Delete - added by mistake", (*) => DeleteTask(MenuTask))
    m.Show()
}

; Right-click a habit. Deleting one throws its streak away, which is a real
; loss, so it lives in a menu rather than beside the tick box.
HabMenu(i) {
    global MenuHabit
    static m := ""
    MenuHabit := i
    m := Menu()
    m.Add("Edit habit...", (*) => HabEdShow(MenuHabit))
    m.Add("Rename", (*) => StartHabitRename(MenuHabit))
    m.Add("Delete habit", (*) => HabitDelete(MenuHabit))
    m.Show()
}

; Opacity, and the row under the pointer. Polled rather than driven by
; WM_MOUSEMOVE, because the message that matters - the mouse LEAVING - never
; arrives, and in click-through mode no mouse messages arrive at all.
HoverCheck() {
    global Hot, HotCard
    if (!PanelVisible) {
        HoverTip(0)
        return
    }
    try WinGetPos(&px, &py, &pw, &ph, PanelHwnd)
    catch
        return
    CoordMode("Mouse", "Screen")
    MouseGetPos(&mx, &my)
    ; inside the rectangle AND not under another window - a panel buried under
    ; your app must not light up, or tip, for a pointer that is on that app
    inside := (mx >= px && mx <= px + pw && my >= py && my <= py + ph)
           && WindowSeenAt(PanelHwnd, mx, my)

    if (inside != Hot) {
        Hot := inside
        ; SOLID does not move at all, DIM comes forward, GHOST retreats
        try WinSetTransparent(!inside ? RestAlpha() : HotAlpha(), PanelHwnd)
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
    h := HabitAt(i)
    if (!h)
        return ""
    today := LogicalDay()
    when := (day = today) ? "today" : DayWords(day, "ddd d MMM")
    st := HabitDayState(h, day, today)
    what := (st = "done") ? "done" : (st = "rest") ? "rest day"
          : (st = "todo") ? "not done yet" : (st = "off") ? "not needed" : "missed"
    ; what the NEXT click does: done -> frozen -> not done (HabitCycleDay)
    act := (st = "rest") ? "Click to take the freeze back."
         : !HabitDid(h, day) ? "Click to mark it done."
         : HabitRestLeft(h, day) ? "Click to freeze it instead."
         : "Click to take it back."
    return when " " Chr(0x2014) " " what ". " act "`nRight-click for the calendar."
}

; The whole name of a row that does not fit, and the task's note for today if
; it has one, once the pointer has rested on it for half a second - long enough
; that sweeping across the panel does not flicker a trail of tips behind it.
; A name that fits is not repeated: a tip saying exactly what the row already
; says is noise. Laid directly under the row, so it reads as part of it.
HoverTip(card) {
    static last := 0, since := 0, shown := false, up := false
    if (String(card) != String(last)) {
        if (shown)
            ToolTip(, , , 7)
        last := card, since := A_TickCount, shown := false, up := false
        return
    }
    if (up)
        TipToFront()
    if (!card || shown || A_TickCount - since < 500)
        return
    shown := true                        ; asked once per rest, fits or not
    if (SubStr(card, 1, 3) = "dot") {
        dk := StrSplit(SubStr(card, 4), "|")
        tip := DotHint(Integer(dk[1]), dk[2])
        if (tip != "") {
            CoordMode("ToolTip", "Screen")
            CoordMode("Mouse", "Screen")
            MouseGetPos(&mx, &my)
            ToolTip(tip, mx + 12, my + 18, 7)
            up := true
            TipToFront()
        }
        return
    }
    if (card > Cards.Length)
        return
    c := Cards[card]
    ctrl := PanelGui[(c.kind = "H" ? "HabTxt" : "RowTxt") c.pool]
    text := ctrl.Text
    ctrl.GetPos(&cX, , &cW)
    tip := (text != "" && TextWidth(ctrl.Hwnd, text) > cW) ? text : ""
    if (c.kind = "T" && (t := TaskAt(At(RowTask, c.pool)))) {
        ; a MISSED row says since when, and what its two buttons do
        if (t.list = "M")
            tip .= (tip != "" ? "`n" : "") "missed " MissSinceText(t.since) "   "
                .  Chr(0x2713) " did it   " Chr(0x2193) " to today   right-click: drop"
        ; a short term row says the day, whole - the tag in front only has room
        ; for "3d"
        if (t.list = "S")
            tip .= (tip != "" ? "`n" : "") ((t.due != "") ? "due " DueText(t.due) : "no deadline")
        note := TaskNote(t, CurDay)
        if (note != "")
            tip .= (tip != "" ? "`n" : "") Chr(0x270E) " " WrapText(note, 60)
    }
    if (tip = "")
        return
    try WinGetPos(&wx, &wy, , , PanelHwnd)
    catch
        return
    CoordMode("ToolTip", "Screen")
    ToolTip(tip, wx + cX, wy + c.y + RowH, 7)
    up := true
    TipToFront()
}

; Keep the tip in front of the panel. Both are topmost windows while the panel
; is on top, and between two topmost windows the one raised last wins - so a
; Relayout's Show, landing while a tip is up, would lift the panel over the
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
    loop parse s, " " {
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
    font := SendMessage(0x31, 0, 0, hwnd)                       ; WM_GETFONT
    old  := DllCall("SelectObject", "ptr", hdc, "ptr", font, "ptr")
    size := Buffer(8, 0)
    DllCall("GetTextExtentPoint32W", "ptr", hdc, "wstr", text, "int", StrLen(text), "ptr", size)
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
        PanelGui.Hide()
        PanelVisible := 0
    } else
        ShowPanel()
}

; The panel key: hidden -> SOLID -> DIM -> GHOST -> hidden, one step a press.
; Coming back from hidden always lands on SOLID, the mode you can read and
; click.
CyclePanel() {
    global PanelMode
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
