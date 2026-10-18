;================================================================================
; SettingsWin.ahk - the settings window, tray menu > Settings
;================================================================================
; Every setting in Daybook.ini, in one dark window, saved as you change it and
; in force the moment it is saved. There is no OK button and nothing to apply:
; type 40 into "red after" and the bar is a 40-minute bar before you have let
; go of the key.
;
; The window is BUILT FROM A TABLE. SetupTable() lists every setting once - its
; section and key in the .ini, the variable it lives in while the script runs,
; its label, its unit and one line of help - and both the layout and the saving
; walk that same list. Adding a setting is one line there and one line in
; Ini.ahk; there is no third place to forget.
;
; It writes the .ini and sets the variable. It does NOT reread the file, so a
; value typed here and a value typed in Notepad arrive at the same place by
; different roads - which is why the file is still worth opening, and why "Edit
; Daybook.ini" is at the bottom of this window. The one difference: the file is
; read once, at start, so Notepad needs a reload and this does not.
;
; WHAT IT LOOKS LIKE. The panel's palette, a dark title bar, and the yes/no
; switches are the panel's clickable words rather than real checkboxes - a
; Windows checkbox on a background this dark is a white square with a white
; tick in it, and reads as something that failed to load.
;
; The kinds a row can be:
;   head   a section title, no control
;   num    a number, with its unit beside it
;   bool   yes / no, clicked to swap
;   path   a folder or a file, the full width, with a picker beside it
;
; IT SCROLLS, and it has to: the table is meant to be added to, and a settings
; window that grows off the bottom of a laptop screen loses the settings at the
; bottom with no way to reach them. It opens as tall as its content or as tall
; as the screen has room for, whichever is less, and can be dragged taller and
; shorter - but only ever 620 wide, because the hints are written to that width.
; Scrolling is the real thing, bar and wheel both: SetupScrollTo moves every
; control at once with ScrollWindowEx rather than putting a child window inside
; a frame, which in v1 is far less to go wrong.
;
; The bar is PAINTED, not a Windows scrollbar - the same three-pixel strip the
; panel draws down its right margin, because the two windows belong to the same
; program and a grey system scrollbar in one of them says otherwise. It is
; drawn in SetupErase and dragged in SetupBarClick.
;================================================================================

; SetupHwnd, SetupBuilt and SetupRows are declared in State.ahk with everything
; else the script keeps, and for a reason worth knowing: a "global x := 1" in
; THIS file would be read as a declaration and never actually run, because
; every file below Start.ahk is past the Return that ends the auto-execute
; section. The variable would exist and be empty. The measurements below are
; locals inside SetupBuild() for the same reason.

