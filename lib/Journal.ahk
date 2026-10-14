;================================================================================
; The day note, and Daybook's own log - two different things, kept apart
;================================================================================
; THE DAY NOTE, YYYY-MM-DD.md in the journal folder, is for you: to read, and
; to write in. Daybook owns ONE part of it - a block between two markers at the
; bottom - and rewrites that block as the day goes: the tasks with their notes,
; the habits, the time at the machine. Everything outside the markers is yours
; and goes back exactly as it came out, so whatever you write above the block
; stays exactly as you wrote it. A new day's note opens with a "## journal"
; heading waiting for you - the part the journal window shows (JournalWin.ahk).
; Notes from before 1.1 say "## my notes"; both are read. See DayNoteWrite().
;
; The block is at the BOTTOM so that rewriting it can never move the text you
; are typing: everything above it stays where it is.
;
; THE LOG, log\YYYY-MM.txt beside the script, is every click as it happened -
; added, ticked, renamed, reopened, dropped. It is append-only and outside your
; vault: nobody reads it in the normal run of things, it is where to look when
; a number seems wrong. Journal() and JournalNote() write to it.
;================================================================================
JournalFile(day) {
    return JournalDir "\" day ".md"
}

TS() {
    FormatTime, t, , HH:mm
    return t
}

Journal(line) {
    LogRaw(TS() "  " line)
}

JournalNote(line) {
    LogRaw("       " Chr(0x21B3) " " line)
}

LogRaw(text) {
    dir := A_ScriptDir "\log"
    if (!InStr(FileExist(dir), "D"))
        FileCreateDir, %dir%
    FormatTime, month, , yyyy-MM
    FileAppend, % LogicalDay() " " text "`n", %dir%\%month%.txt, UTF-8
}

;================================================================================
; The block
;================================================================================
DayMarkStart() {
    return "%% daybook: written by Daybook and rewritten as the day goes."
         . " Write anywhere above this line - that part is yours. %%"
}

DayMarkEnd() {
    return "%% /daybook %%"
}

; Write the day's block into its note. Called from SaveState() for today, and
; for an earlier day whenever something about it changes afterwards - a note
; added the morning after, a habit ticked late.
;
; A day before this version has a note in the old shape and no block, and is
; left exactly as it is. Today's note is made if it is not there yet.
;
; The time at the machine moves every sample, and rewriting a note you might be
; typing in once a minute for that alone would be asking for trouble. So a
; change to the tasks or habits is written at once, and the time only rides
; along - or on its own at most every half hour. force writes regardless: the
; close of a day, and edits to a day already over.
;
; NoteBusy is up while it works: the journal window reads and writes the same
; file, and a save landing between this read and this write would be undone.
DayNoteWrite(day, force := false) {
    global NoteBusy
    was := NoteBusy, NoteBusy := 1
    DayNoteWriteNow(day, force)
    NoteBusy := was
}

