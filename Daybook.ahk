;================================================================================
; Daybook.ahk - always-on-top day panel: tasks, sit-timer, passive app log
;================================================================================
; Its own process. Nothing else launches it - it is started by a Task Scheduler
; task at logon (see AUTOSTART below), so it does not depend on Shortcuts.ahk.
;
; KEYS - only two. Everything else is a click on the panel, see MOUSE.
;   Win + F6            one loop, a step a press: hidden -> SOLID -> DIM ->
;                       GHOST -> hidden. It is also the way out of GHOST, which
;                       takes no clicks at all
;   Win + F1            declare a break by hand, or end one - the same as the
;                       break switch on the panel
;
; MOUSE (in SOLID or DIM mode - GHOST takes no clicks at all)
;   drag anywhere       any empty space moves the panel - the only things that
;                       do not are the buttons themselves
;   click a heading     collapse / expand that section
;   the tick box        done -> a note box opens beside that row, writing is
;                       optional, Esc skips
;   the cross           didn't do it -> same box, asking what blocked it
;   a habit's tick box  ticks today off, and clicking it again takes it back.
;                       There is no note box: a habit is a yes or a no
;   a habit's DOTS      each one is a day, and each one is a button. Click
;                       Tuesday's dot and Tuesday is ticked - for the evening
;                       you did the thing and forgot to say so
;   right-click a row   move between lists / delete, or rename a habit
;   +                   add a task to that list; amber means something is owed.
;                       The box that opens from TODAY'S TASKS:
;                         Enter        add to Today
;                         Ctrl+Enter   add to Long term
;                         Esc          cancel
;                       A task always starts open. What already happened goes
;                       in the journal, not on the list.
;   JOURNAL             opens the journal window: your part of the day's note,
;                       any day, saved as you type - see JournalWin.ahk
;   break / back        declare a break by hand, same as Win+F1
;
; HABITS - the first section, and the one that is the same every day
;   A habit is not a task: it comes back tomorrow whether you did it or not,
;   and the only thing worth showing is whether the chain is unbroken. So each
;   row is a tick box, a name, a week of dots and one number.
;
;       [v] read 20 pages          . . o o o o o     12
;
;   The dots are the last seven days with TODAY on the right - green for done,
;   red for missed (yesterday brightest), grey for still to do, and nothing at
;   all for the days before you added it. Every one of them is clickable, which
;   is how a day you forgot to tick gets ticked. The number is the streak:
;   green once today is done, amber while the chain is alive and today is not,
;   dim at zero. The count in the heading is how many are ticked today, and it
;   turns green when they all are.
;
;   Habits come FIRST on the panel, above both task lists: they are the part
;   that is the same every morning, a list you glance at and clear rather than
;   one you think about.
;
;   Habits.ahk holds the rules. Each day's note carries the habits with the
;   run each had reached, and Daybook.md the streaks and two weeks of them.
;
; THE THREE SWITCHES - bottom right, in a row
;   solid / dim         panel mode; click to swap the two. GHOST is not on this
;                       switch: a GHOST panel cannot be clicked, so the switch
;                       would be a one-way door - Win+F6 goes there and back.
;                       The small circle beside the minutes shows the mode too:
;                         DIM    see-through, lights up when your pointer
;                                crosses it, clickable
;                         GHOST  see-through, FADES AWAY when your pointer
;                                crosses it, and cannot be clicked at all - the
;                                mouse goes straight to whatever is behind it.
;                                Win+F6 once more hides it.
;                         SOLID  fully opaque, clickable, does not react to the
;                                pointer at all
;   on top / top        always on top, on or off. On is the default and is what
;                       makes this a panel rather than a window you have to go
;                       and find; off makes it an ordinary window that falls
;                       behind whatever you click next.
;                       While it is off THE CIRCLE IS GONE - the circle means
;                       "I am sitting over your work, and this is how much of me
;                       you can see", and a window that is not over your work
;                       has nothing to say about that. The mode switch still
;                       spells the mode out, and so does the tray menu.
;   lock / locked       pins the panel where it is, so no amount of dragging
;                       moves it. Not a thing you flip while working, a thing
;                       you set once when the panel is finally where you want
;                       it.
;
; WHEN THERE IS MORE THAN FITS
;   The panel grows until it reaches the bottom of the screen, and then it
;   scrolls instead: a slim bar appears down its right edge and the wheel moves
;   it while the pointer is on it.
;
;   TWO STRIPS NEVER MOVE. The top one - the bar, the status, the minutes and
;   the break switch - because a readout you have to scroll to is not a
;   readout. The bottom one - the two keys, and the mode / on top / lock
;   switches - because those are exactly the things you go looking for, and
;   scrolling to the end of a long list to find the lock would be absurd.
;   Anything that scrolls behind either strip is hidden rather than slid under,
;   since a control always draws over its parent whatever the parent paints.
;
;   How wide it is and how tall it may get are both numbers in Settings -
;   [Look] WidthPx and MaxHeightPx. Not a draggable edge: a window with no
;   frame has no sizing border, so dragging one means a loop that follows the
;   pointer and lays the whole panel out on every step, and a panel that is
;   sometimes exactly as tall as the screen and sometimes two pixels short is a
;   worse thing to own than a box you type 800 into once.
;
;================================================================================
; WHAT THE COLOURS MEAN
;================================================================================
; The bar across the top is the sit-timer and is never hidden. It fills as you
; sit, and it has three states:
;
;   green     under 30 min
;   amber     30-45 min
;   red       over 45 min, and it breathes
;
; The breathe is the only animation in the program, it moves on a ~2.4s cycle
; rather than blinking, and it stops by itself after 15 minutes of no input:
; by then you have either got up or you are not there, and pulsing at an empty
; chair is what makes people uninstall things like this.
;
; The digits count DOWN while you are inside the 45 minutes and UP once you are
; past it ("13m left" -> "+4m over"), so overstaying is a number you can see.
; They are MINUTES, and they repaint once a minute. A per-second counter in the
; corner of your eye is a distraction, which is the whole reason the digits can
; be turned off at all - and turning them off loses nothing, because the bar
; already carries the same information.
;
; The + beside TODAY'S TASKS is the other channel: it turns static amber, with
; no movement, meaning "I need words from you" - the list is empty, or yesterday
; rolled over with unfinished items you have not explained yet. Press it and it
; either starts that review or opens capture, whichever you actually owe.
;
;================================================================================
; PRESENCE - how it knows you are actually there
;================================================================================
; The primary signal is Windows' own: GUID_CONSOLE_DISPLAY_STATE, which says
; whether the display is on. This is better than watching the keyboard, and
; better than watching the audio meter, because of one detail:
;
;   video players call SetThreadExecutionState(ES_DISPLAY_REQUIRED).
;   music players do not.
;
; So Windows already separates the two cases that are otherwise identical -
; no input for two hours, with sound playing:
;
;   watching a film   -> the display is held awake  -> you are here, keep timing
;   left the room     -> nothing holds it, it blanks -> you are gone, reset
;
; It also makes the reset VISIBLE. You do not have to wonder how long to stay
; away: it resets when your screen goes dark, which on this machine is the
; 5-minute display timeout in the Balanced power plan.
;
; Audio is kept as a fallback for the one case the display signal gets wrong:
; an app that pins the display awake for audio-only playback (Chrome does this
; for YouTube). AudioCapMin bounds how long that can hold presence up. Sound
; is read from every playback device, not just the default one.
;
;
; Any input counts as being here, mouse MOVEMENT included - reading with a hand
; on the mouse is sitting. Walking round the room and nudging the mouse to keep
; the screen on is the one case that cannot be told apart from that, and it is
; what the break switch is for: during a declared break only a key or a click
; ends it, so nudging is safe. While the sensors say you are gone the panel says
; AWAY and counts the minutes, so you can see what it decided.
;
;================================================================================
; THE LOG
;================================================================================
; Every SampleMs the foreground PROCESS NAME is recorded, but only if you were
; present for that sample. Process names, not window titles: titles change on
; every tab and every document, so a day aggregates into hundreds of strings
; instead of twenty readable buckets - and titles carry document names and page
; titles into a folder that syncs to your phone. Titles are a later, opt-in
; thing, deliberately not a default.
;
; Idle time is never counted. Walking away with Chrome focused is not three
; hours of Chrome, and getting that wrong is why most cheap time trackers
; produce numbers nobody believes.
;
;================================================================================
; THE JOURNAL
;================================================================================
; One markdown file per day in JournalDir, named YYYY-MM-DD.md to match the
; handwritten journals in the folder above it - kept in its own subfolder so
; generated files never mix with the ones you wrote yourself.
;
; The top of each note is YOURS - it opens with a "## journal" heading - and
; Daybook keeps one block at the bottom, between two markers: the day's tasks
; with their notes, the habits, the time at the machine. Only that block is
; ever rewritten, as the day goes and when something about the day changes
; afterwards; nothing outside the markers is touched. See Journal.ahk.
;
; The JOURNAL heading on the panel opens that top part in a window of its own
; (JournalWin.ahk). The window keeps no copy: it reads the note and writes it
; back, so Obsidian and the window are two ways into the same words.
;
; Obsidian FOLLOWS the panel and never the other way: it cannot show a cross, a
; colour or a week of dots, so it is where you read and write, and the panel is
; where things are done. Daybook.md beside the notes is where things stand -
; the lists, the streaks, two weeks of habits. See Board.ahk.
;
; Every click as it happened - added, ticked, renamed - goes to log\ beside
; this file, not to the vault.
;
;================================================================================
; THE DAY
;================================================================================
; A day starts at DayStartHour (03:00), so a 2am session still belongs to the
; previous day. Crossing that boundary is the ONLY thing that clears Today - a
; crash, a reboot or a power cut mid-day restores everything exactly, because
; state is written the moment it changes.
;
; If the PC was off at 03:00 the rollover happens at the next start, on behalf
; of the day that ended. Unfinished tasks are not deleted: they stay, their
; carry count goes up (the small x2 beside them), and the + stays amber until
; you have said why they did not happen.
;
;================================================================================
; AUTOSTART (do this once, by hand)
;================================================================================
; Task Scheduler > Create Task
;   General : Run only when user is logged on, Run with highest privileges
;   Trigger : At log on (your user)
;   Action  : Start a program
;             the AutoHotkey v1 exe, e.g.
;             "C:\Program Files\AutoHotkey\v1.1.37.02\AutoHotkeyU64.exe"
;             argument: the full path to this file, in quotes
;   Settings: untick "Stop the task if it runs longer than..."
;
; Highest privileges matters: without it Win+F6 and Win+F1 die whenever an
; elevated window has the focus. The If !A_IsAdmin block further down asks for
; it when the file is simply double-clicked, so the scheduled task is only
; needed to have it start by itself.
;
; A Startup-folder shortcut works too and needs no Task Scheduler - it just
; cannot give the script highest privileges, so the keys go quiet over elevated
; windows.
;
;================================================================================
; SETTINGS
;================================================================================
; Tray menu > Settings opens a window with every setting in it, saved as you
; change it and in force the moment it is saved - see SettingsWin.ahk. It
; scrolls, so it can grow. The same settings are in Daybook.ini beside this
; script, where they carry the reasons as well as the numbers; a link at the
; bottom of the window opens it. That file is read once, at start, so editing
; it needs a reload and the window does not.
;
; The journal can be turned off entirely there - [Journal] Write. Nothing is
; then written to the folder, and the panel, the timer and the habit streaks
; carry on exactly as they are.
;
;================================================================================
; NOT IN THIS VERSION (the structure is here, the behaviour is not)
;================================================================================
;   - per-task due times. Task records already carry .due and .asked for
;     them.
;   - drop shadows. The corners turned out to be free - Windows 11 will round
;     a frameless window if you ask it to, see ApplyPanelShape() - but a shadow
;     still needs the whole panel drawn as one GDI+ layered bitmap, and
;     everything here is real controls on a plain window, which is what keeps
;     the focus behaviour honest.
;   - forcing anything: dimming, locking, blocking. NagLevel is the hook and
;     ApplySitState() is the one place any of it would live.
;   - window titles in the log (see THE LOG above).
;================================================================================

