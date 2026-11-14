;================================================================================
; SOLID / DIM / GHOST, always on top, and showing or hiding the panel
;================================================================================
#Requires AutoHotkey v2.0

; DIM -> GHOST -> SOLID -> DIM. It starts on DIM, so the first press still does
; what the old two-way toggle did and the habit survives the extra state.
CycleMode() {
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
SideOnTop(g) {
    if IsObject(g)
        g.Opt((PanelOnTop ? "+" : "-") "AlwaysOnTop")
}

; The Gui's own +/-AlwaysOnTop rather than WinSetAlwaysOnTop: this changes the
; Gui's own option, so it survives the Show that every Relayout() ends with.
;
; WS_EX_NOACTIVATE (0x08000000) moves with it, and that is the whole of
; "clicking it does not bring it forward". The flag says the window can never
; take focus, which is exactly right while the panel floats over your work - a
; readout must not steal the keyboard from a game or an editor - and exactly
; wrong once it is an ordinary window, because ACTIVATING is how a click raises
; a window. Dropping the flag along with always-on-top hands the job back to
; Windows, and the panel then behaves like every other window on the screen.
;
; Hover still works while it is off, and only where the panel can be SEEN: a
; panel buried under another window does not light up, tip or take the wheel
; when your pointer crosses where it is - WindowSeenAt() (lib\Kit\SeenAt.ahk).
;
; As an ordinary window (PanelTaskbar) it never has the flag: clicking a window
; and having it take the keyboard is what a window does, on top or not.
ApplyOnTop() {
    PanelGui.Opt((PanelOnTop ? "+" : "-") "AlwaysOnTop")
    for g in [JrnGui, HabEdGui, CapGui, NoteGui, DueGui]
        if (IsObject(g) && DllCall("IsWindowVisible", "ptr", g.Hwnd))
            SideOnTop(g)
    try WinSetExStyle(((PanelOnTop && !PanelTaskbar) ? "+" : "-") "0x08000000", PanelHwnd)
    PanelGui["ModeTxt"].Text := ModeGlyph()
    SetFootBtns()
    SetTrayOnTop()
}

; Switch between the ordinary window and the overlay - [Look] Taskbar, from the
; settings window. Windows only adds or removes a taskbar button when a window
; is shown, so a visible panel is hidden and shown again around the change.
ApplyWindowKind() {
    global PanelKind
    if (PanelKind = PanelTaskbar)
        return
    if (PanelVisible)
        PanelGui.Hide()
    if (PanelTaskbar)
        PanelGui.Opt("-ToolWindow +MinimizeBox")
    else
        PanelGui.Opt("+ToolWindow -MinimizeBox")
    PanelKind := PanelTaskbar
    ApplyOnTop()
    if (PanelVisible)
        PanelGui.Show("NoActivate")
}

; The window buttons' minimise: down to its taskbar button when it has one,
; else hidden - an overlay has nowhere to minimise to.
PanelMinimise() {
    if (PanelTaskbar && PanelVisible)
        WinMinimize(PanelHwnd)
    else if PanelVisible
        TogglePanel()
}

; The window buttons' close: hidden, as the panel key hides it. Daybook goes on.
PanelHideBtn() {
    if PanelVisible
        TogglePanel()
}

; Minimised from its taskbar button.
PanelIsMin() {
    try return WinGetMinMax(PanelHwnd) = -1
    return false
}

; SOLID / DIM / GHOST as a word. The tray menu is the only place the mode is
; readable when the circle is hidden, so it says which one you are in rather
; than just listing the three.
ModeName() {
    return (PanelMode = 0) ? "SOLID" : (PanelMode = 1) ? "DIM" : "GHOST"
}

; The tray menu shows both, and is made again from the top when either
; changes (KitTray.Build, which calls DaybookTray). Before the menu exists -
; the panel is shown first - there is nothing to change.
SetTrayOnTop() {
    if TrayReady
        KitTray.Build()
}

SetTrayMode() {
    if TrayReady
        KitTray.Build()
}
