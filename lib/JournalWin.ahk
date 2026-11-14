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
#Requires AutoHotkey v2.0

JrnShow(day := "", *) {
    if (!JournalOn)
        return
    if (!IsObject(JrnGui))
        JrnBuild()
    if (day = "")
        day := LogicalDay()
    if (DllCall("IsWindowVisible", "ptr", JrnHwnd)) {
        if (day != JrnDay)
            JrnGo(day)
        WinActivate(JrnHwnd)
        return
    }
    JrnLoad(day)
    ; beside the panel, on whichever side has room - where the habit window goes
    LivePanel(&px, &py, &pw, &ph)
    x := px - JrnW - 8
    if (x < 10)
        x := px + pw + 8
    y := py
    ClampWin(&x, &y, JrnW, JrnH)
    SideOnTop(JrnGui)
    JrnGui.Show("x" x " y" y)
    e := JrnGui["JrnEdit"]
    e.Focus()
    SendMessage(0xB1, -1, -1, e)         ; caret at the end
    SendMessage(0xB7, 0, 0, e)           ; and in view
    SetTimer(JrnLook, 2000)
}

JrnBuild() {
    global JrnGui, JrnHwnd, JrnW, JrnH
    W := 480, L := 20
    g := Gui("+AlwaysOnTop -MaximizeBox -MinimizeBox", "Daybook journal")
    JrnGui := g, JrnHwnd := g.Hwnd
    KitTaskbar.Id(JrnHwnd)                ; under the panel's taskbar button
    g.MarginX := 0, g.MarginY := 0
    g.BackColor := CBg
    g.OnEvent("Close", JrnEdClose)
    g.OnEvent("Escape", JrnEdClose)
    link := (opts, text, fn) => OnClicks(g.Add("Text", opts " BackgroundTrans", text), fn)

    ; ---- which day: arrows either side of it, as the habit calendar's month
    g.SetFont("s10 Norm c" CText, "Segoe UI")
    link("vJrnPrev x" L " y14 w30 h24 +0x200", Chr(0x25C0), (*) => JrnGo(DayShift(JrnDay, -1)))
    g.SetFont("s11 Bold c" CText, "Segoe UI")
    g.Add("Text", "vJrnTitle x" (L + 34) " y14 w" (W - 2 * L - 68) " h24 Center +0x200 BackgroundTrans")
    g.SetFont("s10 Norm c" CText, "Segoe UI")
    link("vJrnNext x" (W - L - 30) " y14 w30 h24 Right +0x200", Chr(0x25B6), JrnNextDay)
    ; "today", or a way back to it
    g.SetFont("s8 Norm c" CDim, "Segoe UI")
    g.Add("Text", "vJrnWhen x" (L + 34) " y38 w" (W - 2 * L - 68) " h16 Center BackgroundTrans")
        .OnEvent("Click", (*) => (JrnDay != LogicalDay() ? JrnGo(LogicalDay()) : 0))

    ; ---- the day's title: it goes in the file name, after the date
    g.SetFont("s10 Bold c" CText, "Segoe UI")
    nm := g.Add("Edit", "vJrnName x" L " y62 w" (W - 2 * L) " h24 -E0x200 Background" CCard)
    nm.OnEvent("Change", (*) => (JrnFitDir(), SetTimer(JrnNameSave, -1500)))
    SendMessage(0xD3, 3, 8 | (8 << 16), nm)                     ; EM_SETMARGINS
    SendMessage(0x1501, 1, StrPtr("a title for the day - optional, it names the file"), nm)   ; EM_SETCUEBANNER

    ; ---- the writing. WantTab, so Tab indents a list the way Obsidian does.
    ; Enter is the key below, not the box's own: it carries a list on.
    y := 96
    g.SetFont("s10 Norm c" CText, "Segoe UI")
    e := g.Add("Edit", "vJrnEdit x" L " y" y " w" (W - 2 * L) " h" JrnEdH " -E0x200 +Multi +VScroll +WantTab Background" CCard)
    e.OnEvent("Change", (*) => (JrnFitDir(), SetTimer(JrnAutoSave, -1500)))
    ; the scrollbar in the theme's skin, and the words off the box's edges -
    ; EM_SETMARGINS, left and right, 8px each
    Theme.Skin(e, "Explorer")
    SendMessage(0xD3, 3, 8 | (8 << 16), e)

    ; ---- the two-editors question, only shown when it is asked - the box
    ; gives up its bottom 60px to it rather than leaving a gap for it always
    g.SetFont("s8 Norm c" CAmber, "Segoe UI")
    g.Add("Text", "vJrnMsg x" L " y" (y + JrnEdH - 56) " w" (W - 2 * L) " h30 BackgroundTrans Hidden")
    g.SetFont("s9 Bold c" CGreen, "Segoe UI")
    link("vJrnKeep x" L " y" (y + JrnEdH - 24) " w170 h22 +0x200 Hidden", "keep what is written here", (*) => JrnKeepMine())
    g.SetFont("s9 Bold c" CText, "Segoe UI")
    link("vJrnTake x" (L + 190) " y" (y + JrnEdH - 24) " w170 h22 +0x200 Hidden", "use the note as it is now", (*) => JrnTakeFile())
    y += JrnEdH + 6

    g.SetFont("s8 Norm c" CDim, "Segoe UI")
    g.Add("Text", "x" L " y" y " w" (W - 2 * L - 120) " h16 BackgroundTrans"
        , "- starts a list, Enter carries it on   " Chr(0x00B7) "   saved as you type")
    g.Add("Text", "vJrnStatus x" (W - L - 120) " y" y " w120 h16 Right BackgroundTrans")
    y += 24

    g.SetFont("s9 Norm c" CMuted, "Segoe UI")
    g.Add("Text", "x" L " y" y " w120 h22 +0x200 BackgroundTrans", "open the note")
        .OnEvent("Click", (*) => JrnOpenFile())
    g.SetFont("s9 Norm c" CText, "Segoe UI")
    g.Add("Text", "x" (W - L - 60) " y" y " w60 h22 Right +0x200 BackgroundTrans", "close")
        .OnEvent("Click", JrnEdClose)
    y += 34

    Theme.TitleBar(JrnHwnd)
    ShapeWindow(JrnHwnd)
    g.Show("Hide w" W " h" y)
    JrnW := W, JrnH := y
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
    try s := FileRead(f, "UTF-8")
    catch {
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
    ; `n: ^ and $ only see `r`n as a line end unless told, and top has had its
    ; `r taken out
    if (p := RegExMatch(top, "im`n)^##[ \t]+(journal|my notes)[ \t]*$", &m)) {
        r.head := SubStr(top, 1, p + m.Len - 1)
        rest := SubStr(top, p + m.Len)
    } else if (RegExMatch(top, "^#[ \t][^\n]*", &m)) {
        r.head := m[0]
        rest := SubStr(top, m.Len + 1)
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
    RegExReplace(r.body, "(*UCP)\w+", "", &n)
    return n
}

; The panel heading's number: today's words, or nothing yet.
JrnPanelCount() {
    static seen := "", n := 0
    if (!JournalOn || !IsObject(PanelGui))
        return
    ; every relayout asks - the note is read again only once its name, time or
    ; size says it changed
    f := JournalFile(LogicalDay())
    stamp := "", size := ""
    try stamp := FileGetTime(f), size := FileGetSize(f)
    if ((f "|" stamp "|" size) != seen)
        n := JrnWords(LogicalDay()), seen := f "|" stamp "|" size
    PanelGui["JrnCnt"].Text := n ? n " words" : ""
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
    JrnGui["JrnEdit"].Value := r.body
    JrnGui["JrnName"].Value := JrnNameBase
    JrnFitDir()
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
    today := LogicalDay()
    JrnGui["JrnTitle"].Text := DayWords(JrnDay, "dddd d MMMM yyyy")
    c := JrnGui["JrnNext"]
    c.SetFont("c" (StrCompare(JrnDay, today) < 0 ? CText : CDim))
    c.Redraw()
    if (JrnDay = today)
        when := "today"
    else if (JrnDay = DayShift(today, -1))
        when := "yesterday   " Chr(0x00B7) "   back to today"
    else
        when := "back to today"
    JrnGui["JrnWhen"].Text := when
}

JrnSay(msg, warn := false) {
    c := JrnGui["JrnStatus"]
    c.SetFont("c" (warn ? CAmber : CDim))
    c.Text := msg
}

; What is in the box, the way the file would have it.
JrnText() {
    return JrnNorm(JrnGui["JrnEdit"].Value)
}

; Write the box to the note, if it has changed. Returns what happened:
; "same" nothing to do, "saved", "busy" Daybook is writing the note (tried
; again shortly), "asking" the two-editors question is up, "failed".
JrnSave(*) {
    global JrnBase, JrnAsk, JrnAskFile
    Critical                             ; nothing of ours writes the note mid-save
    if (JrnAsk)
        return "asking"
    text := JrnText()
    if (text == JrnBase)
        return "same"
    if (NoteBusy) {
        SetTimer(JrnAutoSave, -300)
        return "busy"
    }
    r := JrnRead(JrnDay, true)
    if (!r.ok || r.short) {
        JrnSay("could not read the note - trying again", true)
        SetTimer(JrnAutoSave, -3000)
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
        SetTimer(JrnAutoSave, -3000)
        return "failed"
    }
    JrnBase := text
    JrnSay("saved " FormatTime(, "HH:mm"))
    if (!r.exists && JrnDay = LogicalDay())
        DayNoteWrite(JrnDay, true)       ; a new note for today gets its block now
    if (JrnDay = LogicalDay())
        JrnPanelCount()
    return "saved"
}

; The title box to the file name, if it has changed. A day with no note yet
; gets one first, so there is a file to name. Same answers as JrnSave().
JrnSaveName() {
    global JrnNameBase
    Critical
    t := JrnGui["JrnName"].Value
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
        SetTimer(JrnNameSave, -300)
        return "busy"
    }
    r := JrnRead(JrnDay, true)
    if (!r.ok || r.short) {
        JrnSay("could not read the note - trying again", true)
        SetTimer(JrnNameSave, -3000)
        return "failed"
    }
    if (!r.exists) {
        if (!JrnWrite(r.f, JrnCompose(r, JrnDay, JrnBase))) {
            JrnSay("could not save - trying again", true)
            SetTimer(JrnNameSave, -3000)
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
    JrnSay("named " FormatTime(, "HH:mm"))
    return "saved"
}

; Through a temporary file and a move - DayNoteWrite()'s way, for its
; reasons. A note held open by a sync gets two more tries.
JrnWrite(f, out) {
    try {
        if !DirExist(JournalDir)
            DirCreate(JournalDir)
    }
    loop 3 {
        if NoteReplace(f, out)
            return true
        Sleep(150)
    }
    return false
}

; The words you did not choose, kept where nothing ever clears them.
JrnStash(day, text, what) {
    if (text = "")
        return ""
    SplitPath(StateFile, , &dir)
    if (dir = "")
        dir := A_ScriptDir
    dir .= "\backups\journal-conflicts"
    f := dir "\" day "-" what "-" FormatTime(, "HHmmss") ".md"
    try {
        if !DirExist(dir)
            DirCreate(dir)
        FileAppend(text, f, "UTF-8")
    }
    return f
}

JrnAskShow(on) {
    g := JrnGui
    g["JrnEdit"].Move(, , , on ? JrnEdH - 62 : JrnEdH)
    for name in ["JrnMsg", "JrnKeep", "JrnTake"]
        g[name].Visible := on
    g["JrnMsg"].Text := on ? "This day's note was changed somewhere else"
        . " (Obsidian?) while you were writing here. Which one stays? The other is"
        . " kept in backups\journal-conflicts." : ""
    if (on)
        JrnSay("")
}

JrnKeepMine() {
    global JrnBase, JrnAsk
    JrnStash(JrnDay, JrnAskFile, "from-the-note")
    JrnBase := JrnAskFile                ; that is what is being written over now
    JrnAsk := 0
    JrnAskShow(false)
    JrnSave()
}

JrnTakeFile() {
    JrnStash(JrnDay, JrnText(), "from-the-window")
    JrnLoad(JrnDay)
    JrnSay("yours is kept in backups")
}

; Persian reads right to left. Each box - the title and the writing - takes
; the direction of its first letter: Persian (or any right-to-left script),
; and the box turns right-aligned and right-to-left, so the English words in a
; Persian sentence land where they belong; English, and it stays as it was.
; Looked at again only when that first letter changes language, so Windows' own
; switch (Ctrl + Right Shift / Ctrl + Left Shift) still holds in between.
JrnFitDir() {
    static was := Map()
    for name in ["JrnEdit", "JrnName"] {
        c := JrnGui[name]
        rtl := JrnRtl(c.Value)
        if (was.Has(name) && was[name] = rtl)
            continue
        was[name] := rtl
        h := c.Hwnd
        st := DllCall("GetWindowLongPtr", "ptr", h, "int", -16, "ptr")
        ex := DllCall("GetWindowLongPtr", "ptr", h, "int", -20, "ptr")
        DllCall("SetWindowLongPtr", "ptr", h, "int", -16, "ptr", rtl ? st | 0x2 : st & ~0x2)            ; ES_RIGHT
        DllCall("SetWindowLongPtr", "ptr", h, "int", -20, "ptr", rtl ? ex | 0x3000 : ex & ~0x3000)      ; WS_EX_RTLREADING | WS_EX_RIGHT
        DllCall("SetWindowPos", "ptr", h, "ptr", 0, "int", 0, "int", 0, "int", 0, "int", 0, "uint", 0x37)  ; FRAMECHANGED
        DllCall("InvalidateRect", "ptr", h, "ptr", 0, "int", 1)
    }
}

; Is the first letter of t from a right-to-left script - Persian, Arabic, Hebrew?
JrnRtl(t) {
    if (!RegExMatch(t, "(*UCP)\pL", &m))
        return false
    c := Ord(m[0])
    return (c >= 0x0590 && c <= 0x08FF) || (c >= 0xFB1D && c <= 0xFDFF) || (c >= 0xFE70 && c <= 0xFEFF)
}

JrnNameSave() {
    if (JrnSaveName() != "busy" && JrnClosing)
        JrnClose()
}

JrnAutoSave() {
    if (JrnSave() = "saved" && JrnClosing)
        JrnHide()
}

; Changes made somewhere else, taken up while nothing is being typed here.
JrnLook() {
    global JrnBase, JrnNameBase
    if (!DllCall("IsWindowVisible", "ptr", JrnHwnd)) {
        SetTimer(JrnLook, 0)
        return
    }
    if (JrnAsk || !(JrnText() == JrnBase))
        return                           ; typing - the save will look
    r := JrnRead(JrnDay)
    if (!r.ok || r.short)
        return
    ; renamed somewhere else - Obsidian, Explorer - and not being typed here
    nm := JrnGui["JrnName"]
    if (r.exists && nm.Value == JrnNameBase
        && !(JournalTitleOf(r.f) == JrnNameBase)) {
        JrnNameBase := JournalTitleOf(r.f)
        nm.Value := JrnNameBase
        JrnFitDir()
    }
    if (r.body == JrnBase)
        return
    JrnBase := r.body
    e := JrnGui["JrnEdit"]
    a := 0, b := 0
    DllCall("SendMessage", "ptr", e.Hwnd, "uint", 0xB0, "uint*", &a, "uint*", &b)   ; EM_GETSEL
    e.Value := r.body
    JrnFitDir()
    SendMessage(0xB1, a, a, e)                                                      ; caret back
    JrnSay("updated from the note")
}

;================================================================================
; Moving between days, and closing
;================================================================================
JrnNextDay(*) {
    if (StrCompare(JrnDay, LogicalDay()) < 0)
        JrnGo(DayShift(JrnDay, 1))
}

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

JrnOpenFile() {
    JrnSaveName()
    JrnSave()
    f := JournalFile(JrnDay)
    if (FileExist(f))
        Run('"' f '"')
    else
        JrnSay("no note yet - write something first")
}

JrnEdClose(*) {
    JrnClose()
    return true                          ; hidden by JrnHide, never destroyed
}

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
    SetTimer(JrnAutoSave, 0)
    SetTimer(JrnNameSave, 0)
    SetTimer(JrnLook, 0)
    JrnGui.Hide()
}

; Settings changed: the journal turned off closes the window, saved.
JrnSettingsChanged() {
    if (!JournalOn && IsObject(JrnGui) && DllCall("IsWindowVisible", "ptr", JrnHwnd))
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
    foc := ""
    try foc := JrnGui.FocusedCtrl.Name
    if (foc = "JrnName") {               ; Enter on the title: named, and on to the writing
        JrnSaveName()
        JrnGui["JrnEdit"].Focus()
        return
    }
    if (foc != "JrnEdit")
        return
    hEd := JrnGui["JrnEdit"].Hwnd
    a := 0, b := 0
    DllCall("SendMessage", "ptr", hEd, "uint", 0xB0, "uint*", &a, "uint*", &b)   ; EM_GETSEL
    row := DllCall("SendMessage", "ptr", hEd, "uint", 0xC9, "ptr", a, "ptr", 0, "ptr")   ; EM_LINEFROMCHAR
    ls  := DllCall("SendMessage", "ptr", hEd, "uint", 0xBB, "ptr", row, "ptr", 0, "ptr")  ; EM_LINEINDEX
    len := DllCall("SendMessage", "ptr", hEd, "uint", 0xC1, "ptr", ls, "ptr", 0, "ptr")  ; EM_LINELENGTH
    line := ""
    if (len > 0) {
        buf := Buffer((len + 2) * 2, 0)
        NumPut("ushort", len + 1, buf)                    ; EM_GETLINE: room, first
        got := DllCall("SendMessage", "ptr", hEd, "uint", 0xC4, "ptr", row, "ptr", buf, "ptr")
        line := StrGet(buf, got, "UTF-16")
    }
    ins := "`r`n"
    if (RegExMatch(line, "^([ \t]*)(?:([-*+])( \[.\])?|(\d+)([.)])) ", &m)) {
        if (Trim(SubStr(line, m.Len + 1)) = "" && a = b && a = ls + len) {
            DllCall("SendMessage", "ptr", hEd, "uint", 0xB1, "ptr", ls, "ptr", ls + len)  ; EM_SETSEL
            JrnReplaceSel(hEd, "")
            return
        }
        mark := (m[4] != "") ? (Integer(m[4]) + 1) m[5] : m[2] ((m[3] != "") ? " [ ]" : "")
        ins .= m[1] mark " "
    }
    JrnReplaceSel(hEd, ins)
}

JrnReplaceSel(hEd, s) {
    DllCall("SendMessage", "ptr", hEd, "uint", 0xC2, "ptr", 1, "str", s)   ; EM_REPLACESEL, undoable
    DllCall("SendMessage", "ptr", hEd, "uint", 0xB7, "ptr", 0, "ptr", 0)   ; EM_SCROLLCARET
}

#HotIf WinActive("Daybook journal ahk_class AutoHotkeyGUI")
Enter::JrnEnter()
NumpadEnter::JrnEnter()
^s::JrnSave()
; A plain Edit types a box for Ctrl+Backspace instead of deleting a word.
^BS::Send("^+{Left}{Delete}")
#HotIf
