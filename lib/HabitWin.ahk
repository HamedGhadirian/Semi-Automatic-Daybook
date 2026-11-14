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
; The window holds the habit by NAME, not by its place in the list: a habit
; deleted or added while the window is open would move every place after it,
; and names are unique.
;================================================================================
#Requires AutoHotkey v2.0

HabEdShow(i) {
    global HabEdName, HabEdMonth, HabEdEnd
    h := HabitAt(i)
    if (!h)
        return
    if (!IsObject(HabEdGui))
        HabEdBuild()
    HabEdName := h.text
    HabEdMonth := SubStr(LogicalDay(), 1, 7)
    HabEdEnd := HabitDidToday(h) ? "today" : "yesterday"
    HabEdLoad()
    ; beside the panel, on whichever side has room - where the note box goes
    LivePanel(&px, &py, &pw, &ph)
    x := px - HabEdW - 8
    if (x < 10)
        x := px + pw + 8
    y := py
    ClampWin(&x, &y, HabEdW, HabEdH)
    SideOnTop(HabEdGui)
    HabEdGui.Show("x" x " y" y)
}

; Which habit the window is showing, as a place in the list now - or 0 if it
; has gone.
HabEdIndex() {
    return HabitIndex(HabEdName)
}

HabEdBuild() {
    global HabEdGui, HabEdHwnd, HabEdW, HabEdH, HabEdCells
    W := 360, L := 20, cw := 34, ch := 28, gap := 4
    HabEdCells := []
    g := Gui("+AlwaysOnTop -MaximizeBox -MinimizeBox", "Daybook habit")
    HabEdGui := g, HabEdHwnd := g.Hwnd
    KitTaskbar.Id(HabEdHwnd)              ; under the panel's taskbar button
    g.MarginX := 0, g.MarginY := 0
    g.BackColor := CBg
    g.OnEvent("Close", HabEdClose)
    g.OnEvent("Escape", HabEdClose)
    link := (opts, text, fn) => OnClicks(g.Add("Text", opts " BackgroundTrans", text), fn)

    g.SetFont("s11 Norm c" CText, "Segoe UI")
    g.Add("Edit", "vHabEdNameBox x" L " y16 w" (W - 2 * L) " h28 -E0x200 Background" CCard)

    ; ---- how often
    HabEdHead(L, 58, W, "HOW OFTEN")
    g.SetFont("s9 Norm c" CText, "Segoe UI")
    y := 84
    loop 3
        link("vHabEdDot" A_Index " x" L " y" (y + (A_Index - 1) * 26) " w18 h22 +0x200", "", HabEdPick.Bind(A_Index))
    link("vHabEdOpt1 x" (L + 20) " y" y " w120 h22 +0x200", "every day", HabEdPick.Bind(1))
    y += 26
    link("vHabEdOpt2 x" (L + 20) " y" y " w38 h22 +0x200", "every", HabEdPick.Bind(2))
    g.Add("Edit", "vHabEdN2 x" (L + 60) " y" (y + 1) " w30 h20 Number Limit2 Center -E0x200 Background" CCard)
        .OnEvent("Change", HabEdN.Bind("HabEdN2"))
    link("vHabEdOpt2b x" (L + 96) " y" y " w60 h22 +0x200", "days", HabEdPick.Bind(2))
    y += 26
    g.Add("Edit", "vHabEdN3 x" (L + 20) " y" (y + 1) " w30 h20 Number Limit1 Center -E0x200 Background" CCard)
        .OnEvent("Change", HabEdN.Bind("HabEdN3"))
    link("vHabEdOpt3 x" (L + 56) " y" y " w120 h22 +0x200", "times a week", HabEdPick.Bind(3))
    g.SetFont("s8 Norm c" CDim, "Segoe UI")
    g.Add("Text", "x" (L + 180) " y" (y - 50) " w" (W - L - 200) " h46 BackgroundTrans"
        , "A week is kept when it has that many days done. Weeks start on Monday.")
    ; A week-counted habit's streak in weeks or in days - its own choice.
    ; Only shown for one; see HabEdRule().
    g.Add("Text", "vHabEdUnitLbl x" (L + 180) " y" (y + 2) " w52 h18 BackgroundTrans", "count in")
    g.SetFont("s8 Norm c" CText, "Segoe UI")
    link("vHabEdUnitW x" (L + 232) " y" (y + 2) " w40 h18", "weeks", HabEdUnit.Bind("W"))
    link("vHabEdUnitD x" (L + 276) " y" (y + 2) " w40 h18", "days", HabEdUnit.Bind("D"))

    ; ---- the days
    HabEdHead(L, 170, W, "DAYS")
    ; the month itself is the shared grid (CalGrid.ahk); the week column
    ; beside it is this window's own
    CalGridBuild(g, "HabEd", L, 192, cw, ch, gap, HabEdDayClick, (*) => HabEdMove(-1), (*) => HabEdMove(1))
    g.SetFont("s8 Norm c" CDim, "Segoe UI")
    wx := L + 7 * (cw + gap) + 4
    g.Add("Text", "vHabEdWkHead x" wx " y222 w" (W - wx - L) " h16 Center BackgroundTrans", "week")
    g.SetFont("s8 Norm c" CText, "Segoe UI")
    loop 6
        g.Add("Text", "vHabEdWk" A_Index " x" wx " y" (240 + (A_Index - 1) * (ch + gap))
            . " w" (W - wx - L) " h" ch " Center +0x200 BackgroundTrans")
    y := 240 + 6 * (ch + gap) + 6

    ; the key, and how a click moves a day along
    g.SetFont("s8 Norm", "Segoe UI")
    HabEdKey(L,       y, CGreen, "done")
    HabEdKey(L + 64,  y, CBlue,  "rest day")
    HabEdKey(L + 144, y, CRed,   "missed")
    HabEdKey(L + 216, y, COff,   "not needed")
    g.SetFont("s8 Norm c" CDim, "Segoe UI")
    g.Add("Text", "x" L " y" (y + 18) " w" (W - 2 * L) " h16 BackgroundTrans"
        , "click a day:  done  " Chr(0x2192) "  rest day  " Chr(0x2192) "  not done")
    y += 46

    g.SetFont("s10 Bold c" CText, "Segoe UI")
    g.Add("Text", "vHabEdStats x" L " y" y " w" (W - 2 * L) " h20 BackgroundTrans")
    g.SetFont("s8 Norm c" CDim, "Segoe UI")
    g.Add("Text", "vHabEdRest x" L " y" (y + 22) " w" (W - 2 * L) " h16 BackgroundTrans")
    y += 50

    ; ---- a streak from somewhere else
    HabEdHead(L, y, W, "ALREADY HAD A STREAK?")
    y += 26
    g.SetFont("s9 Norm c" CText, "Segoe UI")
    g.Add("Edit", "vHabEdImp x" L " y" y " w52 h22 Number Limit5 Center -E0x200 Background" CCard)
    g.SetFont("s9 Norm c" CMuted, "Segoe UI")
    g.Add("Text", "x" (L + 58) " y" y " w92 h22 +0x200 BackgroundTrans", "days, ending")
    g.SetFont("s9 Norm c" CText, "Segoe UI")
    link("vHabEdEndTxt x" (L + 146) " y" y " w70 h22 +0x200", "", HabEdFlipEnd)
    g.SetFont("s9 Bold c" CGreen, "Segoe UI")
    link("x" (W - L - 70) " y" y " w70 h22 Right +0x200", "bring in", (*) => HabEdBringIn())
    g.SetFont("s8 Norm c" CDim, "Segoe UI")
    g.Add("Text", "x" L " y" (y + 24) " w" (W - 2 * L) " h30 BackgroundTrans"
        , "Marks that many days done, ending today or yesterday - click the word to switch. Days already there stay.")
    y += 60

    g.SetFont("s8 Norm c" CAmber, "Segoe UI")
    g.Add("Text", "vHabEdMsg x" L " y" y " w" (W - 2 * L) " h30 BackgroundTrans")
    y += 36

    g.SetFont("s9 Norm c" CRed, "Segoe UI")
    g.Add("Text", "x" L " y" y " w100 h22 +0x200 BackgroundTrans", "delete habit")
        .OnEvent("Click", (*) => HabEdDeleteHabit())
    g.SetFont("s9 Norm c" CText, "Segoe UI")
    g.Add("Text", "x" (W - L - 60) " y" y " w60 h22 Right +0x200 BackgroundTrans", "close")
        .OnEvent("Click", HabEdClose)
    y += 34

    Theme.TitleBar(HabEdHwnd)
    ShapeWindow(HabEdHwnd)
    g.Show("Hide w" W " h" y)
    HabEdW := W, HabEdH := y
}

