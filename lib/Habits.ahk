;================================================================================
; Habits - the things you want to keep doing, and how long you have kept it up
;================================================================================
; A habit is not a task. A task is done once and gone; a habit comes back
; whether you did it or not, and the thing worth showing is whether you have
; kept it going.
;
; Each row carries a week of dots and one number, and the DOTS ARE BUTTONS:
; click the one for Tuesday and Tuesday is ticked. That is the answer to
; forgetting, and it is why the dots are there rather than a bare streak.
;
;     [v] read 20 pages          . . o o o o o     12
;
; HOW OFTEN - every habit has a rule, and the streak is measured against it:
;   every day            the chain holds while no day goes by undone
;   every N days         ...while no N days in a row go by undone
;   N times a week       counted in WEEKS: a week is kept when it has N days
;                        done. Weeks start on Monday. The week you are in
;                        cannot break anything until it is over.
;
; REST DAYS are the exceptions to the rule - sick, away, a day off on purpose.
; A rest day does not break the chain and does not count towards it either,
; the way a streak freeze works: 12, rest, 13. In a week-counted habit it takes
; one off that week's target. There are only so many a month (RestPerMonth),
; or any streak could be kept forever.
;
; THE STREAK IS NEVER KEPT BY HAND. It, the best and the days-done count are
; all worked out from the history - the days done and the rest days - every
; time the history changes, by HabitCompute(). Nothing adds one or takes one
; away, so a tick taken back, a day filled in late, a week away with the PC off
; or a streak brought in from somewhere else all come out right by the same
; road. The whole history is kept, for the same reason: a streak longer than
; the history cannot be measured.
;
; IN OBSIDIAN - each day's note has the habits in Daybook's block, with the run
; each one had reached that day (DayBlock in Journal.ahk), and Daybook.md has the
; streaks and two weeks of them (Board.ahk). Ticking a day late rewrites that
; day's block, so the note never disagrees with the dots.
;================================================================================

; A habit's whole record. Nothing else creates one. kind "D" is every n days
; (n 1 is every day), "W" is n times a week.
HabitNew(text) {
    return {text: text, born: LogicalDay(), streak: 0, best: 0, total: 0
          , done: [], rest: [], kind: "D", n: 1, unit: "W"}
}

HabitAdd(text) {
    global Habits
    text := Trim(RegExReplace(text, "[\r\n\t]+", " "))
    if (text = "")
        return
    for _, h in Habits
        if (h.text = text)               ; the same habit twice is never meant
            return
    Habits.Push(HabitNew(text))
    SaveState()
    Refresh()
    Journal("+ habit: " text)
}

HabitRename(i, newText) {
    global Habits, HabEdName
    newText := Trim(RegExReplace(newText, "[\r\n\t]+", " "))
    h := Habits[i]
    if (!h || newText = "" || newText == h.text)     ; == so case counts
        return
    old := h.text
    h.text := newText
    ; The habit window holds its habit by name; renamed from the panel while
    ; it is open, it must follow, or every click in it would find nothing.
    if (HabEdName = old)
        HabEdName := newText
    SaveState()
    Refresh()
    Journal("~ habit renamed: " old "   " Chr(0x2192) "   " newText)
}

HabitDelete(i) {
    global Habits
    h := Habits[i]
    if (!h)
        return
    ; RemoveAt shifts every index above this one, so nothing may be left
    ; pointing at a row by number - the same trap MenuDelete documents.
    if (!CancelMark("H", i))
        CommitMark()
    Habits.RemoveAt(i)
    SaveState()
    Refresh()
    Journal("- habit dropped: " h.text)
}

;================================================================================
; Was it done - asked on every repaint, so it is a lookup, not a search
;================================================================================
; h.done and h.rest are the record, newest first. h.set and h.restSet are the
; same days as lookups, built from them by HabitIndexDays - so anything that
; changes the lists must call HabitCompute() after, which rebuilds them.
HabitDid(h, day) {
    if (!IsObject(h.set))
        HabitIndexDays(h)
    return h.set.HasKey(day)
}