; Every setting there is. The order here is the order on screen.
;
;   sect / key  where it goes in Daybook.ini
;   var         the variable the rest of the script reads
;   mul         what the typed number is multiplied by to reach that variable,
;               for the two that are kept in milliseconds
SetupTable() {
    d := []
    d.Push({kind: "head", label: "GENERAL"})
    d.Push({kind: "bool", sect: "General", key: "RunAsAdmin", var: "RunAsAdmin"
          , label: "Start as administrator"
          , hint: "So Win+F6 and Win+F1 keep working over elevated windows."
                . " From the next start."})

    d.Push({kind: "head", label: "THE JOURNAL"})
    d.Push({kind: "bool", sect: "Journal", key: "Write", var: "JournalOn"
          , label: "Keep a journal"
          , hint: "A note a day: your journal on top, Daybook's summary under it."
                . " No: nothing is written, and JOURNAL leaves the panel."})
    d.Push({kind: "bool", sect: "Journal", key: "Board", var: "BoardOn"
          , label: "Write Daybook.md"
          , hint: "Where things stand: your lists, the streaks, two weeks of"
                . " habits. Rewritten as things change."})
    d.Push({kind: "bool", sect: "Journal", key: "RollUp", var: "RollupOn"
          , label: "Weeks and months"
          , hint: "A note for each week, month and year, from the day notes. A month"
                . " that is over moves into a folder: 2026\2026-10 October."})
    d.Push({kind: "path", sect: "Journal", key: "Folder", var: "JournalDir"
          , label: "Folder", pick: "folder"
          , hint: "One YYYY-MM-DD.md per day goes here. It has to exist already"
                . " - pick makes one."})
    d.Push({kind: "num", sect: "Journal", key: "DayStartsAtHour", var: "DayStartHour"
          , label: "A day starts at", unit: "o'clock"
          , hint: "0-23. At 3, a session at 2am still belongs to yesterday."})

    d.Push({kind: "head", label: "THE SIT TIMER"})
    d.Push({kind: "num", sect: "Timer", key: "AmberAfterMin", var: "SitWarnMin"
          , label: "Amber after", unit: "minutes"
          , hint: "The bar stops being green."})
    d.Push({kind: "num", sect: "Timer", key: "RedAfterMin", var: "SitBreakMin"
          , label: "Red after", unit: "minutes"
          , hint: "It goes red and breathes, and the digits start counting up."})
    d.Push({kind: "num", sect: "Timer", key: "BreakMin", var: "BreakLenMin"
          , label: "A break is", unit: "minutes"
          , hint: "Away this long clears the clock. Less only pauses it, and the"
                . " digits then say the break was cut short."})
    d.Push({kind: "num", sect: "Timer", key: "StopBreathingAfterMin", var: "RedQuietMin"
          , label: "Stop breathing after", unit: "minutes"
          , hint: "Of no input at all. Pulsing at an empty chair is what makes"
                . " people turn things like this off."})
    d.Push({kind: "bool", sect: "Timer", key: "MouseMovementCounts", var: "CountMouseMove"
          , label: "Mouse moving counts"
          , hint: "Yes: reading with a hand on the mouse is sitting. A break you"
                . " declared still only ends on a key or a click."})
    d.Push({kind: "num", sect: "Timer", key: "SoundKeepsYouHereMin", var: "AudioCapMin"
          , label: "Sound holds you", unit: "minutes"
          , hint: "Sound on any output device counts as being here, for this"
                . " long. 0 ignores sound. A dark screen always wins."})
    d.Push({kind: "num", sect: "Timer", key: "SoundHoldSec", var: "SoundHoldS"
          , label: "Silence allowed", unit: "seconds"
          , hint: "A gap between songs, or a pause in speech, is not silence."})
    d.Push({kind: "num", sect: "Timer", key: "BreakGuardSec", var: "BreakGuardS"
          , label: "Ignore input for", unit: "seconds"
          , hint: "After Win+F1. Without it the key that starts a break ends it."})

    d.Push({kind: "head", label: "HABITS"})
    d.Push({kind: "num", sect: "Habits", key: "DaysShown", var: "HabitDays"
          , label: "Days of dots", unit: "days"
          , hint: "The run of dots on a habit row, today last. 0 hides them and"
                . " gives the room to the name."})
    d.Push({kind: "num", sect: "Habits", key: "RestDaysPerMonth", var: "RestPerMonth"
          , label: "Rest days a month", unit: "per habit"
          , hint: "Sick, away, a day off: a rest day keeps the streak without"
                . " adding to it. 0 turns them off."})

    d.Push({kind: "head", label: "THE APP LOG"})
    d.Push({kind: "bool", sect: "Log", key: "LogApps", var: "LogApps"
          , label: "Record what is in front"
          , hint: "Process names only, and only while you are at the desk."})
    d.Push({kind: "num", sect: "Log", key: "SampleSec", var: "SampleMs", mul: 1000
          , label: "Look every", unit: "seconds"
          , hint: "5 is the fastest it will go. Finer buys nothing at day scale."})
    d.Push({kind: "num", sect: "Log", key: "AppsListed", var: "StatsTop"
          , label: "Programs listed", unit: "of them"
          , hint: "How many lines TIME AT THE MACHINE opens to."})

    d.Push({kind: "head", label: "THE PANEL"})
    d.Push({kind: "num", sect: "Look", key: "FadedAlpha", var: "PanelAlpha"
          , label: "Faded to", unit: "of 255"
          , hint: "How faint DIM and GHOST are with the pointer somewhere else."
                . " Lower is fainter. SOLID is always solid."})
    d.Push({kind: "num", sect: "Look", key: "WidthPx", var: "PanelW"
          , label: "Panel width", unit: "pixels"
          , hint: "240 to 700. Everything in the panel is spaced from this."
                . " Takes a reload, unlike the rest of this window."})
    d.Push({kind: "num", sect: "Look", key: "MaxHeightPx", var: "PanelMaxH"
          , label: "Tallest it gets", unit: "pixels"
          , hint: "Past this the panel scrolls instead of growing. 0 is as"
                . " much of the screen as there is below it."})
    d.Push({kind: "bool", sect: "Look", key: "RoundedCorners", var: "PanelRound"
          , label: "Rounded corners"
          , hint: "Every window here at once, this one included. Windows 10 has"
                . " no such thing and ignores it."})
    d.Push({kind: "bool", sect: "Look", key: "Taskbar", var: "PanelTaskbar"
          , label: "On the taskbar"
          , hint: "A taskbar button and Alt+Tab, like any window. Off, it is an"
                . " overlay that never takes the keyboard."})
    d.Push({kind: "num", sect: "Look", key: "UndoSec", var: "MarkDelayMs", mul: 1000
          , label: "Undo window", unit: "seconds"
          , hint: "How long a tick or a cross stays yours to take back, before"
                . " it is written to the journal."})
    ; The tray icon is deliberately NOT here. It is a thing you set once, if
    ; ever, and a file picker for it earned less than the room it took. It is
    ; still in Daybook.ini under [Files], where the rest of its explanation is.
    return d
}

