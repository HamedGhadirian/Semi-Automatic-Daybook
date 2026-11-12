; Rules.test.ahk - how often, rest days, and a streak brought in from elsewhere
;
; Loads the real lib\Habits.ahk with the clock faked, like Habits.test.ahk, and
; walks each rule through real September 2026 dates: the 7th, 14th, 21st and
; 28th are Mondays.
;
; Run it with run-tests.ps1 in this folder, or on its own.
#NoEnv
#SingleInstance off
SetBatchLines -1

global DayStartHour := 3, HabitDays := 7, RestPerMonth := 2, JournalOn := 0
global Habits := []
global CGreen := "G", CAmber := "A", CRed := "R", CTrack := "T", CDim := "D", CBlue := "B", CToday := "Y"
global Fails := 0, Log := ""
global FakeToday := ""

LogicalDay() {
    return FakeToday
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
}
CommitMark() {
}
CancelMark(kind, i) {
    return false
}
PendMark(kind, i, status) {
}
DayNoteWrite(day, force := false) {
}
JournalFile(day, fold := false) {
    return ""
}

#Include %A_ScriptDir%\..\lib\Habits.ahk

Ok(name, got, want) {
    global Fails, Log
    if (got . "" = want . "")
        Log .= "  ok   " name "`n"
    else
        Log .= "  FAIL " name ": got [" got "] want [" want "]`n", Fails += 1
}

; A habit with a rule and a history, all at once.
Make(name, kind, n, born, days, rests := "") {
    global Habits, FakeToday
    was := FakeToday
    FakeToday := born
    HabitAdd(name)
    FakeToday := was
    h := Habits[Habits.Length()]
    h.born := born, h.kind := kind, h.n := n
    h.done := [], h.rest := []
    for _, d in StrSplit(days, ",")
        if (d != "")
            HabitInsertDay(h.done, "2026-09-" d)
    for _, d in StrSplit(rests, ",")
        if (d != "")
            HabitInsertDay(h.rest, "2026-09-" d)
    HabitCompute(h)
    return h
}

; ---- the weekday arithmetic ---------------------------------------------------
Ok("a Monday starts a week",   WeekOf(DayNum("2026-09-28")) - WeekOf(DayNum("2026-09-27")), 1)
Ok("Monday to Sunday is one",  WeekOf(DayNum("2026-09-21")) = WeekOf(DayNum("2026-09-27")) ? 1 : 0, 1)
Ok("day numbers subtract",     DayNum("2026-03-01") - DayNum("2026-02-28"), 1)

; ---- every other day ------------------------------------------------------------
FakeToday := "2026-09-08"
e := Make("swim", "D", 2, "2026-09-01", "01,03,05,07")
Ok("every other day: 4 in a row", e.streak, 4)
Ok("the day off is grey, not red", HabitDayState(e, "2026-09-02", FakeToday), "off")
Ok("not due the day after",        HabitDue(e) ? 1 : 0, 0)
Ok("so the number is green",       HabitStreakColour(e), CGreen)
FakeToday := "2026-09-09"
HabitCompute(e)
Ok("two days on: still alive",     e.streak, 4)
Ok("and due today",                HabitDue(e) ? 1 : 0, 1)
Ok("so the number is amber",       HabitStreakColour(e), CAmber)
FakeToday := "2026-09-10"
HabitCompute(e)
Ok("three days on: broken",        e.streak, 0)
Ok("best remembers",               e.best, 4)
Ok("the second day undone is red", HabitDayState(e, "2026-09-09", FakeToday), "miss")

; ---- every other day, frozen on the day it was due ------------------------------
; done 1st and 3rd, due the 5th and frozen then. The 6th is a day off, NOT a
; miss: the next due day is the 7th, two days after the freeze.
FakeToday := "2026-09-06"
f := Make("non-fiction", "D", 2, "2026-09-01", "01,03", "05")
Ok("frozen: the chain holds on the day after", f.streak, 2)
Ok("frozen: the freeze does not count",        f.total, 2)
Ok("frozen: the day after is not due",         HabitDue(f) ? 1 : 0, 0)
Ok("frozen: the number is green",              HabitStreakColour(f), CGreen)
FakeToday := "2026-09-07"
HabitCompute(f)
Ok("frozen: the 6th is grey, not red",         HabitDayState(f, "2026-09-06", FakeToday), "off")
Ok("frozen: the 7th is due",                   HabitDue(f) ? 1 : 0, 1)
Ok("frozen: still alive on the 7th",           f.streak, 2)
FakeToday := "2026-09-08"
HabitCompute(f)
Ok("frozen: the 7th undone is the miss",       HabitDayState(f, "2026-09-07", FakeToday), "miss")
Ok("frozen: broken on the 8th",                f.streak, 0)
FakeToday := "2026-09-07"
HabitInsertDay(f.done, "2026-09-07")
HabitCompute(f)
Ok("frozen: done on the 7th, 3 days done",     f.streak, 3)
; and the old trap stays shut: a rest day does not let two empty days through
FakeToday := "2026-09-08"
g := Make("walk", "D", 2, "2026-09-01", "01", "03")
HabitCompute(g)
Ok("frozen: 1st done, 3rd frozen, 5th is due", HabitBrokenBy(g, "2026-09-05") ? 1 : 0, 1)
Ok("frozen: and the 4th is a day off",         HabitBrokenBy(g, "2026-09-04") ? 1 : 0, 0)

