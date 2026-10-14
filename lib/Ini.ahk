;================================================================================
; Daybook.ini - what gets written the first time the script runs
;================================================================================
; No double quotes and no per cent signs inside the continuation section: both
; still parse there. See Settings.ahk.
DaybookIniTemplate() {
    return "
    (
; Daybook.ahk settings - the day panel on Win+F6.
;
; The tray menu has these in a window too, under Settings, and a change made
; there takes effect at once. This file is the same settings with the reasons
; attached: save it, then pick Reload in the tray menu, because the file itself
; is only read when the script starts.
;
; Anything you delete or mistype falls back to its default. Nothing in this
; file can stop the script from starting.

[General]
; 1 = start as administrator, which Windows asks about each time. The only
; thing it buys is that Win+F6 and Win+F1 keep working while a window that is
; itself running as administrator has the focus; everything else is the same
; without it. Applies from the next start. A scheduled task set to run with
; highest privileges does this for you and makes the setting moot.
; This is also in the settings window (tray menu > Settings, under GENERAL) -
; but it is the one setting the window cannot act on when you change it, since
; it is read before anything else and only on the way in.
RunAsAdmin=0

[Journal]
; Write a note for each day. The top of it is your journal - the JOURNAL
; heading on the panel opens it in a window, or write in it anywhere else;
; under that, between two markers, Daybook keeps a summary of the day - the
; tasks with their notes, the habits, the time at the machine - and rewrites
; only that part as the day goes. 0 and no note is written and none already
; there is touched; JOURNAL leaves the panel, and the panel, the timer and the
; streaks carry on exactly as they are.
Write=1

; Keep Daybook.md in the folder: where things stand - today's list and the long
; term one with their notes, the streaks, and two weeks of habits. Written by
; Daybook whenever something changes; change things on the panel, not in it.
Board=1

; The folder the daily journal files go in, one YYYY-MM-DD.md per day. Created
; if it is missing. BLANK means a Daybook journal folder inside Documents.
Folder=

; The hour a new day starts, 0-23. 3 means a session at 2am still belongs to
; the day before. Crossing it is the only thing that clears the day.
DayStartsAtHour=3

[Timer]
; The bar across the top. It turns amber after AmberAfterMin minutes of
; sitting, and red - breathing, with the digits counting up - after
; RedAfterMin.
AmberAfterMin=30
RedAfterMin=45

; How long you have to be away for it to count as a break. Away this long or
; longer and the clock starts again from zero. Shorter is only a pause: the
; clock carries on from where it was, so a red bar stays red until you take a
; whole one, and the digits say break cut short.
BreakMin=5

; The red bar stops breathing after this many minutes with no input at all -
; by then you have either got up or you are not looking.
StopBreathingAfterMin=15

; Mouse movement counts as being at the desk. 1 means reading with a hand on
; the mouse is sitting. 0 means only keys, clicks and scrolling count, so
; nudging the mouse to keep the screen on does not.
; Either way, a break you declared with Win+F1 only ends on a key or a click.
MouseMovementCounts=1

; With sound playing on any output device you count as here without touching
; anything - watching a film - for at most this many minutes. 0 means sound is
; ignored and only input counts. The screen going dark always wins.
SoundKeepsYouHereMin=120

; Sound counts as still playing for this many seconds after it was last heard,
; so a pause in speech or a gap between songs is not silence.
SoundHoldSec=30

; After you declare a break with Win+F1, input is ignored for this many seconds
; - otherwise the key that started the break would end it straight away.
BreakGuardSec=20

[Habits]
; A habit is a row you tick once a day, and the dots after its name are the
; last few days - green done, red missed, grey still to do today. This is how
; many of those days are shown, TODAY always being the last one. 0 hides the
; dots and gives the room to the name.
DaysShown=7

; Rest days a habit may have in one calendar month - sick, away, a day off on
; purpose. A rest day keeps the streak alive without adding to it. 0 turns
; them off.
RestDaysPerMonth=2

[Log]
; Record which program is in front while you are at the desk. 0 turns the app
; log off; the timer and the journal carry on.
LogApps=1

; How often, in seconds, the program in front is sampled. 5 is the least it
; will take. Finer buys nothing at day scale.
SampleSec=30

; How many programs the TIME AT THE MACHINE drawer lists.
AppsListed=10

[Look]
; How wide the panel is, in pixels, 240 to 700. Everything inside it is spaced
; from this one number. 300 is what the spacing was designed around, and what
; the Hub panel is, so the two stack neatly. Takes a reload.
WidthPx=300

; The tallest the panel is allowed to get, in pixels. Past that it stops
; growing and scrolls instead - a slim bar appears down its right edge, and the
; wheel moves it while the pointer is on it. 0 means as much of the screen as
; there is below wherever you have put the panel.
;
; Type a number here, or use Settings. 800 on a tall screen keeps the panel to
; the top two thirds of it; 0 lets it reach the bottom of the work area.
MaxHeightPx=0

; Rounded corners, the way Windows 11 rounds an ordinary window - every window
; here at once, the panel and the settings window alike, so the two never
; disagree. 0 is square, which is the default: these are panels rather than
; documents, and a square corner is the sharper thing to read a number off.
; Windows 10 has no such setting and ignores this either way.
RoundedCorners=0

; An ordinary window: a taskbar button, a place in Alt+Tab, and it takes
; the keyboard when you click it. 0 is an overlay - none of those, and a
; click never takes the keyboard from what you are in. Either way Daybook
; never brings itself forward on its own: only you raise or restore it.
Taskbar=1

; How faint the panel is in DIM and GHOST mode while the pointer is somewhere
; else, 0-255. Lower is fainter. SOLID is always fully opaque.
FadedAlpha=125

; After you tick or cross a task, how many seconds you have to undo it before
; it is written to the journal.
UndoSec=6

[Files]
; The tray icon - an .ico, .png, .bmp or .jpg. A bare name means a file next to
; Daybook.ahk, so the icon travels with the folder; a full path works too.
; BLANK means the built-in one, a lined pad with a tick, and so does a file
; Windows will not have.
TrayIcon=

[Saved]
; Written by the panel, not by you: where you dragged it to, which sections are
; open, which of SOLID / DIM / GHOST it was left in, and whether it is locked
; and on top. Safe to delete - the panel writes them again when it closes.
; What you have ticked and how long your streaks are is NOT here: that is in
; Daybook-state.txt, beside this file.
    )"
}