HabitRested(h, day) {
    if (!IsObject(h.restSet))
        HabitIndexDays(h)
    return h.restSet.HasKey(day)
}

HabitDidToday(h) {
    return HabitDid(h, LogicalDay())
}

HabitIndexDays(h) {
    if (!IsObject(h.rest))
        h.rest := []
    set := {}, restSet := {}
    for _, d in h.done
        set[d] := 1
    for _, d in h.rest
        restSet[d] := 1
    h.set := set, h.restSet := restSet
}

;================================================================================
; Changing the history
;================================================================================
; Tick or untick TODAY - the tick box. Held for the grace period like a task's
; tick, so a misclick taken back at once is never written anywhere.
HabitToggle(i) {
    global Habits
    h := Habits[i]
    if (!h)
        return
    today := LogicalDay()
    if (HabitDid(h, today)) {
        HabitDropDay(h.done, today)
        HabitCompute(h)
        ; Untick inside the grace window and the tick was never written, so
        ; neither is this. Past it, the tick is already in the log, and the
        ; honest thing is to say it was taken back.
        if (!CancelMark("H", i)) {
            CommitMark()
            Journal(Chr(0x2717) " habit unticked: " h.text)
        }
        SaveState()
        Refresh()
        return
    }
    HabitDropDay(h.rest, today)          ; a rest day that got done after all
    HabitInsertDay(h.done, today)
    HabitCompute(h)
    SaveState()
    Refresh()
    CommitMark()                         ; another row was still pending
    PendMark("H", i, "done")             ; held, like a task's tick - see CommitMark()
}

; A dot was clicked: tick or untick that day. Today is the tick box's business.
HabitSetDay(i, day) {
    global Habits
    h := Habits[i]
    if (!h)
        return
    if (day = LogicalDay()) {
        HabitToggle(i)
        return
    }
    HabitSetState(i, day, HabitDid(h, day) ? "none" : "done")
}

; Make a day done, a rest day, or neither. Any day from the habit's first to
; today - the whole history is kept, so a fortnight away can still be filled
; in. A correction to the past, so it is written plainly and at once, and that
; day's note is rewritten to match. False when it could not be done: a day out
; of range, or a rest day when the month has none left.
HabitSetState(i, day, state) {
    global Habits
    h := Habits[i]
    if (!h || day > LogicalDay() || day < h.born)
        return false
    was := HabitDid(h, day) ? "done" : HabitRested(h, day) ? "rest" : "none"
    if (was = state)
        return true
    if (state = "rest" && !HabitRestLeft(h, day))
        return false
    HabitDropDay(h.done, day)
    HabitDropDay(h.rest, day)
    if (state = "done")
        HabitInsertDay(h.done, day)
    else if (state = "rest")
        HabitInsertDay(h.rest, day)
    HabitCompute(h)
    SaveState()
    Refresh()
    CommitMark()                         ; a row was pending; it is not this one
    Journal((state = "done") ? Chr(0x2713) " habit ticked for " day ": " h.text
          : (state = "rest") ? Chr(0x2744) " rest day for " day ": " h.text
          : (was = "rest")   ? Chr(0x2717) " rest day taken back for " day ": " h.text
          :                    Chr(0x2717) " habit unticked for " day ": " h.text)
    HabitFixNote(day, h.text, state = "done")    ; a note in the old shape
    DayNoteWrite(day, true)                        ; a note in the new one
    return true
}

; Is there a rest day left in that day's month? RestPerMonth of them, per
; habit, per calendar month; 0 turns rest days off.
HabitRestLeft(h, day) {
    global RestPerMonth
    month := SubStr(day, 1, 7), used := 0
    for _, d in h.rest
        if (SubStr(d, 1, 7) = month && d != day)
            used++
    return used < RestPerMonth
}