; A section heading: blue, with a hairline under it - the settings window's.
HabEdHead(x, y, W, label) {
    HabEdGui.SetFont("s8 Bold c" CBlue, "Segoe UI")
    HabEdGui.Add("Text", "x" x " y" y " w" (W - 2 * x) " BackgroundTrans", label)
    HabEdRect(x, y + 17, W - 2 * x, 1, CTrack)
}

; A plain coloured rectangle.
HabEdRect(x, y, w, h, colour) {
    HabEdGui.Add("Text", "x" x " y" y " w" w " h" h " Background" colour)
}

; One swatch of the key under the calendar.
HabEdKey(x, y, colour, label) {
    HabEdRect(x, y + 3, 10, 10, colour)
    HabEdGui.SetFont("c" CDim)
    HabEdGui.Add("Text", "x" (x + 14) " y" y " w70 h16 BackgroundTrans", label)
}

;================================================================================
; Filling it in
;================================================================================
HabEdLoad() {
    global HabEdLoading, HabEdN2Was, HabEdN3Was
    i := HabEdIndex()
    if (!i)
        return
    h := Habits[i]
    g := HabEdGui
    HabEdLoading := 1
    g["HabEdNameBox"].Value := h.text
    ; What the two number boxes were filled with. Filling a box raises its
    ; Change event - possibly after this function has finished and the Loading
    ; flag is down again - so the flag alone could let the "3" put in the
    ; times-a-week box switch every habit opened here to three times a week.
    ; HabEdN compares against these instead: only a value that differs was
    ; typed by a person.
    HabEdN2Was := (h.kind = "D" && h.n > 1) ? h.n : 2
    HabEdN3Was := (h.kind = "W") ? h.n : 3
    g["HabEdN2"].Value := HabEdN2Was
    g["HabEdN3"].Value := HabEdN3Was
    g["HabEdImp"].Value := ""
    g["HabEdMsg"].Text := ""
    HabEdLoading := 0
    HabEdRule()
    HabEdPaint()
}

