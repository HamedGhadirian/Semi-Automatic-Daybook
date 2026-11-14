;================================================================================
; The roll-up - days into weeks, weeks into months, months into a year
;================================================================================
; Once a day - at start, and when the day turns - Daybook looks back:
;
;   A WEEK that has ended gets a note of its own, 2026-W42.md: the days you
;   wrote, the time at the machine, the tasks, the habits. Weeks run Monday to
;   Sunday, numbered the ISO way, and a week belongs to the month its Thursday
;   is in - so every week has exactly one home, even one that crosses a month.
;
;   A MONTH that has ended is packed: its day notes and its weeks move into
;   2026\2026-10 October\, and a note for the month goes in with them. The
;   month you are in stays loose in the journal folder until it is over.
;
;   The YEAR's note, 2026\2026 year.md, is written again each time a month is
;   packed: a line per month, so far.
;
; Numbers only, nothing guessed: everything comes from the day notes - the
; block Daybook wrote at the bottom of each, and whether you wrote anything
; above it. That is why an old month still adds up after Daybook's own memory
; of it (42 days) is gone, and why a month you were away for is simply short.
; The habits come from their history, which is kept whole.
;
; Your days are LINKED, never copied: a month of journal pasted into one note
; would be a wall. Hover a link in Obsidian and the day shows.
;
; Each summary is shaped like a day note: a heading and a few questions on
; top that are yours to answer, Daybook's block at the bottom between the same
; two markers. Writing a summary again rewrites the block and nothing else.
;
; Files are only ever moved, never deleted, and every move goes in Daybook's
; log. Off ([Journal] RollUp=0) and nothing here runs.
;
; Days and months are text (2026-10-14, 2026-10), compared with StrCompare.
;================================================================================
#Requires AutoHotkey v2.0

; English names, not the system's: a folder's name must not change with the
; language Windows is set to. The finder only reads the "2026-10" in front.
RollMonthName(m) {
    static names := ["January", "February", "March", "April", "May", "June", "July"
        , "August", "September", "October", "November", "December"]
    return names[Integer(SubStr(m, 6, 2))]
}

; "12 Oct"
RollShortDay(day) {
    return Integer(SubStr(day, 9, 2)) " " SubStr(RollMonthName(day), 1, 3)
}

RollMarkStart() {
    return "%% daybook: written by Daybook from the day notes, and rewritten when"
         . " it looks back again. Write anywhere above this line - that part is yours. %%"
}

DayFromNum(n) {
    return DayShift("2000-01-01", n)
}