; A streak you already had somewhere else - 778 days of it, say. Every day from
; days-1 before lastDay up to lastDay is marked done; the habit's first day
; moves back to the first of them if it has to. lastDay is today when today is
; already done, yesterday when it is not.
HabitImport(i, days, lastDay) {
    global Habits
    h := Habits[i]
    days := Round(days)
    if (!h || days < 1 || lastDay > LogicalDay())
        return
    first := DayShift(lastDay, 1 - days)
    s := ""
    for _, d in h.done
        s .= d "`n"
    d := first
    Loop % days {
        s .= d "`n"
        d := DayShift(d, 1)
    }
    Sort, s, R U                         ; newest first, each day once
    h.done := StrSplit(Trim(s, "`n"), "`n")
    keep := []                           ; a rest day inside it is a done day now
    for _, d in h.rest
        if (d < first || d > lastDay)
            keep.Push(d)
    h.rest := keep
    if (first < h.born)
        h.born := first
    HabitCompute(h)
    SaveState()
    Refresh()
    Journal("~ habit " h.text ": brought in " days " days, " first " to " lastDay)
}

; How often. kind "D" with n: every n days. kind "W" with n: n times a week.
HabitSetRule(i, kind, n) {
    global Habits
    h := Habits[i]
    if (!h)
        return
    kind := (kind = "W") ? "W" : "D"
    n := Round(n)
    n := (n < 1) ? 1 : (kind = "W" && n > 7) ? 7 : (n > 60) ? 60 : n
    if (h.kind = kind && h.n = n)
        return
    h.kind := kind, h.n := n
    HabitCompute(h)
    SaveState()
    Refresh()
    Journal("~ habit " h.text ": " HabitRuleText(h))
}

HabitRuleText(h) {
    if (h.kind = "W")
        return (h.n = 7) ? "every day of the week" : h.n " times a week"
    return (h.n = 1) ? "every day" : (h.n = 2) ? "every other day" : "every " h.n " days"
}

; The lists are newest first, each day once.
HabitInsertDay(list, day) {
    at := list.Length() + 1
    for k, d in list {
        if (d = day)
            return
        if (d < day) {
            at := k
            break
        }
    }
    list.InsertAt(at, day)
}

HabitDropDay(list, day) {
    k := list.Length()
    while (k >= 1) {
        if (list[k] = day)
            list.RemoveAt(k)
        k--
    }
}

;================================================================================
; The streak engine - everything measured from the history, nothing by hand
;================================================================================
; Days become plain numbers (days since 2000-01-01) so that "how far apart" is
; a subtraction rather than a trip through the calendar for every day.
DayNum(day) {
    t := SubStr(day, 1, 4) SubStr(day, 6, 2) SubStr(day, 9, 2)
    t -= 20000101, Days
    return t
}

; The Monday-to-Sunday week a day number falls in. 2000-01-03, day 2, was a
; Monday, so every week starts on a day number 2 more than a multiple of 7.
WeekOf(n) {
    return Floor((n - 2) / 7)
}

; Streak, best and days done, from the history. Called whenever the history or
; the rule changes, at start, and whenever the day rolls - a day going by can
; break a chain without anything being clicked.
HabitCompute(h) {
    HabitIndexDays(h)
    if (!h.HasKey("kind") || h.kind = "")
        h.kind := "D", h.n := 1
    r := HabitMeasure(h, LogicalDay())
    h.streak := r.streak, h.best := r.best, h.total := h.done.Length()
    ; the run in days as well - the same as the streak for a day-counted habit
    h.streakDays := r.HasKey("streakDays") ? r.streakDays : r.streak
    h.bestDays   := r.HasKey("bestDays")   ? r.bestDays   : r.best
}

; Every habit - at start and at the turn of the day.
HabitSettle() {
    global Habits
    for _, h in Habits
        HabitCompute(h)
}

; The streak as it stood on a given day - what that day's note says.
HabitStreakAt(h, day) {
    return HabitMeasure(h, day).streak
}

; {streak, best} as of a day, under the habit's own rule.
HabitMeasure(h, asOfDay) {
    asOf := DayNum(asOfDay)
    nums := []                           ; the days done up to asOf, oldest first
    k := h.done.Length()
    while (k >= 1) {
        d := DayNum(h.done[k])
        if (d <= asOf)
            nums.Push(d)
        k--
    }
    rest := {}
    for _, d in h.rest {
        r := DayNum(d)
        if (r <= asOf)
            rest[r] := 1
    }
    if (h.kind = "W")
        return HabitWeeks(h.n, nums, rest, DayNum(h.born), asOf)
    return HabitEvery(h.n, nums, rest, asOf)
}

