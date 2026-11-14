;================================================================================
; Daybook.ahk - always-on-top day panel: tasks, habits, sit-timer, journal
;================================================================================
; AutoHotkey v2 (2.0 or later). Its own process: it starts itself when you sign
; in once Start with Windows is ticked (tray menu, or Settings > GENERAL).
;
; KEYS - only two, and both can be changed in Settings > KEYS. Everything else
; is a click on the panel, see MOUSE.
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
;                       you did the thing and forgot to say so. Each click
;                       goes one step: done (green) -> frozen (blue) -> not
;                       done. Blue is skipped once the month's freezes are
;                       used. A freeze counts as the day the habit was due; it
;                       holds the streak and does not add to it
;   right-click a row   move between lists / delete, or rename a habit
;   +                   add a task to that list; amber means something is owed.
;                       The box that opens from TODAY'S TASKS:
;                         Enter        add to Today
;                         Ctrl+Enter   add to Long term
;                         Esc          cancel
;                       From SHORT TERM TASKS the + asks for the deadline next,
;                       on a small calendar: click a day (or "tomorrow", "in a
;                       week", "no deadline") and it is set. Esc goes back to
;                       the box with your words still in it.
;                       A task always starts open. What already happened goes
;                       in the journal, not on the list.
;   JOURNAL             opens the journal window: your part of the day's note,
;                       any day, saved as you type - see JournalWin.ahk
;   break / back        declare a break by hand, same as the break key
;
; HABITS - the one section that is the same every day
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
;   Habits.ahk holds the rules. Each day's note carries the habits with the
;   run each had reached, and Daybook.md the streaks and two weeks of them.
;
; THE THREE SWITCHES - bottom right, in a row
;   solid / dim         panel mode; click to swap the two. GHOST is not on this
;                       switch: a GHOST panel cannot be clicked, so the switch
;                       would be a one-way door - the panel key goes there and
;                       back. The small circle beside the minutes shows the
;                       mode too:
;                         DIM    see-through, lights up when your pointer
;                                crosses it, clickable
;                         GHOST  see-through, FADES AWAY when your pointer
;                                crosses it, and cannot be clicked at all - the
;                                mouse goes straight to whatever is behind it.
;                                The panel key once more hides it.
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
;   switches - because those are exactly the things you go looking for.
;   Anything that scrolls behind either strip is hidden rather than slid under,
;   since a control always draws over its parent whatever the parent paints.
;
;   How wide it is and how tall it may get are both numbers in Settings -
;   [Look] WidthPx and MaxHeightPx. Not a draggable edge: a window with no
;   frame has no sizing border, so dragging one means a loop that follows the
;   pointer and lays the whole panel out on every step.
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
; The breathe is the only animation in the program, it moves on a ~1.2s cycle
; rather than blinking, and it stops by itself after 15 minutes of no input:
; by then you have either got up or you are not there, and pulsing at an empty
; chair is what makes people uninstall things like this.
;
; The digits count DOWN while you are inside the 45 minutes and UP once you are
; past it ("13m left" -> "+4m over"), so overstaying is a number you can see.
; They are MINUTES, and they repaint once a minute. A per-second counter in the
; corner of your eye is a distraction - and the bar already carries the same
; information.
;
; The + beside TODAY'S TASKS is the other channel: it turns static amber, with
; no movement, meaning "I need words from you" - the list is empty.
;
; Dark or light: Settings > GENERAL > Theme. Daybook starts again to change
; its colours (it takes a second; nothing is lost).
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
; away: it resets when your screen goes dark, which on most machines is the
; 5-minute display timeout in the Balanced power plan.
;
; Audio is kept as a fallback for the one case the display signal gets wrong:
; an app that pins the display awake for audio-only playback (Chrome does this
; for YouTube). AudioCapMin bounds how long that can hold presence up. Sound
; is read from every playback device, not just the default one.
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
; titles into a folder that syncs to your phone.
;
; Idle time is never counted. Walking away with Chrome focused is not three
; hours of Chrome, and getting that wrong is why most cheap time trackers
; produce numbers nobody believes.
;
;================================================================================
; THE JOURNAL
;================================================================================
; One markdown file per day in the journal folder, named YYYY-MM-DD.md - with
; a title after the date once you give the day one.
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
; of the day that ended. Unfinished tasks are not deleted: they move to MISSED,
; their carry count goes up (the small x2 in front of them), and they wait
; there for you to say what happened.
;
;================================================================================
; SETTINGS, STARTING, UPDATES
;================================================================================
; Tray menu > Settings opens a window with every setting in it, saved as you
; change it and in force the moment it is saved. The same settings are in
; Daybook.ini beside this script, where they carry the reasons as well as the
; numbers; a link at the bottom of the window opens it. That file is read at
; start, so editing it by hand needs a reload and the window does not.
;
; Start with Windows (a tick in the tray menu and in Settings) starts Daybook
; when you sign in: a shortcut in your Startup folder, or with Run as
; administrator on, a Task Scheduler task - so Windows does not ask each time.
;
; Run as administrator is OPTIONAL, and off unless you ask for it. Without it
; exactly one thing does not work: the two keys go quiet while a window that is
; itself running as administrator has the focus, because Windows does not let
; an ordinary program see keys meant for an elevated one. Everything else - the
; timer, the habits, the journal, every click on the panel - is the same.
;
; Once a day Daybook asks GitHub whether there is a newer version, and says so
; in the tray. Nothing installs without your click; an update never touches
; Daybook.ini, Daybook-state.txt, backups\ or log\.
;
; The journal can be turned off entirely - Settings > THE JOURNAL. Nothing is
; then written to the folder, and the panel, the timer and the habit streaks
; carry on exactly as they are.
;
;================================================================================
; NOT IN THIS VERSION (the structure is here, the behaviour is not)
;================================================================================
;   - per-task due times. Task records already carry .due and .asked for
;     them.
;   - drop shadows. The corners are free - Windows 11 will round a frameless
;     window if you ask it to, see ApplyPanelShape() - but a shadow still needs
;     the whole panel drawn as one layered bitmap, and everything here is real
;     controls on a plain window, which is what keeps the focus behaviour
;     honest.
;   - forcing anything: dimming, locking, blocking. NagLevel is the hook and
;     ApplySitState() is the one place any of it would live.
;   - window titles in the log (see THE LOG above).
;
;================================================================================
; THE CODE
;================================================================================
; This file only starts things: one Kit.Start below. The settings window, the
; tray menu's frame, the keys, Start with Windows, administrator, the theme and
; updates are the kit's (lib\Kit, shared by every script of the family);
; everything that is Daybook's own is in lib\ - lib\All.ahk lists each part
; and what it does. tests\ checks them (run-tests.ps1).
;
; FILES Daybook makes, all next to this script
;   Daybook.ini         your settings, and where the panel was
;   Daybook-state.txt   your tasks and habits with their whole history - see
;                       Store.ahk for how it is kept safe
;   backups\            a copy of the state from each day it changed, and of
;                       each day note before Daybook first rewrote it
;   log\                every click, as it happened
;   errors.log          anything that went wrong, instead of a dialog
;================================================================================
#Requires AutoHotkey v2.0
#SingleInstance Force
#Include %A_LineFile%\..\lib\Kit\Kit.ahk
#Include %A_LineFile%\..\lib\All.ahk

; A_TimeIdleKeyboard reports nothing unless the keyboard hook is installed, and
; presence must not depend on some hotkey happening to install it as a side
; effect. See IdleMs(). The same for A_TimeIdlePhysical and mouse movement.
InstallKeybdHook()
InstallMouseHook()
SendMode("Input")
SetWorkingDir(A_ScriptDir)
try ProcessSetPriority("H")

; keep: what is yours beside Daybook.ahk, which an update never writes (the
; .ini and errors.log always are). appId stays what it was before the kit, so
; a button pinned to the taskbar holds.
Kit.Start({name: "Daybook", version: DaybookVersion, repo: "HamedGhadirian/Semi-Automatic-Daybook"
    , repoWas: ["HamedPhixer/Semi-Automatic-Daybook"]      ; the account's name before 2026-11
    , ini: IniFile, template: DaybookIniTemplate(), appId: "Ahk.Daybook"
    , icon: "icon.png", iconWas: ["Files", "TrayIcon"]       ; [Icons] Tray; until 1.2.0 [Files] TrayIcon
    , adminWhy: "So the two keys also work while a program that runs as administrator is in front."
    , keep: ["Daybook-state.txt", "Daybook-state.unreadable-*", "backups", "log"]
    , init: () => DaybookStart(), keys: DaybookKeys(), rows: () => DaybookRows(), apply: () => DaybookApply()
    , menu: (m) => DaybookTray(m), default: "Show / hide panel", onTheme: () => DaybookThemeChanged()})
