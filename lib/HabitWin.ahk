;================================================================================
; The habit window - right-click a habit -> Edit habit...
;================================================================================
; Everything about one habit in one place:
;
;   its name
;   HOW OFTEN     every day / every N days / N times a week
;   DAYS          a month at a time, Monday first. Click a day and it goes
;                 done -> rest day -> not done. Any day since the habit
;                 began, back as far as you like. A week-counted habit has a
;                 column at the right saying how each week went: 2/3.
;   the streak, the best, the days done, and the rest days left this month
;   already had a streak?  - N days, brought in from wherever you kept it
;
; The panel's dots stay simple - one click, done or not - and rest days are only
; made here, where it is a choice rather than a slip.
;
; The window holds the habit by NAME, not by its place in the list: a habit
; deleted or added while the window is open would move every place after it,
; and names are unique.
;================================================================================
HabEdShow(i) {
    global Habits, HabEdBuilt, HabEdName, HabEdMonth, HabEdHwnd, HabEdEnd, HabEdW, HabEdH
    h := Habits[i]
    if (!h)
        return
    if (!HabEdBuilt)
        HabEdBuild()
    HabEdName := h.text
    HabEdMonth := SubStr(LogicalDay(), 1, 7)
    HabEdEnd := HabitDidToday(h) ? "today" : "yesterday"
    HabEdLoad()
    ; beside the panel, on whichever side has room - where the note box goes
    LivePanel(px, py, pw, ph)
    ww := HabEdW, wh := HabEdH
    x := px - ww - 8
    if (x < 10)
        x := px + pw + 8
    y := py
    ClampWin(x, y, ww, wh)
    SideOnTop("HabEd")
    Gui, HabEd:Show, x%x% y%y%, Daybook habit
}

; Which habit the window is showing, as a place in the list now - or 0 if it
; has gone.
HabEdIndex() {
    global HabEdName
    return HabitIndex(HabEdName)
}

