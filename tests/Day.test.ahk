; Day.test.ahk - a whole day in Obsidian: the note, the board, the close
;
; Loads the real lib\Day.ahk, Journal.ahk, Board.ahk, Tasks.ahk, Habits.ahk and
; Log.ahk, and writes real notes into tests\journal\day\. The panel is stubbed;
; SaveState does what the real one does for Obsidian and nothing else. Runs on
; the real calendar - yesterday is the day being lived, today the one it rolls
; into - so it is the real RollIfNeeded() that closes it.
;
; Run it with run-tests.ps1 in this folder, or on its own.
#NoEnv
#SingleInstance off
SetBatchLines -1

global DayStartHour := 3, HabitKeep := 372, HabitDays := 7, PastKeepDays := 42
global JournalOn := 1, BoardOn := 1, JournalDir := A_ScriptDir "\journal\day"
global Tasks := [], Habits := [], Past := [], PastTime := {}, NoteFor := ""
global CurDay := "", NextTaskId := 1
global AppSec := {}, HourSec := {}, LogApps := 1, SampleMs := 30000, StatsTop := 8
global SitSec := 0, AwaySec := 0, CutShort := 0
global PendMarkKind := "", PendMarkTask := 0
global CGreen := "0", CAmber := "0", CRed := "0", CTrack := "0", CDim := "0"
global Fails := 0, Log := ""
global StateFile := A_ScriptDir "\journal\day-state.txt"   ; backups\notes goes beside it

SaveState() {
    BoardWrite()
    DayNoteWrite(CurDay)
}
Refresh() {
}
CommitMark() {
}
CancelMark(kind, i) {
    return false
}
PendMark(kind, i, status) {
}
Present() {
    return true
}
; the note box: remembered, so a test can say what it was asked
global Asked := ""
ShowNote(header, rowY := 0, prefill := "", hint := "") {
    global Asked
    Asked := header
}
OpenNote(i, mode, rowY := 0) {
    global Asked
    Asked := "note " mode
}
; the journal window's surroundings - only its file parts are tested here
global NoteBusy := 0
LivePanel(ByRef x, ByRef y, ByRef w, ByRef h) {
}
ClampWin(ByRef x, ByRef y, w, h) {
}
TaskbarId(hwnd, id) {
}
SetupDark(hwnd) {
}
ShapeWindow(hwnd, round) {
}

#Include %A_ScriptDir%\..\lib\Day.ahk
#Include %A_ScriptDir%\..\lib\Journal.ahk
#Include %A_ScriptDir%\..\lib\Board.ahk
#Include %A_ScriptDir%\..\lib\Tasks.ahk
#Include %A_ScriptDir%\..\lib\Habits.ahk
#Include %A_ScriptDir%\..\lib\Log.ahk

Ok(name, got, want) {
    global Fails, Log
    if (got . "" = want . "")
        Log .= "  ok   " name "`n"
    else
        Log .= "  FAIL " name ": got [" got "] want [" want "]`n", Fails += 1
}
Has(name, hay, needle) {
    Ok(name, InStr(hay, needle, true) ? 1 : 0, 1)
}
Hasnt(name, hay, needle) {
    Ok(name, InStr(hay, needle, true) ? 1 : 0, 0)
}
Count(hay, needle) {
    StrReplace(hay, needle, needle, n)
    return n
}
; What SaveNote does with Enter, without the box.
SaveNote_(id, day, txt) {
    TaskSetNote(id, day, txt)
}
Note(day) {
    FileRead, s, % "*P65001 " JournalFile(day)
    return s
}
Put(day, s) {
    f := JournalFile(day)
    FileDelete, %f%
    FileAppend, %s%, *%f%, UTF-8
}

FileRemoveDir, %JournalDir%, 1
FileCreateDir, %JournalDir%
today := LogicalDay()
yday  := DayShift(today, -1)
d2    := DayShift(today, -2)
tick  := Chr(0x2713), cross := Chr(0x2717), box := Chr(0x2610), dash := Chr(0x2014)
dot   := Chr(0x00B7)

