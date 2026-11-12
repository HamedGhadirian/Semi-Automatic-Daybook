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
DueBuild() {
    global
    local L := 16, cw := 34, ch := 28, gap := 4, W, y, opt
    W := L * 2 + 7 * (cw + gap) - gap
    Gui, Due:New, +AlwaysOnTop -Caption +ToolWindow +HwndDueHwnd, Daybook deadline
    Gui, Due:Margin, 0, 0
    Gui, Due:Color, %CBg%, %CCard%
    Gui, Due:Font, s9 Norm c%CText%, Segoe UI
    opt := "vDueWhat x" L " y12 w" (W - 2 * L) " h18 BackgroundTrans"
    Gui, Due:Add, Text, %opt%
    ; the two usual answers, as buttons - the panel is worked with the mouse
    Gui, Due:Font, s9 Norm c%CBlue%, Segoe UI
    opt := "gDueTomorrow x" L " y38 w70 h20 +0x200 BackgroundTrans"
    Gui, Due:Add, Text, %opt%, tomorrow
    opt := "gDueWeek x" (L + 80) " y38 w80 h20 +0x200 BackgroundTrans"
    Gui, Due:Add, Text, %opt%, in a week
    ; a short term task does not have to have a day: "for now, not for good"
    opt := "vDueNone gDueNone x" (L + 170) " y38 w" (W - 2 * L - 170) " h20 Right +0x200 BackgroundTrans"
    Gui, Due:Add, Text, %opt%, no deadline
    y := CalGridBuild("Due", "Due", L, 66, cw, ch, gap, "DueDay", "DuePrev", "DueNext")
    y += 6
    Gui, Due:Font, s8 Norm c%CDim%, Segoe UI
    opt := "x" L " y" (y + 2) " w" (W - 2 * L - 70) " h16 BackgroundTrans"
    Gui, Due:Add, Text, %opt%, % "click a day to set it   " Chr(0x00B7) "   Esc"
    Gui, Due:Font, s9 Norm c%CText%, Segoe UI
    opt := "vDueBack gDueCancel x" (W - L - 60) " y" y " w60 h20 Right +0x200 BackgroundTrans"
    Gui, Due:Add, Text, %opt%, cancel
    y += 30
    ShapeWindow(DueHwnd, PanelRound)
    Gui, Due:Show, Hide w%W% h%y%, Daybook deadline
    DueW := W, DueH := y
    DueBuilt := 1
}

DuePick(mode, text, id) {
    global DueBuilt, DueMode, DueWords, DueId, DueMonth, DueWas, DueW, DueH, Tasks
    today := LogicalDay()
    what := text, was := ""
    if (mode = "move") {
        i := TaskIndex(id)
        if (!i)
            return
        what := Tasks[i].text
        if (Tasks[i].list = "S" && Tasks[i].due != "" && Tasks[i].due >= today)
            was := Tasks[i].due
    }
    if (!DueBuilt)
        DueBuild()
    DueMode := mode, DueWords := text, DueId := id, DueWas := was
    ; it opens on the month of the deadline it already has, or this month
    DueMonth := SubStr((was != "") ? was : today, 1, 7)
    if (StrLen(what) > 40)
        what := SubStr(what, 1, 39) Chr(0x2026)
    GuiControl, Due:, DueWhat, % "deadline for:  " what
    ; from the capture box, stepping out goes back to it; from a menu, it cancels
    GuiControl, Due:, DueBack, % (mode = "add") ? "back" : "cancel"
    DuePaint()
    LivePanel(px, py, pw, ph)
    x := px + pw - DueW, y := py
    ClampWin(x, y, DueW, DueH)
    SideOnTop("Due")
    Gui, Due:Show, x%x% y%y%, Daybook deadline
}

; The furthest month the arrow goes: ten years on. Far enough for any deadline,
; and it moves with today, so it never runs out.
DueLastMonth() {
    return CalMonthShift(SubStr(LogicalDay(), 1, 7), 120)
}

DuePaint() {
    global DueMonth, DueCells, DueWas
    global CBg, CCard, CText, CDim, CBlue, CAmber
    today := LogicalDay()
    start := CalGridStart(DueMonth)
    CalGridTitle("Due", "Due", DueMonth
        , DueMonth > SubStr(today, 1, 7), DueMonth < DueLastMonth())
    Loop 42 {
        day := DayShift(start, A_Index - 1)
        DueCells[A_Index] := ""
        if (SubStr(day, 1, 7) != DueMonth) {
            CalGridCell("Due", "Due", A_Index, CBg, CBg, "")
            continue
        }
        txt := SubStr(day, 9, 2) + 0
        if (day < today) {                       ; gone: dim, not a button
            CalGridCell("Due", "Due", A_Index, CBg, CDim, txt)
            continue
        }
        DueCells[A_Index] := day
        if (day = DueWas)
            CalGridCell("Due", "Due", A_Index, CBlue, CBg, txt)
        else
            CalGridCell("Due", "Due", A_Index, CCard, (day = today) ? CAmber : CText, txt)
    }
}

DueDay:
    DueDayClick(SubStr(A_GuiControl, 8))         ; "DueCell12" -> 12
Return

DueDayClick(k) {
    global DueCells
    day := DueCells[k]
    if (day = "")
        return
    if (day < LogicalDay()) {                    ; midnight came while it was open
        DuePaint()
        return
    }
    DueSet(day)
}

DueTomorrow:
    DueSet(DayShift(LogicalDay(), 1))
Return

DueWeek:
    DueSet(DayShift(LogicalDay(), 7))
Return

DueNone:
    DueSet("")
Return

DuePrev:
    DueMove(-1)
Return

DueNext:
    DueMove(1)
Return

DueMove(dir) {
    global DueMonth
    m := CalMonthShift(DueMonth, dir)
    if (m < SubStr(LogicalDay(), 1, 7) || m > DueLastMonth())
        return
    DueMonth := m
    DuePaint()
}

DueSet(day) {
    global DueMode, DueWords, DueId
    mode := DueMode, DueMode := ""
    Gui, Due:Hide
    if (mode = "add")
        AddTask(DueWords, "S", "open", day)
    else if (mode = "move")
        TaskSetDue(DueId, day)
}

; Esc, or the word under the calendar. From the capture box it steps back into
; it, the words still there, so Esc twice is a full cancel and nothing typed is
; ever thrown away by one key.
DueCancel:
    DueStepOut()
Return

DueStepOut() {
    global DueMode, DueWords
    mode := DueMode, DueMode := ""
    Gui, Due:Hide
    if (mode = "add")
        QuickAdd("S", DueWords)
}

#IfWinActive Daybook deadline ahk_class AutoHotkeyGUI
Escape::DueStepOut()
#IfWinActive