HabEdBuild() {
    global
    local W := 360, L := 20, cw := 34, ch := 28, gap := 4, y, k, r, opt, wx
    HabEdCells := []
    Gui, HabEd:New, +AlwaysOnTop -MaximizeBox -MinimizeBox +LabelHabEd +HwndHabEdHwnd, Daybook habit
    TaskbarId(HabEdHwnd, "Ahk.Daybook")   ; under the panel's taskbar button
    Gui, HabEd:Margin, 0, 0
    Gui, HabEd:Color, %CBg%, %CCard%

    Gui, HabEd:Font, s11 Norm c%CText%, Segoe UI
    opt := "vHabEdNameBox x" L " y16 w" (W - 2 * L) " h28 -E0x200"
    Gui, HabEd:Add, Edit, %opt%

    ; ---- how often
    HabEdHead(L, 58, W, "HOW OFTEN")
    Gui, HabEd:Font, s9 Norm c%CText%, Segoe UI
    y := 84
    Loop 3 {
        opt := "vHabEdDot" A_Index " gHabEdOpt x" L " y" (y + (A_Index - 1) * 26) " w18 h22 +0x200 BackgroundTrans"
        Gui, HabEd:Add, Text, %opt%
    }
    opt := "vHabEdOpt1 gHabEdOpt x" (L + 20) " y" y " w120 h22 +0x200 BackgroundTrans"
    Gui, HabEd:Add, Text, %opt%, every day
    y += 26
    opt := "vHabEdOpt2 gHabEdOpt x" (L + 20) " y" y " w38 h22 +0x200 BackgroundTrans"
    Gui, HabEd:Add, Text, %opt%, every
    opt := "vHabEdN2 gHabEdN x" (L + 60) " y" (y + 1) " w30 h20 Number Limit2 Center -E0x200"
    Gui, HabEd:Add, Edit, %opt%
    opt := "vHabEdOpt2b gHabEdOpt x" (L + 96) " y" y " w60 h22 +0x200 BackgroundTrans"
    Gui, HabEd:Add, Text, %opt%, days
    y += 26
    opt := "vHabEdN3 gHabEdN x" (L + 20) " y" (y + 1) " w30 h20 Number Limit1 Center -E0x200"
    Gui, HabEd:Add, Edit, %opt%
    opt := "vHabEdOpt3 gHabEdOpt x" (L + 56) " y" y " w120 h22 +0x200 BackgroundTrans"
    Gui, HabEd:Add, Text, %opt%, times a week
    Gui, HabEd:Font, s8 Norm c%CDim%, Segoe UI
    opt := "x" (L + 180) " y" (y - 50) " w" (W - L - 200) " h46 BackgroundTrans"
    Gui, HabEd:Add, Text, %opt%, % "A week is kept when it has that many days"
        . " done. Weeks start on Monday."
    ; A week-counted habit's streak in weeks or in days - its own choice.
    ; Only shown for one; see HabEdRule().
    opt := "vHabEdUnitLbl x" (L + 180) " y" (y + 2) " w52 h18 BackgroundTrans"
    Gui, HabEd:Add, Text, %opt%, count in
    Gui, HabEd:Font, s8 Norm c%CText%, Segoe UI
    opt := "vHabEdUnitW gHabEdUnit x" (L + 232) " y" (y + 2) " w40 h18 BackgroundTrans"
    Gui, HabEd:Add, Text, %opt%, weeks
    opt := "vHabEdUnitD gHabEdUnit x" (L + 276) " y" (y + 2) " w40 h18 BackgroundTrans"
    Gui, HabEd:Add, Text, %opt%, days

    ; ---- the days
    HabEdHead(L, 170, W, "DAYS")
    ; the month itself is the shared grid (CalGrid.ahk); the week column
    ; beside it is this window's own
    CalGridBuild("HabEd", "HabEd", L, 192, cw, ch, gap, "HabEdDay", "HabEdPrev", "HabEdNext")
    Gui, HabEd:Font, s8 Norm c%CDim%, Segoe UI
    wx := L + 7 * (cw + gap) + 4
    opt := "vHabEdWkHead x" wx " y222 w" (W - wx - L) " h16 Center BackgroundTrans"
    Gui, HabEd:Add, Text, %opt%, week
    Gui, HabEd:Font, s8 Norm c%CText%, Segoe UI
    Loop 6 {
        opt := "vHabEdWk" A_Index " x" wx " y" (240 + (A_Index - 1) * (ch + gap))
             . " w" (W - wx - L) " h" ch " Center +0x200 BackgroundTrans"
        Gui, HabEd:Add, Text, %opt%
    }
    y := 240 + 6 * (ch + gap) + 6

    ; the key, and how a click moves a day along
    Gui, HabEd:Font, s8 Norm, Segoe UI
    HabEdKey(L,       y, CGreen, "done")
    HabEdKey(L + 64,  y, CBlue,  "rest day")
    HabEdKey(L + 144, y, CRed,   "missed")
    HabEdKey(L + 216, y, "3A4052", "not needed")
    Gui, HabEd:Font, s8 Norm c%CDim%, Segoe UI
    opt := "x" L " y" (y + 18) " w" (W - 2 * L) " h16 BackgroundTrans"
    Gui, HabEd:Add, Text, %opt%, % "click a day:  done  " Chr(0x2192) "  rest day  "
        . Chr(0x2192) "  not done"
    y += 46

    Gui, HabEd:Font, s10 Bold c%CText%, Segoe UI
    opt := "vHabEdStats x" L " y" y " w" (W - 2 * L) " h20 BackgroundTrans"
    Gui, HabEd:Add, Text, %opt%
    Gui, HabEd:Font, s8 Norm c%CDim%, Segoe UI
    opt := "vHabEdRest x" L " y" (y + 22) " w" (W - 2 * L) " h16 BackgroundTrans"
    Gui, HabEd:Add, Text, %opt%
    y += 50

    ; ---- a streak from somewhere else
    HabEdHead(L, y, W, "ALREADY HAD A STREAK?")
    y += 26
    Gui, HabEd:Font, s9 Norm c%CText%, Segoe UI
    opt := "vHabEdImp x" L " y" y " w52 h22 Number Limit5 Center -E0x200"
    Gui, HabEd:Add, Edit, %opt%
    Gui, HabEd:Font, s9 Norm c%CMuted%, Segoe UI
    opt := "x" (L + 58) " y" y " w92 h22 +0x200 BackgroundTrans"
    Gui, HabEd:Add, Text, %opt%, days, ending
    Gui, HabEd:Font, s9 Norm c%CText%, Segoe UI
    opt := "vHabEdEndTxt gHabEdEnd x" (L + 146) " y" y " w70 h22 +0x200 BackgroundTrans"
    Gui, HabEd:Add, Text, %opt%
    Gui, HabEd:Font, s9 Bold c%CGreen%, Segoe UI
    opt := "gHabEdImport x" (W - L - 70) " y" y " w70 h22 Right +0x200 BackgroundTrans"
    Gui, HabEd:Add, Text, %opt%, bring in
    Gui, HabEd:Font, s8 Norm c%CDim%, Segoe UI
    opt := "x" L " y" (y + 24) " w" (W - 2 * L) " h30 BackgroundTrans"
    Gui, HabEd:Add, Text, %opt%, % "Marks that many days done, ending today or yesterday"
        . " - click the word to switch. Days already there stay."
    y += 60

    Gui, HabEd:Font, s8 Norm c%CAmber%, Segoe UI
    opt := "vHabEdMsg x" L " y" y " w" (W - 2 * L) " h30 BackgroundTrans"
    Gui, HabEd:Add, Text, %opt%
    y += 36

    Gui, HabEd:Font, s9 Norm c%CRed%, Segoe UI
    opt := "gHabEdDelete x" L " y" y " w100 h22 +0x200 BackgroundTrans"
    Gui, HabEd:Add, Text, %opt%, delete habit
    Gui, HabEd:Font, s9 Norm c%CText%, Segoe UI
    opt := "gHabEdClose x" (W - L - 60) " y" y " w60 h22 Right +0x200 BackgroundTrans"
    Gui, HabEd:Add, Text, %opt%, close
    y += 34

    SetupDark(HabEdHwnd)
    ShapeWindow(HabEdHwnd, PanelRound)
    Gui, HabEd:Show, Hide w%W% h%y%, Daybook habit
    HabEdW := W, HabEdH := y
    HabEdBuilt := 1
}

