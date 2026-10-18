; Habits.test.ahk - the habit rules, with the clock faked
;
; Loads the real lib\Habits.ahk and nothing else. Everything it leans on -
; today's date, the journal, saving - is stubbed here, so a failure is a
; failure in the rules and not in something four files away. LogicalDay and
; DayShift are copied from lib\Day.ahk exactly, and the first block of tests
; checks the copy against the calendar.
;
; Run it with run-tests.ps1 in this folder, or on its own.
#NoEnv
#SingleInstance off
SetBatchLines -1

global DayStartHour := 3
global RestPerMonth := 2
global HabitDays := 7
global HabitBoardOn := 0
global JournalDir := ""
global Habits := []
global CGreen := "00E676", CAmber := "FFB300", CRed := "FF4D6D"
global CTrack := "2A2F40", CDim := "5F677D", CBlue := "3D9BE9"
global Fails := 0, Log := ""
global FakeToday := ""
global Journalled := []
global JournalOn := 0
global NoteDir := A_ScriptDir "\journal"

DayNoteWrite(day, force := false) {
}
JournalFile(day, fold := false) {
    global NoteDir
    return NoteDir "\" day ".md"
}

LogicalDay() {
    global FakeToday
    if (FakeToday != "")
        return FakeToday
    shift := -DayStartHour
    t := A_Now
    t += %shift%, Hours
    FormatTime, d, %t%, yyyy-MM-dd
    return d
}

DayShift(day, n) {
    t := RegExReplace(day, "-") "000000"
    t += n, Days
    FormatTime, d, %t%, yyyy-MM-dd
    return d
}

SaveState() {
}
Refresh() {
}
Journal(line) {
    global Journalled
    Journalled.Push(line)
}
CommitMark() {
}
CancelMark(kind, i) {
    return false
}
PendMark(kind, i, status) {
}

#Include %A_ScriptDir%\..\lib\Habits.ahk

Ok(name, got, want) {
    global Fails, Log
    if (got . "" = want . "")
        Log .= "  ok   " name "`n"
    else {
        Log .= "  FAIL " name ": got [" got "] want [" want "]`n"
        Fails += 1
    }
}

; ---- DayShift against the calendar -----------------------------------------
Ok("DayShift back one",      DayShift("2026-09-20", -1),  "2026-09-19")
Ok("DayShift over a month",  DayShift("2026-09-01", -1),  "2026-08-31")
Ok("DayShift over a year",   DayShift("2026-01-01", -1),  "2025-12-31")
Ok("DayShift leap day",      DayShift("2024-03-01", -1),  "2024-02-29")
Ok("DayShift not a leap day", DayShift("2025-03-01", -1), "2025-02-28")
Ok("DayShift forward",       DayShift("2026-02-28", 1),   "2026-03-01")
Ok("DayShift seven back",    DayShift("2026-09-20", -6),  "2026-09-14")

; ---- a habit's first day ----------------------------------------------------
FakeToday := "2026-09-10"
HabitAdd("read")
h := Habits[1]
Ok("born",            h.born,   "2026-09-10")
Ok("streak starts 0", h.streak, 0)
Ok("not done yet",    HabitDidToday(h) ? 1 : 0, 0)

HabitToggle(1)
Ok("ticked: streak 1", h.streak, 1)
Ok("ticked: best 1",   h.best,   1)
Ok("ticked: total 1",  h.total,  1)
Ok("ticked: done",     HabitDidToday(h) ? 1 : 0, 1)

HabitToggle(1)
Ok("untick: streak 0", h.streak, 0)
Ok("untick: total 0",  h.total,  0)
Ok("untick: not done", HabitDidToday(h) ? 1 : 0, 0)

HabitToggle(1)
Ok("reticked: streak 1", h.streak, 1)
Ok("reticked: best still 1", h.best, 1)

; ---- three days in a row ----------------------------------------------------
FakeToday := "2026-09-11"
HabitSettle()
Ok("day 2 before ticking, streak survives", h.streak, 1)
HabitToggle(1)
Ok("day 2 streak 2", h.streak, 2)

FakeToday := "2026-09-12"
HabitSettle()
HabitToggle(1)
Ok("day 3 streak 3", h.streak, 3)
Ok("day 3 best 3",   h.best,   3)
Ok("day 3 total 3",  h.total,  3)

