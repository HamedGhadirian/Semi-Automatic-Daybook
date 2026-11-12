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
;================================================================================
SaveState() {
    global NextTaskId
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
    for _, t in Tasks {
        s .= "task`t" t.list "`t" t.status "`t" t.carry "`t" t.born "`t" t.due "`t" t.text "`t" t.id "`t" t.doneOn "`t" t.since "`n"
        for day, note in t.notes
            s .= "tnote`t" t.id "`t" day "`t" note "`n"
    }
    ; The name goes LAST on a habit line, so it is the only field that can
    ; contain anything - the days before it are a fixed shape.
    for _, h in Habits {
        days := ""
        for _, d in h.done
            days .= (days ? "," : "") d
        s .= "habit`t" h.born "`t" h.streak "`t" h.best "`t" h.total "`t" days "`t" h.text "`n"
        ; How often, and the rest days, on a line of their own straight after:
        ; a habit line cannot grow past its name, and a line type the version
        ; before does not know is a line it skips.
        rests := ""
        for _, d in h.rest
            rests .= (rests ? "," : "") d
        s .= "hrule`t" h.kind "`t" h.n "`t" rests "`t" (h.unit = "D" ? "D" : "W") "`n"
    }
    ; Finished days, for as long as they are kept - see CloseDay().
    for _, r in Past
        s .= "past`t" r.day "`t" r.id "`t" r.list "`t" r.status "`t" r.carry "`t" r.note "`t" r.text "`n"
    for day, txt in PastTime
        s .= "ptime`t" day "`t" StrReplace(txt, "`n", "\n") "`n"
    for exe, sec in AppSec
        s .= "app`t" exe "`t" sec "`n"
    for k, sec in HourSec
        s .= "hour`t" k "`t" sec "`n"
    StrReplace(s, "`n", "`n", lines)
    s .= "end`t" lines "`n"
    StateWrite(s)
    ; And the two things in Obsidian that show this state. Both write only if
    ; what they would write has changed, so calling them every save is cheap.
    BoardWrite()
    DayNoteWrite(CurDay)
}

; The file, through a temporary one that is read back before it replaces
; anything. Binary mode (the *) so what is read back is byte for byte what was
; meant - text mode would turn every `n into `r`n on the way out.
StateWrite(s) {
    global StateFile, StateNoSave
    static warned := false
    if (StateNoSave)
        return false                     ; see StateReadOrRecover
    StateBackup()
    tmp := StateFile ".tmp"
    FileDelete, %tmp%
    FileAppend, %s%, *%tmp%, UTF-8
    ok := !ErrorLevel
    if (ok) {
        FileRead, back, *P65001 %tmp%
        ok := !ErrorLevel && back == s
    }
    if (ok) {
        FileMove, %tmp%, %StateFile%, 1
        ok := !ErrorLevel
    }
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
    last := InStr(s, "`n", false, 0)
    if (!last || !RegExMatch(SubStr(s, last + 1), "^end\t(\d+)$", m))
        return false
    StrReplace(SubStr(s, 1, last), "`n", "`n", n)
    return n = m1
}

; Before the first save of each day, the file as it stood - the state at the
; end of the last day anything changed. Only a file that reads is copied: a
; backup of a broken file would be no backup at all.
StateBackup() {
    global StateFile
    static done := ""
    FormatTime, today, , yyyy-MM-dd
    if (done = today || !FileExist(StateFile))
        return                           ; no file yet: nothing to keep, ask again
    dir := StateBackupDir()
    dest := dir "\Daybook-state-" today ".txt"
    if (FileExist(dest)) {
        done := today
        return
    }
    FileRead, s, *P65001 %StateFile%
    if (ErrorLevel || !StateValid(s))
        return
    if (!InStr(FileExist(dir), "D"))
        FileCreateDir, %dir%
    FileCopy, %StateFile%, %dest%, 0
    if (ErrorLevel)
        return                           ; not done: the next save tries again
    done := today
    StatePrune()
}

StateBackupDir() {
    global StateFile
    SplitPath, StateFile, , dir
    return dir "\backups"
}

; The backups' names, oldest first - the dates in them sort that way.
StateBackups() {
    list := ""
    Loop, Files, % StateBackupDir() "\Daybook-state-*.txt"
        if (RegExMatch(A_LoopFileName, "^Daybook-state-\d{4}-\d\d-\d\d\.txt$"))
            list .= A_LoopFileName "`n"
    list := RTrim(list, "`n")
    Sort, list
    return (list = "") ? [] : StrSplit(list, "`n")
}

