;================================================================================
; Config
;================================================================================
; The settings you would ever want to change live in Daybook.ini next to this
; file, seeded with comments the first time the script runs. Tray menu >
; Settings is the way in (SettingsWin.ahk); every change there is written to
; that file and takes effect at once, and the window has a link at the bottom
; that opens the file itself, where the same settings carry their reasons.
; Ini.ahk holds what gets written on the first run. What is left in this section
; is layout arithmetic, which a stray number would break.
;
; Nothing in the .ini can stop the script from starting: a missing, blank or
; nonsense value falls back to the default written here.
; The full path, not just a name: CfgSeed would otherwise put the file beside
; Settings.ahk, which is in lib\. Settings belong next to the script.
global IniFile := CfgSeed(A_ScriptDir "\Daybook.ini", DaybookIniTemplate())

; Shown in the settings window and in the tray tip. MAJOR.MINOR.PATCH; a dash
; on the end makes it a test build, the way Vocab does it.
global DaybookVersion := "1.1.0"

; Read a SECOND time here, and on purpose. Daybook.ahk has to know this before
; a single one of these files is loaded - deciding whether to relaunch itself
; is the first thing it does - so it reads the key with a plain IniRead of its
; own. This copy exists only so the settings window has something to show and
; to write. Nothing else reads it; changing it takes effect at the next start.
global RunAsAdmin    := CfgBool(IniFile, "General", "RunAsAdmin", false)

; The markdown files are the one part of this you can do without. Off, the
; panel, the timer, the habits and their streaks all carry on exactly as they
; are - no daily note is written, and none already there is touched. See
; DayNoteWrite(). The board has a switch of its own.
global JournalOn     := CfgBool(IniFile, "Journal", "Write", true)
global JournalDir    := CfgStrDef(IniFile, "Journal", "Folder", A_MyDocuments "\Daybook journal")
; Daybook.md in the same folder: where things stand - the lists with their
; notes, the streaks, two weeks of habits. Written by Daybook only; see
; Board.ahk. Independent of Write.
global BoardOn       := CfgBool(IniFile, "Journal", "Board", true)
; How long a finished day's list is kept, so that its note can still be
; corrected - and, later, so a week or a month can be looked back over.
global PastKeepDays  := 42
global DayStartHour  := CfgNum(IniFile, "Journal", "DayStartsAtHour", 3)   ; 03:00 -> 03:00

; ---- sit timer -------------------------------------------------------------
global SitWarnMin    := CfgNum(IniFile, "Timer", "AmberAfterMin", 30)
global SitBreakMin   := CfgNum(IniFile, "Timer", "RedAfterMin", 45)
; Away this long = a whole break, and the clock starts clean. Shorter is only a
; pause: the clock carries on from where it was. See CreditBreak().
global BreakLenMin   := CfgNum(IniFile, "Timer", "BreakMin", 5)
global RedQuietMin   := CfgNum(IniFile, "Timer", "StopBreathingAfterMin", 15)
; With sound playing and no input, stay "present" at most this long. 0 means
; sound is not used as a signal at all.
global AudioCapMin   := CfgNum(IniFile, "Timer", "SoundKeepsYouHereMin", 120)
; Sound counts as playing this long after any device last made one - pauses in
; speech and gaps between songs are not silence.
global SoundHoldS    := CfgNum(IniFile, "Timer", "SoundHoldSec", 30)
; After you declare a break by hand, ignore input for this long - otherwise the
; very keystroke that started it ends it again.
global BreakGuardS   := CfgNum(IniFile, "Timer", "BreakGuardSec", 20)
; Mouse movement counts as being at the desk. See SeenMs().
global CountMouseMove := CfgBool(IniFile, "Timer", "MouseMovementCounts", true)

; ---- passive log -----------------------------------------------------------
global LogApps       := CfgBool(IniFile, "Log", "LogApps", true)
global SampleMs      := CfgNum(IniFile, "Log", "SampleSec", 30) * 1000
global StatsTop      := CfgNum(IniFile, "Log", "AppsListed", 10)

; ---- habits ----------------------------------------------------------------
; How many days of dots a habit row carries, TODAY always being the last one.
; 0 hides the dots and gives the whole row to the name and the streak.
global HabitDays     := CfgNum(IniFile, "Habits", "DaysShown", 7)
; Rest days a habit may have in a calendar month - sick, away, a day off on
; purpose. They hold the chain without adding to it. 0 turns them off. See
; Habits.ahk. (The whole history of every habit is kept: a streak can only be
; measured as far back as the days it is measured from.)
global RestPerMonth  := CfgNum(IniFile, "Habits", "RestDaysPerMonth", 2)

