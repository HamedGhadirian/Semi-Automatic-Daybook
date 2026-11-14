;================================================================================
; Due - the calendar that asks for a deadline
;================================================================================
; A short term task is a task for now, not for good - usually with a day to be
; done by. This is the small window that asks for the day. It is the habit
; window's calendar (CalGrid.ahk): the same squares, Monday first, and ONE
; CLICK on a day sets it. Above it, "tomorrow" and "in a week" for the usual
; answers, and "no deadline" for a task that has no day: it waits on the list,
; after the dated ones, and is never sent to MISSED.
;
;   "add"   a new task from the SHORT TERM + - its words were typed in the
;           capture box already, and the task is only made when a day is
;           picked. Esc (or "back") returns to the capture box with the words
;           still in it; nothing is lost and nothing is added
;   "move"  an existing task (by id), from its right-click menu - either moved
;           onto the short term list or given a new deadline. Esc (or
;           "cancel") leaves it exactly where it was
;
; Days before today are dim and do nothing: a deadline that has already gone is
; a miss, and there is a whole section for those. Today is amber, a deadline the
; task already has is blue.
;
; It takes focus, like the capture box: you just asked for it. Built once and
; hidden between uses; everything that depends on the date is worked out when
; it is shown and again on every click, so a window left open over midnight
; still cannot set a day that has just gone by.
;================================================================================
#Requires AutoHotkey v2.0

DueBuild() {
    global DueGui, DueHwnd, DueW, DueH
    L := 16, cw := 34, ch := 28, gap := 4
    W := L * 2 + 7 * (cw + gap) - gap
    g := Gui("+AlwaysOnTop -Caption +ToolWindow", "Daybook deadline")
    DueGui := g, DueHwnd := g.Hwnd
    g.MarginX := 0, g.MarginY := 0
    g.BackColor := CBg
    g.SetFont("s9 Norm c" CText, "Segoe UI")
    g.Add("Text", "vDueWhat x" L " y12 w" (W - 2 * L) " h18 BackgroundTrans")
    ; the two usual answers, as buttons - the panel is worked with the mouse
    g.SetFont("s9 Norm c" CBlue, "Segoe UI")
    g.Add("Text", "x" L " y38 w70 h20 +0x200 BackgroundTrans", "tomorrow")
        .OnEvent("Click", (*) => DueSet(DayShift(LogicalDay(), 1)))
    g.Add("Text", "x" (L + 80) " y38 w80 h20 +0x200 BackgroundTrans", "in a week")
        .OnEvent("Click", (*) => DueSet(DayShift(LogicalDay(), 7)))
    ; a short term task does not have to have a day: "for now, not for good"
    g.Add("Text", "vDueNone x" (L + 170) " y38 w" (W - 2 * L - 170) " h20 Right +0x200 BackgroundTrans", "no deadline")
        .OnEvent("Click", (*) => DueSet(""))
    y := CalGridBuild(g, "Due", L, 66, cw, ch, gap, DueDayClick, (*) => DueMove(-1), (*) => DueMove(1))
    y += 6
    g.SetFont("s8 Norm c" CDim, "Segoe UI")
    g.Add("Text", "x" L " y" (y + 2) " w" (W - 2 * L - 70) " h16 BackgroundTrans", "click a day to set it   " Chr(0x00B7) "   Esc")
    g.SetFont("s9 Norm c" CText, "Segoe UI")
    g.Add("Text", "vDueBack x" (W - L - 60) " y" y " w60 h20 Right +0x200 BackgroundTrans", "cancel")
        .OnEvent("Click", (*) => DueStepOut())
    y += 30
    ShapeWindow(DueHwnd)
    g.Show("Hide w" W " h" y)
    DueW := W, DueH := y
}

DuePick(mode, text, id) {
    global DueMode, DueWords, DueId, DueMonth, DueWas
    today := LogicalDay()
    what := text, was := ""
    if (mode = "move") {
        i := TaskIndex(id)
        if (!i)
            return
        t := Tasks[i]
        what := t.text
        if (t.list = "S" && t.due != "" && StrCompare(t.due, today) >= 0)
            was := t.due
    }
    if (!IsObject(DueGui))
        DueBuild()
    DueMode := mode, DueWords := text, DueId := id, DueWas := was
    ; it opens on the month of the deadline it already has, or this month
    DueMonth := SubStr((was != "") ? was : today, 1, 7)
    if (StrLen(what) > 40)
        what := SubStr(what, 1, 39) Chr(0x2026)
    DueGui["DueWhat"].Text := "deadline for:  " what
    ; from the capture box, stepping out goes back to it; from a menu, it cancels
    DueGui["DueBack"].Text := (mode = "add") ? "back" : "cancel"
    DuePaint()
    LivePanel(&px, &py, &pw, &ph)
    x := px + pw - DueW, y := py
    ClampWin(&x, &y, DueW, DueH)
    SideOnTop(DueGui)
    DueGui.Show("x" x " y" y)
}

; The furthest month the arrow goes: ten years on. Far enough for any deadline,
; and it moves with today, so it never runs out.
DueLastMonth() {
    return CalMonthShift(SubStr(LogicalDay(), 1, 7), 120)
}

DuePaint() {
    global DueCells
    today := LogicalDay()
    start := CalGridStart(DueMonth)
    CalGridTitle(DueGui, "Due", DueMonth
        , StrCompare(DueMonth, SubStr(today, 1, 7)) > 0, StrCompare(DueMonth, DueLastMonth()) < 0)
    DueCells := []
    loop 42 {
        day := DayShift(start, A_Index - 1)
        DueCells.Push("")
        if (SubStr(day, 1, 7) != DueMonth) {
            CalGridCell(DueGui, "Due", A_Index, CBg, CBg, "")
            continue
        }
        txt := Integer(SubStr(day, 9, 2))
        if (StrCompare(day, today) < 0) {        ; gone: dim, not a button
            CalGridCell(DueGui, "Due", A_Index, CBg, CDim, txt)
            continue
        }
        DueCells[A_Index] := day
        if (day = DueWas)
            CalGridCell(DueGui, "Due", A_Index, CBlue, CBg, txt)
        else
            CalGridCell(DueGui, "Due", A_Index, CCard, (day = today) ? CAmber : CText, txt)
    }
}

DueDayClick(k) {
    day := At(DueCells, k)
    if (day = "")
        return
    if (StrCompare(day, LogicalDay()) < 0) {     ; midnight came while it was open
        DuePaint()
        return
    }
    DueSet(day)
}

DueMove(dir) {
    global DueMonth
    m := CalMonthShift(DueMonth, dir)
    if (StrCompare(m, SubStr(LogicalDay(), 1, 7)) < 0 || StrCompare(m, DueLastMonth()) > 0)
        return
    DueMonth := m
    DuePaint()
}

DueSet(day) {
    global DueMode
    mode := DueMode, DueMode := ""
    DueGui.Hide()
    if (mode = "add")
        AddTask(DueWords, "S", "open", day)
    else if (mode = "move")
        TaskSetDue(DueId, day)
}

; Esc, or the word under the calendar. From the capture box it steps back into
; it, the words still there, so Esc twice is a full cancel and nothing typed is
; ever thrown away by one key.
DueStepOut() {
    global DueMode
    mode := DueMode, DueMode := ""
    DueGui.Hide()
    if (mode = "add")
        QuickAdd("S", DueWords)
}

#HotIf WinActive("Daybook deadline ahk_class AutoHotkeyGUI")
Escape::DueStepOut()
#HotIf