;================================================================================
; Building it
;================================================================================
SetupShow() {
    global SetupBuilt, SetupHwnd, SetupContentH, SetupW
    if (!SetupBuilt)
        SetupBuild()
    SetupLoad()
    if (DllCall("IsWindowVisible", "ptr", SetupHwnd)) {
        WinActivate, ahk_id %SetupHwnd%
        return
    }
    ; As tall as it needs, or as tall as this screen has room for. The 96 is a
    ; title bar plus enough margin that the window does not look wedged in.
    SysGet, wa, MonitorWorkArea
    h := SetupContentH
    room := waBottom - waTop - 96
    if (h > room)
        h := room
    Gui, Setup:Show, % "w" SetupW " h" h, Daybook settings
    SetupScrollTo(SetupScrollY)          ; works out the new maximum
    SetupRedraw()
}

; Laid out once, top to bottom, from the table. Every Gui,Add here builds its
; options into one string first: the options are the THIRD parameter and the
; text is the fourth, and mixing an expression into the middle of a command
; parameter is the reliable way to put a control somewhere it was not meant.
SetupBuild() {
    global
    local n, d, y, opt, pickLbl
    ; How wide everything is. The window does not resize: the hints are written
    ; to fit, and a window you can drag narrow is a window that can hide them.
    local W      := SetupW
    local lblX   := 22,  lblW  := 126
    local ctlX   := 156, ctlW  := 56
    local unitX  := 220, unitW := 60
    local hintX  := 286, hintW := 292
    local pathW  := 368              ; a path box, starting at ctlX
    local rowH   := 34, headH := 28, pathH := 52
    SetupRows := SetupTable()
    ; +Resize for the height; MinSize and MaxSize then pin the width to exactly
    ; what the hints were written for. No WS_VSCROLL: the bar is painted rather
    ; than a control, so the client area never changes width and no hint reflows.
    ; +LabelSetup, spelled out. A named Gui does NOT bind SetupClose /
    ; SetupEscape / SetupSize on the strength of its name alone - without this
    ; the window ignores Escape, ignores its own close button, and never hears
    ; that it has been resized. Panel.ahk says +LabelPnl for the same reason.
    Gui, Setup:New, +Resize -MaximizeBox +LabelSetup +HwndSetupHwnd, Daybook settings
    TaskbarId(SetupHwnd, "Ahk.Daybook")   ; under the panel's taskbar button
    Gui, Setup:Margin, 0, 0
    ; the second colour is the one Edit controls use - see BuildCapture()
    Gui, Setup:Color, %CBg%, %CCard%

    Gui, Setup:Font, s12 Bold c%CText%, Segoe UI
    opt := "x" lblX " y16 w320 BackgroundTrans"
    Gui, Setup:Add, Text, %opt%, Daybook settings
    Gui, Setup:Font, s8 Norm c%CMuted%, Segoe UI
    opt := "x" lblX " y44 w420 BackgroundTrans"
    Gui, Setup:Add, Text, %opt%, Saved as you change them, and in force straight away.
    Gui, Setup:Font, s8 Norm c%CDim%, Segoe UI
    opt := "x" (W - 180) " y20 w150 Right BackgroundTrans"
    Gui, Setup:Add, Text, %opt%, % "Daybook " DaybookVersion

    y := 76
    for n, d in SetupRows {
        if (d.kind = "head") {
            ; Blue, and a hairline under it - the same shape Vocab's settings
            ; window uses, so the two look like they were made by one person.
            Gui, Setup:Font, s8 Bold c%CBlue%, Segoe UI
            opt := "x" lblX " y" y " w420 BackgroundTrans"
            Gui, Setup:Add, Text, %opt%, % d.label
            ; a Progress bar: the one control v1 will fill with a colour - a
            ; Text with "Background" silently draws nothing (see HabEdRect)
            opt := "x" lblX " y" (y + 17) " w" (hintX + hintW - lblX)
                 . " h1 Disabled -E0x200 -Theme Background" CTrack " c" CTrack
            Gui, Setup:Add, Progress, %opt%, 0
            y += headH
            continue
        }

        Gui, Setup:Font, s9 Norm c%CText%, Segoe UI
        opt := "x" lblX " y" (y + 4) " w" lblW " BackgroundTrans"
        Gui, Setup:Add, Text, %opt%, % d.label

        if (d.kind = "path") {
            opt := "vSetupV" n " gSetupChanged -E0x200 x" ctlX
                 . " y" y " w" pathW " h22"
            Gui, Setup:Add, Edit, %opt%
            Gui, Setup:Font, s8 Norm c%CDim%, Segoe UI
            pickLbl := (d.pick = "folder") ? "gSetupPickFolder" : "gSetupPickFile"
            opt := pickLbl " x" (ctlX + pathW + 12) " y" (y + 6)
                 . " w40 h16 BackgroundTrans"
            Gui, Setup:Add, Text, %opt%, pick
            opt := "x" ctlX " y" (y + 27) " w" (pathW + 52)
                 . " h16 BackgroundTrans"
            Gui, Setup:Add, Text, %opt%, % d.hint
            y += pathH
            continue
        }

        if (d.kind = "bool") {
            ; a clickable word, not a checkbox - see the note at the top
            Gui, Setup:Font, s9 Norm c%CGreen%, Segoe UI
            opt := "vSetupV" n " gSetupToggle x" ctlX " y" (y + 4)
                 . " w" ctlW " h18 BackgroundTrans"
            Gui, Setup:Add, Text, %opt%, yes
        } else {
            opt := "vSetupV" n " gSetupChanged Number Limit4 -E0x200 x" ctlX
                 . " y" y " w" ctlW " h22"
            Gui, Setup:Add, Edit, %opt%
            Gui, Setup:Font, s8 Norm c%CDim%, Segoe UI
            opt := "x" unitX " y" (y + 6) " w" unitW " h16 BackgroundTrans"
            Gui, Setup:Add, Text, %opt%, % d.unit
        }
        Gui, Setup:Font, s8 Norm c%CDim%, Segoe UI
        opt := "x" hintX " y" (y + 1) " w" hintW " h30 BackgroundTrans"
        Gui, Setup:Add, Text, %opt%, % d.hint
        y += rowH
    }

    ; ---- the footer: where these same settings live as plain text, and the one
    ;      line that says whether the last change landed
    y += 8
    Gui, Setup:Font, s8 Norm c%CDim%, Segoe UI
    opt := "gSetupOpenIni x" lblX " y" y " w180 h16 BackgroundTrans"
    Gui, Setup:Add, Text, %opt%, Edit Daybook.ini instead
    opt := "vSetupNote x" (W - 244) " y" y " w220 h16 Right BackgroundTrans"
    Gui, Setup:Add, Text, %opt%
    y += 28

    SetupContentH := y
    SetupDark(SetupHwnd)
    ShapeWindow(SetupHwnd, PanelRound)   ; the same corners as the panel
    Gui, Setup:+MinSize%W%x240
    Gui, Setup:+MaxSize%W%x
    OnMessage(0x20A, "SetupWheel")       ; WM_MOUSEWHEEL
    Gui, Setup:Show, Hide w%W% h%y%, Daybook settings
    SetupBuilt := 1
}

