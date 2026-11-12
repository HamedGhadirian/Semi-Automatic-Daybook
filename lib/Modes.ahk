;================================================================================
; SOLID / DIM / GHOST, always on top, and showing or hiding the panel
;================================================================================
; DIM -> GHOST -> SOLID -> DIM. It starts on DIM, so the first press still does
; what the old two-way toggle did and the habit survives the extra state.
CycleMode() {
    global PanelMode
    SetPanelMode(Mod(PanelMode + 1, 3))
}

SetPanelMode(mode) {
    global PanelMode
    PanelMode := mode
    SaveIni()
    ApplyPanelMode()
    SetTrayMode()
}

; Always on top is what separates a panel from a window you have to go and find.
; Off, it drops behind whatever you click next and only surfaces when the
; desktop under it is clear - which is exactly the point on a busy screen, and
; exactly why it needs saying somewhere other than the window itself.
ToggleOnTop() {
    global PanelOnTop
    PanelOnTop := !PanelOnTop
    SaveIni()
    ApplyOnTop()
}

; The windows that open beside the panel - journal, habit, note, quick add -
; float when the panel floats, and are ordinary windows when it does not: the
; journal used to stay over everything while the panel itself was not on top.
; Set just before each one is shown, and by ApplyOnTop for the ones open.
; Only ever called on a window already built - a Gui option on one that is not
; would make an empty window.
SideOnTop(gui) {
    global PanelOnTop
    Gui, % gui ":" (PanelOnTop ? "+" : "-") "AlwaysOnTop"
}

; Gui +/-AlwaysOnTop rather than WinSet: this changes the GUI's own option, so
; it survives the Gui,Show that every Relayout() ends with. A WinSet would be
; quietly undone the next time you opened a section.
;
; WS_EX_NOACTIVATE (0x08000000) moves with it, and that is the whole of
; "clicking it does not bring it forward". The flag says the window can never
; take focus, which is exactly right while the panel floats over your work - a
; readout must not steal the keyboard from a game or an editor - and exactly
; wrong once it is an ordinary window, because ACTIVATING is how a click raises
; a window. With the flag on, Windows refuses, and the only thing lifting the
; panel was the hand-rolled SetWindowPos in OnPanelClick - which the very next
; click on any other window put straight back. Dropping the flag along with
; always-on-top hands the job back to Windows, and the panel then behaves like
; every other window on the screen, every time and not just the first.
;
; Hover still works while it is off, and only where the panel can be SEEN: a
; panel buried under another window does not light up, tip or take the wheel
; when your pointer crosses where it is - WindowSeenAt() in SeenAt.ahk.
;
; As an ordinary window (PanelTaskbar) it never has the flag: clicking a window
; and having it take the keyboard is what a window does, on top or not.
ApplyOnTop() {
    global PanelOnTop, PanelHwnd, PanelTaskbar, JrnHwnd, HabEdHwnd, CapHwnd, NoteHwnd, DueHwnd
    Gui, % "Panel:" (PanelOnTop ? "+" : "-") "AlwaysOnTop"
    for gui, hwnd in {JrnEd: JrnHwnd, HabEd: HabEdHwnd, Cap: CapHwnd, Note: NoteHwnd, Due: DueHwnd}
        if (hwnd && DllCall("IsWindowVisible", "ptr", hwnd))
            SideOnTop(gui)
    WinSet, ExStyle, % ((PanelOnTop && !PanelTaskbar) ? "+" : "-") "0x08000000"
        , ahk_id %PanelHwnd%
    GuiControl, Panel:, ModeTxt, % ModeGlyph()
    SetFootBtns()
    SetTrayOnTop()
}

; Switch between the ordinary window and the overlay - [Look] Taskbar, from the
; settings window. Windows only adds or removes a taskbar button when a window
; is shown, so a visible panel is hidden and shown again around the change.
ApplyWindowKind() {
    global PanelTaskbar, PanelKind, PanelVisible
    if (PanelKind = PanelTaskbar)
        return
    if (PanelVisible)
        Gui, Panel:Hide
    if (PanelTaskbar)
        Gui, Panel:-ToolWindow +MinimizeBox
    else
        Gui, Panel:+ToolWindow -MinimizeBox
    PanelKind := PanelTaskbar
    ApplyOnTop()
    if (PanelVisible)
        Gui, Panel:Show, NoActivate
}

; Minimised from its taskbar button.
PanelIsMin() {
    global PanelHwnd
    WinGet, mm, MinMax, ahk_id %PanelHwnd%
    return (mm = -1)
}

; SOLID / DIM / GHOST as a word. The tray menu is the only place the mode is
; readable when the circle is hidden, so it says which one you are in rather
; than just listing the three.
ModeName() {
    global PanelMode
    return (PanelMode = 0) ? "SOLID" : (PanelMode = 1) ? "DIM" : "GHOST"
}

; Both of these are called before BuildTray() has run - ShowPanel() happens
; first - and a Menu command naming an item that does not exist yet is an
; error, so they wait for the menu to exist.
SetTrayOnTop() {
    global PanelOnTop, TrayReady
    if (!TrayReady)
        return
    if (PanelOnTop)
        Menu, Tray, Check, Always on top
    else
        Menu, Tray, Uncheck, Always on top
}

SetTrayMode() {
    global TrayModeItem, TrayReady
    if (!TrayReady)
        return
    fresh := "Panel mode: " ModeName()
    if (fresh = TrayModeItem)
        return
    Menu, Tray, Rename, %TrayModeItem%, %fresh%
    TrayModeItem := fresh
}