;================================================================================
; The run
;================================================================================
; force: the tray's "Write the summaries again" - every week of the last six,
; every month and every year, whether or not it has a note already.
RollupRun(force := false) {
    static ranFor := ""
    if (!JournalOn || !RollupOn || !DirExist(JournalDir))
        return
    today := LogicalDay()
    if (!force && ranFor = today)
        return
    ranFor := today
    cur := SubStr(today, 1, 7)
    redo := Map()                        ; months whose note must be written again
    years := Map()

    ; ---- the weeks that ended, the last six of them
    thisMon := WeekOf(DayNum(today)) * 7 + 2
    loop 6 {
        w := RollWeek(thisMon - 7 * A_Index)
        f := RollWeekFile(w)
        if (f != "" && !force)
            continue
        if (f = "")
            f := (StrCompare(w.month, cur) < 0 ? RollMonthDir(w.month, true) : JournalDir) "\" w.name ".md"
        if (RollWriteWeek(w, f) && StrCompare(w.month, cur) < 0)
            redo[w.month] := 1
    }

    ; ---- months over: whatever of theirs is still loose is packed
    loose := []
    loop files JournalDir "\*.md"
        loose.Push(A_LoopFileName)
    for n in loose {
        if (RegExMatch(n, "^(\d{4}-\d\d)-\d\d(\.md$| )", &m))
            mo := m[1]
        else if (RegExMatch(n, "^\d{4}-W\d\d\.md$"))
            mo := SubStr(RollWeek(RollWeekMon(n)).thu, 1, 7)
        else
            continue
        if (StrCompare(mo, cur) >= 0)
            continue
        dir := RollMonthDir(mo, true)
        if (FileExist(dir "\" n)) {
            Journal("roll-up: " n " left loose - " dir " already has one")
            continue
        }
        try {
            FileMove(JournalDir "\" n, dir "\" n)
            if FileExist(dir "\" n) {
                Journal("roll-up: moved " n " into " SubStr(dir, StrLen(JournalDir) + 2))
                redo[mo] := 1
            }
        }
    }

    ; ---- a note for every month that has a folder and none, or that changed
    loop files JournalDir "\*", "D" {
        if (!RegExMatch(A_LoopFileName, "^\d{4}$"))
            continue
        y := A_LoopFileName
        loop files JournalDir "\" y "\" y "-*", "D" {
            if (!RegExMatch(A_LoopFileName, "^(\d{4}-\d\d)", &m) || StrCompare(m[1], cur) >= 0)
                continue
            f := A_LoopFileFullPath "\" A_LoopFileName ".md"
            if (force || redo.Has(m[1]) || !FileExist(f)) {
                RollWriteMonth(m[1], f)
                years[y] := 1
            }
        }
    }
    for y in years
        RollWriteYear(y, JournalDir "\" y "\" y " year.md")
}

; The month's folder: the one that is there already, whatever it was called
; after the "2026-10" - or 2026\2026-10 October, made if make says so.
RollMonthDir(m, make := false) {
    y := SubStr(m, 1, 4)
    loop files JournalDir "\" y "\" m "*", "D"
        return A_LoopFileFullPath
    dir := JournalDir "\" y "\" m " " RollMonthName(m)
    if (make)
        try DirCreate(dir)
    return dir
}

;================================================================================
; Weeks
;================================================================================
; The week that starts on Monday monNum (a DayNum): its days, its ISO name,
; and the month it belongs to - its Thursday's.
RollWeek(monNum) {
    thu := DayFromNum(monNum + 3)
    yd := Integer(FormatTime(StrReplace(thu, "-") "000000", "YDay"))
    wk := (yd - 1) // 7 + 1
    return {mon: DayFromNum(monNum), sun: DayFromNum(monNum + 6), thu: thu
          , month: SubStr(thu, 1, 7), name: SubStr(thu, 1, 4) "-W" Format("{:02}", wk)}
}

; The Monday (DayNum) of an ISO week, from its name: 2026-W42. Week 1 is the
; one with 4 January in it.
RollWeekMon(name) {
    y := SubStr(name, 1, 4), wk := Integer(SubStr(name, 7, 2))
    return WeekOf(DayNum(y "-01-04")) * 7 + 2 + (wk - 1) * 7
}

; Where a week's note is, loose or packed - "" when it has none yet.
RollWeekFile(w) {
    f := JournalDir "\" w.name ".md"
    if (FileExist(f))
        return f
    f := RollMonthDir(w.month) "\" w.name ".md"
    return FileExist(f) ? f : ""
}

; Written only for a week Daybook was there for - a day with its block. A
; week from before is just its days, and the month lists those.
RollWriteWeek(w, f) {
    days := []
    loop 7
        days.Push(DayShift(w.mon, A_Index - 1))
    s := RollSum(days)
    if (!s.dataDays)
        return false
    yr := SubStr(w.sun, 1, 4)
    sub := RollShortDay(w.mon) " - " RollShortDay(w.sun) " " yr
        . "  " Chr(0x00B7) "  [[" w.month " " RollMonthName(w.month) "]]"
    b := "## the week`n" RollBody(s, w.mon, w.sun, "week")
    q := "- What went well?`n- What got in the way?`n- What do I want from next week?"
    return RollWrite(f, SubStr(w.name, 1, 4) " week " Integer(SubStr(w.name, 7)), sub, q, b)
}

;================================================================================
; Months and the year
;================================================================================
RollMonthDays(m) {
    days := []
    d := m "-01"
    while (SubStr(d, 1, 7) = m) {
        days.Push(d)
        d := DayShift(d, 1)
    }
    return days
}

RollWriteMonth(m, f) {
    days := RollMonthDays(m)
    s := RollSum(days)
    first := days[1], last := days[days.Length]
    ; its weeks: every one whose Thursday is in it
    wl := ""
    n := WeekOf(DayNum(first)) * 7 + 2
    while (StrCompare(DayFromNum(n), last) <= 0) {
        w := RollWeek(n)
        if (w.month = m && RollWeekFile(w) != "")
            wl .= (wl != "" ? "  " Chr(0x00B7) "  " : "") "[[" w.name "]]"
        n += 7
    }
    y := SubStr(m, 1, 4)
    sub := "[[" y " year]]" (wl != "" ? "  " Chr(0x00B7) "  weeks: " wl : "")
    b := "## the month`n" RollBody(s, first, last, "month")
    q := "- What was this month about?`n- What got in the way?`n- What do I want from the next one?"
    RollWrite(f, RollMonthName(m) " " y, sub, q, b)
}

; A line a month, so far: how much you wrote, sat, finished - and the habits
; over the whole year.
RollWriteYear(y, f) {
    today := LogicalDay()
    rows := "", all := []
    tw := 0, tWords := 0, tAct := 0, tDone := 0, tDrop := 0
    loop 12 {
        m := y "-" Format("{:02}", A_Index)
        if (StrCompare(m, SubStr(today, 1, 7)) >= 0)
            break
        days := RollMonthDays(m)
        s := RollSum(days)
        for d in days
            all.Push(d)
        if (!s.notes)
            continue
        c := RollTaskCount(s)
        dir := RollMonthDir(m)
        SplitPath(dir, &mname)
        ; \| - a bare | would end the table cell
        link := FileExist(dir "\" mname ".md") ? "[[" mname "\|" RollMonthName(m) "]]" : RollMonthName(m)
        rows .= "| " link " | " s.written.Length " | " s.words " | "
            . (s.active ? HumanTime(s.active) : "-") " | " c["done"] " | " c["failed"] " |`n"
        tw += s.written.Length, tWords += s.words, tAct += s.active
        tDone += c["done"], tDrop += c["failed"]
    }
    if (rows = "")
        return
    b := "## the year`n`n| month | days written | words | at the machine | tasks done | dropped |`n"
       . "| --- | --: | --: | --: | --: | --: |`n" rows
       . "| **all** | **" tw "** | **" tWords "** | **" (tAct ? HumanTime(tAct) : "-")
       . "** | **" tDone "** | **" tDrop "** |`n"
    h := RollHabitTotals(all[1], all[all.Length])
    if (h != "")
        b .= "`n### habits`n`n" h
    done := (Integer(y) < Integer(SubStr(today, 1, 4)))
    sub := done ? "the whole year" : "so far - to the end of " RollMonthName(all[all.Length])
    q := "- What was this year about?`n- What am I proud of?`n- What do I want from the next one?"
    RollWrite(f, y, sub, q, b)
}

;================================================================================
; Reading the day notes
;================================================================================
; One day's note, as numbers: "" when there is none. words = yours, above
; Daybook's block. The block is read back the way DayBlock() writes it.
RollDay(day) {
    f := JournalFile(day)
    if (!FileExist(f))
        return ""
    try s := FileRead(f, "UTF-8")
    catch
        return ""
    SplitPath(f, , , , &link)
    r := {day: day, link: link, words: 0, block: false, tasks: [], active: 0, apps: Map()}
    RegExReplace(NoteUserPart(s), "(*UCP)\w+", "", &n)
    r.words := n
    a := InStr(s, "%% daybook:", true)
    b := a ? InStr(s, DayMarkEnd(), true, a) : 0
    if (!a || !b)
        return r
    r.block := true
    sect := "", sawActive := false, sawApps := false
    tick := Chr(0x2713), cross := Chr(0x2717)
    for line in StrSplit(StrReplace(SubStr(s, a, b - a), "`r"), "`n") {
        if (RegExMatch(line, "^###\s+(.+?)\s*$", &m)) {
            sect := m[1]
            continue
        }
        if (sect = "tasks" && RegExMatch(line, "^- (\S) (.*)$", &m)) {
            text := m[2], note := ""
            if (p := InStr(text, "  " Chr(0x2014) " ")) {
                note := Trim(SubStr(text, p + 4))
                text := SubStr(text, 1, p - 1)
            }
            text := RegExReplace(text, "  " Chr(0x00B7) " (long term|short term|carried .*)$")
            text := RegExReplace(text, "  " Chr(0x00B7) " (long term|short term|carried .*)$")
            st := (m[1] = tick) ? "done" : (m[1] = cross) ? "failed" : "open"
            r.tasks.Push({text: Trim(text), status: st, note: note, day: day})
        } else if (sect = "time at the machine") {
            if (RegExMatch(line, "^active (.+)$", &m)) {
                r.active := RollSec(m[1]), sawActive := true
            } else if (sawActive && !sawApps && line != "" && !RegExMatch(line, "^\s")) {
                sawApps := true
                for item in StrSplit(line, " " Chr(0x00B7) " ")
                    if (RegExMatch(item, "^(.+?) ((?:\d+h )?\d+m)$", &m))
                        r.apps[m[1]] := RollSec(m[2])
            }
        }
    }
    return r
}

; "12h 40m" or "35m" -> seconds. HumanTime() backwards.
RollSec(t) {
    if (!RegExMatch(Trim(t), "^(?:(\d+)h )?(\d+)m$", &m))
        return 0
    return (m[1] = "" ? 0 : Integer(m[1]) * 3600) + Integer(m[2]) * 60
}

; Many days into one: what was written, the time and the programs, and each
; task as it last stood - a task carried over three days is one task.
RollSum(days) {
    s := {notes: 0, written: [], words: 0, active: 0, timeDays: 0, dataDays: 0
        , apps: DayMap(), tasks: Map(), order: []}
    for day in days {
        r := RollDay(day)
        if (!IsObject(r))
            continue
        s.notes++
        if (r.words) {
            s.written.Push({link: r.link, words: r.words})
            s.words += r.words
        }
        if (r.block)
            s.dataDays++
        if (r.active)
            s.active += r.active, s.timeDays++
        for exe, sec in r.apps
            s.apps[exe] := (s.apps.Has(exe) ? s.apps[exe] : 0) + sec
        for t in r.tasks {
            ; one task however its case was typed - the way the v1 version
            ; grouped them
            k := StrLower(t.text)
            if (!s.tasks.Has(k)) {
                s.tasks[k] := {text: t.text, notes: [], status: "", day: ""}
                s.order.Push(k)
            }
            e := s.tasks[k]
            e.status := t.status, e.day := t.day
            if (t.note != "" && !RollHas(e.notes, t.note))
                e.notes.Push(t.note)
        }
    }
    return s
}

RollHas(list, v) {
    for x in list
        if (x == v)
            return true
    return false
}

RollTaskCount(s) {
    c := Map("done", 0, "failed", 0, "open", 0)
    for k in s.order
        if c.Has(s.tasks[k].status)
            c[s.tasks[k].status] += 1
    return c
}

;================================================================================
; Writing it out
;================================================================================
; The body of a week's or a month's block: headings with no numbers in them,
; so a link to one - [[2026-W42#tasks]] - never breaks.
RollBody(s, first, last, what) {
    b := "`n### days you wrote`n`n"
    if (s.written.Length) {
        for w in s.written
            b .= "- [[" w.link "]]  " Chr(0x00B7) "  " w.words " words`n"
    } else
        b .= "no journal this " what "`n"

    if (s.active) {
        b .= "`n### time at the machine`n`n"
        b .= "active " HumanTime(s.active) " over " s.timeDays (s.timeDays = 1 ? " day" : " days")
           . "  " Chr(0x00B7) "  " HumanTime(s.active // s.timeDays) " a day`n"
        lines := ""
        for exe, sec in s.apps
            lines .= Format("{:09}", sec) "`t" exe "`n"
        lines := Sort(lines, "R")
        tops := "", n := 0
        loop parse lines, "`n" {
            if (A_LoopField = "" || ++n > 8)
                continue
            p := StrSplit(A_LoopField, "`t")
            tops .= (tops != "" ? " " Chr(0x00B7) " " : "") p[2] " " HumanTime(Integer(p[1]))
        }
        if (tops != "")
            b .= "`n" tops "`n"
    }

    if (s.order.Length) {
        c := RollTaskCount(s)
        b .= "`n### tasks`n`n" c["done"] " done  " Chr(0x00B7) "  " c["failed"] " dropped  "
           . Chr(0x00B7) "  " c["open"] " left open`n"
        for want in [["done", "done"], ["failed", "dropped"], ["open", "left open"]] {
            part := ""
            for k in s.order {
                e := s.tasks[k]
                if (e.status != want[1])
                    continue
                note := ""
                for x in e.notes
                    note .= (note != "" ? "; " : "") x
                part .= "- " e.text (note != "" ? "  " Chr(0x2014) " " note : "") "`n"
            }
            if (part != "")
                b .= "`n**" want[2] "**`n`n" part
        }
    }

    h := RollHabitGrid(first, last)
    if (h != "")
        b .= "`n### habits`n`n" h
    return b
}

; One row a habit, one mark a day - a space before each Monday - in a code
; block so the marks line up:
;   push ups   ✓✓·✓~·· ✓✓✓✓✓✓✓   11 days · 9 in a row
RollHabitGrid(first, last) {
    if (!Habits.Length)
        return ""
    wide := 0
    for h in Habits
        if (StrCompare(h.born, last) <= 0 && StrLen(h.text) > wide)
            wide := StrLen(h.text)
    rows := ""
    for h in Habits {
        if (StrCompare(h.born, last) > 0)
            continue
        row := "", c := 0, d := first, i := 0
        while (StrCompare(d, last) <= 0) {
            if (i++ && Mod(DayNum(d) - 2, 7) = 0)
                row .= " "
            if (StrCompare(d, h.born) < 0)
                row .= " "
            else if (HabitDid(h, d))
                row .= Chr(0x2713), c++
            else if (HabitRested(h, d))
                row .= "~"
            else
                row .= Chr(0x00B7)
            d := DayShift(d, 1)
        }
        tail := c (c = 1 ? " day" : " days")
        if (h.kind != "W")
            tail .= "  " Chr(0x00B7) "  " HabitStreakAt(h, last) " in a row"
        else
            tail .= "  " Chr(0x00B7) "  " h.n " a week"
        rows .= Format("{:-" wide "}", h.text) "   " row "   " tail "`n"
    }
    return "``````" "`n" rows "``````" "`n" Chr(0x2713) " done  " Chr(0x00B7) "  ~ rest day  "
         . Chr(0x00B7) "  " Chr(0x00B7) " not done`n"
}

; The year's habits: just how many days each, and the best run.
RollHabitTotals(first, last) {
    out := ""
    for h in Habits {
        if (StrCompare(h.born, last) > 0)
            continue
        c := 0
        for d in h.done
            if (StrCompare(d, first) >= 0 && StrCompare(d, last) <= 0)
                c++
        out .= "- " h.text "  " Chr(0x00B7) "  " c (c = 1 ? " day" : " days")
        ; a week-counted habit's best is in weeks - only a daily one's says days
        out .= (h.kind != "W" ? "  " Chr(0x00B7) "  best run " HabitMeasure(h, last).best " days" : "") "`n"
    }
    return out
}

; A summary note, made or brought up to date. Made: a heading, a line under it,
; the questions as yours, then the block. Already there: only the block is
; rewritten - what you wrote above it stays exactly as it was.
RollWrite(f, title, sub, questions, body) {
    blk := RollMarkStart() "`n" body "`n" DayMarkEnd()
    if (FileExist(f)) {
        try s := FileRead(f, "UTF-8")
        catch
            return false
        nl := InStr(s, "`r`n") ? "`r`n" : "`n"
        blk := StrReplace(blk, "`n", nl)
        a := InStr(s, "%% daybook:", true)
        b := a ? InStr(s, DayMarkEnd(), true, a) : 0
        if (a && !b)
            return false                 ; read short - left for next time
        out := a ? SubStr(s, 1, a - 1) blk SubStr(s, b + StrLen(DayMarkEnd()))
                 : RTrim(s, "`r`n") nl nl blk nl
        if (out == s)
            return true
    } else
        out := "# " title "`n`n" sub "`n`n## journal`n`n" questions "`n`n" blk "`n"
    SplitPath(f, , &dir)
    try {
        if !DirExist(dir)
            DirCreate(dir)
    }
    return NoteReplace(f, out)
}
