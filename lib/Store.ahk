;================================================================================
; Persistence - Daybook-state.txt, and keeping it safe
;================================================================================
; Everything that matters is in one plain-text file beside the script: the
; tasks and their notes, every habit with its WHOLE history and its rule, the
; finished days, the day's time. Everything else - the notes in Obsidian, the
; board - is written from it, and can be written again.
;
; So it is guarded the way Vocab guards words.json:
;
;   - A SAVE CANNOT LEAVE HALF A FILE. It is written to Daybook-state.txt.tmp,
;     read back and checked, and only then moved over the real one. A full
;     disk, a crash or a locked file mid-save leaves the old file whole, and
;     the save is tried again at the next change or minute.
;   - THE FILE SAYS WHERE IT ENDS. Its last line is "end" and the number of
;     lines before it, so one cut short - by a crash, or a sync that stopped
;     halfway - is known for what it is instead of being half read.
;   - A BACKUP A DAY. Before the first save of a day the file as it stood is
;     copied to backups\Daybook-state-YYYY-MM-DD.txt: each one is the state at
;     the end of the last day it changed. Kept: the newest 10, and the oldest
;     of each of the last 6 months. Restoring by hand is copying one over
;     Daybook-state.txt while Daybook is closed.
;   - A FILE THAT CANNOT BE READ IS NEVER SAVED OVER. It is moved aside as
;     Daybook-state.unreadable-<when>.txt, the newest backup that reads is
;     loaded in its place, and the tray says so.
;
; The file is the same in the v1 and the v2 Daybook, line for line.
;================================================================================
#Requires AutoHotkey v2.0

;================================================================================
; Records
;================================================================================
; A task, a habit, a finished day's line: an object whose missing fields read
; as "" - the way they always did in v1, where a state file from an older
; version simply has fewer of them. Asking HasProp still tells them apart.
class DayRec {
    __Get(name, params) => ""
}

Rec(o) {
    o.base := DayRec.Prototype
    return o
}

; arr[i], or "" when there is no such place - v1's arrays answered "" for one
At(arr, i) => (IsInteger(i) && i >= 1 && i <= arr.Length && arr.Has(i)) ? arr[i] : ""

; A table keyed by text that ignores case, the way v1's objects did, and
; answers "" for a key it does not have.
DayMap() {
    m := Map()
    m.CaseSense := "Off"
    m.Default := ""
    return m
}

;================================================================================
; Saving
;================================================================================
SaveState() {
    ; The first line says this file was written with an end line, so one that
    ; has it and not the end is known to be cut short. The version before skips
    ; a line it does not know. 3 is the first with a MISSED list - see LoadState.
    s := "daybook-state`t3`n"
    s .= "day`t" CurDay "`n"
    s .= "sit`t" SitSec "`n"
    s .= "tid`t" NextTaskId "`n"
    ; The id went on the END of a task line when ids arrived, after the text,
    ; so a file written now still reads correctly in the version before - that
    ; one stops at the text and never looks further. Text cannot hold a tab
    ; (AddTask and RenameTask take them out), so nothing can push it along.
    ; doneOn went after the id the same way, then since, and a task's notes
    ; each have a line of their own after it: tnote, id, day, text.
    for t in Tasks {
        s .= "task`t" t.list "`t" t.status "`t" t.carry "`t" t.born "`t" t.due "`t" t.text "`t" t.id "`t" t.doneOn "`t" t.since "`n"
        if IsObject(t.notes)
            for day, note in t.notes
                s .= "tnote`t" t.id "`t" day "`t" note "`n"
    }
    ; The name goes LAST on a habit line, so it is the only field that can
    ; contain anything - the days before it are a fixed shape.
    for h in Habits {
        days := ""
        for d in h.done
            days .= (days != "" ? "," : "") d
        s .= "habit`t" h.born "`t" h.streak "`t" h.best "`t" h.total "`t" days "`t" h.text "`n"
        ; How often, and the rest days, on a line of their own straight after:
        ; a habit line cannot grow past its name, and a line type the version
        ; before does not know is a line it skips.
        rests := ""
        for d in h.rest
            rests .= (rests != "" ? "," : "") d
        s .= "hrule`t" h.kind "`t" h.n "`t" rests "`t" (h.unit = "D" ? "D" : "W") "`n"
    }
    ; Finished days, for as long as they are kept - see CloseDay().
    for r in Past
        s .= "past`t" r.day "`t" r.id "`t" r.list "`t" r.status "`t" r.carry "`t" r.note "`t" r.text "`n"
    for day, txt in PastTime
        s .= "ptime`t" day "`t" StrReplace(txt, "`n", "\n") "`n"
    for exe, sec in AppSec
        s .= "app`t" exe "`t" sec "`n"
    for k, sec in HourSec
        s .= "hour`t" k "`t" sec "`n"
    StrReplace(s, "`n", "`n", , &lines)
    s .= "end`t" lines "`n"
    StateWrite(s)
    ; And the two things in Obsidian that show this state. Both write only if
    ; what they would write has changed, so calling them every save is cheap.
    BoardWrite()
    DayNoteWrite(CurDay)
}

