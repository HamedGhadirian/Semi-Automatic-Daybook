;================================================================================
; Daybook.md - the board: where things stand, written by Daybook alone
;================================================================================
; One file in the journal folder: today's list with its notes, the long term
; list, and the habits - their streaks and a grid of the last two weeks. It is
; rewritten whenever any of that changes, and ONLY then.
;
; It goes one way. Obsidian cannot show a cross, a colour or a week of dots, so
; it is a poor place to DO anything and a good place to read; the panel is
; where things are done. The file says so at the top, and anything typed into
; it is simply replaced at the next change. (The first version read changes
; back from this file. It worked, but it was the most fragile part of Daybook
; for the least gain, and it went on the way to 1.0.)
;
; It replaces Habits.md, the scoreboard that used to be a file of its own.
;================================================================================
BoardWrite() {
    global BoardOn, JournalDir
    static last := ""
    if (!BoardOn || JournalDir = "")
        return
    f := JournalDir "\Daybook.md"
    s := BoardRender()
    if (s == last && FileExist(f))
        return                           ; nothing moved since the last write
    if (FileExist(f)) {
        FileRead, disk, *P65001 %f%
        if (!ErrorLevel && disk == s) {
            last := s
            return
        }
    }
    if (!InStr(FileExist(JournalDir), "D"))
        FileCreateDir, %JournalDir%
    tmp := f ".tmp"                      ; binary (*) - see DayNoteWrite()
    FileDelete, %tmp%
    FileAppend, %s%, *%tmp%, UTF-8
    if (ErrorLevel)
        return
    FileMove, %tmp%, %f%, 1
    if (!ErrorLevel)
        last := s
}

BoardRender() {
    global Tasks, Habits
    today := LogicalDay()
    s := "# Daybook`n`n"
    s .= "Where things stand, written by Daybook whenever something changes."
    s .= " Change things on the panel - anything typed here is replaced. Each"
    s .= " day's own note has that day in full.`n"

    ; missed only while something is in it, as on the panel
    lines := ""
    for _, t in Tasks
        if (t.list = "M")
            lines .= "- " Chr(0x2610) " " t.text "  " Chr(0x00B7) " missed "
                  .  MissSinceText(t.since) "  " Chr(0x00B7) " " Chr(0xD7) t.carry "`n"
    if (lines != "")
        s .= "`n## missed`n`n" lines

    for _, sect in [["T", "today"], ["S", "short term"], ["L", "long term"]] {
        s .= "`n## " sect[2] "`n`n"
        n := 0
        for _, t in Tasks {
            if (t.list != sect[1])
                continue
            line := DayTaskLine({text: t.text, status: t.status, list: "", carry: t.carry
                               , note: TaskNote(t, today)})
            ; the deadline goes after the words, before any note
            if (t.list = "S" && t.due != "") {
                due := "  " Chr(0x00B7) " due " t.due
                p := InStr(line, "  " Chr(0x2014) " ")
                line := p ? SubStr(line, 1, p - 1) due SubStr(line, p) : line due
            }
            s .= line "`n"
            n++
        }
        if (!n)
            s .= "nothing here`n"
    }

    s .= "`n## habits`n`n"
    if (!Habits.Length())
        return s "No habits yet. Add one from the + beside HABITS on the panel.`n"
    s .= "| habit | streak | best | days done | how often | since |`n"
    s .= "| --- | ---: | ---: | ---: | --- | --- |`n"
    for _, h in Habits
        s .= "| " h.text " | " HabitStreakText(h) " | " HabitStreakText(h, true) " | " h.total " | " HabitRuleText(h) " | " h.born " |`n"
    s .= "`n### the last two weeks`n`n| habit |"
    Loop 14
        s .= " " SubStr(DayShift(today, A_Index - 14), 9, 2) " |"
    s .= "`n| --- |"
    Loop 14
        s .= " :-: |"
    s .= "`n"
    for _, h in Habits {
        s .= "| " h.text " |"
        Loop 14 {
            ; a cross only where the panel shows red - a day the rule allowed
            ; off is a dash, a rest day the snowflake the day note uses
            st := HabitDayState(h, DayShift(today, A_Index - 14), today)
            s .= " " ((st = "done") ? Chr(0x2705) : (st = "none") ? " "
                    : (st = "todo") ? Chr(0x2B1C) : (st = "off") ? Chr(0x2013)
                    : (st = "rest") ? Chr(0x2744) : Chr(0x274C)) " |"
        }
        s .= "`n"
    }
    return s
}
