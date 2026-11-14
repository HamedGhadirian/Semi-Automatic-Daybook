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
#Requires AutoHotkey v2.0

;================================================================================
; Which file is a day's note
;================================================================================
; The one whose name STARTS with the date: 2026-10-14.md, or 2026-10-14 world
; cup.md once it has a title - the journal window's title box renames it, and
; so can you, in Obsidian or anywhere. The date is all Daybook looks at, so a
; title never hides a day from it. Looked for in the journal folder, and in the
; month folders the roll-up files days into (2026\2026-10 October\).
;
; Looked up afresh every time - a rename in Obsidian is seen at once, and the
; loop below is the system's own file search, quick on any folder size.
;
; Two files for one day: if the plain one has nothing of yours in it - Daybook
; made it before the titled one turned up - the titled one is the day's note.
; A writer (fold true - they hold NoteBusy, or are Critical) also folds the
; plain one into it: its block moves over, the file goes to backups\notes\
; folded, and the day is one file again. A lookup that only reads never moves
; a file - it may run on a timer in the middle of a writer. If both have your
; words, neither is touched: the plain one is used, and JournalTwins names the
; day so the journal window can say so.
JournalFile(day, fold := false) {
    global JournalTwins
    found := JournalFind(day)
    if (found.Length = 0)
        return JournalDir "\" day ".md"
    if (found.Length = 1)
        return found[1]
    plain := "", named := []
    for f in found {
        SplitPath(f, &name)
        if (name = day ".md")
            plain := f
        else
            named.Push(f)
    }
    if (plain != "" && named.Length = 1) {
        ok := true
        try p := FileRead(plain, "UTF-8")
        catch
            ok := false
        if (ok && NoteUserPart(p) = "") {
            if (fold)
                JournalFold(day, plain, named[1])
            return named[1]
        }
    }
    JournalTwins := day
    return plain != "" ? plain : found[1]
}

JournalFind(day) {
    found := []
    dirs := [JournalDir]
    y := SubStr(day, 1, 4), m := SubStr(day, 1, 7)
    loop files JournalDir "\" y "\" m "*", "D"
        dirs.Push(A_LoopFileFullPath)
    for dir in dirs
        loop files dir "\" day "*.md"
            if (A_LoopFileName = day ".md" || SubStr(A_LoopFileName, 11, 1) = " ")
                found.Push(A_LoopFileFullPath)
    return found
}

; The title in a note's file name: what comes after the date, or "".
JournalTitleOf(f) {
    SplitPath(f, , , , &name)
    return Trim(SubStr(name, 12))
}

