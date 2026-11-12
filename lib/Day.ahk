;================================================================================
; The day
;================================================================================
LogicalDay() {
    shift := -DayStartHour
    t := A_Now
    t += %shift%, Hours
    FormatTime, d, %t%, yyyy-MM-dd
    return d
}

; A day, n days from this one. "2026-09-20", -1 -> "2026-09-19", and it is the
; calendar that answers, so month ends, leap days and the turn of the year all
; come out right without a single special case.
DayShift(day, n) {
    t := RegExReplace(day, "-") "000000"
    t += n, Days
    FormatTime, d, %t%, yyyy-MM-dd
    return d
}

; A day as it is said: "today", "yesterday", "Sat 26 Sep".
MissDayName(day) {
    today := LogicalDay()
    if (day = today)
        return "today"
    if (day = DayShift(today, -1))
        return "yesterday"
    FormatTime, s, % StrReplace(day, "-"), ddd d MMM
    return s
}

; How long a MISSED task has waited: "yesterday", or "since Sat 26 Sep".
MissSinceText(day) {
    if (day = "" || day = DayShift(LogicalDay(), -1))
        return "yesterday"
    return "since " MissDayName(day)
}

;--------------------------------------------------------------------------------
; Deadlines - short term tasks
;--------------------------------------------------------------------------------
; Days from today to a deadline: 0 is today, 1 tomorrow, negative is past.
DueDays(due) {
    return DayNum(due) - DayNum(LogicalDay())
}

; What goes in front of a short term task on the panel: "today", "1d", "12d",
; past 100 days months ("4mo"), past two years years ("3y") - the row has
; little room, and the hover says the whole date.
DueTag(due) {
    n := DueDays(due)
    if (n <= 0)
        return "today"
    return (n >= 730) ? Round(n / 365) "y" : (n >= 100) ? Round(n / 30) "mo" : n "d"
}

; The deadline in words: "today", "tomorrow", "Fri 14 Nov, in 4 days".
DueText(due) {
    n := DueDays(due)
    if (n = 0)
        return "today"
    if (n = 1)
        return "tomorrow"
    FormatTime, s, % StrReplace(due, "-") "000000", ddd d MMM
    return s ", in " n " days"
}

; Indexes into Tasks, soonest deadline first, and the tasks with no deadline
; after all of them. Insertion sort: the lists are a handful long, and it
; keeps tasks with the same day in the order they were added.
DueSort(order) {
    global Tasks
    Loop % order.Length() - 1 {
        k := A_Index + 1
        v := order[k]
        j := k - 1
        while (j >= 1 && DueKey(Tasks[order[j]].due) > DueKey(Tasks[v].due)) {
            order[j + 1] := order[j]
            j--
        }
        order[j + 1] := v
    }
}

; What DueSort compares: the day, or for no deadline a "day" later than any.
DueKey(due) {
    return (due = "") ? "9999-99-99" : due
}

RollIfNeeded() {
    CommitMark()                 ; a pending mark belongs to the day it happened
    today := LogicalDay()
    if (CurDay = today) {
        ; Not a new day, but the streaks still have to be right the first time
        ; this is called - the script may have been closed for a week.
        HabitSettle()
        return
    }
    if (CurDay != "")
        CloseDay()
    CurDay := today
    SitSec := 0, AwaySec := 0, CutShort := 0
    AppSec := {}, HourSec := {}
    HabitSettle()                ; yesterday is settled: chains kept or broken
    SaveState()
    RollupRun()                  ; a week or a month may have just ended
    Refresh()
}

; The day is over. Keep a record of it, write its note for the last time, then
; decide what survives into the next one.
;
; The record (Past) is what lets the day's note still be put right after it is
; over - the answer to "why not?" given the next morning goes onto that day's
; line, not into a new one. Everything on Today's list goes in, and a long term
; task only if it was finished that day.
;
; A short term task waits, deadline in front of it, and moves to MISSED only
; once its deadline day is over; one with no deadline just waits. Unfinished work is never deleted. What was on
; Today's list and is still open
; moves to MISSED, remembering this as the day it was meant for (since), and
; waits there to be told what happened - see Missed.ahk. Its carry count, and
; that of anything already waiting in MISSED, goes up by the days gone by: a
; week with the PC off is a week, not one day. Finished work leaves the panel,
; long term included: it is done, and the note has it.
CloseDay() {
    global Tasks, Past, PastTime, CurDay
    day := CurDay
    gap := DayNum(LogicalDay()) - DayNum(day)
    if (gap < 1)
        gap := 1
    ; A long term task finished before tasks remembered WHEN they were
    ; finished has no doneOn; it leaves the panel now like the rest, so it is
    ; recorded on this day rather than vanishing without a trace.
    ; A short term task is on the day's list on its deadline day, and only then.
    for _, t in Tasks
        if (t.list = "T" || (t.list = "S" && t.due = day) || t.doneOn = day
            || (t.status != "open" && t.doneOn = ""))
            Past.Push({day: day, id: t.id, list: t.list, status: t.status
                     , carry: t.carry, note: TaskNote(t, day), text: t.text})
    PastTime[day] := DayTimeText()
    DayNoteWrite(day, true)              ; the last word, time and all
    keep := []
    for _, t in Tasks {
        if (t.status != "open")
            continue
        if (t.list = "T")
            t.list := "M", t.since := day, t.carry += gap
        else if (t.list = "S" && t.due != "" && t.due < LogicalDay()) {
            ; its deadline has gone by: a real miss, so it goes to MISSED
            ; remembering the day it was due, and the xN counts the days since
            late := DayNum(LogicalDay()) - DayNum(t.due)
            t.list := "M", t.since := t.due, t.due := ""
            t.carry += (late < 1) ? 1 : late
        } else if (t.list = "M")
            t.carry += gap
        t.notes := {}                    ; the day's notes are in Past now
        keep.Push(t)
    }
    Tasks := keep
    PastPrune()
}

; Finished days are kept PastKeepDays, then let go. The day notes keep them for
; good - this is only what Daybook needs to be able to rewrite one.
PastPrune() {
    global Past, PastTime, PastKeepDays
    cut := DayShift(LogicalDay(), -PastKeepDays)
    keep := []
    for _, r in Past
        if !(r.day < cut)
            keep.Push(r)
    Past := keep
    for day in PastTime.Clone()
        if (day < cut)
            PastTime.Delete(day)
}
