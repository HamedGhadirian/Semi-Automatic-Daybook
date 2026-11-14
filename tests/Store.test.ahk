; Store.test.ahk - Daybook-state.txt, written and read back
;
; It checks the thing a state file has to do and nothing else: tasks, two
; habits with history and one without, the finished days - and every field the
; same on the way out as it was on the way in. Then the safety: the end line,
; the daily backup, a broken file set aside. The state file and its backups
; are in the harness's scratch folder.
#Requires AutoHotkey v2.0
#Include %A_LineFile%\..\Harness.ahk

global bk := T_Dir "\backups"
CurDay := "2026-09-20", SitSec := 1234

Tasks.Push(Rec({list: "T", text: "a task with, commas", status: "open", carry: 2
          , born: "2026-09-18", due: "", asked: 0, id: 7, notes: DayMap()}))
NextTaskId := 9
Habits.Push(Rec({text: "read 20 pages", born: "2026-09-01", streak: 12, best: 30
           , total: 143, done: ["2026-09-20", "2026-09-19", "2026-09-17"], rest: [], kind: "D", n: 1}))
Habits.Push(Rec({text: "workout", born: "2026-09-15", streak: 0, best: 2
           , total: 4, done: [], kind: "W", n: 3, rest: ["2026-09-18", "2026-09-16"], unit: "D"}))
Tasks.Push(Rec({list: "M", text: "missed one", status: "open", carry: 3
          , born: "2026-09-15", due: "", asked: 0, id: 8, since: "2026-09-17", notes: DayMap()}))
Tasks[1].notes["2026-09-20"] := "a note, with commas"
Tasks[1].doneOn := "2026-09-20"
Past.Push(Rec({day: "2026-09-19", id: 5, list: "T", status: "failed", carry: 1
         , note: "shop was closed", text: "fix the bike"}))
Past.Push(Rec({day: "2026-09-19", id: 6, list: "L", status: "done", carry: 0
         , note: "", text: "make a game"}))
PastTime["2026-09-19"] := "active 2h 5m`n`nck3 1h`n`n       14  " Chr(0x2588) Chr(0x2588) Chr(0x2588) " ck3`n"
AppSec["chrome.exe"] := 99
HourSec["10"] := 60
SaveState()
Tasks := [], Habits := [], AppSec := DayMap(), HourSec := DayMap()
Past := [], PastTime := DayMap()
CurDay := "", SitSec := 0
LoadState()
Ok("day",   CurDay, "2026-09-20")
Ok("sit",   SitSec, 1234)
Ok("tasks", Tasks.Length, 2)
Ok("task text kept", Tasks[1].text, "a task with, commas")
Ok("habits", Habits.Length, 2)
h := Habits[1]
Ok("habit text",   h.text,   "read 20 pages")
Ok("habit born",   h.born,   "2026-09-01")
Ok("habit streak", h.streak, 12)
Ok("habit best",   h.best,   30)
Ok("habit total",  h.total,  143)
Ok("habit days",   h.done.Length, 3)
Ok("day order",    h.done[1], "2026-09-20")
Ok("last day",     h.done[3], "2026-09-17")
Ok("streak is a number", h.streak + 1, 13)
g := Habits[2]
Ok("empty history", g.done.Length, 0)
Ok("second name",   g.text, "workout")
Ok("rule kept",     g.kind " " g.n, "W 3")
Ok("counted in days kept", g.unit, "D")
Ok("and weeks by default", h.unit, "W")
Ok("rest days kept", g.rest.Length " " g.rest[2], "2 2026-09-16")
Ok("a habit with no rule line is every day", h.kind " " h.n, "D 1")
Ok("missed kept",   Tasks[2].list " " Tasks[2].carry, "M 3")
Ok("since kept",    Tasks[2].since, "2026-09-17")
Ok("a carried Today task stays on Today", Tasks[1].list, "T")
Ok("note kept",     Tasks[1].notes["2026-09-20"], "a note, with commas")
Ok("done on kept",  Tasks[1].doneOn, "2026-09-20")
Ok("past kept",     Past.Length, 2)
Ok("past note",     Past[1].note, "shop was closed")
Ok("past status",   Past[1].status, "failed")
Ok("past empty note stays empty", Past[2].note, "")
Ok("past text after an empty note", Past[2].text, "make a game")
Ok("day's time kept, lines and all", PastTime["2026-09-19"] == "active 2h 5m`n`nck3 1h`n`n       14  " Chr(0x2588) Chr(0x2588) Chr(0x2588) " ck3`n" ? 1 : 0, 1)
Ok("app kept",      AppSec["chrome.exe"], 99)
Ok("task id kept",  Tasks[1].id, 7)
Ok("id counter kept", NextTaskId, 9)
Ok("a field it never had reads empty", Tasks[1].somethingNew, "")

