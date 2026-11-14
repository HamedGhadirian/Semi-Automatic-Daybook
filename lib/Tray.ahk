;================================================================================
; Tray - Daybook's own items, and the icon
;================================================================================
; The menu is the kit's (lib\Kit\Tray.ahk): Daybook's items first, then
; Settings, Start with Windows, Run as administrator, Look for updates now,
; Help, Reload, Exit. The kit builds it again from the top whenever something
; in it changes, and calls DaybookTray() each time - so the ticks and the
; mode's name are simply what they are at that moment.
#Requires AutoHotkey v2.0

DaybookTray(m) {
    global TrayReady
    m.Add("Show / hide panel", (*) => TogglePanel())
    m.Add("I'm on a break", (*) => ToggleBreak())
    m.Add("Panel mode: " ModeName(), (*) => CycleMode())
    m.Add("Always on top", (*) => ToggleOnTop())
    if PanelOnTop
        m.Check("Always on top")
    m.Add("Quick capture", (*) => QuickAdd())
    m.Add()
    ; The journal's items say nothing while it is off - there is no note to
    ; write in or open.
    m.Add("Write in the journal", (*) => JrnShow())
    m.Add("Open today's note", (*) => TrayJournal())
    m.Add("Open the journal folder", (*) => (DirExist(JournalDir) ? Run('"' JournalDir '"') : 0))
    m.Add("Write the summaries again", (*) => RollupRun(true))
    if !JournalOn
        for item in ["Write in the journal", "Open today's note", "Open the journal folder"]
            m.Disable(item)
    if !(JournalOn && RollupOn)
        m.Disable("Write the summaries again")
    TrayReady := true
    ; the keys may have just changed in Settings - the footer says them too
    if IsObject(PanelGui)
        PanelGui["FootTxt"].Text := KeyFootText()
}

TrayJournal() {
    f := JournalFile(LogicalDay())
    if (FileExist(f))
        Run('"' f '"')
    else if DirExist(JournalDir)
        Run('"' JournalDir '"')
}

; Before the panel is built: a window takes the tray icon it is created with,
; and that is the icon on the panel's taskbar button. Your own image first
; ([Files] TrayIcon), then icon.png beside Daybook.ahk, then the built-in one -
; imageres.dll #20, a lined pad with a tick on it.
SetTrayIcon() {
    icon := TrayIconPath()
    if (icon != "") {
        try {
            TraySetIcon(icon)
            return
        }
    }
    try TraySetIcon(A_WinDir "\System32\imageres.dll", 20)
}

; A bare file name means a file next to Daybook.ahk, which is how an icon
; travels with the folder; anything with a separator in it is taken as written.
; Returns "" for a file that is not there.
TrayIconPath() {
    for name in [TrayIcon, "icon.png"] {
        if (name = "")
            continue
        p := (InStr(name, "\") || InStr(name, ":")) ? name : A_ScriptDir "\" name
        if FileExist(p)
            return p
    }
    return ""
}