; The newest 10, and the oldest of each of the last 6 months: a mistake seen
; the same week and one seen months later can both be undone.
StatePrune() {
    names := StateBackups()
    keep := {}, firsts := []
    for _, name in names
        if (!firsts.Length() || SubStr(firsts[firsts.Length()], 15, 7) != SubStr(name, 15, 7))
            firsts.Push(name)
    Loop % (names.Length() < 10 ? names.Length() : 10)
        keep[names[names.Length() - A_Index + 1]] := 1
    Loop % (firsts.Length() < 6 ? firsts.Length() : 6)
        keep[firsts[firsts.Length() - A_Index + 1]] := 1
    dir := StateBackupDir()
    for _, name in names
        if (!keep.HasKey(name))
            FileDelete, %dir%\%name%
}

; Said in the tray and in the log, because it matters and nobody is looking at
; a log.
StateSay(msg) {
    global StateQuiet                    ; the tests set it, to say nothing aloud
    if (!StateQuiet)
        TrayTip, Daybook, %msg%, 10, 2
    LogRaw("! " msg)
}

; The state file's text, or "" to start empty. A file that is there but does
; not read whole is moved aside - never saved over - and the newest backup that
; does read is used instead. A read that fails is tried three times first: a
; sync program can hold the file for a moment, and that is not damage.
StateReadOrRecover() {
    global StateFile, StateNoSave
    if (!FileExist(StateFile))
        return ""
    Loop 3 {
        FileRead, s, *P65001 %StateFile%
        if (!ErrorLevel && StateValid(s))
            return s
        Sleep 200
    }
    FormatTime, stamp, , yyyyMMdd-HHmmss
    SplitPath, StateFile, , dir
    bad := dir "\Daybook-state.unreadable-" stamp ".txt"
    FileMove, %StateFile%, %bad%, 0
    if (ErrorLevel) {
        FileCopy, %StateFile%, %bad%, 0
        if (ErrorLevel) {
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
    k := names.Length()
    while (k >= 1) {                     ; newest first
        FileRead, s, % "*P65001 " StateBackupDir() "\" names[k]
        if (!ErrorLevel && StateValid(s)) {
            StateSay("The state file could not be read. It was set aside as "
                   . bad " and the backup of " SubStr(names[k], 15, 10) " was loaded.")
            return s
        }
        k--
    }
    StateSay("The state file could not be read, and there is no backup that can. It"
           . " was set aside as " bad " - nothing in it has been lost or overwritten.")
    return ""
}

LoadState() {
    global NextTaskId, Past, PastTime
    s := StateReadOrRecover()
    if (s = "")
        return
    notes := [], ver := 0
    Loop, Parse, s, `n, `r
    {
        if (A_LoopField = "")
            continue
        StringSplit, p, A_LoopField, %A_Tab%
        if (p1 = "daybook-state")
            ver := p2 + 0
        else if (p1 = "day")
            CurDay := p2
        else if (p1 = "sit")
            SitSec := p2 + 0
        else if (p1 = "tid")
            NextTaskId := p2 + 0
        else if (p1 = "task")
            Tasks.Push({list: p2, status: p3, carry: p4 + 0, born: p5
                      , due: p6, text: p7, asked: 0, notes: {}
                      , id: (p0 >= 8) ? p8 + 0 : 0, doneOn: (p0 >= 9) ? p9 : ""
                      , since: (p0 >= 10) ? p10 : ""})
        else if (p1 = "tnote")
            notes.Push({id: p2 + 0, day: p3, text: p4})
        else if (p1 = "past")
            Past.Push({day: p2, id: p3 + 0, list: p4, status: p5, carry: p6 + 0
                     , note: p7, text: p8})
        else if (p1 = "ptime")
            PastTime[p2] := StrReplace(p3, "\n", "`n")
        else if (p1 = "habit") {
            days := []
            Loop, Parse, p6, `,
                if (A_LoopField != "")
                    days.Push(A_LoopField)
            Habits.Push({text: p7, born: p2, streak: p3 + 0, best: p4 + 0
                       , total: p5 + 0, done: days, rest: [], kind: "D", n: 1})
        }
        else if (p1 = "hrule" && Habits.Length()) {   ; belongs to the habit above
            h := Habits[Habits.Length()]
            h.kind := (p2 = "W") ? "W" : "D", h.n := (p3 + 0 >= 1) ? p3 + 0 : 1
            h.unit := (p0 >= 5 && p5 = "D") ? "D" : "W"      ; weeks, unless it said days
            Loop, Parse, p4, `,
                if (A_LoopField != "")
                    h.rest.Push(A_LoopField)
        }
        else if (p1 = "app")
            AppSec[p2] := p3 + 0
        else if (p1 = "hour")
            HourSec[p2] := p3 + 0
    }
    ; A file from before ids has none, and a hand-edited one might have a
    ; counter behind its own tasks. Either way: every task gets one, and the
    ; next one handed out is past all of them.
    for _, t in Tasks
        if (t.id >= NextTaskId)
            NextTaskId := t.id + 1
    for _, t in Tasks
        if (!t.id)
            t.id := NextTaskId++
    ; notes last, once every task is in and has its id
    for _, n in notes
        if (i := TaskIndex(n.id))
            Tasks[i].notes[n.day] := n.text
    ; Before MISSED, a task left open stayed on Today's list with its carry
    ; count going up, and the "review" lines (now ignored) asked about it. Those
    ; move to MISSED once, as if they had always been there, waiting since the
    ; day they were added - the day they were meant for.
    if (ver < 3)
        for _, t in Tasks
            if (t.list = "T" && t.status = "open" && t.carry > 0)
                t.list := "M", t.since := (t.born != "" && t.born < CurDay) ? t.born
                                         : DayShift(CurDay, -1)
    ; and one saved half way through the change still has a day to answer for
    for _, t in Tasks
        if (t.list = "M" && t.since = "")
            t.since := DayShift(CurDay, -1)
    ; A long term task cannot have failed at anything, but one moved there from
    ; MISSED used to keep its xN. Cleared here, on the way in - every load, but
    ; after the first one there is nothing left to clear (nothing adds to a
    ; long term task's count any more).
    for _, t in Tasks
        if (t.list = "L" && t.carry)
            t.carry := 0
}

; The panel's own state lives under [Saved], below the settings. It used to be
; under [Panel], before the file held settings too. Whatever is still there -
; an older file, or the old version of this script writing its state on the way
; out of a reload - is moved across once and the old section removed.
LoadIni() {
    old := CfgSection(IniFile, "Panel")
    for k, v in old {
        if k in X,Y,OpenToday,OpenLater,OpenLong,OpenShort,OpenStats,OpenHabits,PanelMode,Locked,OnTop,ClickThru
            IniWrite, %v%, %IniFile%, Saved, %k%
    }
    if (old.Count())
        IniDelete, %IniFile%, Panel
    IniRead, PanelX,    %IniFile%, Saved, X,         NONE
    IniRead, PanelY,    %IniFile%, Saved, Y,         NONE
    IniRead, OpenToday, %IniFile%, Saved, OpenToday, 1
    IniRead, OpenMissed, %IniFile%, Saved, OpenMissed, 1
    ; LATER TASKS became LONG TERM TASKS. An .ini written before that still says
    ; OpenLater, so the old key answers when the new one is not there - the same
    ; way ClickThru answers for PanelMode below.
    IniRead, OpenLong, %IniFile%, Saved, OpenLong, NONE
    if (OpenLong = "NONE" || OpenLong = "ERROR")
        IniRead, OpenLong, %IniFile%, Saved, OpenLater, 0
    IniRead, OpenShort, %IniFile%, Saved, OpenShort, 1
    IniRead, OpenStats, %IniFile%, Saved, OpenStats, 0
    IniRead, OpenHabits, %IniFile%, Saved, OpenHabits, 1
    IniRead, PanelLocked, %IniFile%, Saved, Locked, 0
    IniRead, PanelOnTop, %IniFile%, Saved, OnTop, 1
    ; PanelMode replaced the old two-state ClickThru flag. When the new key is
    ; missing the old one is read instead, so an existing Daybook.ini comes back
    ; in the mode it was left in: ClickThru 1 was today's GHOST, 0 today's DIM.
    IniRead, PanelMode, %IniFile%, Saved, PanelMode, NONE
    if (PanelMode = "NONE" || PanelMode = "ERROR") {
        IniRead, wasThru, %IniFile%, Saved, ClickThru, 0
        PanelMode := wasThru ? 2 : 1
    }
    if (PanelMode != 0 && PanelMode != 1 && PanelMode != 2)
        PanelMode := 1
    if (PanelX = "NONE" || PanelX = "ERROR")
        PanelX := A_ScreenWidth - PanelW - 24
    if (PanelY = "NONE" || PanelY = "ERROR")
        PanelY := 80
}

SaveIni() {
    global PanelX, PanelY
    if (PanelVisible) {
        WinGet, mm, MinMax, ahk_id %PanelHwnd%
        WinGetPos, x, y, , , ahk_id %PanelHwnd%
        if (x != "" && mm != -1)             ; minimised, it is at -32000
            PanelX := x, PanelY := y
    }
    IniWrite, %PanelX%,    %IniFile%, Saved, X
    IniWrite, %PanelY%,    %IniFile%, Saved, Y
    IniWrite, %OpenToday%, %IniFile%, Saved, OpenToday
    IniWrite, %OpenMissed%, %IniFile%, Saved, OpenMissed
    IniWrite, %OpenShort%, %IniFile%, Saved, OpenShort
    IniWrite, %OpenLong%,  %IniFile%, Saved, OpenLong
    IniWrite, %OpenStats%, %IniFile%, Saved, OpenStats
    IniWrite, %OpenHabits%, %IniFile%, Saved, OpenHabits
    IniWrite, %PanelMode%,   %IniFile%, Saved, PanelMode
    IniWrite, %PanelLocked%, %IniFile%, Saved, Locked
    IniWrite, %PanelOnTop%,  %IniFile%, Saved, OnTop
}