; ---- a day being lived -------------------------------------------------------
CurDay := yday
AddTask("buy milk")
AddTask("call mom")
AddTask("fix the bike")
AddTask("make a game", "L")
HabitAdd("painting")
HabitAdd("exercise")
Habits[1].born := d2, Habits[2].born := d2
SetStatus(1, "done")
TaskSetNote(Tasks[1].id, yday, "got the oat one")
SetStatus(3, "failed")
SetStatus(4, "done")
AppSec := {"ck3": 3600}, HourSec := {"14|ck3": 3600}   ; rides along with the next change
HabitSetDay(1, yday)
f := Note(yday)
Has("note: made with its heading",   f, "# " yday "`n`n## journal`n")
Has("block: starts with its marker", f, "%% daybook:")
Has("block: a task with its note",   f, "- " tick " buy milk  " dash " got the oat one`n")
Has("block: crossed",                f, "- " cross " fix the bike`n")
Has("block: still open",             f, "- " box " call mom`n")
Has("block: long term done that day", f, "- " tick " make a game  " dot " long term`n")
Has("block: habit count",            f, "1 of 2 done")
Has("block: habit with its run",     f, "- " tick " painting  " dot " 1 in a row`n")
Has("block: habit not done",         f, "- " box " exercise`n")
Has("block: time",                   f, "### time at the machine`n`nactive 1h 0m")
Has("block: ends with its marker",   f, "%% /daybook %%")

; ---- your writing, above and below, is never touched ------------------------
f := StrReplace(f, "## journal`n`n`n", "## journal`n`nA long day. I liked it.`n`n")
f .= "`nPS written under the block`n"
Put(yday, f)
SetStatus(2, "done")
f := Note(yday)
Has("rewritten: the change is in",   f, "- " tick " call mom`n")
Ok("your words above, once",         Count(f, "A long day. I liked it."), 1)
Ok("your words below, once",         Count(f, "PS written under the block"), 1)
Ok("one block, not two",             Count(f, "%% daybook:"), 1)

; ---- the time alone does not rewrite a note you may be typing in ------------
AppSec["ck3"] := 7200
SaveState()
Has("time alone: not rewritten yet", Note(yday), "active 1h 0m")
SetStatus(2, "open")
f := Note(yday)
Has("time rides along with a real change", f, "active 2h 0m")

; ---- the day closes -----------------------------------------------------------
RollIfNeeded()
Ok("rolled to today",                CurDay, today)
Ok("only the unfinished stay",       Tasks.Length(), 1)
Ok("and it is the open one",         Tasks[1].text, "call mom")
Ok("carried",                        Tasks[1].carry, 1)
Ok("the day is kept",                Past.Length(), 4)
Ok("the open one is missed",         Tasks[1].list, "M")
Ok("  since the day it was meant for", Tasks[1].since, yday)
mom := Tasks[1].id
f := Note(yday)
Has("closed note: still open",       f, "- " box " call mom`n")
Has("closed note: time kept",        f, "active 2h 0m")
Ok("closed note: your words still once", Count(f, "A long day. I liked it."), 1)
t := Note(today)
Has("today's note made",             t, "# " today "`n`n## journal")
Hasnt("today: a missed task is not on today's list", t, "call mom")
Hasnt("today: not yesterday's done", t, "buy milk")

; ---- the board shows it waiting ----------------------------------------------
b := ""
FileRead, b, % "*P65001 " JournalDir "\Daybook.md"
Has("board: missed, and since when", b, "## missed`n`n- " box " call mom  " dot " missed yesterday  " dot " " Chr(0xD7) "1`n")

; ---- back onto Today: one question, and the answer goes onto yday -----------
MissToToday(1)
Ok("back on today",                  Tasks[1].list, "T")
Has("  asked why, about yesterday",  Asked, "not done yesterday - why?")
Ok("  it is still carried",          Tasks[1].carry, 1)
SaveNote_(mom, yday, "ran out of time")
f := Note(yday)
Has("answer on yesterday's line",    f, "- " box " call mom  " dash " ran out of time`n")
Ok("and your words are still there", Count(f, "A long day. I liked it."), 1)
Hasnt("not on today's",              Note(today), "ran out of time")

