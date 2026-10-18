;================================================================================
; The journal window - the JOURNAL heading on the panel, or the tray
;================================================================================
; A window onto YOUR part of a day note: everything under its "## journal"
; heading and above Daybook's block. It keeps no copy of its own. It reads the
; note when it opens, writes it back a moment after you stop typing, and that
; file is the only place the words live - so whatever you write in Obsidian
; is simply what the window shows next time, and there is nothing to sync.
;
; Two editors on one file can still cross. So a save reads the note again
; first, and if your part of it is no longer what the window loaded - changed
; in Obsidian while you were typing here - nothing is written. The window
; says so and you choose; the text you did not choose goes to
; backups\journal-conflicts\, which nothing clears - neither side is lost.
;
; While nothing is being typed here, the window looks at the note every two
; seconds and quietly takes up any change made somewhere else.
;
; Daybook's own writers - DayNoteWrite(), HabitFixNote() - read the note and
; write it back too. A save that landed between their read and their write
; would be undone by it, so they raise NoteBusy while they work, and a save
; that finds it raised waits for them.
;
; Off ([Journal] Write=0) means off: no heading on the panel, no tray item.
;================================================================================
JrnShow(day := "") {
    global JournalOn, JrnBuilt, JrnHwnd, JrnW, JrnH, JrnDay
    if (!JournalOn)
        return
    if (!JrnBuilt)
        JrnBuild()
    if (day = "")
        day := LogicalDay()
    if (DllCall("IsWindowVisible", "ptr", JrnHwnd)) {
        if (day != JrnDay)
            JrnGo(day)
        WinActivate, ahk_id %JrnHwnd%
        return
    }
    JrnLoad(day)
    ; beside the panel, on whichever side has room - where the habit window goes
    LivePanel(px, py, pw, ph)
    x := px - JrnW - 8
    if (x < 10)
        x := px + pw + 8
    y := py
    ClampWin(x, y, JrnW, JrnH)
    Gui, JrnEd:Show, x%x% y%y%, Daybook journal
    GuiControl, JrnEd:Focus, JrnEdit
    GuiControlGet, hEd, JrnEd:Hwnd, JrnEdit
    DllCall("SendMessage", "ptr", hEd, "uint", 0xB1, "ptr", -1, "ptr", -1)   ; caret at the end
    DllCall("SendMessage", "ptr", hEd, "uint", 0xB7, "ptr", 0, "ptr", 0)    ; and in view
    SetTimer, JrnWatch, 2000
}