; The file, through a temporary one that is read back before it replaces
; anything. No line-end translation, so what is read back is byte for byte
; what was meant.
StateWrite(s) {
    static warned := false
    if (StateNoSave)
        return false                     ; see StateReadOrRecover
    StateBackup()
    tmp := StateFile ".tmp"
    ok := false
    try {
        try FileDelete(tmp)
        FileAppend(s, tmp, "UTF-8")
        ok := (FileRead(tmp, "UTF-8") == s)
        if ok
            FileMove(tmp, StateFile, 1)
    } catch
        ok := false
    if (!ok) {
        ; Once, not every minute: the old file is whole and the next save tries
        ; again. What is in memory is not lost while Daybook runs.
        if (!warned)
            StateSay("Daybook could not save its state file - the last good one is"
                   . " untouched, and it will keep trying.")
        warned := true
        return false
    }
    warned := false
    return true
}

; Complete, or not. A file that starts with the "daybook-state" line must end
; with "end" and the number of lines before it - anything else was cut short.
; A file from before that line existed is taken as complete if it starts the
; way those always did: there is no way to tell more, and it is only ever the
; first load after an update.
StateValid(s) {
    s := RTrim(StrReplace(s, "`r"), "`n")
    if (s = "")
        return false
    if (SubStr(s, 1, 14) != "daybook-state`t")
        return SubStr(s, 1, 4) = "day`t"
    last := InStr(s, "`n", false, -1)
    if (!last || !RegExMatch(SubStr(s, last + 1), "^end\t(\d+)$", &m))
        return false
    StrReplace(SubStr(s, 1, last), "`n", "`n", , &n)
    return n = Integer(m[1])
}

; Before the first save of each day, the file as it stood - the state at the
; end of the last day anything changed. Only a file that reads is copied: a
; backup of a broken file would be no backup at all.
StateBackup() {
    static done := ""
    today := FormatTime(, "yyyy-MM-dd")
    if (done = today || !FileExist(StateFile))
        return                           ; no file yet: nothing to keep, ask again
    dir := StateBackupDir()
    dest := dir "\Daybook-state-" today ".txt"
    if (FileExist(dest)) {
        done := today
        return
    }
    try s := FileRead(StateFile, "UTF-8")
    catch
        return
    if !StateValid(s)
        return
    try {
        if !DirExist(dir)
            DirCreate(dir)
        FileCopy(StateFile, dest, 0)
    } catch
        return                           ; not done: the next save tries again
    done := today
    StatePrune()
}

StateBackupDir() {
    SplitPath(StateFile, , &dir)
    return dir "\backups"
}

; The backups' names, oldest first - the dates in them sort that way.
StateBackups() {
    list := ""
    loop files StateBackupDir() "\Daybook-state-*.txt"
        if (RegExMatch(A_LoopFileName, "^Daybook-state-\d{4}-\d\d-\d\d\.txt$"))
            list .= A_LoopFileName "`n"
    list := Sort(RTrim(list, "`n"))
    return (list = "") ? [] : StrSplit(list, "`n")
}