; ---- a note today, edited, then taken away -----------------------------------
TaskSetNote(Tasks[1].id, today, "ring after six")
Has("today: note on the task",       Note(today), "- " box " call mom  " dot " carried " Chr(0xD7) "1  " dash " ring after six`n")
TaskSetNote(Tasks[1].id, today, "")
Hasnt("today: note taken away",      Note(today), "ring after six")

; ---- the board ---------------------------------------------------------------
b := ""
FileRead, b, % "*P65001 " JournalDir "\Daybook.md"
Has("board: today",                  b, "## today`n`n- " box " call mom  " dot " carried")
Has("board: long term, empty",       b, "## long term`n`nnothing here`n")
Has("board: streaks",                b, "| painting | ")
Has("board: two weeks",              b, "### the last two weeks")
Hasnt("board: no checkboxes to click", b, "- [ ]")

; ---- a note from before this version is left exactly as it is -------------
old := "# " d2 "`n`n10:00  + added: something`n"
Put(d2, old)
HabitSetDay(2, d2)
Ok("old note untouched by a late tick", Note(d2) == old ? 1 : 0, 1)
DayNoteWrite(d2, true)
Ok("old note untouched by a rewrite",   Note(d2) == old ? 1 : 0, 1)

; ---- a late tick rewrites the day it belongs to ------------------------------
HabitSetDay(2, yday)
; the day before it was ticked just above, so the run that day was two
Has("late tick in yesterday's note", Note(yday), "- " tick " exercise  " dot " 2 in a row`n")
Has("and the count with it",         Note(yday), "2 of 2 done")

; ---- journal off: nothing is written -----------------------------------------
JournalOn := 0
before := Note(today)
AddTask("while off")
Ok("journal off: today's note unchanged", Note(today) == before ? 1 : 0, 1)
JournalOn := 1