; The three ways, with the one in force lit.
HabEdRule() {
    i := HabEdIndex()
    if (!i)
        return
    h := Habits[i]
    g := HabEdGui
    pick := (h.kind = "W") ? 3 : (h.n > 1) ? 2 : 1
    loop 3 {
        on := (A_Index = pick)
        c := g["HabEdDot" A_Index]
        c.SetFont("c" (on ? CGreen : CDim))
        c.Text := on ? Chr(0x25CF) : Chr(0x25CB)
        c := g["HabEdOpt" A_Index]
        c.SetFont("c" (on ? CText : CMuted))
        c.Redraw()
    }
    g["HabEdOpt2b"].SetFont("c" ((pick = 2) ? CText : CMuted))
    g["HabEdOpt2b"].Redraw()
    ; weeks or days - only a week-counted habit has the choice
    for c in ["HabEdUnitLbl", "HabEdUnitW", "HabEdUnitD"]
        g[c].Visible := (pick = 3)
    days := (h.unit = "D")
    g["HabEdUnitW"].SetFont("c" (days ? CDim : CGreen))
    g["HabEdUnitW"].Redraw()
    g["HabEdUnitD"].SetFont("c" (days ? CGreen : CDim))
    g["HabEdUnitD"].Redraw()
}

HabEdUnit(unit, *) {
    if (i := HabEdIndex()) {
        HabitSetUnit(i, unit)
        HabEdRule()
        HabEdPaint()
    }
}

