;================================================================================
; Quick capture - the whole point is that this takes under two seconds
;================================================================================
BuildCapture() {
    global
    Gui, Cap:New, +AlwaysOnTop -Caption +ToolWindow +HwndCapHwnd
    ShapeWindow(CapHwnd, PanelRound)     ; the same corners as the panel
    Gui, Cap:Margin, 12, 10
    ; The SECOND parameter is the one that matters. A per-control
    ; "Background" option is silently ignored on an Edit, which left a white
    ; box with near-white text in it - invisible while typing.
    Gui, Cap:Color, %CBg%, %CCard%
    Gui, Cap:Font, s10 Norm, Segoe UI
    ; Multi-line, so a long name WRAPS instead of sliding off to the left out
    ; of sight - and the box grows a line at a time to show all of it, see
    ; BoxFit(). No new lines can be typed into it: Enter is taken by the keys
    ; below before the box ever sees it. +0x40 is ES_AUTOVSCROLL, for text
    ; past the last line the box will grow to.
    Gui, Cap:Add, Edit, vCapEdit gCapGrow w360 h26 c%CText% -E0x200 +Multi -VScroll +0x40
    Gui, Cap:Font, s8, Segoe UI
    ; Two lines on purpose: on one line this hint was wider than the panel, and
    ; AutoSize then stretched the whole box past it.
    ; There is no "already did it" any more. A task starts open, always: the
    ; list is for what is still to do, and what already happened belongs in the
    ; journal - the JOURNAL heading on the panel.
    CapHintAdd := "Enter add   " Chr(0x00B7) " Esc cancel`n"
                . "Ctrl+Enter long term"
    Gui, Cap:Add, Text, vCapHint w360 c%CDim%, %CapHintAdd%
    BoxRemember("Cap")
}

;================================================================================
; Boxes that grow with what you type - the capture box and the note box
;================================================================================
; A one-line box whose start disappears off the left edge as you type is a box
; you cannot read back. These wrap instead, and the window grows downward a
; line at a time as the text needs it, up to BoxMaxLines; only past that does
; the text scroll, and then up and down, never sideways.
;
; Sizes here are real pixels, moved with MoveWindow, not Gui units: GuiControl
; Move would scale them by the screen's DPI a second time.
CapGrow:
    BoxFit("Cap")
Return

NoteGrow:
    BoxFit("Note")
Return

BoxWin(gui) {
    global CapHwnd, NoteHwnd
    return (gui = "Cap") ? CapHwnd : NoteHwnd
}

; The one-line shape the box was built with - what every show starts from.
BoxRemember(gui) {
    global BoxBase
    GuiControlGet, hEd, %gui%:Hwnd, %gui%Edit
    GuiControlGet, hHint, %gui%:Hwnd, %gui%Hint
    e := CtrlRect(hEd, BoxWin(gui)), t := CtrlRect(hHint, BoxWin(gui))
    BoxBase[gui] := {edH: e.h, hintY: t.y, pad: e.h - LineHeight(hEd)}
}

; Back to one line, before the window is shown again and sized to fit.
BoxReset(gui) {
    global BoxBase
    b := BoxBase[gui]
    GuiControlGet, hEd, %gui%:Hwnd, %gui%Edit
    GuiControlGet, hHint, %gui%:Hwnd, %gui%Hint
    e := CtrlRect(hEd, BoxWin(gui)), t := CtrlRect(hHint, BoxWin(gui))
    DllCall("MoveWindow", "ptr", hEd, "int", e.x, "int", e.y, "int", e.w, "int", b.edH, "int", 1)
    DllCall("MoveWindow", "ptr", hHint, "int", t.x, "int", b.hintY, "int", t.w, "int", t.h, "int", 1)
}