;================================================================================
; Scrolling
;================================================================================
; Everything in the window is a real control on one window, so scrolling is
; moving all of them together - ScrollWindowEx with SW_SCROLLCHILDREN does
; exactly that, and invalidates the strip it uncovered so Windows repaints the
; background there. No child frame, no second Gui, nothing to keep in step.
SetupScrollTo(pos) {
    global SetupHwnd, SetupScrollY
    max := SetupMaxScroll()
    if (pos < 0)
        pos := 0
    if (pos > max)
        pos := max
    dy := SetupScrollY - pos             ; positive = the content moves down
    SetupScrollY := pos
    if (dy)
        DllCall("ScrollWindowEx", "ptr", SetupHwnd, "int", 0, "int", dy
              , "ptr", 0, "ptr", 0, "ptr", 0, "ptr", 0, "uint", 0x0007)
                                         ; SW_SCROLLCHILDREN|SW_INVALIDATE|SW_ERASE
    ; ScrollWindowEx moved the painted bar along with everything else, so the
    ; strip it lives in has to be drawn again where it belongs.
    SetupBarRedraw()
}

; Just the right-hand margin, which is the only part of the background that has
; anything on it. Repainting the whole window on every notch would flicker.
SetupBarRedraw() {
    global SetupHwnd
    VarSetCapacity(rc, 16, 0)
    DllCall("GetClientRect", "ptr", SetupHwnd, "ptr", &rc)
    NumPut(NumGet(rc, 8, "int") - 14, rc, 0, "int")
    DllCall("InvalidateRect", "ptr", SetupHwnd, "ptr", &rc, "int", true)
}