; ---- a missed day breaks it -------------------------------------------------
FakeToday := "2026-09-13"
HabitSettle()
Ok("13th, not ticked yet, chain alive", h.streak, 3)
FakeToday := "2026-09-14"
HabitSettle()
Ok("14th, the 13th went by, chain broken", h.streak, 0)
Ok("best remembers",  h.best, 3)
HabitToggle(1)
Ok("restart at 1", h.streak, 1)

; ---- the script was closed for a fortnight ----------------------------------
FakeToday := "2026-09-28"
HabitSettle()
Ok("back after two weeks, chain broken", h.streak, 0)

; ---- the dots ---------------------------------------------------------------
FakeToday := "2026-09-28"
Ok("dot today",        HabitDayState(h, "2026-09-28", "2026-09-28"), "todo")
Ok("dot yesterday",    HabitDayState(h, "2026-09-27", "2026-09-28"), "miss")
Ok("dot older miss",   HabitDayState(h, "2026-09-20", "2026-09-28"), "old")
Ok("dot a done day",   HabitDayState(h, "2026-09-12", "2026-09-28"), "done")
Ok("dot before born",  HabitDayState(h, "2026-09-01", "2026-09-28"), "none")
Ok("colour done",  HabitDotColour("done"), CGreen)
Ok("colour miss",  HabitDotColour("miss"), CRed)
Ok("colour todo",  HabitDotColour("todo"), CTrack)

; ---- the streak colour ------------------------------------------------------
Ok("streak colour at zero", HabitStreakColour(h), CDim)
HabitToggle(1)
Ok("streak colour done today", HabitStreakColour(h), CGreen)
FakeToday := "2026-09-29"
HabitSettle()
Ok("streak colour alive but not done", HabitStreakColour(h), CAmber)

; ---- the whole history is kept ---------------------------------------------
Habits := []
FakeToday := "2026-01-01"
HabitAdd("long")
g := Habits[1]
Loop 100 {
    FakeToday := DayShift("2026-01-01", A_Index - 1)
    HabitSettle()
    HabitToggle(1)
}
Ok("100 days: streak 100", g.streak, 100)
Ok("100 days: best 100",   g.best,   100)
Ok("100 days: total 100",  g.total,  100)
Ok("100 days: every day kept", g.done.Length(), 100)
Ok("newest day first", g.done[1], FakeToday)

; ---- two habits with the same name are one habit ---------------------------
Habits := []
FakeToday := "2026-05-05"
HabitAdd("water")
HabitAdd("water")
Ok("no duplicate", Habits.Length(), 1)

; ---- counting -------------------------------------------------------------
HabitAdd("walk")
Ok("none done", HabitsDone(), 0)
HabitToggle(1)
Ok("one done",  HabitsDone(), 1)
HabitToggle(2)
Ok("both done", HabitsDone(), 2)

; ---- the run a day's note shows beside a tick ------------------------------
Ok("run to today", HabitStreakAt(Habits[1], "2026-05-05"), 1)
Ok("run to a day not done", HabitStreakAt(Habits[1], "2026-05-04"), 0)
HabitToggle(2)

; ---- deleting ---------------------------------------------------------------
HabitDelete(1)
Ok("deleted", Habits.Length(), 1)
Ok("the other one survived", Habits[1].text, "walk")


; ---- ticking a day you missed, from the dots -------------------------------
Habits := []
FakeToday := "2026-06-10"
HabitAdd("floss")
f := Habits[1]
f.born := "2026-06-01"
; done on the 8th and 9th, missed the 7th, today not done
f.done := ["2026-06-09", "2026-06-08"]
HabitCompute(f)
Ok("chain before the fix", f.streak, 2)
HabitSetDay(1, "2026-06-07")                 ; fill in the gap
Ok("gap filled: streak 3",  f.streak, 3)
Ok("gap filled: total 3",   f.total,  3)
Ok("newest day still first", f.done[1], "2026-06-09")
Ok("inserted in order",      f.done[3], "2026-06-07")
HabitSetDay(1, "2026-06-08")                 ; take the middle back out
Ok("split again: streak 1", f.streak, 1)
Ok("total back to 2",       f.total,  2)
; The 3 only ever existed because of the day just taken back. What is left is
; the 7th and the 9th - two runs of one.
Ok("best is the longest run left", f.best, 1)
HabitSetDay(1, "2026-06-20")                 ; the future is not yours to tick
Ok("future refused",  f.total, 2)
HabitSetDay(1, "2026-05-30")                 ; before it was born
Ok("pre-birth refused", f.total, 2)
HabitSetDay(1, "2026-06-01")                 ; older than the dots go: fine now,
Ok("out of sight but kept", f.total, 3)      ; the whole history is there
HabitSetDay(1, "2026-06-10")                 ; today goes the normal way
Ok("today ticks",  HabitDidToday(f) ? 1 : 0, 1)
Ok("today counts", f.streak, 2)

