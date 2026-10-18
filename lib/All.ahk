;================================================================================
; All.ahk - every part of Daybook, in the order it loads
;================================================================================
; Daybook.ahk includes this file and nothing else. The order matters for the
; first three and only the first three: in AutoHotkey v1 a script RUNS from the
; top until it meets a Return or a key definition, so everything that has to
; happen at start-up has to come before anything that does not.
;
;   Config     the settings, read from Daybook.ini once - and the colours
;   State      every value the script keeps while it runs
;   Start      builds the windows, starts the timers, then Return
;   ----------- nothing below here runs on its own -----------------------------
;   Keys       Win+F6, Win+F1, and the clicks that only leave a timestamp
;   Timers     the four clocks, and the sit counter they drive
;   Presence   is anybody there: the display, the lock screen, sound, input
;   Bar        the sit timer as the bar across the top, and the digits
;   Log        which program was in front, and the day's totals
;   Tasks      adding, renaming and marking a task
;   Habits     the daily habits, their week of dots and their streaks
;   Day        when a day starts and what happens when it ends
;   Journal    the day note (Daybook's block + yours) and Daybook's own log
;   Board      Daybook.md - where things stand, written one way
;   Rollup     the weeks, the months and the year, and packing months away
;   Store      Daybook-state.txt, and the [Saved] part of Daybook.ini
;   Panel      building the panel, painting it, and how much of it shows
;   Break      a break you declared by hand
;   Modes      SOLID / DIM / GHOST, always on top, show and hide
;   Layout     where every section and row ends up
;   Events     what a click on any of it does
;   Capture    the box you type a new task into
;   Note       the box that opens beside a task you just marked
;   Missed     what a day ended without: did it, drop it, or back to today
;   SettingsWin  the settings window
;   HabitWin   one habit's window: how often, its calendar, its streak
;   JournalWin the journal window - your part of a day note
;   Tray       the tray icon's menu, and leaving tidily
;   Ini        the commented Daybook.ini written on the first run
;
; Last of all, Settings.ahk: the reader that turns Daybook.ini into values, and
; Taskbar.ahk: Daybook's windows get a taskbar button of their own, not one
; shared with other AutoHotkey scripts. And SeenAt.ahk: whether the pointer is
; on the panel you can see, or on a window over it. All three are all functions,
; so where they go in the list does not matter.
;================================================================================
#Include %A_LineFile%\..\Config.ahk
#Include %A_LineFile%\..\State.ahk
#Include %A_LineFile%\..\Start.ahk
#Include %A_LineFile%\..\Keys.ahk
#Include %A_LineFile%\..\Timers.ahk
#Include %A_LineFile%\..\Presence.ahk
#Include %A_LineFile%\..\Bar.ahk
#Include %A_LineFile%\..\Log.ahk
#Include %A_LineFile%\..\Tasks.ahk
#Include %A_LineFile%\..\Habits.ahk
#Include %A_LineFile%\..\Day.ahk
#Include %A_LineFile%\..\Journal.ahk
#Include %A_LineFile%\..\Board.ahk
#Include %A_LineFile%\..\Rollup.ahk
#Include %A_LineFile%\..\Store.ahk
#Include %A_LineFile%\..\Panel.ahk
#Include %A_LineFile%\..\Break.ahk
#Include %A_LineFile%\..\Modes.ahk
#Include %A_LineFile%\..\Layout.ahk
#Include %A_LineFile%\..\Events.ahk
#Include %A_LineFile%\..\Capture.ahk
#Include %A_LineFile%\..\Note.ahk
#Include %A_LineFile%\..\Missed.ahk
#Include %A_LineFile%\..\SettingsWin.ahk
#Include %A_LineFile%\..\HabitWin.ahk
#Include %A_LineFile%\..\JournalWin.ahk
#Include %A_LineFile%\..\Tray.ahk
#Include %A_LineFile%\..\Ini.ahk
#Include %A_LineFile%\..\Settings.ahk
#Include %A_LineFile%\..\Taskbar.ahk
#Include %A_LineFile%\..\SeenAt.ahk