; The background of the settings window, painted by hand so the scroll bar can
; be painted with it. Reached from OnErase, which is the one WM_ERASEBKGND
; handler this script is allowed to have - see the note there.
SetupErase(hdc) {
    global SetupHwnd, SetupContentH, SetupScrollY
    global CBg, CTrack, CDim
    VarSetCapacity(rc, 16, 0)
    DllCall("GetClientRect", "ptr", SetupHwnd, "ptr", &rc)
    cw := NumGet(rc, 8, "int"), ch := NumGet(rc, 12, "int")
    FillRc(hdc, rc, CBg)
    max := (SetupContentH > ch) ? SetupContentH - ch : 0
    if (max > 0) {
        thumb := Round(ch * ch / SetupContentH)
        if (thumb < 24)
            thumb := 24
        span := ch - 16 - thumb
        if (span < 0)
            span := 0
        pos := (SetupScrollY > max) ? max : SetupScrollY
        ty := 8 + Round(span * pos / max)
        NumPut(cw - 9, rc, 0, "int"), NumPut(8,           rc, 4,  "int")
        NumPut(cw - 6, rc, 8, "int"), NumPut(ch - 8,      rc, 12, "int")
        FillRc(hdc, rc, CTrack)
        NumPut(cw - 9, rc, 0, "int"), NumPut(ty,          rc, 4,  "int")
        NumPut(cw - 6, rc, 8, "int"), NumPut(ty + thumb,  rc, 12, "int")
        FillRc(hdc, rc, CDim)
    }
    return 1
}