; ---- a file from before ids -------------------------------------------------
; Seven fields and no tid line: every task gets an id, all different, and the
; counter ends up past them.
FileDelete(StateFile)
FileAppend("day`t2026-09-20`ntask`tT`topen`t0`t2026-09-18`t`tfirst`n"
     . "task`tL`topen`t0`t2026-09-18`t`tsecond`n", StateFile, "UTF-8")
Tasks := [], NextTaskId := 1
LoadState()
Ok("old: text still read", Tasks[2].text, "second")
Ok("old: ids handed out", (Tasks[1].id && Tasks[2].id && Tasks[1].id != Tasks[2].id) ? 1 : 0, 1)
Ok("old: counter past them", NextTaskId > Tasks[2].id ? 1 : 0, 1)

; ---- a file from before MISSED ----------------------------------------------
; A carried task was still on Today's list, and a review line asked about it.
; It moves to MISSED once, waiting since the day it was added; the review line
; is dropped; a task added that day stays where it is.
FileDelete(StateFile)
FileAppend("daybook-state`t2`nday`t2026-09-20`n"
    . "task`tT`topen`t2`t2026-09-17`t`tcarried twice`t1`t`n"
    . "task`tT`topen`t0`t2026-09-20`t`tadded today`t2`t`n"
    . "task`tT`tdone`t1`t2026-09-18`t`tcarried and done`t3`t2026-09-20`n"
    . "review`tcarried twice`t2026-09-19`t1`nend`t6`n", StateFile, "UTF-8")
Tasks := [], NextTaskId := 1
LoadState()
Ok("v2: the carried task is missed",     Tasks[1].list, "M")
Ok("  since the day it was added",       Tasks[1].since, "2026-09-17")
Ok("  its count kept",                   Tasks[1].carry, 2)
Ok("  today's own stays on Today",       Tasks[2].list, "T")
Ok("  a carried one already done stays", Tasks[3].list, "T")
SaveState()
s := FileRead(StateFile, "UTF-8")
Ok("  the review line is gone",          InStr(s, "`nreview`t") ? 1 : 0, 0)
Ok("  and the file says it is version 3", SubStr(s, 1, 16), "daybook-state`t3`n")
; once only: a task brought back to Today and carried again is not moved again
; by a load - that is CloseDay's call, not the reader's
Tasks[1].list := "T"
SaveState()
Tasks := []
LoadState()
Ok("v3: a carried Today task is left alone", Tasks[1].list, "T")
Tasks := [Tasks[1]], Tasks[1].list := "T", Tasks[1].text := "first"

; ---- the version before reads a new file -----------------------------------
; It splits on tabs and takes field 7 as the text; the id after it must not
; change what that sees.
SaveState()
s := FileRead(StateFile, "UTF-8")
RegExMatch(s, "m`n)^task\t.*$", &line)     ; `n: the file ends its lines in `n alone
Ok("new file, old reader: text is field 7", StrSplit(line[0], "`t")[7], "first")

; ---- the same file the v1 Daybook writes, byte for byte ----------------------
raw := FileRead(StateFile, "RAW")
Ok("a BOM first, as v1 wrote it", NumGet(raw, 0, "uchar") "," NumGet(raw, 1, "uchar") "," NumGet(raw, 2, "uchar"), "239,187,191")
Ok("lines end in LF alone, as v1 wrote them", InStr(s, "`r") ? 1 : 0, 0)

