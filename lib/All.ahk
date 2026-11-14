;================================================================================
; All.ahk - every part of Daybook, in the order it loads
;================================================================================
; Daybook.ahk includes the kit and this file. In AutoHotkey v2 every function
; is known wherever it is written, so the order only matters for the values
; set at the top of a file: Config and State first, because their globals are
; what everything else starts from.
;
;   Config     the version, the settings and their defaults, the colours, the
;              two keys, the settings window's rows, the .ini template
;   State      every value the script keeps while it runs
;   Start      the start-up, settings changed, the theme changed, leaving
;   Keys       the clicks that only leave a timestamp, and the panel's wheel
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
;   CalGrid    the month calendar the habit window and Due both draw
;   Due        the calendar that asks a short term task for its deadline
;   HabitWin   one habit's window: how often, its calendar, its streak
;   JournalWin the journal window - your part of a day note
;   Tray       Daybook's own tray items, and the icon
;
; The settings window, the tray menu's frame, the keys, Start with Windows,
; administrator, the theme, updates, the taskbar button and "is the panel
; really seen here" (WindowSeenAt) are the kit's - lib\Kit\Kit.ahk.
;================================================================================
#Requires AutoHotkey v2.0
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
#Include %A_LineFile%\..\CalGrid.ahk
#Include %A_LineFile%\..\Due.ahk
#Include %A_LineFile%\..\HabitWin.ahk
#Include %A_LineFile%\..\JournalWin.ahk
#Include %A_LineFile%\..\Tray.ahk