; ---- a note read short is never written back --------------------------------
cut := "# " yday "`n`n## my notes`n`nhalf a thought`n`n%% daybook: written by Daybook and rewr"
Put(yday, cut)
TaskSetNote(mom, yday, "a later answer")     ; wants to rewrite it
Ok("cut note: left exactly as found", Note(yday) == cut ? 1 : 0, 1)
Ok("the note was copied aside before Daybook first touched it"
  , FileExist(A_ScriptDir "\journal\backups\notes\" yday ".md") ? 1 : 0, 1)

; ---- did it, on an earlier day -------------------------------------------------
; Put back as it was: missed since yday, and the note there whole again.
Put(yday, "# " yday "`n`n## my notes`n`nA long day. I liked it.`n`n" DayMarkStart() "`n" DayMarkEnd() "`n")
DayNoteWrite(yday, true)
i := TaskIndex(mom), Tasks[i].list := "M", Tasks[i].since := yday
MissDone(mom, yday)
Ok("done on yday: off the panel",    TaskIndex(mom), 0)
Has("  and ticked in yday's note",   Note(yday), "- " tick " call mom")
Has("  the box asks about that day", Asked, "done yesterday")
SaveNote_(mom, yday, "did it after all")
Has("  its note lands there",        Note(yday), "- " tick " call mom  " dash " did it after all`n")

; ---- did it today -------------------------------------------------------------
CurDay := today
AddTask("post the letter")
k := Tasks.Length(), lid := Tasks[k].id
Tasks[k].list := "M", Tasks[k].since := yday, Tasks[k].carry := 1
MissDone(lid, today)
Ok("done today: on Today's list, ticked", Tasks[k].list " " Tasks[k].status, "T done")
Ok("  the usual note box",           Asked, "note done")

; ---- dropped: Esc keeps it, Enter drops it with its reason ------------------
AddTask("paint the fence")
k := Tasks.Length(), fid := Tasks[k].id
Tasks[k].list := "M", Tasks[k].since := yday, Tasks[k].carry := 1
Past.Push({day: yday, id: fid, list: "T", status: "open", carry: 0, note: "", text: "paint the fence"})
MissDropAsk(k)
Ok("drop asks first",                NoteFor.drop ? 1 : 0, 1)
NoteFor := ""                        ; Esc
Ok("  Esc keeps it",                 TaskIndex(fid) ? 1 : 0, 1)
MissDropNow(fid, yday, "rained all week")
Ok("  Enter drops it",               TaskIndex(fid), 0)
Has("  crossed on the day it was meant for, with why", Note(yday), "- " cross " paint the fence  " dash " rained all week`n")

; ---- a missed task waits, and its count goes up with the days --------------
AddTask("sort the photos")
k := Tasks.Length(), pid := Tasks[k].id
CurDay := d2                         ; pretend today's list was two days ago
RollIfNeeded()
i := TaskIndex(pid)
Ok("two days gone: missed, x2",      Tasks[i].list " " Tasks[i].carry, "M 2")
Ok("  since the day it was on",      Tasks[i].since, d2)

; ---- old days are let go -----------------------------------------------------
Past.Push({day: DayShift(today, -60), id: 99, list: "T", status: "done", carry: 0, note: "", text: "long ago"})
PastTime[DayShift(today, -60)] := "x"
PastPrune()
gone := 1
for _, r in Past
    if (r.id = 99)
        gone := 0
Ok("pruned: the record",   gone, 1)
Ok("pruned: its time",     PastTime.HasKey(DayShift(today, -60)) ? 0 : 1, 1)
Ok("kept: yesterday",      PastTime.HasKey(yday) ? 1 : 0, 1)

;================================================================================
; The journal window's reading and writing (no window - its parts)
;================================================================================
j1 := DayShift(today, -100), j2 := DayShift(today, -101), j3 := DayShift(today, -102)
blk := DayMarkStart() "`n## the day`n" DayMarkEnd() "`n"

; a note from before 1.1: the old heading is found, the body is what is under it
old := "# " j1 "`n`n## my notes`n`nhello`n- a`n`n" blk
Put(j1, old)
r := JrnRead(j1)
Ok("journal: old heading read",      r.body, "hello`n- a")
Ok("journal: the head ends at it",   SubStr(r.head, -10), "## my notes")
Ok("journal: unchanged goes back as it was", JrnCompose(r, j1, r.body) == old ? 1 : 0, 1)
Put(j1, JrnCompose(r, j1, "hello`n- a`n- b"))
f := Note(j1)
Has("journal: new body in place",    f, "## my notes`n`nhello`n- a`n- b`n`n%% daybook:")
Ok("journal: block still once",      Count(f, "%% daybook:"), 1)
Ok("journal: words",                 JrnWords(j1), 3)

; no note yet: made in the shape a new day gets
r := JrnRead(j2)
Ok("journal: no note",               r.exists ? 1 : 0, 0)
Ok("journal: a new note",            JrnCompose(r, j2, "first words"), "# " j2 "`n`n## journal`n`nfirst words`n")

; CRLF stays CRLF; a title and no heading: the rest of the top is the body
Put(j3, "# " j3 "`r`n`r`nsome text`r`n`r`n" StrReplace(blk, "`n", "`r`n"))
r := JrnRead(j3)
Ok("journal: title only, body",      r.body, "some text")
out := JrnCompose(r, j3, "some text`nmore")
Has("journal: CRLF kept",            out, "some text`r`nmore`r`n`r`n%% daybook:")
Hasnt("journal: no bare LF",         StrReplace(out, "`r`n"), "`n")

; read short - a marker and no end - is reported, so it is never saved over
Put(j3, "# " j3 "`n`n## journal`n`nhalf`n`n%% daybook: written by")
Ok("journal: short read seen",       JrnRead(j3).short ? 1 : 0, 1)

; Daybook's own writers raise the flag, and lower it again
Ok("journal: NoteBusy down after a write", NoteBusy ? 1 : 0, 0)

FileDelete, %A_ScriptDir%\results-Day.txt
FileAppend, % (Fails ? Fails " FAILED`n" : "all passed`n") Log
    , %A_ScriptDir%\results-Day.txt, UTF-8
ExitApp

; last: it has a menu label, which would end the auto-execute section above
#Include %A_ScriptDir%\..\lib\Missed.ahk
#Include %A_ScriptDir%\..\lib\JournalWin.ahk