; As many lines as the text wraps to, and the window with it. The hint under
; the box moves down by the same amount, and the window grows at the bottom -
; unless that would take it off the screen, and then it moves up instead.
BoxFit(gui) {
    global BoxBase, BoxMaxLines
    hWin := BoxWin(gui)
    if (!DllCall("IsWindowVisible", "ptr", hWin))
        return                           ; sized when it is shown - see ShowCapture
    GuiControlGet, hEd, %gui%:Hwnd, %gui%Edit
    GuiControlGet, hHint, %gui%:Hwnd, %gui%Hint
    SendMessage, 0xBA, 0, 0, , ahk_id %hEd%      ; EM_GETLINECOUNT
    lines := ErrorLevel + 0
    lines := (lines < 1) ? 1 : (lines > BoxMaxLines) ? BoxMaxLines : lines
    want := lines * LineHeight(hEd) + BoxBase[gui].pad
    if (want < BoxBase[gui].edH)
        want := BoxBase[gui].edH
    e := CtrlRect(hEd, hWin)
    d := want - e.h
    if (!d)
        return
    t := CtrlRect(hHint, hWin)
    DllCall("MoveWindow", "ptr", hEd, "int", e.x, "int", e.y, "int", e.w, "int", want, "int", 1)
    DllCall("MoveWindow", "ptr", hHint, "int", t.x, "int", t.y + d, "int", t.w, "int", t.h, "int", 1)
    VarSetCapacity(r, 16, 0)
    DllCall("GetWindowRect", "ptr", hWin, "ptr", &r)
    x := NumGet(r, 0, "int"), y := NumGet(r, 4, "int")
    w := NumGet(r, 8, "int") - x, h := NumGet(r, 12, "int") - y + d
    ClampWin(x, y, w, h)
    DllCall("SetWindowPos", "ptr", hWin, "ptr", 0, "int", x, "int", y, "int", w, "int", h
          , "uint", 0x14)                ; SWP_NOZORDER | SWP_NOACTIVATE
    ; the caret's line has to be in view after the box changed size under it
    SendMessage, 0xB7, 0, 0, , ahk_id %hEd%      ; EM_SCROLLCARET
}

; A control's rectangle inside its window, in pixels: {x, y, w, h}.
CtrlRect(hCtrl, hWin) {
    VarSetCapacity(r, 16, 0)
    DllCall("GetWindowRect", "ptr", hCtrl, "ptr", &r)
    DllCall("MapWindowPoints", "ptr", 0, "ptr", hWin, "ptr", &r, "uint", 2)
    x := NumGet(r, 0, "int"), y := NumGet(r, 4, "int")
    return {x: x, y: y, w: NumGet(r, 8, "int") - x, h: NumGet(r, 12, "int") - y}
}

; The height of one line of text in a control's own font, in pixels.
LineHeight(hwnd) {
    hdc  := DllCall("GetDC", "ptr", hwnd, "ptr")
    font := DllCall("SendMessage", "ptr", hwnd, "uint", 0x31, "ptr", 0, "ptr", 0, "ptr")   ; WM_GETFONT
    old  := DllCall("SelectObject", "ptr", hdc, "ptr", font, "ptr")
    VarSetCapacity(tm, 64, 0)                    ; TEXTMETRICW
    DllCall("GetTextMetricsW", "ptr", hdc, "ptr", &tm)
    DllCall("SelectObject", "ptr", hdc, "ptr", old)
    DllCall("ReleaseDC", "ptr", hwnd, "ptr", hdc)
    return NumGet(tm, 0, "int")                  ; tmHeight
}

; User-initiated, so this one DOES take focus - you just asked for somewhere to
; type. Nothing that appears on its own ever takes it.
QuickAdd(list := "T") {
    global CapMode, CapTask, CapList, CapHintAdd
    CapMode := "add", CapTask := 0
    CapList := list                        ; plain Enter goes to whichever list
    ; A habit has nowhere else to go, so the three-way hint would be a lie -
    ; every Enter here makes a habit. See CommitAdd().
    if (list = "H")
        ShowCapture("", "Enter  a habit, every day from now on   "
                      . Chr(0x00B7) "   Esc cancel")
    else
        ShowCapture("", CapHintAdd)        ; the + you pressed belongs to
}

; Renaming a habit goes through the same box as everything else, and back out
; through the same Enter - CommitAdd() sorts out which it was.
StartHabitRename(i) {
    global CapMode, CapTask, Habits
    if (!Habits[i])
        return
    CapMode := "habit", CapTask := i
    ShowCapture(Habits[i].text, "Enter save   " Chr(0x00B7) " Esc cancel")
}

