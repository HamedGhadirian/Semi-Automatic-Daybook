;================================================================================
; CalGrid - the month calendar, drawn the Daybook way
;================================================================================
; One calendar for every window that shows days: the habit window and the
; deadline picker. A month at a time, Monday first, whatever Windows' region
; settings say:
;
;   <  November 2026  >      the arrows are text, dimmed when they lead nowhere
;   M  T  W  T  F  S  S
;   six rows of seven squares, each square a day
;
; Why not Windows' own calendar control (MonthCal): it takes the first day of
; the week from the region settings, it can only be coloured in its old
; Windows 95 look, and one click on it only highlights a day. This one looks
; like the rest of Daybook, and a day is a button.
;
; Each day is two controls: a coloured square, and the number on top of it. A
; Text control in v1 cannot be given a background colour of its own (only
; BackgroundTrans) - the first version tried, and every done day came out as
; dark text on the dark window, invisible. A Progress bar CAN, which is what
; the panel's top bar already is. The square is Disabled so that Windows looks
; straight past it for the click, to the number.
;
; The controls are named from a prefix, so the window that owns them keeps its
; own names: prefix "HabEd" makes HabEdPrev, HabEdMonthTxt, HabEdNext,
; HabEdSq1..42 and HabEdCell1..42.
;
; Dates are plain yyyy-MM-dd text and are only ever moved with DayShift and
; CalMonthShift - no table of month lengths, no 30-day guesses - so leap years
; and the turn of a year need nothing special, today or in 2040.
;================================================================================

; Build the grid. y is the top of the month line; the squares start 48 below
; it. The three labels are what a click on a day, the left arrow and the right
; arrow run. Returns the y just under the last row.
CalGridBuild(gui, p, L, y, cw, ch, gap, dayLabel, prevLabel, nextLabel) {
    global                               ; the controls' variables must be global
    local opt, k, r, name, gx, gy
    Gui, %gui%:Font, s10 Norm c%CText%, Segoe UI
    opt := "v" p "Prev g" prevLabel " x" L " y" y " w30 h24 +0x200 BackgroundTrans"
    Gui, %gui%:Add, Text, %opt%, % Chr(0x25C0)
    opt := "v" p "MonthTxt x" (L + 34) " y" y " w" (7 * (cw + gap) - 72) " h24 Center +0x200 BackgroundTrans"
    Gui, %gui%:Add, Text, %opt%
    opt := "v" p "Next g" nextLabel " x" (L + 7 * (cw + gap) - gap - 30) " y" y " w30 h24 Right +0x200 BackgroundTrans"
    Gui, %gui%:Add, Text, %opt%, % Chr(0x25B6)
    Gui, %gui%:Font, s8 Norm c%CDim%, Segoe UI
    for k, name in ["M", "T", "W", "T", "F", "S", "S"] {
        opt := "x" (L + (k - 1) * (cw + gap)) " y" (y + 30) " w" cw " h16 Center BackgroundTrans"
        Gui, %gui%:Add, Text, %opt%, %name%
    }
    Gui, %gui%:Font, s9 Norm c%CText%, Segoe UI
    Loop 42 {
        k := A_Index, r := (k - 1) // 7
        gx := L + Mod(k - 1, 7) * (cw + gap), gy := y + 48 + r * (ch + gap)
        opt := "v" p "Sq" k " x" gx " y" gy " w" cw " h" ch
             . " Disabled -E0x200 -Theme Background" CCard " c" CCard
        Gui, %gui%:Add, Progress, %opt%, 0
        opt := "v" p "Cell" k " g" dayLabel " x" gx " y" gy " w" cw " h" ch " Center +0x200 BackgroundTrans"
        Gui, %gui%:Add, Text, %opt%
    }
    return y + 48 + 6 * (ch + gap)
}

; The Monday on or before the 1st of a month (yyyy-MM): the first square.
; 2000-01-03 was a Monday, day number 2 (see WeekOf). The double Mod keeps a
; day before 2000 - a negative day number - on a Monday too.
CalGridStart(month) {
    first := month "-01"
    return DayShift(first, -Mod(Mod(DayNum(first) - 2, 7) + 7, 7))
}

; The month line and its two arrows. An arrow that leads nowhere is dimmed.
CalGridTitle(gui, p, month, canPrev, canNext) {
    global CText, CDim
    FormatTime, title, % StrReplace(month, "-") "01", MMMM yyyy
    GuiControl, %gui%:, %p%MonthTxt, %title%
    col := canPrev ? CText : CDim
    GuiControl, %gui%:+c%col%, %p%Prev
    GuiControl, %gui%:MoveDraw, %p%Prev
    col := canNext ? CText : CDim
    GuiControl, %gui%:+c%col%, %p%Next
    GuiControl, %gui%:MoveDraw, %p%Next
}

; One square: its colour, its number's colour, and the number ("" for none).
CalGridCell(gui, p, k, bg, fg, txt) {
    GuiControl, %gui%:+Background%bg%, %p%Sq%k%
    GuiControl, %gui%:+c%fg%, %p%Cell%k%
    GuiControl, %gui%:, %p%Cell%k%, %txt%
    GuiControl, %gui%:MoveDraw, %p%Cell%k%   ; on top of the new colour
}

; A month (yyyy-MM) moved by n months, either way, across years: "2026-12" and
; 1 is "2027-01". Whole-number arithmetic, nothing to drift.
CalMonthShift(month, n) {
    m := (SubStr(month, 1, 4) + 0) * 12 + (SubStr(month, 6, 2) - 1) + n
    y := m // 12, mo := Mod(m, 12) + 1
    return Format("{:04}-{:02}", y, mo)
}