JrnBuild() {
    global
    local W := 480, L := 20, y, opt
    Gui, JrnEd:New, +AlwaysOnTop -MaximizeBox -MinimizeBox +LabelJrnEd +HwndJrnHwnd, Daybook journal
    TaskbarId(JrnHwnd, "Ahk.Daybook")     ; under the panel's taskbar button
    Gui, JrnEd:Margin, 0, 0
    Gui, JrnEd:Color, %CBg%, %CCard%

    ; ---- which day: arrows either side of it, as the habit calendar's month
    Gui, JrnEd:Font, s10 Norm c%CText%, Segoe UI
    opt := "vJrnPrev gJrnPrev x" L " y14 w30 h24 +0x200 BackgroundTrans"
    Gui, JrnEd:Add, Text, %opt%, % Chr(0x25C0)
    Gui, JrnEd:Font, s11 Bold c%CText%, Segoe UI
    opt := "vJrnTitle x" (L + 34) " y14 w" (W - 2 * L - 68) " h24 Center +0x200 BackgroundTrans"
    Gui, JrnEd:Add, Text, %opt%
    Gui, JrnEd:Font, s10 Norm c%CText%, Segoe UI
    opt := "vJrnNext gJrnNext x" (W - L - 30) " y14 w30 h24 Right +0x200 BackgroundTrans"
    Gui, JrnEd:Add, Text, %opt%, % Chr(0x25B6)
    ; "today", or a way back to it
    Gui, JrnEd:Font, s8 Norm c%CDim%, Segoe UI
    opt := "vJrnWhen gJrnToday x" (L + 34) " y38 w" (W - 2 * L - 68) " h16 Center BackgroundTrans"
    Gui, JrnEd:Add, Text, %opt%

    ; ---- the day's title: it goes in the file name, after the date
    Gui, JrnEd:Font, s10 Bold c%CText%, Segoe UI
    opt := "vJrnName gJrnNamed x" L " y62 w" (W - 2 * L) " h24 -E0x200"
    Gui, JrnEd:Add, Edit, %opt%
    GuiControlGet, hNm, JrnEd:Hwnd, JrnName
    DllCall("SendMessage", "ptr", hNm, "uint", 0xD3, "ptr", 3, "ptr", 8 | (8 << 16))
    DllCall("SendMessage", "ptr", hNm, "uint", 0x1501, "ptr", 1, "wstr", "a title for the day - optional, it names the file")

    ; ---- the writing. WantTab, so Tab indents a list the way Obsidian does.
    ; Enter is the key below, not the box's own: it carries a list on.
    y := 96
    JrnEdY := y, JrnEdH := 440
    Gui, JrnEd:Font, s10 Norm c%CText%, Segoe UI
    opt := "vJrnEdit gJrnTyped x" L " y" y " w" (W - 2 * L) " h" JrnEdH " -E0x200 +Multi +VScroll +WantTab"
    Gui, JrnEd:Add, Edit, %opt%
    GuiControlGet, hEd, JrnEd:Hwnd, JrnEdit
    ; a dark scrollbar, not the white one, and the words off the box's edges -
    ; EM_SETMARGINS, left and right, 8px each
    DllCall("uxtheme\SetWindowTheme", "ptr", hEd, "str", "DarkMode_Explorer", "ptr", 0)
    DllCall("SendMessage", "ptr", hEd, "uint", 0xD3, "ptr", 3, "ptr", 8 | (8 << 16))

    ; ---- the two-editors question, only shown when it is asked - the box
    ; gives up its bottom 60px to it rather than leaving a gap for it always
    Gui, JrnEd:Font, s8 Norm c%CAmber%, Segoe UI
    opt := "vJrnMsg x" L " y" (y + JrnEdH - 56) " w" (W - 2 * L) " h30 BackgroundTrans Hidden"
    Gui, JrnEd:Add, Text, %opt%
    Gui, JrnEd:Font, s9 Bold c%CGreen%, Segoe UI
    opt := "vJrnKeep gJrnKeep x" L " y" (y + JrnEdH - 24) " w170 h22 +0x200 BackgroundTrans Hidden"
    Gui, JrnEd:Add, Text, %opt%, keep what is written here
    Gui, JrnEd:Font, s9 Bold c%CText%, Segoe UI
    opt := "vJrnTake gJrnTake x" (L + 190) " y" (y + JrnEdH - 24) " w170 h22 +0x200 BackgroundTrans Hidden"
    Gui, JrnEd:Add, Text, %opt%, use the note as it is now
    y += JrnEdH + 6

    Gui, JrnEd:Font, s8 Norm c%CDim%, Segoe UI
    opt := "x" L " y" y " w" (W - 2 * L - 120) " h16 BackgroundTrans"
    Gui, JrnEd:Add, Text, %opt%, % "- starts a list, Enter carries it on   " Chr(0x00B7) "   saved as you type"
    opt := "vJrnStatus x" (W - L - 120) " y" y " w120 h16 Right BackgroundTrans"
    Gui, JrnEd:Add, Text, %opt%
    y += 24

    Gui, JrnEd:Font, s9 Norm c%CMuted%, Segoe UI
    opt := "gJrnOpenFile x" L " y" y " w120 h22 +0x200 BackgroundTrans"
    Gui, JrnEd:Add, Text, %opt%, open the note
    Gui, JrnEd:Font, s9 Norm c%CText%, Segoe UI
    opt := "gJrnEdClose x" (W - L - 60) " y" y " w60 h22 Right +0x200 BackgroundTrans"
    Gui, JrnEd:Add, Text, %opt%, close
    y += 34

    SetupDark(JrnHwnd)
    ShapeWindow(JrnHwnd, PanelRound)
    Gui, JrnEd:Show, Hide w%W% h%y%, Daybook journal
    JrnW := W, JrnH := y
    JrnBuilt := 1
}