DayNoteWriteNow(day, force) {
    global JournalOn, CurDay
    static last := {}
    if (!JournalOn || day = "")
        return
    live := (day = CurDay)
    bare := DayBlock(day, false)
    if (!force && live && last.HasKey(day) && last[day].bare == bare
        && A_TickCount - last[day].at < 30 * 60000)
        return
    block := DayBlock(day, true)
    f := JournalFile(day)
    there := FileExist(f)
    s := ""
    if (there) {
        FileRead, s, *P65001 %f%
        if (ErrorLevel)
            return
    } else if (!live)
        return                           ; no note that day: nothing to correct
    nl := InStr(s, "`r`n") ? "`r`n" : "`n"
    blk := StrReplace(block, "`n", nl)
    a := InStr(s, "%% daybook:", true)
    b := a ? InStr(s, DayMarkEnd(), true, a) : 0
    ; The opening marker with no closing one after it is a note read short -
    ; caught mid-save by Obsidian or a sync - or one somebody cut. Either way,
    ; writing it back would lose whatever is missing, so it is left alone.
    if (a && !b)
        return
    if (there)
        DayNoteKeep(day, f, s)
    if (a && b)
        out := SubStr(s, 1, a - 1) blk SubStr(s, b + StrLen(DayMarkEnd()))
    else if (there) {
        if (!live)
            return                       ; an old note - see above
        out := RTrim(s, "`r`n") nl nl blk nl
    } else
        out := "# " day nl nl "## journal" nl nl nl blk nl
    if (there && out == s) {
        last[day] := {bare: bare, at: A_TickCount}
        return
    }
    if (!InStr(FileExist(JournalDir), "D"))
        FileCreateDir, %JournalDir%
    ; Binary mode, the *: text mode turns every `n into `r`n on the way out,
    ; and the file would come back with line ends it never had.
    tmp := f ".tmp"
    FileDelete, %tmp%
    FileAppend, %out%, *%tmp%, UTF-8
    if (ErrorLevel)
        return
    FileMove, %tmp%, %f%, 1
    ; Remembered only once it is on disk: a write that failed - the note held
    ; open by Obsidian or a sync - is tried again at the next save, rather
    ; than being taken as done for the next half hour.
    if (!ErrorLevel)
        last[day] := {bare: bare, at: A_TickCount}
}

; A note is yours, and Daybook is about to rewrite part of it - so the first
; time in a run that it touches a day's note, the note as it stood is copied to
; backups\notes\ beside the script. Whatever happens next, the words you wrote
; there are in that copy. Copies older than PastKeepDays are let go.
DayNoteKeep(day, f, s) {
    global StateFile, PastKeepDays
    static kept := {}
    if (kept.HasKey(day) || StateFile = "")
        return                           ; no state file named: nowhere of ours to put it
    kept[day] := 1
    SplitPath, StateFile, , dir
    dir .= "\backups\notes"
    if (!InStr(FileExist(dir), "D"))
        FileCreateDir, %dir%
    FileCopy, %f%, %dir%\%day%.md, 1
    cut := DayShift(LogicalDay(), -PastKeepDays)
    Loop, Files, %dir%\*.md
        if (SubStr(A_LoopFileName, 1, 10) < cut)
            FileDelete, %A_LoopFileFullPath%
}

; The block itself, from the first marker to the last, lines ending in `n.
; Headings rather than bold lines, and never with a number in them: a heading
; is what an Obsidian link or embed points at - ![[2026-09-26#tasks]] - and one
; whose words changed during the day would be a link that breaks.
DayBlock(day, withTime := true) {
    global Habits, CurDay, PastTime
    s := DayMarkStart() "`n## the day`n"
    s .= "`n### tasks`n`n"
    rows := DayTasks(day)
    for _, r in rows
        s .= DayTaskLine(r) "`n"
    if (!rows.Length())
        s .= "nothing on the list`n"
    live := 0, done := 0, lines := ""
    for _, h in Habits {
        if (day < h.born)
            continue
        live++
        if (HabitDid(h, day)) {
            done++
            lines .= "- " Chr(0x2713) " " h.text "  " Chr(0x00B7) " " HabitRunText(h, day) "`n"
        } else if (HabitRested(h, day))
            lines .= "- " Chr(0x2744) " " h.text "  " Chr(0x00B7) " rest day`n"
        else
            lines .= "- " Chr(0x2610) " " h.text "`n"
    }
    if (live)
        s .= "`n### habits`n`n" done " of " live " done`n`n" lines
    if (withTime) {
        t := (day = CurDay) ? DayTimeText() : (PastTime.HasKey(day) ? PastTime[day] : "")
        if (t != "")
            s .= "`n### time at the machine`n`n" t
    }
    return s "`n" DayMarkEnd()
}

; One task as a line, the same in the day note and on the board.
;   - ✓ buy milk  · long term  — got the oat one
DayTaskLine(r) {
    mark := (r.status = "done") ? Chr(0x2713) : (r.status = "failed") ? Chr(0x2717) : Chr(0x2610)
    s := "- " mark " " r.text
    if (r.list = "L")
        s .= "  " Chr(0x00B7) " long term"
    if (r.status = "open" && r.carry > 0)     ; days it had already been left undone
        s .= "  " Chr(0x00B7) " carried " Chr(0xD7) r.carry
    if (r.note != "")
        s .= "  " Chr(0x2014) " " r.note
    return s
}

; What was on that day's list, as {text, status, list, carry, note}. Today is
; read from the live list: everything on Today, and a long term task only if it
; was finished today. An earlier day is read from what CloseDay() kept of it.
DayTasks(day) {
    global Tasks, Past, CurDay
    out := []
    if (day = CurDay) {
        for _, want in ["T", "L"]
            for _, t in Tasks
                if (t.list = want && (want = "T" || t.doneOn = day))
                    out.Push({text: t.text, status: t.status, list: t.list
                            , carry: t.carry, note: TaskNote(t, day)})
    } else {
        for _, r in Past
            if (r.day = day)
                out.Push(r)
    }
    return out
}

; The time section: the total, the top programs, the hour strip.
DayTimeText() {
    total := TotalLogged()
    if (!total)
        return ""
    s := "active " HumanTime(total) "`n"
    tops := ""
    for _, a in TopApps(8)
        tops .= (tops ? " " Chr(0x00B7) " " : "") a.exe " " HumanTime(a.sec)
    if (tops != "")
        s .= "`n" tops "`n"
    strip := HourStrip()                 ; indented, so markdown keeps it monospaced
    if (strip != "")
        s .= "`n" strip
    return s
}
