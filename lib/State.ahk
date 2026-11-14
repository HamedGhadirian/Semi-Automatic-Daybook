;================================================================================
; State - every value the script keeps while it runs
;================================================================================
; Records are made by Rec() (Store.ahk): a task, a habit or a finished day's
; line answers "" for a field it does not have, the way it always did - a
; state file from an older version simply has fewer fields.
#Requires AutoHotkey v2.0

; ---- kept in Daybook-state.txt ----------------------------------------------
; list: "T" today, "S" short term (due is its deadline, a day), "L" long term,
; "M" missed (since is the day it was meant for)
global Tasks        := []        ; {list:"T"/"S"/"L"/"M", text, status, carry, born, due, asked, since, notes}
global Habits       := []        ; {text, born, streak, best, total, done:[days], rest:[days], kind, n, unit}
global CurDay       := ""
global SitSec       := 0
global AwaySec      := 0
global Away         := 0         ; the sensors say you are gone (not a declared break)
global CutShort     := 0         ; came back early from a break taken while overdue
global AppSec       := DayMap()  ; program -> seconds today
global HourSec      := DayMap()  ; "HH|program" -> seconds
global NextTaskId   := 1         ; the id the next new task gets - see Tasks.ahk
; What each finished day had on its list, kept so its note can still be
; rewritten when something about it changes afterwards - an answer to "why
; not?" given the next morning. {day, id, list, status, carry, note, text}, for
; PastKeepDays. CloseDay() fills it.
global Past         := []
global NoteBusy     := 0         ; Daybook is writing a day note - see DayNoteWrite()
global PastTime     := DayMap()  ; day -> that day's time-at-the-machine text
global NoteFor      := ""        ; the note box is open for {id, day[, drop]}
global StateNoSave  := 0         ; the state file could not be read OR set aside
global StateQuiet   := 0         ; the tests set it, to say nothing aloud
; Two more for the tests, both empty in the real run: the day it is, and the
; header of the note box that would have opened (the tests build no panel and
; no boxes - see Refresh() and ShowNote()).
global FakeToday    := ""
global NoteAsked    := ""
global Journalled   := ""        ; an array in the tests: every log line, kept
global JournalTwins := ""        ; a day with two notes that both have your words

; ---- runtime ---------------------------------------------------------------
global StateFile    := A_ScriptDir "\Daybook-state.txt"
global PanelGui := "", CapGui := "", NoteGui := ""
global PanelHwnd := 0, CapHwnd := 0, NoteHwnd := 0
global OpenMissed   := 1         ; the MISSED section - list code "M", see Missed.ahk
global OpenToday    := 1
global OpenShort    := 1         ; the SHORT TERM TASKS section - list code "S"
global OpenLong     := 0         ; the LONG TERM TASKS section - list code "L"
global OpenStats    := 0
global OpenHabits   := 1
global PanelVisible := 1
global PanelWasMin  := 0         ; minimised from the taskbar - see PnlSize
global PanelMode    := 1         ; 0 SOLID, 1 DIM, 2 GHOST - see PanelAlpha
global PanelLocked  := 0         ; the lock button: drags are ignored while set
global PanelOnTop   := 1         ; floating over everything, or an ordinary window
global TrayReady    := false     ; the tray menu exists - see DaybookTray()
global PanelX := "", PanelY := ""
global RowTask      := []        ; task pool row -> index into Tasks
global RowY         := []        ; task pool row -> y, for the note box
global HabRow       := []        ; habit pool row -> index into Habits
; Every card on the panel, in the order it is drawn: {y, kind:"T"/"H", pool}.
; One list rather than one per section, because painting, hovering and
; right-clicking all ask the same question - what is under this y - and asking
; it twice is how the two lists drift apart. Layout.ahk fills it.
global Cards        := []
global HotCard      := 0         ; index into Cards, or 0
global PanelColours := Map()     ; control name -> the colour PSay last gave it
global Dots         := []        ; {x, y, c, hab, day} - the habit dots, painted in OnErase
global StatsShown   := 0         ; how many app lines the drawer was SIZED for
; The panel scrolls once its content is taller than the room below it. The
; offset is subtracted in Relayout rather than scrolled with ScrollWindowEx,
; because everything here is laid out from a y that starts at the top anyway -
; so "scrolled" is just a different starting y, and every card rectangle, dot
; and hit test comes out right without knowing anything about it.
global PanelScrollY  := 0        ; how far down the content the window is looking
global PanelContentH := 0        ; how tall it would be if it all fitted
global PanelScrollMax := 0       ; 0 when it all fits, and then nothing scrolls
global PanelRelaying := 0        ; laying out inside a layout - see Relayout()
global PanelFootLine := 0        ; the y the scrolling part has to stop above
; The counts Refresh() makes for Relayout(): open today, and how many in each list
global NOpen := 0, NToday := 0, NLong := 0, NMiss := 0, NShort := 0
global Meters       := []        ; one peak meter per active playback device
global MeterAt      := 0
global LastSoundAt  := 0         ; last tick any of them heard anything
global BreathStep   := 0
global EdgeState    := -1
global DisplayOn    := 1
global BreakMode    := 0         ; you pressed the break key: ground truth beats sensors
global BreakStart   := 0
global AwayIdleMs   := 0
global LastClickTick := 0        ; last mouse click or wheel event, see IdleMs()
global MissMenuId   := 0         ; the task the "did it on..." menu is for
global MenuTask     := 0
global MenuHabit    := 0
global DueGui := "", DueHwnd := 0, DueMode := "", DueWords := "", DueId := 0   ; the deadline picker - Due.ahk
global DueW := 0, DueH := 0, DueMonth := "", DueCells := [], DueWas := ""
global CapList      := "T"       ; which list the capture box was opened for
global CapMode      := "add"     ; "add" or "rename" - what Enter will do
global CapTask      := 0         ; the task or habit being renamed
global CapHintAdd   := ""        ; the normal hint, restored after a rename
global PendMarkKind := ""        ; "T" a task, "H" a habit, "" nothing pending
global PendMarkTask := 0         ; a tick/cross waiting out its grace period
global PendMarkStatus := ""
global BoxBase      := Map()     ; each growing box's one-line shape - see BoxFit()
; ---- the habit window - see HabitWin.ahk --------------------------------------
global HabEdGui := "", HabEdHwnd := 0, HabEdName := "", HabEdMonth := ""
global HabEdEnd := "yesterday", HabEdCells := [], HabEdLoading := 0, HabEdTyped := ""
global HabEdW := 0, HabEdH := 0
global HabEdN2Was := "", HabEdN3Was := ""
; ---- the journal window - see JournalWin.ahk ----------------------------------
global JrnGui := "", JrnHwnd := 0, JrnW := 0, JrnH := 0, JrnDay := ""
global JrnBase := "", JrnAsk := 0, JrnAskFile := "", JrnNameBase := ""
global JrnEdH := 440, JrnClosing := 0

global LastShownMin := 9999
global Hot          := false
global PanelH       := 200