; ---- every 3 days -----------------------------------------------------------------
FakeToday := "2026-09-11"
t := Make("plants", "D", 3, "2026-09-01", "01,04,08")
Ok("every 3 days: 1 to 4 holds, 4 to 8 breaks", t.best, 2)
Ok("the chain from the 8th is alive on the 11th", t.streak, 1)
Ok("  and the 11th is the day it is due",       HabitDue(t) ? 1 : 0, 1)
FakeToday := "2026-09-12"
HabitCompute(t)
Ok("  the 12th: three days gone, broken",       t.streak, 0)

; ---- rest days, every day ----------------------------------------------------------
FakeToday := "2026-09-13"
r := Make("read", "D", 1, "2026-09-01", "10,11,13", "12")
Ok("rest day holds the chain",       r.streak, 3)
Ok("and does not count",             r.total, 3)
Ok("the rest day is blue",           HabitDotColour(HabitDayState(r, "2026-09-12", FakeToday)), CBlue)
i := Habits.Length()
Ok("a second rest this month",       HabitSetState(i, "2026-09-05", "rest") ? 1 : 0, 1)
Ok("a third is refused",             HabitSetState(i, "2026-09-06", "rest") ? 1 : 0, 0)
Ok("refused means nothing changed",  HabitRested(r, "2026-09-06") ? 1 : 0, 0)
RestPerMonth := 0
Ok("0 a month: none at all",         HabitSetState(i, "2026-09-07", "rest") ? 1 : 0, 0)
RestPerMonth := 2
Ok("rest to done",                   HabitSetState(i, "2026-09-12", "done") ? 1 : 0, 1)
Ok("  now it counts",                r.total, 4)
Ok("  and it is not a rest any more", HabitRested(r, "2026-09-12") ? 1 : 0, 0)
Ok("done to nothing",                HabitSetState(i, "2026-09-12", "none") ? 1 : 0, 1)
Ok("  the chain splits",             r.streak, 1)

; ---- 3 times a week -----------------------------------------------------------------
; week of the 7th: 3 days, kept. The 14th: 2, failed. The 21st: 3, kept. The
; 28th: 1 so far, and it is Tuesday - open.
FakeToday := "2026-09-29"
w := Make("gym", "W", 3, "2026-09-07", "07,09,11,15,17,21,22,23,28")
Ok("weeks: the open week does not count or break", w.streak, 1)
Ok("weeks: best",                    w.best, 1)
p := HabitWeekProgress(w, FakeToday)
Ok("this week: 1 of 3",              p.done " of " p.need, "1 of 3")
Ok("due while the week is short",    HabitDue(w) ? 1 : 0, 1)
Ok("a day off in a week is grey",    HabitDayState(w, "2026-09-08", FakeToday), "off")
Ok("the note says how the week stood", HabitRunText(w, "2026-09-22"), "2 of 3 this week")
; a rest day in the short week lowers its target to 2, and it is kept
HabitInsertDay(w.rest, "2026-09-19")
HabitCompute(w)
Ok("a rest day saves the short week", w.streak, 3)
Ok("  and best follows",             w.best, 3)
; counted in days: every day done in that run of weeks, this one's included
Ok("shown in weeks by default",      HabitStreakText(w), "3w")
Ok("the same run in days: 3+2+3+1",  w.streakDays, 9)
HabitSetUnit(Habits.Length(), "D")
Ok("switched to days",               HabitStreakText(w), "9")
Ok("  best in days too",             HabitStreakText(w, true), "9")
HabitSetUnit(Habits.Length(), "W")
Ok("and back to weeks",              HabitStreakText(w, true), "3w")
; a failed week ends the run in days as well as in weeks
HabitDropDay(w.rest, "2026-09-19")
HabitCompute(w)
Ok("the short week breaks it: 3+1 days", w.streakDays, 4)
Ok("  best days is the longer side", w.bestDays, 4)
HabitInsertDay(w.rest, "2026-09-19")
HabitCompute(w)
; an every-day habit is days whatever the switch says
Ok("every-day habits ignore the switch", HabitStreakText(r), r.streak)
; three days in by Wednesday: kept already, counts, nothing more due
FakeToday := "2026-09-30"
HabitInsertDay(w.done, "2026-09-29")
HabitInsertDay(w.done, "2026-09-30")
HabitCompute(w)
Ok("kept by Wednesday: counts at once", w.streak, 4)
Ok("  and nothing is due",           HabitDue(w) ? 1 : 0, 0)
Ok("  so the number is green",       HabitStreakColour(w), CGreen)