; A title as a file name can carry it: no \ / : * ? " < > | (Windows will not
; have them) and no # ^ [ ] (an Obsidian link to the note would break on
; them), no dots or spaces at the end, one space between words, not too long.
; A date typed in front of it is taken off - the date is already there.
JournalCleanTitle(t) {
    t := RegExReplace(t, "[\\/:*?`"<>|#^\[\]\r\n\t]", " ")
    t := RegExReplace(t, "^\s*\d{4}-\d\d-\d\d\b")
    t := Trim(RegExReplace(t, "\s+", " "))
    t := SubStr(t, 1, 80)
    return RTrim(t, ". ")
}

; Give a day's note a title, or take it away: the file is renamed in place.
; Returns the new path, or "" when it could not be - another file already has
; that name, or the note is held open. There must be a note to rename.
;
; A note whose first line IS its old title - the older notes, "# world cup" -
; gets the new one there too, so the two never disagree. A first line that is
; anything else (Daybook's "# 2026-10-14", or your own words) is left alone.
JournalRetitle(day, title) {
    f := JournalFile(day, true)
    if (!FileExist(f))
        return ""
    SplitPath(f, , &dir)
    t := JournalCleanTitle(title)
    g := dir "\" day (t != "" ? " " t : "") ".md"
    if (g == f)
        return f
    ; a change of case alone is the same file to Windows - overwrite is how
    ; MoveFileEx is told to go ahead with it
    same := (g = f)
    if (!same && FileExist(g))
        return ""
    was := JournalTitleOf(f)
    moved := false
    loop 3 {
        try {
            FileMove(f, g, same)
            if FileExist(g) {
                moved := true
                break
            }
        }
        Sleep(150)
    }
    if (!moved)
        return ""
    if (was != "")
        JournalRetitleHead(g, was, t != "" ? t : day)
    return g
}

JournalRetitleHead(f, was, now) {
    try s := FileRead(f, "UTF-8")
    catch
        return
    nl := InStr(s, "`r`n") ? "`r`n" : "`n"
    first := SubStr(s, 1, (p := InStr(s, nl)) ? p - 1 : StrLen(s))
    if !(Trim(first) == "# " was)
        return
    NoteReplace(f, "# " now SubStr(s, StrLen(first) + 1))
}

; Fold a plain note Daybook made into the titled one beside it - only when the
; plain one holds none of your words. Its block goes to the titled note if that
; has none; the plain file is moved, not deleted, to backups\notes\folded.
JournalFold(day, plain, named) {
    try p := FileRead(plain, "UTF-8")
    catch
        return false
    if (NoteUserPart(p) != "")
        return false
    try n := FileRead(named, "UTF-8")
    catch
        return false
    a := InStr(p, "%% daybook:", true)
    b := a ? InStr(p, DayMarkEnd(), true, a) : 0
    if (a && !b)
        return false                     ; read short - leave both for now
    if (a && !InStr(n, "%% daybook:", true)) {
        nl := InStr(n, "`r`n") ? "`r`n" : "`n"
        blk := SubStr(p, a, b + StrLen(DayMarkEnd()) - a)
        blk := StrReplace(StrReplace(blk, "`r"), "`n", nl)
        if !NoteReplace(named, RTrim(n, "`r`n") nl nl blk nl)
            return false
    }
    SplitPath(StateFile, , &dir)
    if (dir = "")
        dir := A_ScriptDir
    dir .= "\backups\notes\folded"
    if !DirExist(dir)
        DirCreate(dir)
    try {
        FileMove(plain, dir "\" day "-" FormatTime(, "HHmmss") ".md", 1)
        return true
    }
    return false
}

; Your words in a note: everything above Daybook's block, less the title line
; and the "## journal" heading. "" when there are none.
NoteUserPart(s) {
    t := StrReplace(s, "`r")
    if (a := InStr(t, "%% daybook:", true))
        t := SubStr(t, 1, a - 1)
    t := RegExReplace(t, "^\x{FEFF}")
    t := RegExReplace(t, "^#[ \t][^\n]*")
    t := RegExReplace(t, "im`n)^##[ \t]+(journal|my notes)[ \t]*$")
    return Trim(t, " `t`n")
}

; A note's text, or "" when it cannot be read.
NoteRead(f) {
    try return FileRead(f, "UTF-8")
    return ""
}

; A note written whole: through a temporary file and a move, so a crash or a
; full disk leaves the old one as it was. No line-end translation - the text
; goes out byte for byte with the line ends it came in with. True once done.
NoteReplace(f, out) {
    tmp := f ".tmp"
    try FileDelete(tmp)
    try {
        FileAppend(out, tmp, "UTF-8")
        FileMove(tmp, f, 1)
        return true
    }
    try FileDelete(tmp)
    return false
}

TS() {
    return FormatTime(, "HH:mm")
}

Journal(line) {
    if IsObject(Journalled)              ; the tests: what would have been written
        Journalled.Push(line)
    LogRaw(TS() "  " line)
}

JournalNote(line) {
    LogRaw("       " Chr(0x21B3) " " line)
}

LogRaw(text) {
    dir := A_ScriptDir "\log"
    try {
        if !DirExist(dir)
            DirCreate(dir)
        FileAppend(LogicalDay() " " text "`n", dir "\" FormatTime(, "yyyy-MM") ".txt", "UTF-8")
    }
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
    try DayNoteWriteNow(day, force)
    catch as e
        Kit.Log("Day note " day ": " e.Message)
    NoteBusy := was
}

DayNoteWriteNow(day, force) {
    static last := Map()
    if (!JournalOn || day = "")
        return
    live := (day = CurDay)
    bare := DayBlock(day, false)
    if (!force && live && last.Has(day) && last[day].bare == bare
        && A_TickCount - last[day].at < 30 * 60000)
        return
    block := DayBlock(day, true)
    f := JournalFile(day, true)
    there := FileExist(f)
    s := ""
    if (there) {
        try s := FileRead(f, "UTF-8")
        catch
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
    if !DirExist(JournalDir)
        DirCreate(JournalDir)
    ; Remembered only once it is on disk: a write that failed - the note held
    ; open by Obsidian or a sync - is tried again at the next save, rather
    ; than being taken as done for the next half hour.
    if NoteReplace(f, out)
        last[day] := {bare: bare, at: A_TickCount}
}

; A note is yours, and Daybook is about to rewrite part of it - so the first
; time in a run that it touches a day's note, the note as it stood is copied to
; backups\notes\ beside the script. Whatever happens next, the words you wrote
; there are in that copy. Copies older than PastKeepDays are let go.
DayNoteKeep(day, f, s) {
    static kept := Map()
    if (kept.Has(day) || StateFile = "")
        return                           ; no state file named: nowhere of ours to put it
    kept[day] := 1
    SplitPath(StateFile, , &dir)
    dir .= "\backups\notes"
    try {
        if !DirExist(dir)
            DirCreate(dir)
        FileCopy(f, dir "\" day ".md", 1)
    }
    cut := DayShift(LogicalDay(), -PastKeepDays)
    loop files dir "\*.md"
        if (StrCompare(SubStr(A_LoopFileName, 1, 10), cut) < 0)
            try FileDelete(A_LoopFileFullPath)
}

; The block itself, from the first marker to the last, lines ending in `n.
; Headings rather than bold lines, and never with a number in them: a heading
; is what an Obsidian link or embed points at - ![[2026-09-26#tasks]] - and one
; whose words changed during the day would be a link that breaks.
DayBlock(day, withTime := true) {
    s := DayMarkStart() "`n## the day`n"
    s .= "`n### tasks`n`n"
    rows := DayTasks(day)
    for r in rows
        s .= DayTaskLine(r) "`n"
    if (!rows.Length)
        s .= "nothing on the list`n"
    live := 0, done := 0, lines := ""
    for h in Habits {
        if (StrCompare(day, h.born) < 0)
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
        t := (day = CurDay) ? DayTimeText() : (PastTime.Has(day) ? PastTime[day] : "")
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
    else if (r.list = "S")
        s .= "  " Chr(0x00B7) " short term"
    if (r.status = "open" && r.carry > 0)     ; days it had already been left undone
        s .= "  " Chr(0x00B7) " carried " Chr(0xD7) r.carry
    if (r.note != "")
        s .= "  " Chr(0x2014) " " r.note
    return s
}

; What was on that day's list, as {text, status, list, carry, note}. Today is
; read from the live list: everything on Today, a short term task on its
; deadline day, and a long term task only if it was finished today. An
; earlier day is read from what CloseDay() kept of it.
DayTasks(day) {
    out := []
    if (day = CurDay) {
        for want in ["T", "S", "L"]
            for t in Tasks
                if (t.list = want && (want = "T" || t.doneOn = day
                    || (want = "S" && t.due = day)))
                    out.Push(Rec({text: t.text, status: t.status, list: t.list
                            , carry: t.carry, note: TaskNote(t, day)}))
    } else {
        for r in Past
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
    for a in TopApps(8)
        tops .= (tops != "" ? " " Chr(0x00B7) " " : "") a.exe " " HumanTime(a.sec)
    if (tops != "")
        s .= "`n" tops "`n"
    strip := HourStrip()                 ; indented, so markdown keeps it monospaced
    if (strip != "")
        s .= "`n" strip
    return s
}