; v1, and it has to be: this is written in v1 commands throughout and v2 would
; stop on the first line of it. #Requires turns that into a sentence saying so
; rather than a syntax error.
#Requires AutoHotkey v1.1.33+
#SingleInstance force
#NoEnv
; A_TimeIdleKeyboard reports nothing unless the keyboard hook is installed, and
; presence must not depend on some hotkey happening to install it as a side
; effect. See IdleMs().
#InstallKeybdHook
; Same for A_TimeIdlePhysical and mouse movement - see Present().
#InstallMouseHook
SendMode Input
SetWorkingDir %A_ScriptDir%
SetBatchLines -1

; Administrator is OPTIONAL, and off unless you ask for it - [General]
; RunAsAdmin in Daybook.ini. Without it exactly one thing does not work: Win+F6
; and Win+F1 go quiet while a window that is itself running as administrator
; has the focus, because Windows does not let an ordinary program see keys
; meant for an elevated one. Everything else - the timer, the habits, the
; journal, every click on the panel - is the same either way.
;
; Started from a scheduled task with highest privileges this is already true
; and the block is skipped. Decline the Windows prompt and Daybook carries on
; without it rather than refusing to start.
;
; Read with a plain IniRead: this runs before lib\Settings.ahk exists.
IniRead, DaybookAsAdmin, %A_ScriptDir%\Daybook.ini, General, RunAsAdmin, 0
if (!A_IsAdmin && DaybookAsAdmin = 1) {
    try {
        Run *RunAs "%A_AhkPath%" "%A_ScriptFullPath%"
        ExitApp
    }
}
Process, Priority, , H

;================================================================================
; The code
;================================================================================
; This file only starts things. Everything else is in lib\ - lib\All.ahk lists
; each part and what it does, in the order it loads.
;
; The folder is self-contained: the two files Daybook writes for itself,
; Daybook.ini and Daybook-state.txt, are made beside this one on the first run,
; and lib\Settings.ahk is its own copy of the .ini reader rather than a
; reference to one somewhere else. Copy the folder anywhere and it runs.
;================================================================================
#Include %A_ScriptDir%\lib\All.ahk