;================================================================================
; Keeping it safe
;================================================================================
s := FileRead(StateFile, "UTF-8")
Ok("the file says where it ends",    RegExMatch(s, "\nend\t\d+\n$") ? 1 : 0, 1)
Ok("  and so it reads as whole",     StateValid(s) ? 1 : 0, 1)
Ok("cut short, it does not",         StateValid(SubStr(s, 1, StrLen(s) // 2)) ? 1 : 0, 0)
Ok("cut before its end line",        StateValid(RegExReplace(s, "end\t\d+\n$")) ? 1 : 0, 0)
Ok("a line lost in the middle",      StateValid(RegExReplace(s, "m`n)^sit\t.*\n")) ? 1 : 0, 0)
Ok("an old file with no end line",   StateValid("day`t2026-09-20`nsit`t5`n") ? 1 : 0, 1)
Ok("nothing at all",                 StateValid("") ? 1 : 0, 0)

; a backup a day, of the file as it stood, and only one
today := FormatTime(, "yyyy-MM-dd")
Ok("the first save today backed it up", FileExist(bk "\Daybook-state-" today ".txt") ? 1 : 0, 1)
t1 := FileGetTime(bk "\Daybook-state-" today ".txt")
SaveState()
t2 := FileGetTime(bk "\Daybook-state-" today ".txt")
Ok("later saves leave today's alone",   t1 = t2 ? 1 : 0, 1)

; a file that will not read is set aside and the newest good backup loaded
try FileDelete(bk "\*.txt")
good := "daybook-state`t2`nday`t2026-09-18`nsit`t0`ntask`tT`topen`t0`t2026-09-18`t`tfrom the backup`t1`t`nend`t4`n"
DirCreate(bk)
FileAppend(good, bk "\Daybook-state-2026-09-18.txt", "UTF-8")
FileAppend("not a state file", bk "\Daybook-state-2026-09-19.txt", "UTF-8")
FileDelete(StateFile)
FileAppend(SubStr(s, 1, 40), StateFile, "UTF-8")      ; cut short
Tasks := [], Habits := [], CurDay := ""
LoadState()
Ok("unreadable: the newest GOOD backup is loaded", Tasks.Length " " Tasks[1].text, "1 from the backup")
Ok("  the day with it",                             CurDay, "2026-09-18")
aside := 0, keptBad := ""
loop files T_Dir "\Daybook-state.unreadable-*.txt"
    aside++, keptBad := A_LoopFileFullPath
Ok("  the broken file is kept, not saved over",     aside, 1)
Ok("  and it is exactly what it was",               FileRead(keptBad, "UTF-8") == SubStr(s, 1, 40) ? 1 : 0, 1)
FileDelete(keptBad)

; a file that could not be read OR set aside: nothing may be saved over it
before := FileExist(StateFile) ? FileRead(StateFile, "UTF-8") : "none"
StateNoSave := 1
Tasks := [], Habits := []
SaveState()
Ok("refusing to save leaves the file as it was", (FileExist(StateFile) ? FileRead(StateFile, "UTF-8") : "none") == before ? 1 : 0, 1)
StateNoSave := 0

; the backups kept: the newest 10, and the oldest of each of the last 6 months
try FileDelete(bk "\*.txt")
DirCreate(bk)
for d in ["2026-01-05", "2026-02-03", "2026-02-20", "2026-03-01", "2026-04-02", "2026-05-06"
        , "2026-06-01", "2026-06-15", "2026-07-01", "2026-08-01", "2026-09-01", "2026-09-02"
        , "2026-09-03", "2026-09-04", "2026-09-05", "2026-09-06", "2026-09-07", "2026-09-08"
        , "2026-09-09", "2026-09-10"]
    FileAppend("x", bk "\Daybook-state-" d ".txt")
StatePrune()
left := ""
for n in StateBackups()
    left .= SubStr(n, 15, 10) " "
Ok("pruned to 10 newest + 6 month-firsts"
  , Trim(left), "2026-04-02 2026-05-06 2026-06-01 2026-07-01 2026-08-01 2026-09-01 2026-09-02"
  . " 2026-09-03 2026-09-04 2026-09-05 2026-09-06 2026-09-07 2026-09-08 2026-09-09 2026-09-10")

;================================================================================
; The panel's own place in Daybook.ini
;================================================================================
IniWrite(1, IniFile, "Saved", "ClickThru")          ; an .ini from before PanelMode
IniWrite(1, IniFile, "Saved", "OpenLater")          ; ... and from before LONG TERM
LoadIni()
Ok("ini: the old ClickThru is GHOST",  PanelMode, 2)
Ok("ini: the old OpenLater opens LONG TERM", OpenLong, 1)
Ok("ini: no place yet - the right of the screen", PanelX, A_ScreenWidth - PanelW - 24)
IniWrite(0, IniFile, "Saved", "PanelMode")
IniWrite(40, IniFile, "Saved", "X")
LoadIni()
Ok("ini: the new key wins",            PanelMode " " PanelX, "0 40")

Done()