; EVERY N DAYS. Two done days belong to one chain while fewer than n days that
; were not rest days lie between them - every day (n 1) allows none, every
; other day (n 2) allows one. The chain is still alive today while the days
; since the last done one are within the same allowance; today itself is still
; open. The streak is the number of days DONE in the chain: rest days hold it
; together without adding to it.
HabitEvery(n, nums, rest, asOf) {
    best := 0, run := 0, prev := ""
    for _, d in nums {
        run := (prev != "" && HabitGap(prev, d, rest) < n) ? run + 1 : 1
        if (run > best)
            best := run
        prev := d
    }
    streak := 0
    if (prev != "" && (prev = asOf || HabitGap(prev, asOf, rest) < n))
        streak := run
    return {streak: streak, best: best}
}

; Days strictly between two day numbers that were not rest days.
HabitGap(a, b, rest) {
    g := b - a - 1
    for r in rest
        if (r > a && r < b)
            g--
    return g
}

; N TIMES A WEEK. Counted in weeks: a week is KEPT when it has as many days
; done as it needs, and it needs n less one for each rest day in it. The first
; week needs no more days than it had left after the habit began. The week you
; are in is OPEN until it is kept or over - it cannot break the streak before
; Sunday is out. A week whose rest days took its target to nothing is a
; bridge: it holds the chain and does not add to it.
HabitWeeks(n, nums, rest, born, asOf) {
    wNow := WeekOf(asOf), wBorn := WeekOf(born)
    if (wBorn > wNow)
        return {streak: 0, best: 0, streakDays: 0, bestDays: 0}
    done := {}, rested := {}
    for _, d in nums {
        w := WeekOf(d)
        done[w] := (done.HasKey(w) ? done[w] : 0) + 1
    }
    for r in rest {
        w := WeekOf(r)
        rested[w] := (rested.HasKey(w) ? rested[w] : 0) + 1
    }
    ; The same walk counts the run two ways: in weeks kept, and in DAYS done
    ; inside the run - every week that has not broken it, the open one and a
    ; bridge included. Which of the two the panel shows is the habit's own
    ; choice (h.unit); the chain is the same chain either way.
    best := 0, run := 0, bestDays := 0, runDays := 0, w := wBorn
    while (w <= wNow) {
        v := HabitWeekVerdict(w, n, done, rested, born, wBorn, wNow)
        if (v = "fail") {
            run := 0, runDays := 0
        } else {
            if (v = "kept" && ++run > best)
                best := run
            runDays += done.HasKey(w) ? done[w] : 0
            if (runDays > bestDays)
                bestDays := runDays
        }
        w++
    }
    streak := 0, streakDays := 0, w := wNow
    while (w >= wBorn) {
        v := HabitWeekVerdict(w, n, done, rested, born, wBorn, wNow)
        if (v = "fail")
            break
        if (v = "kept")
            streak++
        streakDays += done.HasKey(w) ? done[w] : 0
        w--
    }
    return {streak: streak, best: best, streakDays: streakDays, bestDays: bestDays}
}

HabitWeekVerdict(w, n, done, rested, born, wBorn, wNow) {
    c := done.HasKey(w) ? done[w] : 0
    need := n - (rested.HasKey(w) ? rested[w] : 0)
    if (w = wBorn) {
        left := w * 7 + 8 - born + 1     ; the habit's first day to that Sunday
        if (left < need)
            need := left
    }
    if (need <= 0)
        return "bridge"
    if (c >= need)
        return "kept"
    return (w = wNow) ? "open" : "fail"
}