; ---- a tick taken back takes its best back ---------------------------------
Habits := []
FakeToday := "2026-07-01"
HabitAdd("stretch")
s := Habits[1]
HabitToggle(1)
HabitToggle(1)
Ok("first-day tick undone: best 0", s.best, 0)

; a record set today and taken back returns to the old record
s.done := ["2026-06-30", "2026-06-29"]
HabitCompute(s)
HabitToggle(1)
Ok("new record 3", s.best, 3)
HabitToggle(1)
Ok("record taken back: best 2", s.best, 2)
Ok("streak back to 2", s.streak, 2)

; a record saved before the fix (best 1, nothing done) is mended at start
s.born := "2026-07-01"
s.done := [], s.streak := 0, s.best := 1, s.total := 0
HabitSettle()
Ok("saved stray best mended", s.best, 0)

; ---- a run filled in afterwards counts, even when it does not reach today --
; The real case: exercise ticked for the 21st to the 24th, the 25th left
; empty, looked at on the 26th. Streak 0, best 4 - it said 3.
Habits := []
FakeToday := "2026-09-26"
HabitAdd("exercise")
e := Habits[1]
e.born := "2026-09-20"
for _, d in ["2026-09-22", "2026-09-24", "2026-09-23", "2026-09-21"]
    HabitSetDay(1, d)
Ok("filled-in run: streak 0", e.streak, 0)
Ok("filled-in run: best 4",   e.best,   4)
; the mess of clicks the journal showed on the day, one habit ticked and
; unticked back and forth, ends where the days end, whatever the order
for _, d in ["2026-09-25", "2026-09-25", "2026-09-22", "2026-09-22", "2026-09-20", "2026-09-20"]
    HabitSetDay(1, d)
Ok("back and forth: best still 4", e.best, 4)
HabitSetDay(1, "2026-09-22")
Ok("split in two: best 2", e.best, 2)
HabitSetDay(1, "2026-09-25")                 ; 23, 24, 25: reaches yesterday
Ok("three reaching yesterday: streak 3", e.streak, 3)
Ok("three reaching yesterday: best 3",   e.best,   3)
HabitToggle(1)                               ; and today makes four
Ok("today joins it: best 4", e.best, 4)

; ---- a day ticked late is corrected in its own note ------------------------
FileCreateDir, %NoteDir%
note := JournalFile("2026-07-03")
FileDelete, %note%
body := "# 2026-07-03`n`n10:00  wrote this myself - [ ] stretch`n`n"
      . "03:00  " Chr(0x2014) " day closed`n`n## habits`n`nhabits-done:: 0/2`n`n"
      . "- [ ] stretch  (streak:: 0)`n- [ ] read  (streak:: 4)`n`n"
FileAppend, %body%, %note%, UTF-8
FileRead, before, *P65001 %note%         ; as it is on disk: CRLF, like a real note
Habits := []
FakeToday := "2026-07-05"
HabitAdd("stretch")
HabitAdd("read")
Habits[1].born := "2026-07-01", Habits[2].born := "2026-07-01"
JournalOn := 1
HabitSetDay(1, "2026-07-03")
FileRead, after, *P65001 %note%
Ok("note: box ticked",    InStr(after, "- [x] stretch  (streak:: 0)") ? 1 : 0, 1)
Ok("note: count follows", InStr(after, "habits-done:: 1/2") ? 1 : 0, 1)
Ok("note: other habit untouched", InStr(after, "- [ ] read  (streak:: 4)") ? 1 : 0, 1)
Ok("note: your own line untouched", InStr(after, "wrote this myself - [ ] stretch") ? 1 : 0, 1)
HabitSetDay(1, "2026-07-03")
FileRead, after, *P65001 %note%
Ok("note: untick puts it back, byte for byte", after == before ? 1 : 0, 1)
JournalOn := 0

FileDelete, %A_ScriptDir%\results-Habits.txt
FileAppend, % (Fails ? Fails " FAILED`n" : "all passed`n") Log
    , %A_ScriptDir%\results-Habits.txt, UTF-8
ExitApp