; a habit begun on a Saturday cannot owe three days that week
FakeToday := "2026-09-15"
b := Make("stretch", "W", 3, "2026-09-12", "12,13")
Ok("first week: only the days it had", b.streak, 1)

; a week whose rest days took the target to nothing is a bridge
FakeToday := "2026-09-22"
g := Make("run", "W", 2, "2026-09-07", "07,08,21", "15,16")
Ok("bridge week: holds, does not add", g.streak, 1)
Ok("  the week before it still counts in best", g.best, 1)
FakeToday := "2026-09-23"
HabitInsertDay(g.done, "2026-09-23")
HabitCompute(g)
Ok("kept either side of a bridge: 2", g.streak, 2)

; red in a week-counted habit: the day the week can no longer be made, and the
; undone days after it. 3 a week, the week of the 14th: nothing Mon to Thu.
FakeToday := "2026-09-21"
k := Make("yoga", "W", 3, "2026-09-07", "07,09,11,19")
Ok("a lost week: Thursday could still be made", HabitDayState(k, "2026-09-17", FakeToday), "off")
Ok("  Friday is where it was lost",   HabitDayState(k, "2026-09-18", FakeToday), "old")
Ok("  Saturday done is still green",  HabitDayState(k, "2026-09-19", FakeToday), "done")
Ok("  Sunday undone is red too",      HabitDayState(k, "2026-09-20", FakeToday), "miss")
; a rest day on Thursday takes the target to 2, and Sat + Sun could make it
HabitInsertDay(k.rest, "2026-09-17")
HabitCompute(k)
Ok("a rest day moves the red later",  HabitDayState(k, "2026-09-18", FakeToday), "off")
Ok("  to the Sunday that was not done", HabitDayState(k, "2026-09-20", FakeToday), "miss")
; the open week goes red mid-week, not only once Sunday is over
FakeToday := "2026-10-03"
Ok("mid-week: Friday lost, seen on Saturday", HabitDayState(k, "2026-10-02", FakeToday), "miss")
Ok("  and Thursday stays grey",       HabitDayState(k, "2026-10-01", FakeToday), "off")

; ---- changing the rule ------------------------------------------------------------
FakeToday := "2026-09-13"
c := Make("walk", "D", 1, "2026-09-01", "01,03,05,07,09,11,13")
Ok("every day: broken every other day", c.streak, 1)
HabitSetRule(Habits.Length(), "D", 2)
Ok("every other day: all of it holds", c.streak, 7)
Ok("rule in words",                  HabitRuleText(c), "every other day")
HabitSetRule(Habits.Length(), "W", 9)
Ok("a week has only 7 days",         c.n, 7)

; ---- a 778-day streak brought in -------------------------------------------------
FakeToday := "2026-09-26"
HabitAdd("duolingo")
dl := Habits.Length()
d := Habits[dl]
HabitInsertDay(d.rest, "2026-09-20")         ; a rest day inside it becomes a done day
t0 := A_TickCount
HabitImport(dl, 778, "2026-09-25")           ; not done today yet
took := A_TickCount - t0
Ok("778: streak",                    d.streak, 778)
Ok("778: best",                      d.best, 778)
Ok("778: days done",                 d.total, 778)
Ok("778: born moves back",           d.born, DayShift("2026-09-25", -777))
Ok("778: the rest day is gone",      d.rest.Length(), 0)
Ok("778: still due today",           HabitDue(d) ? 1 : 0, 1)
HabitToggle(dl)
Ok("779 once today is ticked",       d.streak, 779)
t0 := A_TickCount
Loop 20
    HabitCompute(d)
per := (A_TickCount - t0) / 20
t0 := A_TickCount
Loop 7000
    HabitDid(d, "2025-01-01")
look := A_TickCount - t0
Ok("778: bringing it in is quick (under 1.5s)", took < 1500 ? 1 : 0, 1)
Ok("778: a recount is quick (under 150ms)",     per < 150 ? 1 : 0, 1)
Ok("778: a thousand repaints of dots, under 150ms", look < 150 ? 1 : 0, 1)
Log .= "       (import " took "ms, recount " Round(per) "ms, 7000 lookups " look "ms)`n"

FileDelete, %A_ScriptDir%\results-Rules.txt
FileAppend, % (Fails ? Fails " FAILED`n" : "all passed`n") Log
    , %A_ScriptDir%\results-Rules.txt, UTF-8
ExitApp
