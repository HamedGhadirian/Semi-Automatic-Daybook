;================================================================================
; Start-up, settings changed, the theme changed, and leaving tidily
;================================================================================
; Kit.Start (Daybook.ahk) seeds Daybook.ini, settles administrator and closes
; an older copy, then calls DaybookStart() - before the two keys are switched
; on, so a key can never find the panel half made.
#Requires AutoHotkey v2.0

DaybookStart() {
    ; A v1 Daybook from the same folder was just told to close (Kit.CloseOld).
    ; It saves its state on the way out, so wait for that before reading it -
    ; two copies writing one state file is how a day gets lost.
    DaybookWaitForOld()
    DaybookLoad(true)
    DaybookColours()
    LoadIni()
    LoadState()
    SetTrayIcon()                ; first: the panel's taskbar button takes it
    BuildPanel()
    BuildCapture()
    BuildNote()
    WatchDisplay()

    RollIfNeeded()
    RollupRun()                  ; weeks and months that ended while it was closed
    Journal(Chr(0x00B7) " session start")

    Refresh()
    SaveState()                  ; today's note and the board, there from the start

    SetTimer(TickFast, 150)
    SetTimer(TickSecond, 1000)
    SetTimer(TickSample, SampleMs)
    SetTimer(TickMinute, 60000)
    OnExit(DaybookExit)
}

; Up to three seconds for any other copy of this script - by path - to go.
DaybookWaitForOld() {
    was := DetectHiddenWindows(true)
    loop 30 {
        other := false
        try {
            for hwnd in WinGetList(A_ScriptFullPath " ahk_class AutoHotkey")
                if (hwnd != A_ScriptHwnd)
                    other := true
        }
        if !other
            break
        Sleep(100)
    }
    DetectHiddenWindows(was)
}

; Settings changed one of Daybook's own rows: the file is read again, and
; everything that had cached something hears of it. All of it is cheap, and
; all of it is safe to do when nothing actually moved.
DaybookApply() {
    global EdgeState, LastShownMin
    DaybookLoad()
    SetTimer(TickSample, SampleMs)        ; a new sampling interval, from now
    SetTrayIcon()
    ApplyPanelMode()                      ; the faded alpha, applied at rest
    ApplyWindowKind()                     ; taskbar window or overlay
    JrnSettingsChanged()
    EdgeState := -1, LastShownMin := 9999 ; make the bar and the digits repaint
    if TrayReady
        KitTray.Build()                   ; the journal's items on or off
    Refresh()
}

; Dark or light, changed in Settings. Every window of Daybook's own was made
; in the old colours, so Daybook starts again - the state is saved on the way
; out and read on the way in, and the settings window comes back.
DaybookThemeChanged() {
    SetTimer(() => Kit.Restart("--settings"), -50)
}

DaybookExit(reason, code) {
    CommitMark()
    SaveIni()
    SaveState()
    for m in Meters
        try ObjRelease(m)
}
