;================================================================================
; Quick capture - the whole point is that this takes under two seconds
;================================================================================
#Requires AutoHotkey v2.0

BuildCapture() {
    global CapGui, CapHwnd, CapHintAdd
    g := Gui("+AlwaysOnTop -Caption +ToolWindow", "Daybook capture")
    CapGui := g, CapHwnd := g.Hwnd
    ShapeWindow(CapHwnd)     ; round, like the panel
    g.MarginX := 12, g.MarginY := 10
    g.BackColor := CBg
    g.SetFont("s10 Norm c" CText, "Segoe UI")
    ; Multi-line, so a long name WRAPS instead of sliding off to the left out
    ; of sight - and the box grows a line at a time to show all of it, see
    ; BoxFit(). No new lines can be typed into it: Enter is taken by the keys
    ; below before the box ever sees it. +0x40 is ES_AUTOVSCROLL, for text
    ; past the last line the box will grow to.
    e := g.Add("Edit", "vCapEdit w360 h26 -E0x200 +Multi -VScroll +0x40 Background" CCard)
    e.OnEvent("Change", (*) => BoxFit("Cap"))
    g.SetFont("s8 c" CDim, "Segoe UI")
    ; Two lines on purpose: on one line this hint was wider than the panel, and
    ; AutoSize then stretched the whole box past it.
    ; There is no "already did it" any more. A task starts open, always: the
    ; list is for what is still to do, and what already happened belongs in the
    ; journal - the JOURNAL heading on the panel.
    CapHintAdd := "Enter add   " Chr(0x00B7) " Esc cancel`n"
                . "Ctrl+Enter long term"
    g.Add("Text", "vCapHint w360", CapHintAdd)
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
; Sizes here are real pixels, moved with MoveWindow, not Gui units: a Gui's
; Move would scale them by the screen's DPI a second time.
BoxGui(which) => (which = "Cap") ? CapGui : NoteGui

; The one-line shape the box was built with - what every show starts from.
BoxRemember(which) {
    g := BoxGui(which)
    hEd := g[which "Edit"].Hwnd, hHint := g[which "Hint"].Hwnd
    e := CtrlRect(hEd, g.Hwnd), t := CtrlRect(hHint, g.Hwnd)
    BoxBase[which] := {edH: e.h, hintY: t.y, pad: e.h - LineHeight(hEd)}
}

; Back to one line, before the window is shown again and sized to fit.
BoxReset(which) {
    g := BoxGui(which)
    b := BoxBase[which]
    hEd := g[which "Edit"].Hwnd, hHint := g[which "Hint"].Hwnd
    e := CtrlRect(hEd, g.Hwnd), t := CtrlRect(hHint, g.Hwnd)
    DllCall("MoveWindow", "ptr", hEd, "int", e.x, "int", e.y, "int", e.w, "int", b.edH, "int", 1)
    DllCall("MoveWindow", "ptr", hHint, "int", t.x, "int", b.hintY, "int", t.w, "int", t.h, "int", 1)
}

; As many lines as the text wraps to, and the window with it. The hint under
; the box moves down by the same amount, and the window grows at the bottom -
; unless that would take it off the screen, and then it moves up instead.
BoxFit(which) {
    g := BoxGui(which)
    hWin := g.Hwnd
    if (!DllCall("IsWindowVisible", "ptr", hWin))
        return                           ; sized when it is shown - see ShowCapture
    hEd := g[which "Edit"].Hwnd, hHint := g[which "Hint"].Hwnd
    lines := SendMessage(0xBA, 0, 0, hEd)        ; EM_GETLINECOUNT
    lines := (lines < 1) ? 1 : (lines > BoxMaxLines) ? BoxMaxLines : lines
    want := lines * LineHeight(hEd) + BoxBase[which].pad
    if (want < BoxBase[which].edH)
        want := BoxBase[which].edH
    e := CtrlRect(hEd, hWin)
    d := want - e.h
    if (!d)
        return
    t := CtrlRect(hHint, hWin)
    DllCall("MoveWindow", "ptr", hEd, "int", e.x, "int", e.y, "int", e.w, "int", want, "int", 1)
    DllCall("MoveWindow", "ptr", hHint, "int", t.x, "int", t.y + d, "int", t.w, "int", t.h, "int", 1)
    r := Buffer(16, 0)
    DllCall("GetWindowRect", "ptr", hWin, "ptr", r)
    x := NumGet(r, 0, "int"), y := NumGet(r, 4, "int")
    w := NumGet(r, 8, "int") - x, h := NumGet(r, 12, "int") - y + d
    ClampWin(&x, &y, w, h)
    DllCall("SetWindowPos", "ptr", hWin, "ptr", 0, "int", x, "int", y, "int", w, "int", h
          , "uint", 0x14)                ; SWP_NOZORDER | SWP_NOACTIVATE
    ; the caret's line has to be in view after the box changed size under it
    SendMessage(0xB7, 0, 0, hEd)                 ; EM_SCROLLCARET
}

; A control's rectangle inside its window, in pixels: {x, y, w, h}.
CtrlRect(hCtrl, hWin) {
    r := Buffer(16, 0)
    DllCall("GetWindowRect", "ptr", hCtrl, "ptr", r)
    DllCall("MapWindowPoints", "ptr", 0, "ptr", hWin, "ptr", r, "uint", 2)
    x := NumGet(r, 0, "int"), y := NumGet(r, 4, "int")
    return {x: x, y: y, w: NumGet(r, 8, "int") - x, h: NumGet(r, 12, "int") - y}
}

; The height of one line of text in a control's own font, in pixels.
LineHeight(hwnd) {
    hdc  := DllCall("GetDC", "ptr", hwnd, "ptr")
    font := SendMessage(0x31, 0, 0, hwnd)        ; WM_GETFONT
    old  := DllCall("SelectObject", "ptr", hdc, "ptr", font, "ptr")
    tm   := Buffer(64, 0)                        ; TEXTMETRICW
    DllCall("GetTextMetricsW", "ptr", hdc, "ptr", tm)
    DllCall("SelectObject", "ptr", hdc, "ptr", old)
    DllCall("ReleaseDC", "ptr", hwnd, "ptr", hdc)
    return NumGet(tm, 0, "int")                  ; tmHeight
}

; User-initiated, so this one DOES take focus - you just asked for somewhere to
; type. Nothing that appears on its own ever takes it.
; prefill is for coming BACK to the box: Esc on the deadline calendar returns
; here with the words that were typed (see Due.ahk).
QuickAdd(list := "T", prefill := "") {
    global CapMode, CapTask, CapList
    CapMode := "add", CapTask := 0
    CapList := list                        ; plain Enter goes to whichever list
    ; A habit has nowhere else to go, so the three-way hint would be a lie -
    ; every Enter here makes a habit. See CommitAdd().
    if (list = "H")
        ShowCapture(prefill, "Enter  a habit, every day from now on   "
                      . Chr(0x00B7) "   Esc cancel")
    else if (list = "S")                   ; the deadline is asked for next
        ShowCapture(prefill, "Enter  then pick the deadline   "
                      . Chr(0x00B7) "   Esc cancel`nCtrl+Enter long term, no deadline")
    else
        ShowCapture(prefill, CapHintAdd)   ; the + you pressed belongs to
}

; Renaming a habit goes through the same box as everything else, and back out
; through the same Enter - CommitAdd() sorts out which it was.
StartHabitRename(i) {
    global CapMode, CapTask
    h := HabitAt(i)
    if (!h)
        return
    CapMode := "habit", CapTask := i
    ShowCapture(h.text, "Enter save   " Chr(0x00B7) " Esc cancel")
}

; Rename reuses the capture box rather than growing another window: same place,
; same key, already prefilled.
StartRename(i) {
    global CapMode, CapTask
    t := TaskAt(i)
    if (!t)
        return
    CapMode := "rename", CapTask := i
    ShowCapture(t.text, "Enter save   " Chr(0x00B7) " Esc cancel")
}

ShowCapture(prefill, hint) {
    g := CapGui
    g["CapEdit"].Value := prefill
    g["CapHint"].Text := hint
    LivePanel(&px, &py, &pw, &ph)
    w := (pw > CapW) ? pw : CapW
    g["CapEdit"].Move(, , w - 24)
    g["CapHint"].Move(, , w - 24)
    x := px + pw - w
    y := py
    ClampWin(&x, &y, w, 76)
    BoxReset("Cap")                        ; one line, then grown to fit below
    SideOnTop(g)
    g.Show("x" x " y" y " AutoSize")
    g["CapEdit"].Focus()
    if (prefill != "")                     ; caret at the end, nothing selected,
        SendMessage(0xB1, -1, -1, g["CapEdit"])   ; so you can tweak rather than retype (EM_SETSEL)
    BoxFit("Cap")                          ; a long name being renamed shows whole
}

; The panel's ACTUAL position right now.
;
; PanelX/PanelY are only rewritten when something gets saved, so anything that
; positions itself against the panel has to ask the window rather than trust the
; variables - otherwise, after you drag the panel, these boxes keep opening at
; the old spot until you happen to collapse a section.
LivePanel(&x, &y, &w, &h) {
    x := PanelX, y := PanelY, w := PanelW, h := PanelH
    try WinGetPos(&x, &y, &w, &h, PanelHwnd)
}

; Keep a popup inside the monitor it sits on. The panel lives against a screen
; edge by design, so a box placed relative to it will hang off the side unless
; something pulls it back.
ClampWin(&x, &y, w, h) {
    best := 0
    cx := x + w // 2
    loop MonitorGetCount() {
        MonitorGetWorkArea(A_Index, &mLeft, &mTop, &mRight, &mBottom)
        if (cx >= mLeft && cx <= mRight && y >= mTop && y <= mBottom) {
            best := A_Index
            break
        }
    }
    MonitorGetWorkArea(best ? best : MonitorGetPrimary(), &mLeft, &mTop, &mRight, &mBottom)
    if (x + w > mRight)
        x := mRight - w
    if (x < mLeft)
        x := mLeft
    if (y + h > mBottom)
        y := mBottom - h
    if (y < mTop)
        y := mTop
}

#HotIf WinActive("Daybook capture ahk_class AutoHotkeyGUI")
Enter::CommitAdd("", "open")
NumpadEnter::CommitAdd("", "open")
^Enter::CommitAdd("L", "open")
^NumpadEnter::CommitAdd("L", "open")
Escape::CloseCapture()
#HotIf

CommitAdd(list, status) {
    global CapMode
    txt := CapGui["CapEdit"].Value
    CapGui.Hide()
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
    ; From the SHORT TERM +, a task needs a day before it exists: the calendar
    ; opens, and the task is made when one is picked. Esc there adds nothing.
    if (CapList = "S" && list = "S") {
        txt := Trim(RegExReplace(txt, "[\r\n\t]+", " "))
        if (txt != "")
            DuePick("add", txt, 0)
        return
    }
    AddTask(txt, list, status)
}

CloseCapture() {
    global CapMode
    CapMode := "add"
    CapGui.Hide()
}
