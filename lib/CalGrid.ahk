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
; Each day is one Text control: its background is the square's colour and its
; text the number, centred. (v1 could not colour a Text control's background,
; so each day was a Progress bar with a number laid on top; v2 can.)
;
; The controls are named from a prefix, so the window that owns them keeps its
; own names: prefix "HabEd" makes HabEdPrev, HabEdMonthTxt, HabEdNext and
; HabEdCell1..42.
;
; Dates are plain yyyy-MM-dd text and are only ever moved with DayShift and
; CalMonthShift - no table of month lengths, no 30-day guesses - so leap years
; and the turn of a year need nothing special, today or in 2040.
;================================================================================
#Requires AutoHotkey v2.0

; Build the grid on window g. y is the top of the month line; the squares start
; 48 below it. onDay(k) is called with the square's number (1-42) when a day
; is clicked, onPrev and onNext for the arrows. Returns the y just under the
; last row.
CalGridBuild(g, p, L, y, cw, ch, gap, onDay, onPrev, onNext) {
    g.SetFont("s10 Norm c" CText, "Segoe UI")
    OnClicks(g.Add("Text", "v" p "Prev x" L " y" y " w30 h24 +0x200 BackgroundTrans", Chr(0x25C0)), onPrev)
    g.Add("Text", "v" p "MonthTxt x" (L + 34) " y" y " w" (7 * (cw + gap) - 72) " h24 Center +0x200 BackgroundTrans")
    OnClicks(g.Add("Text", "v" p "Next x" (L + 7 * (cw + gap) - gap - 30) " y" y " w30 h24 Right +0x200 BackgroundTrans", Chr(0x25B6)), onNext)
    g.SetFont("s8 Norm c" CDim, "Segoe UI")
    for k, name in ["M", "T", "W", "T", "F", "S", "S"]
        g.Add("Text", "x" (L + (k - 1) * (cw + gap)) " y" (y + 30) " w" cw " h16 Center BackgroundTrans", name)
    g.SetFont("s9 Norm c" CText, "Segoe UI")
    loop 42 {
        k := A_Index, r := (k - 1) // 7
        gx := L + Mod(k - 1, 7) * (cw + gap), gy := y + 48 + r * (ch + gap)
        c := g.Add("Text", "v" p "Cell" k " x" gx " y" gy " w" cw " h" ch " Center +0x200 Background" CCard)
        OnClicks(c, CalGridClick.Bind(onDay, k))       ; a quick second click is a click too
    }
    return y + 48 + 6 * (ch + gap)
}

CalGridClick(onDay, k, *) => onDay.Call(k)

; The Monday on or before the 1st of a month (yyyy-MM): the first square.
; 2000-01-03 was a Monday, day number 2 (see WeekOf). The double Mod keeps a
; day before 2000 - a negative day number - on a Monday too.
CalGridStart(month) {
    first := month "-01"
    return DayShift(first, -Mod(Mod(DayNum(first) - 2, 7) + 7, 7))
}

; The month line and its two arrows. An arrow that leads nowhere is dimmed.
CalGridTitle(g, p, month, canPrev, canNext) {
    g[p "MonthTxt"].Text := DayWords(month "-01", "MMMM yyyy")
    for which, on in Map("Prev", canPrev, "Next", canNext) {
        c := g[p which]
        c.SetFont("c" (on ? CText : CDim))
        c.Redraw()
    }
}

; One square: its colour, its number's colour, and the number ("" for none).
CalGridCell(g, p, k, bg, fg, txt) {
    c := g[p "Cell" k]
    c.Opt("Background" bg)
    c.SetFont("c" fg)
    c.Text := txt
    c.Redraw()
}

; A month (yyyy-MM) moved by n months, either way, across years: "2026-12" and
; 1 is "2027-01". Whole-number arithmetic, nothing to drift.
CalMonthShift(month, n) {
    m := Integer(SubStr(month, 1, 4)) * 12 + (Integer(SubStr(month, 6, 2)) - 1) + n
    y := m // 12, mo := Mod(m, 12) + 1
    return Format("{:04}-{:02}", y, mo)
}