; A section heading: blue, with a hairline under it - the settings window's.
HabEdHead(x, y, W, label) {
    global CBlue, CTrack
    Gui, HabEd:Font, s8 Bold c%CBlue%, Segoe UI
    opt := "x" x " y" y " w" (W - 2 * x) " BackgroundTrans"
    Gui, HabEd:Add, Text, %opt%, %label%
    HabEdRect(x, y + 17, W - 2 * x, 1, CTrack)
}

; A plain coloured rectangle - a Progress bar, the one control v1 will colour.
HabEdRect(x, y, w, h, colour) {
    opt := "x" x " y" y " w" w " h" h " Disabled -E0x200 -Theme Background" colour " c" colour
    Gui, HabEd:Add, Progress, %opt%, 0
}

; One swatch of the key under the calendar.
HabEdKey(x, y, colour, label) {
    global CDim
    HabEdRect(x, y + 3, 10, 10, colour)
    opt := "x" (x + 14) " y" y " w70 h16 c" CDim " BackgroundTrans"
    Gui, HabEd:Add, Text, %opt%, %label%
}

;================================================================================
; Filling it in
;================================================================================
HabEdLoad() {
    global Habits, HabEdLoading
    i := HabEdIndex()
    if (!i)
        return
    h := Habits[i]
    HabEdLoading := 1
    GuiControl, HabEd:, HabEdNameBox, % h.text
    ; What the two number boxes were filled with. Filling a box fires its
    ; g-label - LATE, after this function has finished and the Loading flag is
    ; down again - so the flag alone let the "3" put in the times-a-week box
    ; switch every habit opened here to three times a week. HabEdN compares
    ; against these instead: only a value that differs was typed by a person.
    HabEdN2Was := (h.kind = "D" && h.n > 1) ? h.n : 2
    HabEdN3Was := (h.kind = "W") ? h.n : 3
    GuiControl, HabEd:, HabEdN2, %HabEdN2Was%
    GuiControl, HabEd:, HabEdN3, %HabEdN3Was%
    GuiControl, HabEd:, HabEdImp,
    GuiControl, HabEd:, HabEdMsg,
    HabEdLoading := 0
    HabEdRule()
    HabEdPaint()
}