; The month, the week column, the numbers under them.
HabEdPaint() {
    global HabEdCells
    i := HabEdIndex()
    if (!i)
        return
    h := Habits[i]
    g := HabEdGui
    today := LogicalDay()
    start := CalGridStart(HabEdMonth)               ; the Monday on or before the 1st
    CalGridTitle(g, "HabEd", HabEdMonth
        , StrCompare(HabEdMonth, SubStr(h.born, 1, 7)) > 0, StrCompare(HabEdMonth, SubStr(today, 1, 7)) < 0)
    HabEdCells := []
    loop 42 {
        day := DayShift(start, A_Index - 1)
        mine := (SubStr(day, 1, 7) = HabEdMonth)
        HabEdCells.Push(mine ? day : "")
        if (!mine) {
            bg := CBg, fg := CBg, txt := ""
        } else {
            txt := Integer(SubStr(day, 9, 2))
            st := (StrCompare(day, today) > 0) ? "future" : HabitDayState(h, day, today)
            bg := CCard, fg := CText
            if (st = "done")
                bg := CGreen, fg := CBg
            else if (st = "rest")
                bg := CBlue, fg := CBg
            else if (st = "miss")
                bg := CRed, fg := CBg
            else if (st = "old")
                bg := COld
            else if (st = "future" || st = "none")
                bg := CBg, fg := CDim
            if (day = today && (st = "todo"))
                fg := CAmber
        }
        CalGridCell(g, "HabEd", A_Index, bg, fg, txt)
    }
    ; A week-counted habit: how each week of this month went.
    g["HabEdWkHead"].Visible := (h.kind = "W")
    loop 6 {
        monday := DayShift(start, (A_Index - 1) * 7)
        sunday := DayShift(monday, 6)
        txt := "", col := CDim
        if (h.kind = "W" && StrCompare(monday, today) <= 0 && StrCompare(sunday, h.born) >= 0
            && (SubStr(monday, 1, 7) = HabEdMonth || SubStr(sunday, 1, 7) = HabEdMonth)) {
            p := HabitWeekProgress(h, (StrCompare(sunday, today) < 0) ? sunday : today)
            if (p.need <= 0)
                txt := "rest", col := CBlue
            else if (p.done >= p.need)
                txt := Chr(0x2713) " " p.done, col := CGreen     ; kept - "7/3" read oddly
            else
                txt := p.done "/" p.need, col := (StrCompare(sunday, today) >= 0) ? CAmber : CRed
        }
        c := g["HabEdWk" A_Index]
        c.SetFont("c" col)
        c.Text := txt
    }
    ; A week-counted habit's streak is in WEEKS unless switched to days, and
    ; says which - 777 days kept three times a week is 112 weeks.
    unit := HabitInWeeks(h) ? " weeks" : " days"
    g["HabEdStats"].Text := "streak " RegExReplace(HabitStreakText(h), "w$") unit
        . "   " Chr(0x00B7) "   best " RegExReplace(HabitStreakText(h, true), "w$") unit
        . "   " Chr(0x00B7) "   " h.total " days done"
    used := 0
    for d in h.rest
        if (SubStr(d, 1, 7) = HabEdMonth)
            used++
    left := RestPerMonth - used
    g["HabEdRest"].Text := (RestPerMonth <= 0) ? "rest days are off - Settings, under HABITS"
        : "rest days left in " DayWords(HabEdMonth "-01", "MMMM") ": " (left < 0 ? 0 : left) " of " RestPerMonth
    g["HabEdEndTxt"].Text := HabEdEnd
}

HabEdSay(msg) {
    HabEdGui["HabEdMsg"].Text := msg
}