; Rename reuses the capture box rather than growing another window: same place,
; same key, already prefilled.
StartRename(i) {
    global CapMode, CapTask
    if (!Tasks[i])
        return
    CapMode := "rename", CapTask := i
    ShowCapture(Tasks[i].text, "Enter save   " Chr(0x00B7) " Esc cancel")
}

ShowCapture(prefill, hint) {
    global
    GuiControl, Cap:, CapEdit, %prefill%
    GuiControl, Cap:, CapHint, %hint%
    LivePanel(px, py, pw, ph)
    w := (pw > CapW) ? pw : CapW
    GuiControl, Cap:Move, CapEdit, % "w" (w - 24)
    GuiControl, Cap:Move, CapHint, % "w" (w - 24)
    x := px + pw - w
    y := py
    ClampWin(x, y, w, 76)
    BoxReset("Cap")                        ; one line, then grown to fit below
    Gui, Cap:Show, x%x% y%y% AutoSize, Daybook capture
    GuiControl, Cap:Focus, CapEdit
    if (prefill != "") {                   ; caret at the end, nothing selected,
        GuiControlGet, hEd, Cap:Hwnd, CapEdit    ; so you can tweak rather than
        SendMessage, 0xB1, -1, -1, , ahk_id %hEd%   ; retype (EM_SETSEL)
    }
    BoxFit("Cap")                          ; a long name being renamed shows whole
}

; The panel's ACTUAL position right now.
;
; PanelX/PanelY are only rewritten when something gets saved, so anything that
; positions itself against the panel has to ask the window rather than trust the
; variables - otherwise, after you drag the panel, these boxes keep opening at
; the old spot until you happen to collapse a section.
LivePanel(ByRef x, ByRef y, ByRef w, ByRef h) {
    global PanelHwnd, PanelX, PanelY, PanelW, PanelH
    WinGetPos, x, y, w, h, ahk_id %PanelHwnd%
    if (x = "")
        x := PanelX, y := PanelY, w := PanelW, h := PanelH
}

; Keep a popup inside the monitor it sits on. The panel lives against a screen
; edge by design, so a box placed relative to it will hang off the side unless
; something pulls it back.
ClampWin(ByRef x, ByRef y, w, h) {
    SysGet, count, MonitorCount
    best := 0
    cx := x + w // 2
    Loop % count {
        SysGet, m, MonitorWorkArea, %A_Index%
        if (cx >= mLeft && cx <= mRight && y >= mTop && y <= mBottom) {
            best := A_Index
            break
        }
    }
    SysGet, m, MonitorWorkArea, % best ? best : 1
    if (x + w > mRight)
        x := mRight - w
    if (x < mLeft)
        x := mLeft
    if (y + h > mBottom)
        y := mBottom - h
    if (y < mTop)
        y := mTop
}

#IfWinActive Daybook capture ahk_class AutoHotkeyGUI
Enter::CommitAdd("", "open")
NumpadEnter::CommitAdd("", "open")
^Enter::CommitAdd("L", "open")
^NumpadEnter::CommitAdd("L", "open")
Escape::CloseCapture()
#IfWinActive

CommitAdd(list, status) {
    global CapMode, CapTask, CapList
    GuiControlGet, txt, Cap:, CapEdit
    Gui, Cap:Hide
    if (CapMode = "rename") {              ; every Enter variant just saves here
        CapMode := "add"
        RenameTask(CapTask, txt)
        return
    }
    if (CapMode = "habit") {
        CapMode := "add"
        HabitRename(CapTask, txt)
        return
    }
    if (list = "")
        list := CapList
    ; Opened from the HABITS +, so Ctrl has nothing to offer: there is no
    ; other list to put it in.
    if (CapList = "H") {
        HabitAdd(txt)
        return
    }
    AddTask(txt, list, status)
}

CloseCapture() {
    global CapMode
    CapMode := "add"
    Gui, Cap:Hide
}

