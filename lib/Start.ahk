;================================================================================
; Start-up - and the end of the auto-execute section
;
; Everything above this file is a variable being set. Everything below it is a
; function, a label or a key, and none of that runs until something calls it -
; so the Return at the bottom is what stops the script falling into the first
; label it meets. See All.ahk.
;================================================================================
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

BuildTray()
Refresh()
SaveState()                  ; today's note and the board, there from the start

SetTimer, TickFast,   150
SetTimer, TickSecond, 1000
SetTimer, TickSample, %SampleMs%
SetTimer, TickMinute, 60000
OnExit, DaybookExit
Return

