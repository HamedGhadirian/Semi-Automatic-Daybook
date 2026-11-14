;================================================================================
; Tasks
;================================================================================
; Every task has an id, a number it keeps for life. The panel never shows it;
; it is what lets a finished day's record (Past) and a note say "this is that
; task" after the words on it have changed. Never reused, so a line left over
; from a task deleted long ago can never be mistaken for a new one.
#Requires AutoHotkey v2.0

; Tasks[i], or "" when there is no such place in the list - a click on a row
; whose task went a moment ago, a menu opened for one that was deleted since.
TaskAt(i) => (IsInteger(i) && i >= 1 && i <= Tasks.Length) ? Tasks[i] : ""

AddTask(text, list := "T", status := "open", due := "") {
    global NextTaskId
    text := Trim(RegExReplace(text, "[\r\n\t]+", " "))
    if (text = "")
        return
    CommitMark()                     ; anything pending belongs to another task
    Tasks.Push(Rec({list: list, text: text, status: status, carry: 0
              , born: LogicalDay(), due: (list = "S") ? due : "", asked: 0, id: NextTaskId++
              , notes: DayMap(), doneOn: (status = "open") ? "" : CurDay, since: ""}))
    SaveState()
    Refresh()
    ; The line is not written yet - see CommitMark(). Held for MarkDelayMs, it
    ; absorbs a typo fix or a delete made in the next few seconds.
    PendMark("T", Tasks.Length, (status = "done") ? "unplanned" : "add")
}

; Renaming inside the grace window costs nothing: the task's line has not been
; written, and CommitMark() builds it from the CURRENT text, so a typo fixed
; seconds after typing it leaves no trace of the typo at all.
;
; Past the window the old name is already on disk. The log is append-only -
; that is what makes it crash-proof - so the honest move is to record the
; change rather than pretend it never happened.
;
; == and not =, which ignores case: "buy Milk" to "buy milk" is a rename too.
RenameTask(i, newText) {
    newText := Trim(RegExReplace(newText, "[\r\n\t]+", " "))
    t := TaskAt(i)
    if (!t || newText = "" || newText == t.text)
        return
    old := t.text
    t.text := newText
    SaveState()
    Refresh()
    if (PendMarkKind = "T" && PendMarkTask = i)
        return
    Journal("~ renamed: " old "   " Chr(0x2192) "   " newText)
}

; Move a task to Today or Long term. It starts that list clean: the xN in front
; of a MISSED task is days left undone ON THE LIST IT FAILED ON, and a task
; parked for the long term has not failed at anything - so it moves with its
; count and its deadline cleared. (Moving it back to Today and missing it again
; starts the count over, which is the honest reading of it.)
TaskMoveTo(i, list) {
    t := TaskAt(i)
    if (!t || t.list = list)
        return
    CommitMark()                     ; indexes are about to be read again
    t.list := list, t.carry := 0, t.since := "", t.due := ""
    SaveState()
    Refresh()
    Journal(Chr(0x2192) " moved to " (list = "L" ? "long term" : "today") ": " t.text)
}

; A task onto the short term list, or a new deadline for one already there. due
; is a day, yyyy-MM-dd - or "" for no deadline at all: the task waits on the
; list and never goes to MISSED by itself.
TaskSetDue(id, due) {
    i := TaskIndex(id)
    if (!i)
        return
    t := Tasks[i]
    if (t.list = "S" && t.due = due)     ; nothing changes: no journal line
        return
    CommitMark()
    was := (t.list = "S") ? t.due : ""
    t.list := "S", t.due := due, t.carry := 0, t.since := ""
    SaveState()
    Refresh()
    Journal(Chr(0x2192) " short term, " ((due != "") ? "due " due : "no deadline")
        . ((was != "") ? " (was " was ")" : "") ": " t.text)
}

; doneOn is the day it was ticked or crossed, which is what puts a LONG TERM
; task into that day's note: it was not on the day's list, but it was finished
; that day.
SetStatus(i, status) {
    t := TaskAt(i)
    if (!t)
        return
    t.status := status
    t.doneOn := (status = "open") ? "" : CurDay
    SaveState()
    Refresh()
}

;================================================================================
; Notes
;================================================================================
; A note belongs to a task AND a day: "shop was closed" is about Tuesday, and
; if the same task is carried to Wednesday and done, Wednesday gets its own. So
; a task keeps notes as day -> text, and CloseDay() moves the finished day's
; into Past with the rest of that day.
;
; The hover shows today's, right-click edits it, and the day's note in
; Obsidian carries it beside the task it is about.
TaskNote(t, day) {
    return (IsObject(t.notes) && t.notes.Has(day)) ? t.notes[day] : ""
}

; Set, change or - with "" - remove the note on a task for a day. The day may
; be over: an answer to "why not?" given the next morning belongs to the day
; before, and that day's note is rewritten to carry it.
TaskSetNote(id, day, text) {
    text := Trim(RegExReplace(text, "[\r\n\t]+", " "))
    i := TaskIndex(id)
    if (i) {
        t := Tasks[i]
        if (!IsObject(t.notes))
            t.notes := DayMap()
        if (text = "") {
            if t.notes.Has(day)
                t.notes.Delete(day)
        } else
            t.notes[day] := text
    }
    for r in Past
        if (r.id = id && r.day = day)
            r.note := text
    SaveState()
    Refresh()
    if (day != CurDay)
        DayNoteWrite(day, true)
}

; Added and dropped inside the grace window: it never happened, so nothing is
; written at all - not the add, not the drop. Otherwise flush whatever was
; pending (it belongs to a different task) and record the drop. Either way
; nothing stays pending, which matters: RemoveAt shifts every index above it
; and a pending one would then point at the wrong task.
DeleteTask(i) {
    t := TaskAt(i)
    if (!t)
        return
    if (!CancelMark("T", i)) {
        CommitMark()
        Journal("- dropped: " t.text)
    }
    Tasks.RemoveAt(i)
    SaveState()
    Refresh()
}

; Where the task with this id is in Tasks right now, or 0.
TaskIndex(id) {
    if (!id)
        return 0
    for i, t in Tasks
        if (t.id = id)
            return i
    return 0
}