;================================================================================
; Your part of a note
;================================================================================
; A note read and taken apart: head (the title and the "## journal" heading,
; and anything above that heading), body (what the window shows), tail
; (Daybook's block, from its first marker to the end). Line ends are `n here;
; nl is what the file had, and goes back on with them.
;
; No journal heading - an old note, or one somebody tidied - and the title line
; alone is the head. No title either, and the whole top is the body.
;
; fold: the caller is about to write - see JournalFile().
JrnRead(day, fold := false) {
    f := JournalFile(day, fold)
    r := {f: f, exists: false, ok: true, short: false, nl: "`n", s: ""
        , head: "", body: "", tail: ""}
    if (!FileExist(f))
        return r
    r.exists := true
    FileRead, s, *P65001 %f%
    if (ErrorLevel) {
        r.ok := false
        return r
    }
    r.s := s
    r.nl := InStr(s, "`r`n") ? "`r`n" : "`n"
    t := StrReplace(s, "`r")
    a := InStr(t, "%% daybook:", true)
    ; the opening marker with no closing one: a note read short, mid-save -
    ; the same thing DayNoteWrite() will not write over
    if (a && !InStr(t, DayMarkEnd(), true, a))
        r.short := true
    top := a ? SubStr(t, 1, a - 1) : t
    r.tail := a ? SubStr(t, a) : ""
    ; `n: AutoHotkey's ^ and $ only see `r`n as a line end unless told, and
    ; top has had its `r taken out
    if (p := RegExMatch(top, "im`n)^##[ \t]+(journal|my notes)[ \t]*$", m)) {
        r.head := SubStr(top, 1, p + StrLen(m) - 1)
        rest := SubStr(top, p + StrLen(m))
    } else if (RegExMatch(top, "^#[ \t][^\n]*", m)) {
        r.head := m
        rest := SubStr(top, StrLen(m) + 1)
    } else
        rest := top
    r.body := JrnNorm(rest)
    return r
}

; The same text, however it was spaced at either end: what two versions of a
; body are compared by. Leading spaces on the first line are kept - they are
; an indent.
JrnNorm(s) {
    s := StrReplace(s, "`r")
    s := RegExReplace(s, "^\n+")
    return RTrim(s, " `t`n")
}

; The whole note again, with a new body. A day with no note yet gets the shape
; DayNoteWrite() gives one, and Daybook's block is added under it by that.
JrnCompose(r, day, body) {
    head := r.exists ? r.head : "# " day "`n`n## journal"
    out := RTrim(head, " `t`n")
    if (body != "")
        out .= (out != "" ? "`n`n" : "") body
    if (r.tail != "")
        out .= (out != "" ? "`n`n" : "") r.tail
    else
        out .= "`n"
    return StrReplace(out, "`n", r.nl)
}

; How many words are in a day's journal - the number beside the heading.
JrnWords(day) {
    r := JrnRead(day)
    if (!r.ok || r.body = "")
        return 0
    RegExReplace(r.body, "(*UCP)\w+", "", n)
    return n
}

; The panel heading's number: today's words, or nothing yet.
JrnPanelCount() {
    global JournalOn
    static seen := "", n := 0
    if (!JournalOn)
        return
    ; every relayout asks - the note is read again only once its name, time or
    ; size says it changed
    f := JournalFile(LogicalDay())
    FileGetTime, at, %f%
    FileGetSize, size, %f%
    if ((f "|" at "|" size) != seen)
        n := JrnWords(LogicalDay()), seen := f "|" at "|" size
    GuiControl, Panel:, JrnCnt, % n ? n " words" : ""
}

;================================================================================
; Loading and saving
;================================================================================
JrnLoad(day) {
    global JrnDay, JrnBase, JrnAsk, JrnNameBase, JournalTwins
    JournalTwins := ""
    r := JrnRead(day)
    JrnDay := day
    JrnBase := r.body
    JrnNameBase := r.exists ? JournalTitleOf(r.f) : ""
    JrnAsk := 0
    JrnAskShow(false)
    GuiControl, JrnEd:, JrnEdit, % r.body
    GuiControl, JrnEd:, JrnName, %JrnNameBase%
    JrnPaintDay()
    if (!r.ok)
        JrnSay("could not read the note", true)
    else if (JournalTwins = day)
        JrnSay("two notes for this day!", true)
    else
        JrnSay(r.exists ? "" : "no note yet")
}

; The day at the top, and the arrows - forward stops at today.
JrnPaintDay() {
    global JrnDay, CText, CDim
    today := LogicalDay()
    FormatTime, title, % StrReplace(JrnDay, "-") "000000", dddd d MMMM yyyy
    GuiControl, JrnEd:, JrnTitle, %title%
    col := (JrnDay < today) ? CText : CDim
    GuiControl, JrnEd:+c%col%, JrnNext
    GuiControl, JrnEd:MoveDraw, JrnNext
    if (JrnDay = today)
        when := "today"
    else if (JrnDay = DayShift(today, -1))
        when := "yesterday   " Chr(0x00B7) "   back to today"
    else
        when := "back to today"
    GuiControl, JrnEd:, JrnWhen, %when%
}

JrnSay(msg, warn := false) {
    global CDim, CAmber
    col := warn ? CAmber : CDim
    GuiControl, JrnEd:+c%col%, JrnStatus
    GuiControl, JrnEd:, JrnStatus, %msg%
}

; What is in the box, the way the file would have it.
JrnText() {
    GuiControlGet, t, JrnEd:, JrnEdit
    return JrnNorm(t)
}

; Write the box to the note, if it has changed. Returns what happened:
; "same" nothing to do, "saved", "busy" Daybook is writing the note (tried
; again shortly), "asking" the two-editors question is up, "failed".
JrnSave() {
    global JrnDay, JrnBase, JrnAsk, NoteBusy, JrnAskFile
    Critical                             ; nothing of ours writes the note mid-save
    if (JrnAsk)
        return "asking"
    text := JrnText()
    if (text == JrnBase)
        return "same"
    if (NoteBusy) {
        SetTimer, JrnAutoSave, -300
        return "busy"
    }
    r := JrnRead(JrnDay, true)
    if (!r.ok || r.short) {
        JrnSay("could not read the note - trying again", true)
        SetTimer, JrnAutoSave, -3000
        return "failed"
    }
    if (r.exists && !(r.body == JrnBase)) {
        ; changed somewhere else since this window last read it
        JrnAsk := 1, JrnAskFile := r.body
        JrnAskShow(true)
        return "asking"
    }
    if (r.exists)
        DayNoteKeep(JrnDay, r.f, r.s)    ; the note as it stood, once a run
    if (!JrnWrite(r.f, JrnCompose(r, JrnDay, text))) {
        JrnSay("could not save - trying again", true)
        SetTimer, JrnAutoSave, -3000
        return "failed"
    }
    JrnBase := text
    FormatTime, hm, , HH:mm
    JrnSay("saved " hm)
    if (!r.exists && JrnDay = LogicalDay())
        DayNoteWrite(JrnDay, true)       ; a new note for today gets its block now
    if (JrnDay = LogicalDay())
        JrnPanelCount()
    return "saved"
}

; The title box to the file name, if it has changed. A day with no note yet
; gets one first, so there is a file to name. Same answers as JrnSave().
JrnSaveName() {
    global JrnDay, JrnBase, JrnAsk, NoteBusy, JrnNameBase
    Critical
    GuiControlGet, t, JrnEd:, JrnName
    ; the box as it was filled is no change - even a title from Obsidian that
    ; the cleaning below would spell another way (too long, two spaces)
    if (t == JrnNameBase)
        return "same"
    t := JournalCleanTitle(t)
    if (t == JrnNameBase)
        return "same"
    if (JrnAsk)
        return "asking"
    if (NoteBusy) {
        SetTimer, JrnNameSave, -300
        return "busy"
    }
    r := JrnRead(JrnDay, true)
    if (!r.ok || r.short) {
        JrnSay("could not read the note - trying again", true)
        SetTimer, JrnNameSave, -3000
        return "failed"
    }
    if (!r.exists) {
        if (!JrnWrite(r.f, JrnCompose(r, JrnDay, JrnBase))) {
            JrnSay("could not save - trying again", true)
            SetTimer, JrnNameSave, -3000
            return "failed"
        }
        if (JrnDay = LogicalDay())
            DayNoteWrite(JrnDay, true)
    }
    if (JournalRetitle(JrnDay, t) = "") {
        JrnSay("could not rename - that name is taken?", true)
        return "failed"
    }
    JrnNameBase := t
    FormatTime, hm, , HH:mm
    JrnSay("named " hm)
    return "saved"
}

; Through a temporary file and a move, in binary mode - DayNoteWrite()'s way,
; for its reasons. A note held open by a sync gets two more tries.
JrnWrite(f, out) {
    global JournalDir
    if (!InStr(FileExist(JournalDir), "D"))
        FileCreateDir, %JournalDir%
    tmp := f ".tmp"
    Loop 3 {
        FileDelete, %tmp%
        FileAppend, %out%, *%tmp%, UTF-8
        if (!ErrorLevel) {
            FileMove, %tmp%, %f%, 1
            if (!ErrorLevel)
                return true
        }
        Sleep, 150
    }
    FileDelete, %tmp%
    return false
}

; The words you did not choose, kept where nothing ever clears them.
JrnStash(day, text, what) {
    global StateFile
    if (text = "")
        return ""
    SplitPath, StateFile, , dir
    if (dir = "")
        dir := A_ScriptDir
    dir .= "\backups\journal-conflicts"
    if (!InStr(FileExist(dir), "D"))
        FileCreateDir, %dir%
    FormatTime, hms, , HHmmss
    f := dir "\" day "-" what "-" hms ".md"
    FileAppend, %text%, %f%, UTF-8
    return f
}

JrnAskShow(on) {
    global JrnDay, JrnEdH
    show := on ? "Show" : "Hide"
    GuiControl, JrnEd:Move, JrnEdit, % "h" (on ? JrnEdH - 62 : JrnEdH)
    GuiControl, JrnEd:%show%, JrnMsg
    GuiControl, JrnEd:%show%, JrnKeep
    GuiControl, JrnEd:%show%, JrnTake
    GuiControl, JrnEd:, JrnMsg, % on ? "This day's note was changed somewhere else"
        . " (Obsidian?) while you were writing here. Which one stays? The other is"
        . " kept in backups\journal-conflicts." : ""
    if (on)
        JrnSay("")
}

JrnKeep:
    JrnKeepMine()
Return

JrnKeepMine() {
    global JrnDay, JrnBase, JrnAsk, JrnAskFile
    JrnStash(JrnDay, JrnAskFile, "from-the-note")
    JrnBase := JrnAskFile                ; that is what is being written over now
    JrnAsk := 0
    JrnAskShow(false)
    JrnSave()
}

JrnTake:
    JrnTakeFile()
Return

JrnTakeFile() {
    global JrnDay
    JrnStash(JrnDay, JrnText(), "from-the-window")
    JrnLoad(JrnDay)
    JrnSay("yours is kept in backups")
}

; Typing: saved once it stops for a moment, not on every key.
JrnTyped:
    SetTimer, JrnAutoSave, -1500
Return

JrnNamed:
    SetTimer, JrnNameSave, -1500
Return

JrnNameSave:
    if (JrnSaveName() != "busy" && JrnClosing)
        JrnClose()
Return

JrnAutoSave:
    if (JrnSave() = "saved" && JrnClosing)
        JrnHide()
Return

; Changes made somewhere else, taken up while nothing is being typed here.
JrnWatch:
    JrnLook()
Return

JrnLook() {
    global JrnHwnd, JrnDay, JrnBase, JrnAsk, JrnNameBase
    if (!DllCall("IsWindowVisible", "ptr", JrnHwnd)) {
        SetTimer, JrnWatch, Off
        return
    }
    if (JrnAsk || !(JrnText() == JrnBase))
        return                           ; typing - the save will look
    r := JrnRead(JrnDay)
    if (!r.ok || r.short)
        return
    ; renamed somewhere else - Obsidian, Explorer - and not being typed here
    GuiControlGet, t, JrnEd:, JrnName
    if (r.exists && t == JrnNameBase
        && !(JournalTitleOf(r.f) == JrnNameBase)) {
        JrnNameBase := JournalTitleOf(r.f)
        GuiControl, JrnEd:, JrnName, %JrnNameBase%
    }
    if (r.body == JrnBase)
        return
    JrnBase := r.body
    GuiControlGet, hEd, JrnEd:Hwnd, JrnEdit
    DllCall("SendMessage", "ptr", hEd, "uint", 0xB0, "uint*", a, "uint*", b)   ; EM_GETSEL
    GuiControl, JrnEd:, JrnEdit, % r.body
    DllCall("SendMessage", "ptr", hEd, "uint", 0xB1, "ptr", a, "ptr", a)       ; caret back
    JrnSay("updated from the note")
}

;================================================================================
; Moving between days, and closing
;================================================================================
JrnPrev:
    JrnGo(DayShift(JrnDay, -1))
Return

JrnNext:
    if (JrnDay < LogicalDay())
        JrnGo(DayShift(JrnDay, 1))
Return

JrnToday:
    if (JrnDay != LogicalDay())
        JrnGo(LogicalDay())
Return

; The day you were on is saved before another one is opened - and if it
; cannot be, you stay on it.
JrnGo(day) {
    res := JrnSaveName()
    if (res = "busy" || res = "failed")
        return
    res := JrnSave()
    if (res = "asking" || res = "failed" || res = "busy")
        return
    JrnLoad(day)
}

JrnOpenFile:
    JrnSaveName()
    JrnSave()
    if (FileExist(JournalFile(JrnDay)))
        Run, % JournalFile(JrnDay)
    else
        JrnSay("no note yet - write something first")
Return

JrnEdClose:
JrnEdEscape:
    JrnClose()
Return

; Saved, then hidden. A save that is waiting for Daybook's own writer closes
; the window once it lands; the two-editors question keeps it open.
JrnClose() {
    global JrnClosing
    res := JrnSaveName()
    if (res = "busy") {
        JrnClosing := 1                  ; JrnNameSave closes it once the name lands
        return
    }
    if (res = "failed") {
        JrnClosing := 0
        return
    }
    res := JrnSave()
    if (res = "busy" || res = "failed") {
        JrnClosing := 1
        return
    }
    if (res = "asking")
        return
    JrnHide()
}

JrnHide() {
    global JrnClosing
    JrnClosing := 0
    SetTimer, JrnAutoSave, Off
    SetTimer, JrnNameSave, Off
    SetTimer, JrnWatch, Off
    Gui, JrnEd:Hide
}

; Settings changed: the journal turned off closes the window, saved.
JrnSettingsChanged() {
    global JournalOn, JrnBuilt, JrnHwnd
    if (!JournalOn && JrnBuilt && DllCall("IsWindowVisible", "ptr", JrnHwnd))
        JrnClose()
}

;================================================================================
; Lists - Enter carries one on, the way Obsidian does
;================================================================================
; On a line that starts "- ", "* ", "+ ", "- [ ] " or "1. ", Enter starts the
; next line the same way, indented the same; a numbered one counts up. Enter
; on an item with nothing in it ends the list instead. Anywhere else it is a
; plain new line.
JrnEnter() {
    GuiControlGet, foc, JrnEd:FocusV
    if (foc = "JrnName") {               ; Enter on the title: named, and on to the writing
        JrnSaveName()
        GuiControl, JrnEd:Focus, JrnEdit
        return
    }
    if (foc != "JrnEdit")
        return
    GuiControlGet, hEd, JrnEd:Hwnd, JrnEdit
    DllCall("SendMessage", "ptr", hEd, "uint", 0xB0, "uint*", a, "uint*", b)   ; EM_GETSEL
    ln  := DllCall("SendMessage", "ptr", hEd, "uint", 0xC9, "ptr", a, "ptr", 0, "ptr")   ; EM_LINEFROMCHAR
    ls  := DllCall("SendMessage", "ptr", hEd, "uint", 0xBB, "ptr", ln, "ptr", 0, "ptr")  ; EM_LINEINDEX
    len := DllCall("SendMessage", "ptr", hEd, "uint", 0xC1, "ptr", ls, "ptr", 0, "ptr")  ; EM_LINELENGTH
    line := ""
    if (len > 0) {
        VarSetCapacity(buf, (len + 2) * 2, 0)
        NumPut(len + 1, buf, 0, "ushort")                 ; EM_GETLINE: room, first
        got := DllCall("SendMessage", "ptr", hEd, "uint", 0xC4, "ptr", ln, "ptr", &buf, "ptr")
        line := StrGet(&buf, got, "UTF-16")
    }
    ins := "`r`n"
    if (RegExMatch(line, "^([ \t]*)(?:([-*+])( \[.\])?|(\d+)([.)])) ", m)) {
        if (Trim(SubStr(line, StrLen(m) + 1)) = "" && a = b && a = ls + len) {
            DllCall("SendMessage", "ptr", hEd, "uint", 0xB1, "ptr", ls, "ptr", ls + len)  ; EM_SETSEL
            JrnReplaceSel(hEd, "")
            return
        }
        mark := (m4 != "") ? (m4 + 1) m5 : m2 ((m3 != "") ? " [ ]" : "")
        ins .= m1 mark " "
    }
    JrnReplaceSel(hEd, ins)
}

JrnReplaceSel(hEd, s) {
    DllCall("SendMessage", "ptr", hEd, "uint", 0xC2, "ptr", 1, "str", s)   ; EM_REPLACESEL, undoable
    DllCall("SendMessage", "ptr", hEd, "uint", 0xB7, "ptr", 0, "ptr", 0)   ; EM_SCROLLCARET
}

#IfWinActive Daybook journal ahk_class AutoHotkeyGUI
Enter::JrnEnter()
NumpadEnter::JrnEnter()
^s::JrnSave()
; A plain Edit types a box for Ctrl+Backspace instead of deleting a word.
^BS::Send, ^+{Left}{Delete}
#IfWinActive