; The three ways, with the one in force lit.
HabEdRule() {
    global Habits, CGreen, CDim, CText, CMuted
    i := HabEdIndex()
    if (!i)
        return
    h := Habits[i]
    pick := (h.kind = "W") ? 3 : (h.n > 1) ? 2 : 1
    Loop 3 {
        on := (A_Index = pick)
        col := on ? CGreen : CDim
        GuiControl, HabEd:+c%col%, HabEdDot%A_Index%
        GuiControl, HabEd:, HabEdDot%A_Index%, % on ? Chr(0x25CF) : Chr(0x25CB)
        col := on ? CText : CMuted
        GuiControl, HabEd:+c%col%, HabEdOpt%A_Index%
        GuiControl, HabEd:MoveDraw, HabEdOpt%A_Index%
    }
    col := (pick = 2) ? CText : CMuted
    GuiControl, HabEd:+c%col%, HabEdOpt2b
    GuiControl, HabEd:MoveDraw, HabEdOpt2b
    ; weeks or days - only a week-counted habit has the choice
    show := (pick = 3) ? "Show" : "Hide"
    for _, c in ["HabEdUnitLbl", "HabEdUnitW", "HabEdUnitD"]
        GuiControl, HabEd:%show%, %c%
    days := (h.unit = "D")
    col := days ? CDim : CGreen
    GuiControl, HabEd:+c%col%, HabEdUnitW
    GuiControl, HabEd:MoveDraw, HabEdUnitW
    col := days ? CGreen : CDim
    GuiControl, HabEd:+c%col%, HabEdUnitD
    GuiControl, HabEd:MoveDraw, HabEdUnitD
}

HabEdUnit:
    if (HabEdI := HabEdIndex()) {
        HabitSetUnit(HabEdI, (A_GuiControl = "HabEdUnitD") ? "D" : "W")
        HabEdRule()
        HabEdPaint()
    }
Return