; ---- panel -----------------------------------------------------------------
; How wide the panel is. Everything horizontal is worked out from it, so this
; is the one number to change; 300 is what the spacing was designed around and
; what the Hub panel matches, so the two stack.
global PanelW        := CfgNum(IniFile, "Look", "WidthPx", 300)
; Three numbers own every horizontal position on this panel.
;
;   HdrNumR   the right edge everything in a HEADING row lines up on: the +,
;             the break switch, and the running total. Nothing is hardcoded to
;             it any more - move this and all three follow.
;   CardL     left edge of anything INSIDE a section
;   CardR     right edge of the same
;   Indent    how far the per-app times sit inside the total above them
;
;   heading    TIME AT THE MACHINE ............ 3h 47m   +   <- ends at HdrNumR
;   contents      claude ..................... 1h 23m        <- CardL .. CardR
;
; so the names sit in from the heading by as much as their times sit in from the
; total, and a task card does the same against its heading and its +.
global Indent        := 8
global Margin        := 22                   ; the panel's edge to its contents
global HdrNumR       := PanelW - Margin      ; right edge of a heading's number
global CardL         := Margin + Indent      ; 30 at the default width
global CardR         := HdrNumR - Indent     ; 270 at the default width
global RowH          := 26       ; card height
global RowGap        := 4
global MaxRows       := 10       ; per list before it stops drawing
global RowPool       := 32       ; controls pre-made for rows; the three lists
                                 ; share them, so this is the total on screen
; Habit rows have their own pool - three controls each, and a shape nothing
; else on the panel has. A habit you never do is still a habit, so the list
; does not grow the way the task lists do and ten is plenty.
global HabPool       := 10
global HabDotD       := 7        ; a dot, across
global HabDotGap     := 3        ; and the space between two of them
global HabNumW       := 36       ; the streak column: "1000", or "112w" for weeks
global CapW          := 260      ; capture box: the panel's width, or this as a
global NoteW         := 260      ; floor if the panel is ever narrower
global BoxMaxLines   := 6        ; the most either box grows to before it scrolls
global MarkDelayMs   := CfgNum(IniFile, "Look", "UndoSec", 6) * 1000
                                 ; grace period before a tick or a cross is
                                 ; written to the journal. Undo inside this
                                 ; window and nothing is ever written - see
                                 ; CommitMark().
; Window transparency, 0 (invisible) to 255 (solid). The mode switch cycles three
; modes, and each one is just a pair of these numbers - what the panel looks
; like at rest, and what it looks like with the pointer on it:
;
;   SOLID  255 / 255   never reacts, never in the way of reading it
;   DIM    125 / 255   comes forward when you go to use it      (the default)
;   GHOST  125 /   0   retreats instead, and is click-through
;
; RestAlpha() and HotAlpha() are the two functions that read this table; which
; mode you are in lives in PanelMode.
global PanelAlpha    := CfgNum(IniFile, "Look", "FadedAlpha", 125)
                                 ; resting: pointer somewhere else
global PanelAlphaHot := 255      ; pointer on it, DIM mode
global PanelAlphaGho := 0        ; pointer on it, GHOST mode - it gets out of
                                 ; the way instead of lighting up
global PanelAlphaSol := 255      ; SOLID mode, resting and hovered alike

; The tallest the panel is allowed to get, in pixels. Past that it scrolls -
; see PanelRoom() and PanelScroll(). 0 means "as much of the screen as there is
; below where you put it", which is what you want unless you would rather the
; panel simply never got big.
; The tallest the panel is allowed to get, in pixels. Past that it stops
; growing and scrolls - see PanelRoom() and PanelScroll(). 0 means as much of
; the screen as there is below where you put it.
;
; A number rather than a draggable edge, deliberately. A frameless window has
; no sizing border, so dragging one means running a loop that follows the
; pointer and lays the whole panel out on every step - and a panel that is
; sometimes exactly as tall as the screen and sometimes two pixels short of it
; is a worse thing to own than a box you type 800 into once.
global PanelMaxH     := CfgNum(IniFile, "Look", "MaxHeightPx", 0)
; The strip at the top that never scrolls: the bar, the status, the minutes and
; the break switch. They are the reason the panel is on the screen at all, so
; they stay put while everything under them moves.
global PanelHdrH     := 37
; And the strip at the bottom that never scrolls either: the two keys, and the
; mode / on top / lock switches. Set-once things, but things you have to be
; able to reach without scrolling to the end of a list to find them.
global PanelFootH    := 20