; How the week holding this day stands on that day: {done, need} - "2 of 3".
HabitWeekProgress(h, day) {
    num := DayNum(day), w := WeekOf(num)
    c := 0, r := 0
    for _, d in h.done {
        dn := DayNum(d)
        if (dn < w * 7 + 2)
            break                        ; newest first: nothing older is in it
        if (WeekOf(dn) = w && dn <= num)
            c++
    }
    for _, d in h.rest
        if (WeekOf(DayNum(d)) = w)
            r++
    need := h.n - r
    born := DayNum(h.born)
    if (WeekOf(born) = w && w * 7 + 8 - born + 1 < need)
        need := w * 7 + 8 - born + 1
    return {done: c, need: (need < 0) ? 0 : need}
}

; What the day's note says beside a tick: "3 in a row", or for a week-counted
; habit how that week stood - "2 of 3 this week".
HabitRunText(h, day) {
    if (h.kind = "W") {
        p := HabitWeekProgress(h, day)
        return p.done " of " p.need " this week"
    }
    return HabitStreakAt(h, day) " in a row"
}

; Does today need doing to keep the chain? A daily habit not done yet: yes.
; Every other day, done yesterday: not today. A week-counted one: while the
; week is not kept yet.
HabitDue(h) {
    today := LogicalDay()
    if (HabitDid(h, today))
        return false
    if (h.kind = "W") {
        p := HabitWeekProgress(h, today)
        return p.done < p.need
    }
    return HabitBrokenBy(h, today)
}

; Had n days gone by undone - rest days not counted - by the end of this day?
; For an every-N-days habit that is what makes a day a miss rather than one of
; the days the rule allows off.
HabitBrokenBy(h, day) {
    n := h.n, miss := 0
    Loop {
        if (day < h.born || HabitDid(h, day))
            return false
        if (!HabitRested(h, day) && ++miss >= n)
            return true
        day := DayShift(day, -1)
    }
}

;================================================================================
; Old notes
;================================================================================
; Which habit has this name, or 0. Names are unique ignoring case - HabitAdd
; refuses a second one - so ignoring case here finds the same one it would.
HabitIndex(name) {
    global Habits
    for i, h in Habits
        if (h.text = name)
            return i
    return 0
}

; A day you filled in afterwards is corrected in that day's own note as well -
; for a note in the OLD shape, from before Daybook kept a block in each note
; (those notes have no block for DayNoteWrite to rewrite; this handles them).
;
; The note's "## habits" block was written when the day closed, and said what
; was true then. Leave it, and the note says "not done" about a day the panel
; and Daybook.md now say was done - two records, disagreeing. So this changes
; the one box, and the count above it, and nothing else in the file.
;
; It touches only Daybook's own block: a line that is not a checkbox under
; "## habits" goes back exactly as it came out, whoever wrote it. A day that has
; not closed yet has no block, and needs nothing - the close will write it right.
HabitFixNote(day, name, did) {
    global NoteBusy
    was := NoteBusy, NoteBusy := 1       ; see DayNoteWrite()
    HabitFixNoteNow(day, name, did)
    NoteBusy := was
}