; The month, the week column, the numbers under them.
HabEdPaint() {
    global Habits, HabEdMonth, HabEdCells, HabEdEnd, RestPerMonth
    global CBg, CCard, CText, CDim, CMuted, CGreen, CBlue, CRed, CAmber
    i := HabEdIndex()
    if (!i)
        return
    h := Habits[i]
    today := LogicalDay()
    start := CalGridStart(HabEdMonth)               ; the Monday on or before the 1st
    CalGridTitle("HabEd", "HabEd", HabEdMonth
        , HabEdMonth > SubStr(h.born, 1, 7), HabEdMonth < SubStr(today, 1, 7))
    Loop 42 {
        day := DayShift(start, A_Index - 1)
        mine := (SubStr(day, 1, 7) = HabEdMonth)
        HabEdCells[A_Index] := mine ? day : ""
        if (!mine) {
            bg := CBg, fg := CBg, txt := ""
        } else {
            txt := SubStr(day, 9, 2) + 0
            st := (day > today) ? "future" : HabitDayState(h, day, today)
            bg := CCard, fg := CText
            if (st = "done")
                bg := CGreen, fg := CBg
            else if (st = "rest")
                bg := CBlue, fg := CBg
            else if (st = "miss")
                bg := CRed, fg := CBg
            else if (st = "old")
                bg := "8A2A3C"
            else if (st = "future" || st = "none")
                bg := CBg, fg := CDim
            if (day = today && (st = "todo"))
                fg := CAmber
        }
        CalGridCell("HabEd", "HabEd", A_Index, bg, fg, txt)
    }
    ; A week-counted habit: how each week of this month went.
    GuiControl, % "HabEd:" (h.kind = "W" ? "Show" : "Hide"), HabEdWkHead
    Loop 6 {
        monday := DayShift(start, (A_Index - 1) * 7)
        sunday := DayShift(monday, 6)
        txt := "", col := CDim
        if (h.kind = "W" && monday <= today && sunday >= h.born
            && (SubStr(monday, 1, 7) = HabEdMonth || SubStr(sunday, 1, 7) = HabEdMonth)) {
            p := HabitWeekProgress(h, (sunday < today) ? sunday : today)
            if (p.need <= 0)
                txt := "rest", col := CBlue
            else if (p.done >= p.need)
                txt := Chr(0x2713) " " p.done, col := CGreen     ; kept - "7/3" read oddly
            else
                txt := p.done "/" p.need, col := (sunday >= today) ? CAmber : CRed
        }
        GuiControl, HabEd:+c%col%, HabEdWk%A_Index%
        GuiControl, HabEd:, HabEdWk%A_Index%, %txt%
    }
    ; A week-counted habit's streak is in WEEKS unless switched to days, and
    ; says which - 777 days kept three times a week is 112 weeks.
    unit := HabitInWeeks(h) ? " weeks" : " days"
    GuiControl, HabEd:, HabEdStats, % "streak " RegExReplace(HabitStreakText(h), "w$") unit
        . "   " Chr(0x00B7) "   best " RegExReplace(HabitStreakText(h, true), "w$") unit
        . "   " Chr(0x00B7) "   " h.total " days done"
    used := 0
    for _, d in h.rest
        if (SubStr(d, 1, 7) = HabEdMonth)
            used++
    FormatTime, mname, % StrReplace(HabEdMonth, "-") "01", MMMM
    left := RestPerMonth - used
    GuiControl, HabEd:, HabEdRest, % (RestPerMonth <= 0) ? "rest days are off - Settings, under HABITS"
        : "rest days left in " mname ": " (left < 0 ? 0 : left) " of " RestPerMonth
    GuiControl, HabEd:, HabEdEndTxt, %HabEdEnd%
}

HabEdSay(msg) {
    GuiControl, HabEd:, HabEdMsg, %msg%
}

;================================================================================
; What the clicks do
;================================================================================
HabEdDay:
    HabEdDayClick(SubStr(A_GuiControl, 10))
Return

HabEdDayClick(k) {
    global Habits, HabEdCells, HabEdMonth, RestPerMonth
    i := HabEdIndex()
    day := HabEdCells[k]
    if (!i || day = "")
        return
    h := Habits[i]
    if (day > LogicalDay() || day < h.born) {
        HabEdSay((day > LogicalDay()) ? "That day has not happened yet."
               : "The habit had not started yet. To reach back further, bring in a streak below.")
        return
    }
    HabEdSay("")
    ; done -> rest day -> not done -> done
    if (HabitDid(h, day))
        next := "rest"
    else if (HabitRested(h, day))
        next := "none"
    else
        next := "done"
    if (!HabitSetState(i, day, next)) {
        ; no rest day left this month: the click takes it straight to not done
        FormatTime, mname, % StrReplace(SubStr(day, 1, 7), "-") "01", MMMM
        HabEdSay("No rest days left in " mname " - there are " RestPerMonth
               . " a month (Settings, under HABITS). Marked not done instead.")
        HabitSetState(i, day, "none")
    }
    HabEdPaint()
}

HabEdPrev:
    HabEdMove(-1)
Return

HabEdNext:
    HabEdMove(1)
Return

HabEdMove(dir) {
    global Habits, HabEdMonth
    i := HabEdIndex()
    if (!i)
        return
    m := CalMonthShift(HabEdMonth, dir)
    if (m <SubStr(Habits[i].born, 1, 7) || m > SubStr(LogicalDay(), 1, 7))
        return
    HabEdMonth := m
    HabEdSay("")
    HabEdPaint()
}

HabEdOpt:
    HabEdPick(SubStr(A_GuiControl, 9, 1))
Return