;================================================================================
; What the clicks do
;================================================================================
HabEdDayClick(k) {
    i := HabEdIndex()
    day := At(HabEdCells, k)
    if (!i || day = "")
        return
    h := Habits[i]
    if (StrCompare(day, LogicalDay()) > 0 || StrCompare(day, h.born) < 0) {
        HabEdSay((StrCompare(day, LogicalDay()) > 0) ? "That day has not happened yet."
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
        HabEdSay("No rest days left in " DayWords(day, "MMMM") " - there are " RestPerMonth
               . " a month (Settings, under HABITS). Marked not done instead.")
        HabitSetState(i, day, "none")
    }
    HabEdPaint()
}

HabEdMove(dir) {
    global HabEdMonth
    i := HabEdIndex()
    if (!i)
        return
    m := CalMonthShift(HabEdMonth, dir)
    if (StrCompare(m, SubStr(Habits[i].born, 1, 7)) < 0 || StrCompare(m, SubStr(LogicalDay(), 1, 7)) > 0)
        return
    HabEdMonth := m
    HabEdSay("")
    HabEdPaint()
}

; 1 every day, 2 every N days, 3 N times a week
HabEdPick(which, *) {
    i := HabEdIndex()
    if (!i)
        return
    n2 := HabEdGui["HabEdN2"].Value, n3 := HabEdGui["HabEdN3"].Value
    if (which = 1)
        HabitSetRule(i, "D", 1)
    else if (which = 2)
        HabitSetRule(i, "D", (IsNumber(n2) && n2 >= 2) ? n2 : 2)
    else
        HabitSetRule(i, "W", (IsNumber(n3) && n3 >= 1) ? n3 : 3)
    HabEdSay("")
    HabEdRule()
    HabEdPaint()
}

; A number typed into one of the two boxes picks that way - once the typing
; has stopped, so "12" is not first taken as "1".
HabEdN(name, *) {
    global HabEdTyped
    v := HabEdGui[name].Value
    if (HabEdLoading || v = "" || v = ((name = "HabEdN2") ? HabEdN2Was : HabEdN3Was))
        return                           ; the window filling it in, not a person
    HabEdTyped := name
    SetTimer(HabEdNApply, -700)
}

HabEdNApply() {
    global HabEdTyped, HabEdN2Was, HabEdN3Was
    if (HabEdTyped != "") {
        HabEdPick(HabEdTyped = "HabEdN2" ? 2 : 3)
        HabEdN2Was := HabEdGui["HabEdN2"].Value
        HabEdN3Was := HabEdGui["HabEdN3"].Value
    }
    HabEdTyped := ""
}

HabEdFlipEnd(*) {
    global HabEdEnd
    HabEdEnd := (HabEdEnd = "today") ? "yesterday" : "today"
    HabEdGui["HabEdEndTxt"].Text := HabEdEnd
}

HabEdBringIn() {
    global HabEdMonth
    i := HabEdIndex()
    if (!i)
        return
    days := HabEdGui["HabEdImp"].Value
    days := IsNumber(days) ? Integer(days) : 0
    if (days < 1) {
        HabEdSay("Type how many days the streak was, then bring it in.")
        return
    }
    last := (HabEdEnd = "today") ? LogicalDay() : DayShift(LogicalDay(), -1)
    HabitImport(i, days, last)
    HabEdGui["HabEdImp"].Value := ""
    HabEdMonth := SubStr(LogicalDay(), 1, 7)
    HabEdSay("Brought in " days " days, " DayShift(last, 1 - days) " to " last ".")
    HabEdPaint()
}

HabEdDeleteHabit() {
    i := HabEdIndex()
    if (!i)
        return
    name := Habits[i].text
    HabEdGui.Opt("+OwnDialogs")
    if (MsgBox("Delete " Chr(0x201C) name Chr(0x201D) " and all of its history?`n`n"
        . "The day notes keep what they said about it. Daybook cannot bring the streak back."
        , "Daybook", "YesNo Icon! Default2") = "Yes") {
        HabitDelete(i)
        HabEdGui.Hide()
    }
}

; The name is taken when the window closes, or on Enter - not letter by letter,
; which would log a rename for every key.
HabEdApplyName() {
    global HabEdName
    i := HabEdIndex()
    if (!i)
        return
    name := Trim(HabEdGui["HabEdNameBox"].Value)
    if (name != "" && !(name == HabEdName)) {
        HabitRename(i, name)
        HabEdName := name
    }
}

HabEdClose(*) {
    SetTimer(HabEdNApply, 0)
    HabEdNApply()                        ; a number still being typed counts
    HabEdApplyName()
    HabEdGui.Hide()
    return true                          ; closed here - not destroyed
}

#HotIf WinActive("Daybook habit ahk_class AutoHotkeyGUI")
; Enter in the streak box brings it in; anywhere else it takes the name.
Enter::
NumpadEnter:: {
    foc := ""
    try foc := HabEdGui.FocusedCtrl.Name
    if (foc = "HabEdImp")
        HabEdBringIn()
    else {
        HabEdApplyName()
        HabEdSay("")
    }
}
#HotIf