HabitFixNoteNow(day, name, did) {
    global JournalOn
    if (!JournalOn)
        return
    f := JournalFile(day)
    if (!FileExist(f))
        return
    FileRead, s, *P65001 %f%
    if (ErrorLevel)
        return
    nl := InStr(s, "`r`n") ? "`r`n" : "`n"
    lines := StrSplit(StrReplace(s, "`r"), "`n")
    inBlock := 0, changed := 0, countAt := 0, done := 0, live := 0
    lines.Push("## ")                    ; a heading past the end closes the last block
    for k, line in lines {
        if (RegExMatch(line, "^#{1,6}\s")) {
            if (inBlock && countAt)
                lines[countAt] := RegExReplace(lines[countAt], "\d+/\d+", done "/" live)
            inBlock := RegExMatch(line, "i)^##\s+habits\s*$")
            countAt := 0, done := 0, live := 0
            continue
        }
        if (!inBlock)
            continue
        if (RegExMatch(line, "^habits-done::"))
            countAt := k
        else if (RegExMatch(line, "^(\s*[-*+]\s+\[)(.)(\]\s+)(.*?)(\s+\(streak::[^)]*\))?\s*$", m)) {
            live++
            if (Trim(m4) = name) {
                box := did ? "x" : " "
                if (m2 != box)
                    lines[k] := m1 box m3 m4 m5, m2 := box, changed := 1
            }
            if (m2 != " ")
                done++
        }
    }
    lines.Pop()
    if (!changed)
        return
    out := ""
    for k, line in lines
        out .= (k > 1 ? nl : "") line
    ; The * is binary mode. Without it FileAppend turns every `n into `r`n on
    ; the way out, and the file would come back with line ends it never had.
    tmp := f ".tmp"
    FileDelete, %tmp%
    FileAppend, %out%, *%tmp%, UTF-8
    if (!ErrorLevel)
        FileMove, %tmp%, %f%, 1
}

;================================================================================
; On the panel
;================================================================================
; How many are ticked today.
HabitsDone() {
    global Habits
    n := 0
    for _, h in Habits
        if (HabitDidToday(h))
            n++
    return n
}

; What one dot means. "none" is a day before the habit existed and is not drawn
; at all - a habit added on Thursday has nothing to say about Monday. "off" is
; a day not done that the rule allowed - every other day's day off, or a day of
; a week that can still be kept - and is grey, not red: red means the chain
; broke. For a week-counted habit that is the day the week could no longer be
; made, and every undone day after it that week.
HabitDayState(h, day, today) {
    if (day < h.born)
        return "none"
    if (HabitDid(h, day))
        return "done"
    if (HabitRested(h, day))
        return "rest"
    if (day = today)
        return "todo"
    if (h.kind = "W" ? !HabitWeekLost(h, day) : !HabitBrokenBy(h, day))
        return "off"
    return (day = DayShift(today, -1)) ? "miss" : "old"
}

; By the end of this day, could its week still reach its target? Done so far,
; plus every day left in the week that is not a rest day, against what the week
; needs. Three a week and nothing by Friday night: Friday is where it was lost.
HabitWeekLost(h, day) {
    p := HabitWeekProgress(h, day)
    num := DayNum(day)
    left := 0, d := day
    Loop % WeekOf(num) * 7 + 8 - num {           ; the days after it, to Sunday
        d := DayShift(d, 1)
        if (!HabitRested(h, d))
            left++
    }
    return p.done + left < p.need
}

; Yesterday is the one that stings, so it keeps the full red. Older misses fade
; to the dark red the overdue bar breathes through - still red, still countable
; at a glance, but not a wall of alarm every morning. A rest day is the blue a
; declared break is.
HabitDotColour(state) {
    global CGreen, CRed, CTrack, CBlue
    if (state = "done")
        return CGreen
    if (state = "miss")
        return CRed
    if (state = "todo")
        return CTrack
    if (state = "rest")
        return CBlue
    if (state = "off")
        return "3A4052"
    return "8A2A3C"                      ; "old"
}

; A streak as it is shown - the current one, or the best with best true. A
; week-counted habit shows weeks with a "w" after them (777 days kept three
; times a week is 112w; without the w it reads as if days had gone missing),
; unless it was switched to count in days, and then it shows the days done in
; that same run.
HabitStreakText(h, best := false) {
    if (HabitInWeeks(h))
        return (best ? h.best : h.streak) "w"
    if (h.kind = "W")
        return best ? h.bestDays : h.streakDays
    return best ? h.best : h.streak
}

HabitInWeeks(h) {
    return h.kind = "W" && h.unit != "D"
}

; Count a week-counted habit's streak in weeks ("W") or in days ("D").
HabitSetUnit(i, unit) {
    global Habits
    h := Habits[i]
    unit := (unit = "D") ? "D" : "W"
    if (!h || h.unit = unit)
        return
    h.unit := unit
    SaveState()
    Refresh()
}

; The number at the end of the row: green while the chain is safe for today,
; amber while it is alive but today needs doing, dim at zero.
HabitStreakColour(h) {
    global CGreen, CAmber, CDim
    ; by the number the row actually shows - weeks, or days if it was switched
    if ((h.kind = "W" && h.unit = "D" ? h.streakDays : h.streak) <= 0)
        return CDim
    return HabitDue(h) ? CAmber : CGreen
}