; 1 every day, 2 every N days, 3 N times a week
HabEdPick(which) {
    i := HabEdIndex()
    if (!i)
        return
    GuiControlGet, n2, HabEd:, HabEdN2
    GuiControlGet, n3, HabEd:, HabEdN3
    if (which = 1)
        HabitSetRule(i, "D", 1)
    else if (which = 2)
        HabitSetRule(i, "D", (n2 >= 2) ? n2 : 2)
    else
        HabitSetRule(i, "W", (n3 >= 1) ? n3 : 3)
    HabEdSay("")
    HabEdRule()
    HabEdPaint()
}

; A number typed into one of the two boxes picks that way - once the typing
; has stopped, so "12" is not first taken as "1".
HabEdN:
    GuiControlGet, HabEdV, HabEd:, %A_GuiControl%
    if (HabEdLoading || HabEdV = "" || HabEdV = ((A_GuiControl = "HabEdN2") ? HabEdN2Was : HabEdN3Was))
        return                           ; the window filling it in, not a person
    HabEdTyped := A_GuiControl
    SetTimer, HabEdNApply, -700
Return

HabEdNApply:
    if (HabEdTyped != "") {
        HabEdPick(HabEdTyped = "HabEdN2" ? 2 : 3)
        GuiControlGet, HabEdN2Was, HabEd:, HabEdN2
        GuiControlGet, HabEdN3Was, HabEd:, HabEdN3
    }
    HabEdTyped := ""
Return

HabEdEnd:
    HabEdEnd := (HabEdEnd = "today") ? "yesterday" : "today"
    GuiControl, HabEd:, HabEdEndTxt, %HabEdEnd%
Return

HabEdImport:
    HabEdBringIn()
Return

HabEdBringIn() {
    global HabEdEnd, HabEdMonth
    i := HabEdIndex()
    if (!i)
        return
    GuiControlGet, days, HabEd:, HabEdImp
    days := days + 0
    if (days < 1) {
        HabEdSay("Type how many days the streak was, then bring it in.")
        return
    }
    last := (HabEdEnd = "today") ? LogicalDay() : DayShift(LogicalDay(), -1)
    HabitImport(i, days, last)
    GuiControl, HabEd:, HabEdImp,
    HabEdMonth := SubStr(LogicalDay(), 1, 7)
    HabEdSay("Brought in " days " days, " DayShift(last, 1 - days) " to " last ".")
    HabEdPaint()
}

HabEdDelete:
    HabEdDeleteHabit()
Return

HabEdDeleteHabit() {
    global Habits, HabEdHwnd
    i := HabEdIndex()
    if (!i)
        return
    name := Habits[i].text
    Gui, HabEd:+OwnDialogs
    MsgBox, 0x134, Daybook, % "Delete " Chr(0x201C) name Chr(0x201D) " and all of its"
        . " history?`n`nThe day notes keep what they said about it. Daybook cannot bring"
        . " the streak back."
    IfMsgBox, Yes
    {
        HabitDelete(i)
        Gui, HabEd:Hide
    }
}

; The name is taken when the window closes, or on Enter - not letter by letter,
; which would log a rename for every key.
HabEdApplyName() {
    global HabEdName
    i := HabEdIndex()
    if (!i)
        return
    GuiControlGet, name, HabEd:, HabEdNameBox
    name := Trim(name)
    if (name != "" && !(name == HabEdName)) {
        HabitRename(i, name)
        HabEdName := name
    }
}

HabEdClose:
HabEdEscape:
    SetTimer, HabEdNApply, Off
    Gosub, HabEdNApply                   ; a number still being typed counts
    HabEdApplyName()
    Gui, HabEd:Hide
Return

#IfWinActive Daybook habit ahk_class AutoHotkeyGUI
; Enter in the streak box brings it in; anywhere else it takes the name.
Enter::
NumpadEnter::
    GuiControlGet, HabEdFocus, HabEd:FocusV
    if (HabEdFocus = "HabEdImp")
        HabEdBringIn()
    else {
        HabEdApplyName()
        HabEdSay("")
    }
Return
#IfWinActive
