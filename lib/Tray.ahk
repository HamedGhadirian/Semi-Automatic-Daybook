;================================================================================
; Tray
;================================================================================
; Before the panel is built: a GUI window takes the tray icon it is created
; with, and that is the icon on the panel's taskbar button.
SetTrayIcon() {
    ; Your own image first, the built-in second. imageres.dll #20 is a lined pad
    ; with a tick on it - AHK numbers icons from 1, so it is what ExtractIconEx
    ; would call index 19.
    ok := false
    icon := TrayIconPath()
    if (icon != "") {
        try {
            Menu, Tray, Icon, %icon%
            ok := true
        }
    }
    if (!ok && FileExist(A_WinDir "\System32\imageres.dll"))
        Menu, Tray, Icon, %A_WinDir%\System32\imageres.dll, 20
}

BuildTray() {
    Menu, Tray, NoStandard
    Menu, Tray, Add, Show / hide panel, TrayToggle
    Menu, Tray, Add, I'm on a break, TrayBreak
    TrayModeItem := "Panel mode: " ModeName()
    Menu, Tray, Add, %TrayModeItem%, TrayGhost
    Menu, Tray, Add, Always on top, TrayOnTop
    Menu, Tray, Add, Quick capture, TrayAdd
    Menu, Tray, Add
    Menu, Tray, Add, Write in the journal, TrayWrite
    Menu, Tray, Add, Open today's note, TrayJournal
    Menu, Tray, Add, Open the journal folder, TrayFolder
    Menu, Tray, Add, Write the summaries again, TrayRollup
    Menu, Tray, Add
    Menu, Tray, Add, Settings, TraySettings
    Menu, Tray, Add, Reload, TrayReload
    Menu, Tray, Add, Exit, TrayExit
    Menu, Tray, Default, Show / hide panel
    Menu, Tray, Tip, % "Daybook " DaybookVersion "`nWin+F6 show, dim, ghost, hide`nWin+F1 break"
    ; From here the two items above can be ticked and renamed. Both are called
    ; once now, so the menu matches whatever the ini restored.
    TrayReady := true
    SetTrayOnTop()
    SetTrayMode()
    SetTrayJournal()
}

; The journal's three items say nothing while it is off - there is no note to
; write in or open. Called again whenever the settings change.
SetTrayJournal() {
    global JournalOn, RollupOn
    act := JournalOn ? "Enable" : "Disable"
    for _, item in ["Write in the journal", "Open today's note", "Open the journal folder"]
        Menu, Tray, %act%, %item%
    act := (JournalOn && RollupOn) ? "Enable" : "Disable"
    Menu, Tray, %act%, Write the summaries again
}

; A bare file name means a file next to Daybook.ahk, which is how an icon
; travels with the folder; anything with a separator in it is taken as written.
; Returns "" for a file that is not there, so the built-in one is used instead.
TrayIconPath() {
    global TrayIcon
    if (TrayIcon = "")
        return ""
    p := (InStr(TrayIcon, "\") || InStr(TrayIcon, ":"))
       ? TrayIcon : A_ScriptDir "\" TrayIcon
    return FileExist(p) ? p : ""
}

TrayToggle:
    TogglePanel()
Return

TrayBreak:
    ToggleBreak()
Return

TrayGhost:
    CycleMode()
Return

TrayOnTop:
    ToggleOnTop()
Return

TrayAdd:
    QuickAdd()
Return

TrayWrite:
    JrnShow()
Return

TrayJournal:
    JFile := JournalFile(LogicalDay())
    if (FileExist(JFile))
        Run, %JFile%
    else if (InStr(FileExist(JournalDir), "D"))
        Run, %JournalDir%
Return

TrayRollup:
    RollupRun(true)
Return

TrayFolder:
    if (InStr(FileExist(JournalDir), "D"))
        Run, %JournalDir%
Return

TraySettings:
    SetupShow()
Return

TrayIni:
    CfgOpen(IniFile)
Return

TrayReload:
    Reload
Return

TrayExit:
    ExitApp
Return

DaybookExit:
    CommitMark()
    SaveIni()
    SaveState()
    for _, m in Meters
        ObjRelease(m)
ExitApp

