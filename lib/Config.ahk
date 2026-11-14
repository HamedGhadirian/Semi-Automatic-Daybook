;================================================================================
; Config - the version, the settings, the colours, the keys
;================================================================================
; The settings you would ever want to change live in Daybook.ini next to
; Daybook.ahk, seeded with comments the first time the script runs (the
; template is at the bottom of this file). Tray menu > Settings is the way in
; (the kit's settings window, built from DaybookRows() below); every change
; there is written to that file and takes effect at once - DaybookApply() in
; Start.ahk reads the file again. The window has a link at the bottom that
; opens the file itself, where the same settings carry their reasons.
;
; Nothing in the .ini can stop the script from starting: a missing, blank or
; nonsense value falls back to the default written here.
;================================================================================
#Requires AutoHotkey v2.0

; MAJOR.MINOR.PATCH - a dash on the end makes it a test version. The release
; build reads it from this line, and the tag that starts the build must match.
global DaybookVersion := "1.2.0"

; The full path: settings belong next to the script, not in lib\.
global IniFile := A_ScriptDir "\Daybook.ini"

; Every setting, with the default a new download starts with. DaybookLoad()
; reads them from the file - at start, and again after Settings changed one.
;
; The markdown files are the one part of this you can do without. Off, the
; panel, the timer, the habits and their streaks all carry on exactly as they
; are - no daily note is written, and none already there is touched. See
; DayNoteWrite(). The board has a switch of its own.
global JournalOn     := true
global JournalDir    := A_MyDocuments "\Daybook journal"
; Daybook.md in the same folder: where things stand - the lists with their
; notes, the streaks, two weeks of habits. Written by Daybook only; see
; Board.ahk. Independent of Write.
global BoardOn       := true
; Weeks, months and a year: summaries written from the day notes, and each
; month that is over packed into a folder of its own. See Rollup.ahk. Off
; until you turn it on - it is the one thing that moves your files.
global RollupOn      := false
; How long a finished day's list is kept, so that its note can still be
; corrected - and so a week or a month can be looked back over.
global PastKeepDays  := 42
global DayStartHour  := 3        ; 03:00 -> 03:00

; ---- sit timer -------------------------------------------------------------
global SitWarnMin    := 30
global SitBreakMin   := 45
; Away this long = a whole break, and the clock starts clean. Shorter is only a
; pause: the clock carries on from where it was. See CreditBreak().
global BreakLenMin   := 5
global RedQuietMin   := 15
; With sound playing and no input, stay "present" at most this long. 0 means
; sound is not used as a signal at all.
global AudioCapMin   := 120
; Sound counts as playing this long after any device last made one - pauses in
; speech and gaps between songs are not silence.
global SoundHoldS    := 30
; After you declare a break by hand, ignore input for this long - otherwise the
; very keystroke that started it ends it again.
global BreakGuardS   := 20
; Mouse movement counts as being at the desk. See SeenMs().
global CountMouseMove := true

; ---- passive log -----------------------------------------------------------
global LogApps       := true
global SampleMs      := 30000
global StatsTop      := 10

; ---- habits ----------------------------------------------------------------
; How many days of dots a habit row carries, TODAY always being the last one.
; 0 hides the dots and gives the whole row to the name and the streak.
global HabitDays     := 7
; Rest days a habit may have in a calendar month - sick, away, a day off on
; purpose. They hold the chain without adding to it. 0 turns them off. See
; Habits.ahk. (The whole history of every habit is kept: a streak can only be
; measured as far back as the days it is measured from.)
global RestPerMonth  := 2

; ---- panel -----------------------------------------------------------------
; How wide the panel is. Everything horizontal is worked out from it, so this
; is the one number to change; 300 is what the spacing was designed around and
; what the Hub panel matches, so the two stack. Read once, at start: the
; panel's controls are made at this width.
global PanelW        := 300
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
global HdrNumR       := 0                    ; PanelW - Margin, set by DaybookLoad
global CardL         := Margin + Indent      ; 30 at the default width
global CardR         := 0                    ; HdrNumR - Indent, set by DaybookLoad
global RowH          := 26       ; card height
global RowGap        := 4
global MaxRows       := 10       ; per list before it stops drawing
global RowPool       := 32       ; controls pre-made for rows; the lists share
                                 ; them, so this is the total on screen
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
; Grace period before a tick or a cross is written to the journal. Undo inside
; this window and nothing is ever written - see CommitMark().
global MarkDelayMs   := 6000
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
global PanelAlpha    := 125      ; resting: pointer somewhere else
global PanelAlphaHot := 255      ; pointer on it, DIM mode
global PanelAlphaGho := 0        ; pointer on it, GHOST mode - it gets out of
                                 ; the way instead of lighting up
global PanelAlphaSol := 255      ; SOLID mode, resting and hovered alike

; The tallest the panel is allowed to get, in pixels. Past that it stops
; growing and scrolls - see PanelRoom() and PanelScroll(). 0 means as much of
; the screen as there is below where you put it.
;
; A number rather than a draggable edge, deliberately. A frameless window has
; no sizing border, so dragging one means running a loop that follows the
; pointer and lays the whole panel out on every step - and a panel that is
; sometimes exactly as tall as the screen and sometimes two pixels short of it
; is a worse thing to own than a box you type 800 into once.
global PanelMaxH     := 0
; The strip at the top that never scrolls: the bar, the status, the minutes and
; the break switch. They are the reason the panel is on the screen at all, so
; they stay put while everything under them moves.
global PanelHdrH     := 37
; And the strip at the bottom that never scrolls either: the two keys, and the
; mode / on top / lock switches. Set-once things, but things you have to be
; able to reach without scrolling to the end of a list to find them.
global PanelFootH    := 20

; An ordinary window: a taskbar button, a place in Alt+Tab, focus when you
; click it, and a taskbar click minimises it. 0 is the overlay it used to be -
; none of those, and a click never takes the keyboard from what you are in.
; Either way Daybook never brings itself forward: a timer running out, the
; minutes moving, a day closing - none of it raises, restores or focuses the
; panel. Only you do. See ApplyWindowKind().
global PanelTaskbar  := true
global PanelBtns     := ""        ; the window buttons, top right (KitWinBtns)
global PanelKind     := ""        ; which of the two the window is right now

; ---- tray ------------------------------------------------------------------
; Your own tray icon - [Icons] Tray in the .ini (the kit writes that section;
; until 1.2.0 the line was [Files] TrayIcon, carried over). Blank means
; icon.png beside Daybook.ahk; a file that is not there, or an image Windows
; refuses, falls back to the built-in one rather than erroring. See TrayIconPath().
global TrayIcon      := ""

; ---- future ----------------------------------------------------------------
global NagLevel      := 0        ; 0 = colours only. Teeth would start here.

;================================================================================
; Reading them
;================================================================================
; first: the start. The panel's width is only read then - its controls are
; made at that width, so a new one takes a reload (Settings says so).
DaybookLoad(first := false) {
    global
    local f := IniFile
    JournalOn      := CfgBool(f, "Journal", "Write", true)
    JournalDir     := CfgStrDef(f, "Journal", "Folder", A_MyDocuments "\Daybook journal")
    BoardOn        := CfgBool(f, "Journal", "Board", true)
    RollupOn       := CfgBool(f, "Journal", "RollUp", false)
    DayStartHour   := CfgNum(f, "Journal", "DayStartsAtHour", 3)
    SitWarnMin     := CfgNum(f, "Timer", "AmberAfterMin", 30)
    SitBreakMin    := CfgNum(f, "Timer", "RedAfterMin", 45)
    BreakLenMin    := CfgNum(f, "Timer", "BreakMin", 5)
    RedQuietMin    := CfgNum(f, "Timer", "StopBreathingAfterMin", 15)
    AudioCapMin    := CfgNum(f, "Timer", "SoundKeepsYouHereMin", 120)
    SoundHoldS     := CfgNum(f, "Timer", "SoundHoldSec", 30)
    BreakGuardS    := CfgNum(f, "Timer", "BreakGuardSec", 20)
    CountMouseMove := CfgBool(f, "Timer", "MouseMovementCounts", true)
    LogApps        := CfgBool(f, "Log", "LogApps", true)
    SampleMs       := CfgNum(f, "Log", "SampleSec", 30) * 1000
    StatsTop       := CfgNum(f, "Log", "AppsListed", 10)
    HabitDays      := CfgNum(f, "Habits", "DaysShown", 7)
    RestPerMonth   := CfgNum(f, "Habits", "RestDaysPerMonth", 2)
    if first
        PanelW     := CfgNum(f, "Look", "WidthPx", 300)
    PanelMaxH      := CfgNum(f, "Look", "MaxHeightPx", 0)
    PanelTaskbar   := CfgBool(f, "Look", "Taskbar", true)
    PanelAlpha     := CfgNum(f, "Look", "FadedAlpha", 125)
    MarkDelayMs    := CfgNum(f, "Look", "UndoSec", 6) * 1000
    TrayIcon       := KitIcons.Path()       ; [Icons] Tray; icon.png beside Daybook.ahk when blank
    ClampConfig()
    HdrNumR := PanelW - Margin
    CardR   := HdrNumR - Indent
}

;================================================================================
; The rules the numbers above have to obey
;================================================================================
; Nothing here is taste - each one is a value that would break something
; rather than merely look wrong.
ClampConfig() {
    global
    SampleMs := Round(SampleMs)
    if (SampleMs < 5000)                 ; sampling faster buys nothing at all
        SampleMs := 5000
    if (BreakLenMin < 1)
        BreakLenMin := 1
    if (SitBreakMin < 1)                 ; the bar divides by this
        SitBreakMin := 45
    DayStartHour := Round(DayStartHour)
    if (DayStartHour < 0 || DayStartHour > 23)
        DayStartHour := 3
    ; More dots than the row is wide would eat the name. 14 still leaves room.
    HabitDays := Round(HabitDays)
    if (HabitDays < 0)
        HabitDays := 0
    if (HabitDays > 14)
        HabitDays := 14
    if (RestPerMonth < 0)
        RestPerMonth := 0
    PanelAlpha := Round(PanelAlpha)
    if (PanelAlpha < 0)
        PanelAlpha := 0
    if (PanelAlpha > 255)
        PanelAlpha := 255
    StatsTop := Round(StatsTop)
    if (StatsTop < 1)
        StatsTop := 1
    ; Narrower than this and a task card has no room for words; wider and it
    ; has stopped being a panel in the corner of the screen.
    PanelW := Round(PanelW)
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
    MarkDelayMs := Round(MarkDelayMs)
    if (MarkDelayMs < 1)
        MarkDelayMs := 1
}

;================================================================================
; Colours
;================================================================================
; The family's palette (lib\Kit\Theme.ahk), dark or light as Settings >
; GENERAL says. Dark until DaybookColours copies them in at start.
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
; One accent blue, used for things that are neither a warning nor a
; reassurance: section titles, a rest day, and a break you declared yourself.
global CBlue    := "3D9BE9"
global CBreak   := CBlue
; Three of Daybook's own, which the palette has no role for:
;   CToday   today's dot on a habit not done yet. It used to be CTrack, which
;            is almost exactly the colour of a row under the pointer, so the dot
;            vanished the moment you hovered the row. This one shows on both.
;   COff     a day the rule allowed off - grey, not red
;   COld     an older miss: the dark red the overdue bar breathes through
global CToday   := "6A7390"
global COff     := "3A4052"
global COld     := "8A2A3C"
; The breathing red bar, one shade a step.
global CBreathe := ["8A2A3C", "A33049", "C03A57", "FF4D6D", "C03A57", "A33049", "8A2A3C", "742536"]

DaybookColours() {
    global
    CBg := Theme.Bg, CCard := Theme.Card, CCardHi := Theme.CardHi, CTrack := Theme.Track
    CText := Theme.Text, CMuted := Theme.Muted, CDim := Theme.Dim
    CGreen := Theme.Green, CAmber := Theme.Amber, CRed := Theme.Red, CBlue := Theme.Blue
    CBreak := CBlue
    if Theme.dark {
        CToday := "6A7390", COff := "3A4052", COld := "8A2A3C"
        CBreathe := ["8A2A3C", "A33049", "C03A57", "FF4D6D", "C03A57", "A33049", "8A2A3C", "742536"]
    } else {
        CToday := "9AA1B5", COff := "D3D7E1", COld := "E7A3B0"
        CBreathe := ["F0B7C2", "E58B9D", "DC607A", "D33A55", "DC607A", "E58B9D", "F0B7C2", "F6CDD5"]
    }
}

;================================================================================
; The keys - the kit's (lib\Kit\Keys.ahk), changeable in Settings > KEYS
;================================================================================
; Only two. Everything else is a click on the panel.
DaybookKeys() {
    return [{id: "Panel", name: "The panel: solid, dim, ghost, hidden", short: "panel", def: "#F6"
            , fn: (hk) => CyclePanel()}
        , {id: "Break", name: "A break, or back from one", short: "break", def: "#F1"
            , fn: (hk) => ToggleBreak()}]
}

; The two keys as the panel's footer says them: "Win+F6 panel  ·  Win+F1 break"
KeyFootText() {
    out := ""
    for a in DaybookKeys() {
        hk := KitKeys.Cur(a.id)
        if (hk != "")
            out .= (out != "" ? "   " Chr(0x00B7) "   " : "") KitKeys.Label(hk, true) " " a.short
    }
    return out
}

;================================================================================
; The settings window's own rows - under GENERAL and KEYS, which are the kit's
;================================================================================
; Each row names its line in Daybook.ini; the kit writes it the moment it
; changes, and DaybookApply() then reads the file again.
DaybookRows() {
    return [{kind: "head", label: "THE JOURNAL"}
        , {kind: "bool", sect: "Journal", key: "Write", def: 1, label: "Keep a journal"
            , hint: "A note a day: your journal on top, Daybook's summary under it."
                . " Off: nothing is written, and JOURNAL leaves the panel."}
        , {kind: "bool", sect: "Journal", key: "Board", def: 1, label: "Write Daybook.md"
            , hint: "Where things stand: your lists, the streaks, two weeks of habits. Rewritten as things change."}
        , {kind: "bool", sect: "Journal", key: "RollUp", def: 0, label: "Weeks and months"
            , hint: "A note for each week, month and year, from the day notes. A month"
                . " that is over moves into a folder: 2026\2026-10 October."}
        , {kind: "path", sect: "Journal", key: "Folder", def: "", label: "Folder", pick: "folder"
            , title: "Where the daily journal files go", cue: A_MyDocuments "\Daybook journal"
            , hint: "One YYYY-MM-DD.md per day goes here. It has to exist already - pick makes one."
                . " Empty: a Daybook journal folder in Documents."}
        , {kind: "note", label: "Plain .md files - Obsidian or any editor opens them. Your writing at the"
            . " top of a day note goes both ways: write it in Daybook or anywhere else. Daybook's block"
            . " under it, Daybook.md and the week and month notes are Daybook's: it writes them again,"
            . " so change things on the panel, not in the files."}
        , {kind: "num", sect: "Journal", key: "DayStartsAtHour", def: 3, min: 0, max: 23, unit: "o'clock"
            , label: "A day starts at", hint: "At 3, a session at 2am still belongs to yesterday."}

        , {kind: "head", label: "THE SIT TIMER"}
        , {kind: "num", sect: "Timer", key: "AmberAfterMin", def: 30, min: 0, max: 600, unit: "minutes"
            , label: "Amber after", hint: "The bar stops being green."}
        , {kind: "num", sect: "Timer", key: "RedAfterMin", def: 45, min: 1, max: 600, unit: "minutes"
            , label: "Red after", hint: "It goes red and pulses, and the digits start counting up."}
        , {kind: "num", sect: "Timer", key: "StopBreathingAfterMin", def: 15, min: 0, max: 600, unit: "minutes"
            , label: "Stop pulsing after", hint: "No keys or mouse for this long - say, while you watch a"
                . " movie - and the red bar stops pulsing. It stays red."}
        , {kind: "num", sect: "Timer", key: "BreakMin", def: 5, min: 1, max: 120, unit: "minutes"
            , label: "A break is", hint: "Away this long clears the clock. Less only pauses it, and the"
                . " digits then say the break was cut short."}
        , {kind: "bool", sect: "Timer", key: "MouseMovementCounts", def: 1, label: "Mouse moving counts"
            , hint: "On: reading with a hand on the mouse is sitting. Off: only keys, clicks and the wheel count."}
        , {kind: "num", sect: "Timer", key: "SoundKeepsYouHereMin", def: 120, min: 0, max: 1440, unit: "minutes"
            , label: "Sound holds you", hint: "You watch a movie and touch nothing: while sound plays, that is"
                . " still sitting - for this long at most. 0 ignores sound. A dark screen always means away."}

        , {kind: "head", label: "HABITS"}
        , {kind: "num", sect: "Habits", key: "DaysShown", def: 7, min: 0, max: 14, unit: "days"
            , label: "Days of dots", hint: "The run of dots on a habit row, today last. 0 hides them and"
                . " gives the room to the name."}
        , {kind: "num", sect: "Habits", key: "RestDaysPerMonth", def: 2, min: 0, max: 31, unit: "per habit"
            , label: "Rest days a month", hint: "Sick, away, a day off: a rest day keeps the streak without"
                . " adding to it. 0 turns them off."}

        , {kind: "head", label: "THE APP LOG"}
        , {kind: "bool", sect: "Log", key: "LogApps", def: 1, label: "Record what is in front"
            , hint: "Process names only, and only while you are at the desk."}
        , {kind: "num", sect: "Log", key: "SampleSec", def: 30, min: 5, max: 3600, unit: "seconds"
            , label: "Look every", hint: "5 is the fastest it will go. Finer buys nothing at day scale."}
        , {kind: "num", sect: "Log", key: "AppsListed", def: 10, min: 1, max: 50, unit: "of them"
            , label: "Programs listed", hint: "How many lines TIME AT THE MACHINE opens to."}

        , {kind: "head", label: "THE PANEL"}
        , {kind: "num", sect: "Look", key: "FadedAlpha", def: 125, min: 0, max: 255, unit: "of 255"
            , label: "Faded to", hint: "How faint DIM and GHOST are with the pointer somewhere else."
                . " Lower is fainter. SOLID is always solid."}
        , {kind: "num", sect: "Look", key: "WidthPx", def: 300, min: 240, max: 700, unit: "pixels"
            , label: "Panel width", hint: "Everything in the panel is spaced from this."
                . " Takes a reload (tray menu), unlike the rest of this window."}
        , {kind: "num", sect: "Look", key: "MaxHeightPx", def: 0, min: 0, max: 10000, unit: "pixels"
            , label: "Tallest it gets", hint: "Past this the panel scrolls instead of growing. 0 is as"
                . " much of the screen as there is below it."}
        , {kind: "bool", sect: "Look", key: "Taskbar", def: 1, label: "On the taskbar"
            , hint: "Off: no taskbar button."}]
    ; Not here, and still in Daybook.ini for anyone who wants them: the tray
    ; icon, how long a silence may be (SoundHoldSec), how long input is ignored
    ; after the break key (BreakGuardSec), and the undo window (UndoSec). Each
    ; has a default that is right, and a new user never needs to think of it.
}

;================================================================================
; Daybook.ini - what gets written the first time the script runs
;================================================================================
; Only ever written when the file is NOT there, so it can never overwrite a
; setting you changed. Plain ASCII, and no double quotes in the text.
DaybookIniTemplate() {
    head := "
    (
; Daybook settings - the day panel.
;
; Easiest from the tray menu: Settings. Everything in this file is there
; except the tray icon, and a change made there works at once. If you edit
; this file by hand instead, reload Daybook after (tray menu, Reload).
;
; Anything you delete or mistype falls back to its default. Nothing in this
; file can stop the script from starting.


    )"
    own := "
    (
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

; Look back: a note for each week that ends (2026-W42.md), and for each
; month - the days you wrote, the time at the machine, the tasks, the
; habits - with a few questions on top that are yours. A month that is over
; is packed: its days and weeks move into 2026\2026-10 October\. Plus a
; year note, a line a month. Files are moved, never deleted. 0 = off.
RollUp=0

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

; No keys or mouse for this many minutes - say, while you watch a movie - and
; the red bar stops pulsing. It stays red.
StopBreathingAfterMin=15

; How long you have to be away for it to count as a break. Away this long or
; longer and the clock starts again from zero. Shorter is only a pause: the
; clock carries on from where it was, so a red bar stays red until you take a
; whole one, and the digits say break cut short.
BreakMin=5

; Mouse movement counts as being at the desk. 1 means reading with a hand on
; the mouse is sitting. 0 means only keys, clicks and scrolling count, so
; nudging the mouse to keep the screen on does not.
; Either way, a break you declared with the break key only ends on a key or
; a click.
MouseMovementCounts=1

; With sound playing on any output device you count as here without touching
; anything - watching a film - for at most this many minutes. 0 means sound is
; ignored and only input counts. The screen going dark always wins.
SoundKeepsYouHereMin=120

; Sound counts as still playing for this many seconds after it was last heard,
; so a pause in speech or a gap between songs is not silence.
SoundHoldSec=30

; After you declare a break with the break key, input is ignored for this
; many seconds - otherwise the key that started the break would end it
; straight away.
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
; from this one number. 300 is what the spacing was designed around. Takes a
; reload.
WidthPx=300

; The tallest the panel is allowed to get, in pixels. Past that it stops
; growing and scrolls instead - a slim bar appears down its right edge, and the
; wheel moves it while the pointer is on it. 0 means as much of the screen as
; there is below wherever you have put the panel.
MaxHeightPx=0

; A taskbar button, like any window. 0: no taskbar button.
Taskbar=1

; How faint the panel is in DIM and GHOST mode while the pointer is somewhere
; else, 0-255. Lower is fainter. SOLID is always fully opaque.
FadedAlpha=125

; After you tick or drop a task, how many seconds you have to take it back
; before it is written to the click log (log\ beside Daybook). Taken back
; later, the log says so in a line of its own.
UndoSec=6

[Saved]
; Written by the panel, not by you: where you dragged it to, which sections are
; open, which of SOLID / DIM / GHOST it was left in, and whether it is locked
; and on top. Safe to delete - the panel writes them again when it closes.
; What you have ticked and how long your streaks are is NOT here: that is in
; Daybook-state.txt, beside this file.

    )"
    return head Kit.IniGeneral("so the two keys also work while a program that runs as administrator is in front") own
}