; Rounded corners, the way Windows 11 rounds an ordinary window - for EVERY
; window here, the panel and the settings window alike, so the two never
; disagree with each other. Square by default: these are panels rather than
; documents, and a square corner is the sharper thing to read a number off.
;
; Windows rounds a titled window like the settings one unless asked not to, and
; leaves a frameless one like the panel square unless asked to - so both are
; asked, every time, and this one switch decides. See ShapeWindow(). Windows 10
; has no such attribute and ignores either request.
global PanelRound    := CfgBool(IniFile, "Look", "RoundedCorners", false)

; An ordinary window: a taskbar button, a place in Alt+Tab, focus when you
; click it, and a taskbar click minimises it. 0 is the overlay it used to be -
; none of those, and a click never takes the keyboard from what you are in.
; Either way Daybook never brings itself forward: a timer running out, the
; minutes moving, a day closing - none of it raises, restores or focuses the
; panel. Only you do. See ApplyWindowKind().
global PanelTaskbar  := CfgBool(IniFile, "Look", "Taskbar", true)
global PanelKind     := ""        ; which of the two the window is right now

; ---- tray ------------------------------------------------------------------
; Your own tray icon - see [Files] in the .ini. A path that does not exist, or
; an image Windows refuses, falls back to the built-in one rather than erroring.
; Blank by default: an icon is a file, and a default naming one that exists only
; on the machine this was written on is a default that is wrong everywhere else.
global TrayIcon      := CfgStr(IniFile, "Files", "TrayIcon", "")

; ---- future ----------------------------------------------------------------
global NagLevel      := 0        ; 0 = colours only. Teeth would start here.

; A few values that would break something rather than just look odd. In a
; function because the settings window sets the same variables while the script
; is running (SettingsWin.ahk), and a rule enforced in only one of the two
; places is a rule that holds until the day you change it in the other.
ClampConfig()

;================================================================================
; Colours
;================================================================================
global CBg      := "181B24"
global CCard    := "202430"
global CCardHi  := "2A3040"      ; row under the pointer
global CTrack   := "2A2F40"      ; unfilled part of the top bar
global CText    := "EBEEF5"
global CMuted   := "8C94AA"
global CDim     := "5F677D"
global CGreen   := "00E676"
global CAmber   := "FFB300"
global CRed     := "FF4D6D"
; One accent blue, used for two things that are neither a warning nor a
; reassurance: the section titles in the settings window, and a break you
; declared yourself.
global CBlue    := "3D9BE9"
global CBreak   := CBlue

;================================================================================
; The rules the numbers above have to obey
;================================================================================
; Called once on the way in, and again every time the settings window changes
; one of them. Nothing here is taste - each one is a value that would break
; something rather than merely look wrong.
ClampConfig() {
    global
    if (SampleMs < 5000)                 ; sampling faster buys nothing at all
        SampleMs := 5000
    if (BreakLenMin < 1)
        BreakLenMin := 1
    if (SitBreakMin < 1)                 ; the bar divides by this
        SitBreakMin := 45
    if (DayStartHour < 0 || DayStartHour > 23)
        DayStartHour := 3
    ; More dots than the row is wide would eat the name. 14 still leaves room.
    if (HabitDays < 0)
        HabitDays := 0
    if (HabitDays > 14)
        HabitDays := 14
    if (RestPerMonth < 0)
        RestPerMonth := 0
    if (PanelAlpha < 0)
        PanelAlpha := 0
    if (PanelAlpha > 255)
        PanelAlpha := 255
    if (StatsTop < 1)
        StatsTop := 1
    ; Narrower than this and a task card has no room for words; wider and it
    ; has stopped being a panel in the corner of the screen.
    if (PanelW < 240)
        PanelW := 240
    if (PanelW > 700)
        PanelW := 700
    ; Negative minutes and seconds parse perfectly well and then quietly turn
    ; a feature off - a negative guard ends a break the instant it starts, a
    ; negative hold means sound is never heard. Zero already means "off" for
    ; all of these and says so in the .ini, so nothing below zero is a thing
    ; anyone meant.
    if (SitWarnMin < 0)
        SitWarnMin := 0
    if (RedQuietMin < 0)
        RedQuietMin := 0
    if (AudioCapMin < 0)
        AudioCapMin := 0
    if (SoundHoldS < 0)
        SoundHoldS := 0
    if (BreakGuardS < 0)
        BreakGuardS := 0
    ; UndoSec 0 is a fair choice - write the line at once, no taking it back -
    ; but the timer that carries it has to be given some delay to run at.
    if (MarkDelayMs < 1)
        MarkDelayMs := 1
}