; Click or drag anywhere on the painted bar. One gesture rather than the three
; a real scrollbar has - no arrows, no page-up strip - because there is nothing
; here long enough to need them: grab it and it follows the pointer, tap it and
; it goes there.
SetupBarClick(cx, cy) {
    global SetupHwnd, SetupContentH
    max := SetupMaxScroll()
    if (max <= 0)
        return false
    VarSetCapacity(rc, 16, 0)
    DllCall("GetClientRect", "ptr", SetupHwnd, "ptr", &rc)
    cw := NumGet(rc, 8, "int"), ch := NumGet(rc, 12, "int")
    if (cx < cw - 14)                    ; a little wider than it looks, to aim at
        return false
    thumb := Round(ch * ch / SetupContentH)
    if (thumb < 24)
        thumb := 24
    span := ch - 16 - thumb
    if (span <= 0)
        return true
    ; the screen y of client (0,0), so the pointer can be read against the track
    VarSetCapacity(pt, 8, 0)
    DllCall("ClientToScreen", "ptr", SetupHwnd, "ptr", &pt)
    oy := NumGet(pt, 4, "int")
    CoordMode, Mouse, Screen
    Loop {
        MouseGetPos, , my
        rel := my - oy - 8 - (thumb // 2)
        SetupScrollTo(Round(rel * max / span))
        if (!GetKeyState("LButton", "P"))
            break
        Sleep, 15
    }
    return true
}

SetupClientH() {
    global SetupHwnd
    VarSetCapacity(rc, 16, 0)
    DllCall("GetClientRect", "ptr", SetupHwnd, "ptr", &rc)
    return NumGet(rc, 12, "int")
}

; How far there is to scroll, worked out now rather than remembered. Two
; DllCalls, and it cannot go stale the way a cached number can when the window
; is resized by something that forgot to tell us.
SetupMaxScroll() {
    global SetupContentH
    ch := SetupClientH()
    return (SetupContentH > ch) ? SetupContentH - ch : 0
}

; The wheel goes to whatever holds the keyboard focus, which in this window is
; usually one of the Edit boxes - so a message arriving at a CHILD of the window
; counts as arriving at the window.
SetupWheel(wParam, lParam, msg, hwnd) {
    global SetupHwnd, SetupScrollY
    if (hwnd != SetupHwnd && DllCall("GetParent", "ptr", hwnd, "ptr") != SetupHwnd)
        return
    delta := (wParam >> 16) & 0xFFFF
    if (delta > 32767)
        delta -= 65536
    SetupScrollTo(SetupScrollY - (delta // 120) * 68)   ; two rows to a notch
    return 0
}

; Dragged taller or shorter: the page is now a different number of screens
; long, and a window made taller while looking at the bottom of the list has to
; pull the content back down with it or it would show a gap under the end.
;
; Then repaint the lot. A window class without CS_HREDRAW/CS_VREDRAW - which is
; every AutoHotkey Gui - is not asked to paint the strip a resize just
; uncovered, so growing this window left the desktop showing through it.
;
; The flag guards against a resize handler that causes a resize. Nothing here
; does any more, now that the bar is painted rather than a real scrollbar
; appearing and disappearing - but it costs one variable and the day something
; in here starts changing the client area again it will save an afternoon.
SetupSize:
    if (SetupSizing)
        return
    SetupSizing := 1
    SetupScrollTo(SetupScrollY)
    SetupRedraw()
    SetupSizing := 0
Return

; RDW_INVALIDATE|RDW_ERASE|RDW_ALLCHILDREN|RDW_UPDATENOW. ALLCHILDREN is the
; part that matters and the part WinSet,Redraw leaves out: without it the
; labels come back blank.
SetupRedraw() {
    global SetupHwnd
    DllCall("RedrawWindow", "ptr", SetupHwnd, "ptr", 0, "ptr", 0, "uint", 0x185)
}

; The title bar, painted dark. DWMWA_USE_IMMERSIVE_DARK_MODE is 20 on anything
; current and was 19 on the first builds that had it, so both are set and the
; one this Windows does not know about is ignored.
SetupDark(hwnd) {
    VarSetCapacity(on, 4, 0)
    NumPut(1, on, 0, "int")
    DllCall("dwmapi\DwmSetWindowAttribute", "ptr", hwnd, "int", 20, "ptr", &on, "int", 4)
    DllCall("dwmapi\DwmSetWindowAttribute", "ptr", hwnd, "int", 19, "ptr", &on, "int", 4)
}

; Put what the variables currently say into the boxes. Reading the variables
; rather than the file means the window always shows what is actually in force,
; including anything ClampConfig() has quietly corrected.
; Filling a box in counts as changing it: in v1 an Edit fires its g-label when
; GuiControl writes to it, not only when a person types. Without the flag,
; OPENING this window would save the file - and would have saved whatever the
; boxes happened to hold at that instant.
SetupLoad() {
    global SetupRows, SetupLoading
    SetupLoading := 1
    for n, d in SetupRows {
        if (d.kind = "head")
            continue
        v := SetupGet(d)
        if (d.kind = "bool")
            SetupPaintBool(n, v)
        else
            GuiControl, Setup:, SetupV%n%, %v%
    }
    SetupLoading := 0
    SetupSay("")
}

; One setting's value, in the form the .ini writes it.
SetupGet(d) {
    v := SetupVar(d.var)
    if (d.mul)
        v := Round(v / d.mul)
    if (d.kind = "bool")
        v := v ? 1 : 0
    return v
}

; A variable by name, and back again. Everything this window touches is
; declared with "global" at the top level (Config.ahk), which in v1 makes it a
; super-global - visible inside every function without being redeclared. The
; "global" line here is what points the dynamic reference at those rather than
; at a local of the same name.
;
; It has to go through v, and "return %name%" will not do: v1 does not treat
; the percent signs as a double dereference there, and hands back the NAME.
; An assignment does. (And v is declared local, or an assume-global function
; would quietly create a global called v.)
SetupVar(name) {
    global
    local v
    v := %name%
    return v
}

SetupSetVar(name, value) {
    global
    %name% := value
}

SetupPaintBool(n, on) {
    global CGreen, CDim
    col := on ? CGreen : CDim
    GuiControl, Setup:+c%col%, SetupV%n%
    GuiControl, Setup:, SetupV%n%, % on ? "yes" : "no"
}

;================================================================================
; Saving
;================================================================================
; An Edit fires its g-label on every keystroke, so "40" would be saved as 4 and
; then as 40. Waiting out a short pause means the half-typed number is never the
; one that lands - and 400ms is short enough to still feel immediate.
SetupChanged:
    if (!SetupLoading)
        SetTimer, SetupSaveTick, -400
Return

SetupSaveTick:
    SetupSave()
Return

SetupToggle:
    SetupFlip(SubStr(A_GuiControl, 7))
Return

SetupFlip(n) {
    global SetupRows
    if (!SetupRows[n])
        return
    GuiControlGet, was, Setup:, SetupV%n%
    SetupPaintBool(n, (was = "yes") ? 0 : 1)
    SetupSave()
}

; Walk the table, write every row, then tell the parts of the script that had
; cached something. Writing all of them rather than the one that changed keeps
; this to a single path - there is no "which control was it" to get wrong - and
; nineteen IniWrites behind a 400ms pause is nothing.
SetupSave() {
    global SetupRows, IniFile
    bad := ""
    for n, d in SetupRows {
        if (d.kind = "head")
            continue
        GuiControlGet, v, Setup:, SetupV%n%
        if (d.kind = "bool")
            v := (v = "yes") ? 1 : 0
        else if (d.kind = "num") {
            ; An empty box is somebody halfway through retyping a number, not
            ; somebody asking for zero. Writing the zero and then clamping it
            ; back would put a number in the file that was never typed.
            if (v = "")
                continue
            v := v + 0
        } else
            v := Trim(v)
        ; A journal folder that is not there yet would be CREATED by the next
        ; line written to it, and half of a path typed on the way to the real
        ; one is a folder nobody asked for. So that one box only counts once it
        ; names somewhere real.
        if (d.pick = "folder" && v != "" && !InStr(FileExist(v), "D")) {
            bad := "no such folder yet"
            continue
        }
        IniWrite, %v%, %IniFile%, % d.sect, % d.key
        SetupSetVar(d.var, d.mul ? v * d.mul : v)
    }
    SetupApply()
    SetupSay(bad ? bad : "saved")
}

; Everything that has to happen because a number changed. All of it is cheap,
; and all of it is safe to do when nothing actually moved.
SetupApply() {
    global SampleMs, EdgeState, LastShownMin
    ClampConfig()                         ; the same rules the .ini goes through
    ; RunAsAdmin is deliberately NOT acted on here. It is written to the .ini
    ; like everything else, and read on the way in next time.
    SetTimer, TickSample, %SampleMs%      ; a new sampling interval, from now
    SetupIcon()
    ApplyPanelMode()                      ; the faded alpha, applied at rest
    ApplyPanelShape()                     ; and the corners, on the panel
    ApplyWindowKind()                     ; taskbar window or overlay
    SetTrayJournal()                      ; the journal on or off
    JrnSettingsChanged()
    ShapeWindow(SetupHwnd, PanelRound)    ; and on this window, as you watch
    EdgeState := -1, LastShownMin := 9999 ; make the bar and the digits repaint
    Refresh()
}

; Only swap the tray icon for a file that is really there. Half a path typed on
; the way to a real one would otherwise blank the icon as you went. Bare names
; are resolved the same way BuildTray resolves them - see TrayIconPath().
SetupIcon() {
    icon := TrayIconPath()
    if (icon = "")
        return
    try {
        Menu, Tray, Icon, %icon%
    }
}

; The line at the bottom right. It says "saved" and then stops saying it, so
; the word means the last thing you did rather than something permanently on
; the screen.
SetupSay(txt) {
    GuiControl, Setup:, SetupNote, %txt%
    if (txt != "")
        SetTimer, SetupUnsay, -1800
}

SetupUnsay:
    GuiControl, Setup:, SetupNote,
Return

;================================================================================
; The two things in here that are not settings
;================================================================================
SetupPickFolder:
    SetupPick("folder")
Return

SetupPickFile:
    SetupPick("file")
Return

; Find the one path row of that sort and fill it in. There is exactly one of
; each, which is why this can look it up rather than be told which.
SetupPick(what) {
    global SetupRows
    for n, d in SetupRows {
        if (d.kind != "path" || d.pick != what)
            continue
        GuiControlGet, was, Setup:, SetupV%n%
        if (what = "folder") {
            start := (was != "") ? "*" was : ""
            FileSelectFolder, got, %start%, 3, Where the daily journal files go
        } else {
            FileSelectFile, got, 3, %was%, An icon for the tray
                , Images (*.ico; *.png; *.bmp; *.jpg)
        }
        if (got = "")                     ; cancelled: leave what was there
            return
        GuiControl, Setup:, SetupV%n%, %got%
        SetupSave()
        return
    }
}

SetupOpenIni:
    CfgOpen(IniFile)
Return

SetupClose:
SetupEscape:
    Gui, Setup:Hide
Return