; The newest 10, and the oldest of each of the last 6 months: a mistake seen
; the same week and one seen months later can both be undone.
StatePrune() {
    names := StateBackups()
    keep := Map(), firsts := []
    for name in names
        if (!firsts.Length || SubStr(firsts[firsts.Length], 15, 7) != SubStr(name, 15, 7))
            firsts.Push(name)
    loop Min(names.Length, 10)
        keep[names[names.Length - A_Index + 1]] := 1
    loop Min(firsts.Length, 6)
        keep[firsts[firsts.Length - A_Index + 1]] := 1
    dir := StateBackupDir()
    for name in names
        if (!keep.Has(name))
            try FileDelete(dir "\" name)
}

; Said in the tray and in the log, because it matters and nobody is looking at
; a log.
StateSay(msg) {
    if (!StateQuiet)
        TrayTip(msg, "Daybook", 2 | 16)
    LogRaw("! " msg)
}

; The state file's text, or "" to start empty. A file that is there but does
; not read whole is moved aside - never saved over - and the newest backup that
; does read is used instead. A read that fails is tried three times first: a
; sync program can hold the file for a moment, and that is not damage.
StateReadOrRecover() {
    global StateNoSave
    if (!FileExist(StateFile))
        return ""
    loop 3 {
        try {
            s := FileRead(StateFile, "UTF-8")
            if StateValid(s)
                return s
        }
        Sleep(200)
    }
    SplitPath(StateFile, , &dir)
    bad := dir "\Daybook-state.unreadable-" FormatTime(, "yyyyMMdd-HHmmss") ".txt"
    try FileMove(StateFile, bad, 0)
    catch {
        try FileCopy(StateFile, bad, 0)
        catch {
            ; Could not be read, and could not be set aside either - most
            ; likely something is holding it. Then this run must not save:
            ; the next save would put an empty state over the only copy.
            StateNoSave := 1
            StateSay("The state file could not be read or set aside, so Daybook will"
                   . " not save anything this run - close it and start it again.")
            return ""
        }
    }
    names := StateBackups()
    k := names.Length
    while (k >= 1) {                     ; newest first
        try {
            s := FileRead(StateBackupDir() "\" names[k], "UTF-8")
            if StateValid(s) {
                StateSay("The state file could not be read. It was set aside as "
                       . bad " and the backup of " SubStr(names[k], 15, 10) " was loaded.")
                return s
            }
        }
        k--
    }
    StateSay("The state file could not be read, and there is no backup that can. It"
           . " was set aside as " bad " - nothing in it has been lost or overwritten.")
    return ""
}

; A field of a state line: the n-th, or "" when the line is shorter.
StateField(p, n) => (n <= p.Length) ? p[n] : ""

; A number in a state line, or 0 when it is not one.
StateNum(v) => IsNumber(v) ? Number(v) : 0

LoadState() {
    global CurDay, SitSec, NextTaskId
    s := StateReadOrRecover()
    if (s = "")
        return
    notes := [], ver := 0
    loop parse s, "`n", "`r" {
        if (A_LoopField = "")
            continue
        p := StrSplit(A_LoopField, "`t")
        f := (n) => StateField(p, n)
        switch p[1], true {
            case "daybook-state":
                ver := StateNum(f(2))
            case "day":
                CurDay := f(2)
            case "sit":
                SitSec := StateNum(f(2))
            case "tid":
                NextTaskId := StateNum(f(2))
            case "task":
                Tasks.Push(Rec({list: f(2), status: f(3), carry: StateNum(f(4)), born: f(5)
                          , due: f(6), text: f(7), asked: 0, notes: DayMap()
                          , id: StateNum(f(8)), doneOn: f(9), since: f(10)}))
            case "tnote":
                notes.Push({id: StateNum(f(2)), day: f(3), text: f(4)})
            case "past":
                Past.Push(Rec({day: f(2), id: StateNum(f(3)), list: f(4), status: f(5), carry: StateNum(f(6))
                         , note: f(7), text: f(8)}))
            case "ptime":
                PastTime[f(2)] := StrReplace(f(3), "\n", "`n")
            case "habit":
                days := []
                loop parse f(6), ","
                    if (A_LoopField != "")
                        days.Push(A_LoopField)
                Habits.Push(Rec({text: f(7), born: f(2), streak: StateNum(f(3)), best: StateNum(f(4))
                           , total: StateNum(f(5)), done: days, rest: [], kind: "D", n: 1, unit: "W"}))
            case "hrule":
                if !Habits.Length               ; belongs to the habit above
                    continue
                h := Habits[Habits.Length]
                h.kind := (f(2) = "W") ? "W" : "D", h.n := (StateNum(f(3)) >= 1) ? StateNum(f(3)) : 1
                h.unit := (f(5) = "D") ? "D" : "W"      ; weeks, unless it said days
                loop parse f(4), ","
                    if (A_LoopField != "")
                        h.rest.Push(A_LoopField)
            case "app":
                AppSec[f(2)] := StateNum(f(3))
            case "hour":
                HourSec[f(2)] := StateNum(f(3))
        }
    }
    ; A file from before ids has none, and a hand-edited one might have a
    ; counter behind its own tasks. Either way: every task gets one, and the
    ; next one handed out is past all of them.
    for t in Tasks
        if (t.id >= NextTaskId)
            NextTaskId := t.id + 1
    for t in Tasks
        if (!t.id)
            t.id := NextTaskId++
    ; notes last, once every task is in and has its id
    for n in notes
        if (i := TaskIndex(n.id))
            Tasks[i].notes[n.day] := n.text
    ; Before MISSED, a task left open stayed on Today's list with its carry
    ; count going up, and the "review" lines (now ignored) asked about it. Those
    ; move to MISSED once, as if they had always been there, waiting since the
    ; day they were added - the day they were meant for.
    if (ver < 3)
        for t in Tasks
            if (t.list = "T" && t.status = "open" && t.carry > 0)
                t.list := "M", t.since := (t.born != "" && StrCompare(t.born, CurDay) < 0) ? t.born
                                         : DayShift(CurDay, -1)
    ; and one saved half way through the change still has a day to answer for
    for t in Tasks
        if (t.list = "M" && t.since = "")
            t.since := DayShift(CurDay, -1)
    ; A long term task cannot have failed at anything, but one moved there from
    ; MISSED used to keep its xN. Cleared here, on the way in - every load, but
    ; after the first one there is nothing left to clear (nothing adds to a
    ; long term task's count any more).
    for t in Tasks
        if (t.list = "L" && t.carry)
            t.carry := 0
}

; The panel's own state lives under [Saved], below the settings. It used to be
; under [Panel], before the file held settings too. Whatever is still there -
; an older file - is moved across once and the old section removed.
LoadIni() {
    global PanelX, PanelY, OpenToday, OpenMissed, OpenLong, OpenShort, OpenStats
    global OpenHabits, PanelLocked, PanelOnTop, PanelMode
    old := CfgSection(IniFile, "Panel")
    for k, v in old
        if RegExMatch(k, "i)^(X|Y|OpenToday|OpenLater|OpenLong|OpenShort|OpenStats|OpenHabits|PanelMode|Locked|OnTop|ClickThru)$")
            try IniWrite(v, IniFile, "Saved", k)
    if (old.Count)
        try IniDelete(IniFile, "Panel")
    sv := (key, def) => CfgStr(IniFile, "Saved", key, def)
    on := (key, def) => (CfgNum(IniFile, "Saved", key, def) ? 1 : 0)
    PanelX      := sv("X", "")
    PanelY      := sv("Y", "")
    OpenToday   := on("OpenToday", 1)
    OpenMissed  := on("OpenMissed", 1)
    ; LATER TASKS became LONG TERM TASKS. An .ini written before that still says
    ; OpenLater, so the old key answers when the new one is not there - the same
    ; way ClickThru answers for PanelMode below.
    OpenLong    := on("OpenLong", on("OpenLater", 0))
    OpenShort   := on("OpenShort", 1)
    OpenStats   := on("OpenStats", 0)
    OpenHabits  := on("OpenHabits", 1)
    PanelLocked := on("Locked", 0)
    PanelOnTop  := on("OnTop", 1)
    ; PanelMode replaced the old two-state ClickThru flag. When the new key is
    ; missing the old one is read instead, so an existing Daybook.ini comes back
    ; in the mode it was left in: ClickThru 1 was today's GHOST, 0 today's DIM.
    PanelMode := CfgNum(IniFile, "Saved", "PanelMode", on("ClickThru", 0) ? 2 : 1)
    if (PanelMode != 0 && PanelMode != 1 && PanelMode != 2)
        PanelMode := 1
    if !IsNumber(PanelX)
        PanelX := A_ScreenWidth - PanelW - 24
    if !IsNumber(PanelY)
        PanelY := 80
    PanelX := Integer(PanelX), PanelY := Integer(PanelY)
}

SaveIni() {
    global PanelX, PanelY
    if (PanelVisible && PanelHwnd) {
        try {
            if (WinGetMinMax(PanelHwnd) != -1) {         ; minimised, it is at -32000
                WinGetPos(&x, &y, , , PanelHwnd)
                PanelX := x, PanelY := y
            }
        }
    }
    for k, v in Map("X", PanelX, "Y", PanelY, "OpenToday", OpenToday, "OpenMissed", OpenMissed
            , "OpenShort", OpenShort, "OpenLong", OpenLong, "OpenStats", OpenStats
            , "OpenHabits", OpenHabits, "PanelMode", PanelMode, "Locked", PanelLocked, "OnTop", PanelOnTop)
        try IniWrite(v, IniFile, "Saved", k)
}
