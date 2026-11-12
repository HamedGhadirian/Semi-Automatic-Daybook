;================================================================================
; Laying the panel out - where every section and row ends up
;================================================================================
; Lay out whatever is open, top to bottom: JOURNAL (while the journal is on),
; HABITS, MISSED (only when there is something in it), TODAY'S TASKS, LONG
; TERM TASKS, TIME AT THE MACHINE.
;
; The journal heads the panel - one line, the door to the day's writing. Then
; habits, because they are the part that is the same every morning -
; a list you glance at and clear, above the list you think about. The two task
; lists share one pool of row controls, so a row's index in the pool has
; nothing to do with which task is in it.
Relayout() {
    global
    Gui, Panel:Default
    used := 0
    habUsed := 0
    ; RowTask too: a pool row left over from a longer list would otherwise still
    ; claim a task, and EditNote could find it there, with no y to go with it
    RowY := [], RowTask := [], Cards := [], Dots := []

    ; How tall the panel will be has to be known BEFORE anything is placed,
    ; because the footer line is what everything has to stop above - and it is
    ; only known from the content, which is not laid out yet. So it starts from
    ; last time's answer and is corrected below, laying out a second and final
    ; time if the guess was wrong. PanelRelaying makes that twice, never more.
    room := PanelRoom()
    panH := (PanelContentH > 0 && PanelContentH < room) ? PanelContentH : room
    PanelFootLine := panH - PanelFootH

    y := 13
    ; The status keeps the left edge; the other three hang off the right one,
    ; so the top row follows the width the way every heading row does.
    GuiControl, Panel:Move, StatusTxt, % "y" y
    GuiControl, Panel:Move, TimerTxt,  % "x" (HdrNumR - 170) " y" y " w118"
    GuiControl, Panel:Move, ModeTxt,   % "x" (HdrNumR - 50) " y" y " w12"
    GuiControl, Panel:Move, BreakBtn,  % "x" (HdrNumR - 48) " y" (y + 1) " w48"
    y += 24

    ; From here down, everything is placed against y - so starting y further up
    ; the page IS the scroll, and every card rectangle, dot and hit test comes
    ; out right without knowing anything about it. The four controls above keep
    ; their own y and never move: the bar and the minutes are what the panel is
    ; for, and a readout you have to scroll to is not a readout.
    y -= PanelScrollY

    ; ---- Journal - first, a heading that opens a window, nothing under it
    if (JournalOn) {
        PlaceHdr(y, 20, {"JrnHdr": "y" y
                   , "JrnCnt": "x" (HdrNumR - 96) " y" (y + 2) " w96"})
        y += 22
    } else {
        GuiControl, Panel:Hide, JrnHdr
        GuiControl, Panel:Hide, JrnCnt
    }

    ; ---- Habits
    PlaceHdr(y, 20, {"HabHdr": "y" y
               , "HabCnt": "x" (HdrNumR - 112) " y" (y + 2) " w36"
               , "HabAdd": "x" (HdrNumR - 24) " y" (y - 2) " w24"})
    GuiControl, Panel:, HabHdr, % Caret(OpenHabits) " HABITS"
    y += 22
    if (OpenHabits)
        habUsed := PlaceHabits(y)
    Loop % HabPool {
        if (A_Index > habUsed)
            HideHab(A_Index)
    }

    ; ---- Missed - just above Today, because what it asks is what goes on it
    if (nMiss) {
        PlaceHdr(y, 20, {"MissHdr": "y" y
                   , "MissCnt": "x" (HdrNumR - 102) " y" (y + 2) " w26"})
        GuiControl, Panel:, MissHdr, % Caret(OpenMissed) " MISSED"
        y += 22
        if (OpenMissed)
            used := PlaceRows("M", y, used)
    } else {
        GuiControl, Panel:Hide, MissHdr
        GuiControl, Panel:Hide, MissCnt
    }

    ; ---- Today
    PlaceHdr(y, 20, {"TodayHdr": "y" y
               , "TodayCnt": "x" (HdrNumR - 102) " y" (y + 2) " w26"
               , "AddBtn":   "x" (HdrNumR - 24) " y" (y - 2) " w24"})
    GuiControl, Panel:, TodayHdr, % Caret(OpenToday) " TODAY'S TASKS"
    y += 22
    if (OpenToday)
        used := PlaceRows("T", y, used)

    ; ---- Short term - a deadline each, soonest first
    PlaceHdr(y, 20, {"ShortHdr": "y" y
               , "ShortCnt": "x" (HdrNumR - 102) " y" (y + 2) " w26"
               , "ShortAdd": "x" (HdrNumR - 24) " y" (y - 2) " w24"})
    GuiControl, Panel:, ShortHdr, % Caret(OpenShort) " SHORT TERM TASKS"
    y += 22
    if (OpenShort)
        used := PlaceRows("S", y, used)

    ; ---- Long term
    PlaceHdr(y, 20, {"LongHdr": "y" y
               , "LongCnt": "x" (HdrNumR - 102) " y" (y + 2) " w26"
               , "LongAdd": "x" (HdrNumR - 24) " y" (y - 2) " w24"})
    GuiControl, Panel:, LongHdr, % Caret(OpenLong) " LONG TERM TASKS"
    y += 22
    if (OpenLong)
        used := PlaceRows("L", y, used)

    ; ---- Today so far
    PlaceHdr(y, 20, {"StatsHdr":   "y" y
               , "StatsTotal": "x" (HdrNumR - 96) " y" (y + 2) " w96"})
    GuiControl, Panel:, StatsHdr, % Caret(OpenStats) " TIME AT THE MACHINE"
    y += 20
    UpdateStats()
    if (OpenStats) {
        StatsShown := StatsLines()
        h := StatsShown * 15 + 4
        ; the times end one Indent inside the total above them, the names start
        ; one Indent inside the heading - the two edges mirror each other
        valW := 102
        valX := HdrNumR - Indent - valW
        ; This one block is taller than a row, so all-or-nothing is wrong for
        ; it: hidden, it leaves a hole the size of itself above the footer, and
        ; the drawer only appears once the WHOLE of it fits. Show as much as
        ; there is room for instead, and scroll for the rest. The full height
        ; is still what y advances by, or there would be nothing to scroll to.
        fit := PanelFootLine - y
        if (fit > h)
            fit := h
        if (y >= PanelHdrH && fit >= 14) {
            GuiControl, Panel:Move, StatsTxt, % "x" CardL " y" y " w" (valX - CardL - 8) " h" fit
            GuiControl, Panel:Move, StatsVal, % "x" valX " y" y " w" valW " h" fit
            GuiControl, Panel:Show, StatsTxt
            GuiControl, Panel:Show, StatsVal
        } else {
            GuiControl, Panel:Hide, StatsTxt
            GuiControl, Panel:Hide, StatsVal
        }
        y += h + 6
    } else {
        GuiControl, Panel:Hide, StatsTxt
        GuiControl, Panel:Hide, StatsVal
    }

    ; ---- park the unused pool rows off-panel
    Loop % RowPool {
        if (A_Index <= used)
            continue
        HideRow(A_Index)
    }

    ; The content has stopped. Its true height is what was laid out, plus the
    ; scroll that was taken off the top, plus the footer that is not part of it.
    PanelContentH := y + PanelScrollY + PanelFootH
    want := PanelContentH
    if (want > room)
        want := room
    PanelScrollMax := (PanelContentH > want) ? PanelContentH - want : 0
    scroll := PanelScrollY
    if (scroll > PanelScrollMax)
        scroll := PanelScrollMax
    if (scroll < 0)
        scroll := 0

    ; The guess at the top was wrong, or the scroll is past the end because a
    ; task was ticked off the bottom. Either way, once more with the truth.
    if ((want != panH || scroll != PanelScrollY) && !PanelRelaying) {
        PanelScrollY := scroll
        PanelRelaying := 1
        Relayout()
        PanelRelaying := 0
        return
    }
    PanelScrollY := scroll
    PanelFootLine := panH - PanelFootH
    PlaceFoot(PanelFootLine)

    PanelH := panH
    ; A Show restores a minimised window and shows a hidden one - and this runs
    ; on timers. Either would be Daybook bringing itself back on its own, so
    ; it only sizes a panel that is up. Coming back lays out again anyway: see
    ; ShowPanel() and PnlSize.
    if (PanelVisible && !PanelIsMin())
        Gui, Panel:Show, NoActivate w%PanelW% h%panH%
    ApplyPanelShape()
    ; Two repaint problems in one call. Moving or shrinking a control does not
    ; repaint the space it left, so a list that got shorter leaves its old rows
    ; painted where they land on the next heading and look real. And now that
    ; the background is painted by hand, the parent paints straight over its own
    ; children, so the labels have to be redrawn after it.
    ; RDW_INVALIDATE|RDW_ERASE|RDW_ALLCHILDREN|RDW_UPDATENOW - the ALLCHILDREN
    ; is the part "WinSet, Redraw" does not do, and without it rows come back
    ; blank.
    DllCall("RedrawWindow", "ptr", PanelHwnd, "ptr", 0, "ptr", 0, "uint", 0x185)
}

; Put a row of controls where it goes - or take it off the panel, if that is
; behind the pinned header at the top or the pinned footer at the bottom.
;
; Hiding rather than letting it slide under: a control is a window of its own,
; and a window draws over its parent's background whatever the parent paints
; there. Scrolled content would otherwise appear straight through the status
; line. Everything in one row goes or stays together, because half a heading
; peeping out from under the minutes is worse than no heading.
PlaceHdr(y, tall, specs) {
    global PanelHdrH, PanelFootLine
    show := (y >= PanelHdrH && y + tall <= PanelFootLine)
    for name, opt in specs {
        if (!show) {
            GuiControl, Panel:Hide, %name%
            continue
        }
        GuiControl, Panel:Move, %name%, %opt%
        GuiControl, Panel:Show, %name%
    }
    return show
}

; The footer, which is not part of the scrolling page at all. It sits on the
; bottom edge wherever that edge happens to be, and is always shown: the lock
; and the on-top switch are exactly the things you go looking for, and having
; to scroll to the end of a long list to find them would be absurd.
PlaceFoot(y) {
    global HdrNumR
    GuiControl, Panel:Move, FootTxt, % "y" (y + 2)
    GuiControl, Panel:Move, ModeBtn, % "x" (HdrNumR - 106) " y" (y + 2) " w32"
    GuiControl, Panel:Move, TopBtn,  % "x" (HdrNumR - 68)  " y" (y + 2) " w34"
    GuiControl, Panel:Move, LockBtn, % "x" (HdrNumR - 30)  " y" (y + 2) " w30"
    for _, name in ["FootTxt", "ModeBtn", "TopBtn", "LockBtn"]
        GuiControl, Panel:Show, %name%
}

; How much room the panel has: from where its top edge is to the bottom of the
; work area on that monitor, or PanelMaxH if the .ini names one. Never less than
; a floor, because a panel dragged to the bottom of the screen should still be
; usable rather than a two-row sliver.
PanelRoom() {
    global PanelHwnd, PanelMaxH, PanelX, PanelY
    WinGetPos, px, py, , , ahk_id %PanelHwnd%
    if (px = "")
        px := PanelX, py := PanelY
    SysGet, count, MonitorCount
    best := 0
    Loop % count {
        SysGet, m, MonitorWorkArea, %A_Index%
        if (px >= mLeft && px <= mRight && py >= mTop && py <= mBottom) {
            best := A_Index
            break
        }
    }
    SysGet, m, MonitorWorkArea, % best ? best : 1
    ; Right down to the edge of the work area, with nothing held back. A panel
    ; put at the top of the screen should be able to fill it.
    room := mBottom - py
    if (PanelMaxH > 0 && room > PanelMaxH)
        room := PanelMaxH
    return (room < 260) ? 260 : room
}

; One card a notch, two notches a turn of the wheel. Nothing happens when it
; all fits, which is the usual case and why there is no scrollbar to look at
; until there is something to scroll.
PanelScroll(dir) {
    global PanelScrollY, PanelScrollMax, RowH, RowGap
    want := PanelScrollY + dir * (RowH + RowGap) * 2
    if (want < 0)
        want := 0
    if (want > PanelScrollMax)
        want := PanelScrollMax
    if (want = PanelScrollY)
        return
    PanelScrollY := want
    Relayout()
}

; Whether a turn of the wheel belongs to the panel. Worked out fresh rather
; than read from Hot, which HoverCheck only refreshes every 150ms - long enough
; that the first notch after the pointer arrives would go to the window behind.
PanelCanScroll() {
    global PanelVisible, PanelScrollMax, PanelHwnd
    if (!PanelVisible || PanelScrollMax <= 0 || Ghost())
        return false
    WinGetPos, px, py, pw, ph, ahk_id %PanelHwnd%
    if (px = "")
        return false
    CoordMode, Mouse, Screen
    MouseGetPos, mx, my
    return (mx >= px && mx <= px + pw && my >= py && my <= py + ph)
        && WindowSeenAt(PanelHwnd, mx, my)    ; the wheel belongs to a window on top of it
}

; Open sections point down, closed ones point right - the usual accordion cue,
; and the only thing left saying which state a heading is in now that the
; collapse buttons are gone.
Caret(open) {
    return open ? Chr(0x25BE) : Chr(0x25B8)
}

; Draw the tasks of one list into the next free pool rows. Returns the new
; high-water mark.
PlaceRows(list, ByRef y, used) {
    global
    shown := 0
    ; The tasks of this list, as indexes into Tasks. Short term goes soonest
    ; deadline first; the array itself is never re-sorted, because a pending
    ; tick holds a task by its index (see PendMark).
    rowOrder := []
    for i, t in Tasks
        if (t.list = list)
            rowOrder.Push(i)
    if (list = "S")
        DueSort(rowOrder)
    for _, i in rowOrder {
        t := Tasks[i]
        if (++shown > MaxRows)
            break
        ; see the same skip in PlaceHabits
        if (y < PanelHdrH || y + RowH > PanelFootLine) {
            y += RowH + RowGap
            continue
        }
        if (used >= RowPool)
            break
        n := ++used
        RowTask[n] := i
        RowY[n] := y                     ; where the note box opens
        Cards.Push({y: y, kind: "T", pool: n})

        done := (t.status = "done")
        fail := (t.status = "failed")
        miss := (list = "M")
        ; how many days it has been left undone, in front where it is seen
        label := (t.carry > 0) ? Chr(0xD7) t.carry "  " t.text : t.text
        ; a short term task wears the time it has left in front: "3d  call the bank"
        if (list = "S" && t.due != "")
            label := DueTag(t.due) "  " t.text

        ; Each colour goes into a variable first: "+c%" only forces an
        ; expression when the % is the FIRST thing in the parameter, and here
        ; the parameter already starts with "Panel:+c".
        chkGlyph := done ? Chr(0x2713) : Chr(0x2610)
        chkCol   := done ? CGreen : CMuted
        xCol     := fail ? CRed : CDim
        txtCol   := (done || fail) ? CDim : CText
        ; due today or tomorrow: amber, the colour that means "this one needs you"
        if (list = "S" && !done && !fail && t.due != "" && DueDays(t.due) <= 1)
            txtCol := CAmber

        GuiControl, Panel:Move, RowChk%n%, % "x" (CardL + 6) " y" y
        GuiControl, Panel:+c%chkCol%, RowChk%n%
        GuiControl, Panel:, RowChk%n%, %chkGlyph%
        GuiControl, Panel:Show, RowChk%n%

        GuiControl, Panel:Move, RowX%n%, % "x" (CardL + 30) " y" y
        GuiControl, Panel:+c%xCol%, RowX%n%
        GuiControl, Panel:, RowX%n%, % Chr(0x2715)
        GuiControl, Panel:Show, RowX%n%

        if (miss) {
            GuiControl, Panel:Move, RowGo%n%, % "x" (CardL + 50) " y" y
            GuiControl, Panel:Show, RowGo%n%
        } else
            GuiControl, Panel:Hide, RowGo%n%

        txtX := CardL + (miss ? 72 : 52)
        GuiControl, Panel:Move, RowTxt%n%, % "x" txtX " y" y " w" (CardR - txtX - 6)
        GuiControl, Panel:+c%txtCol%, RowTxt%n%
        GuiControl, Panel:, RowTxt%n%, %label%
        GuiControl, Panel:Show, RowTxt%n%

        y += RowH + RowGap
    }
    if (shown)
        y += 2
    return used
}

HideRow(n) {
    GuiControl, Panel:Hide, RowChk%n%
    GuiControl, Panel:Hide, RowX%n%
    GuiControl, Panel:Hide, RowGo%n%
    GuiControl, Panel:Hide, RowTxt%n%
}

; Draw the habits into their own pool of rows, and work out where every dot
; goes while we are here. The dots themselves are painted later, by OnErase,
; out of the Dots list this fills - a circle is not a control.
;
; Explicitly scoped, unlike PlaceRows above it: this one runs a loop inside a
; loop, and the note at the top of OnErase says what assume-global costs when a
; repaint lands in the middle of one.
PlaceHabits(ByRef y) {
    global Habits, HabPool, HabitDays, HabDotD, HabDotGap, HabNumW
    global CardL, CardR, RowH, RowGap, Cards, Dots, HabRow, PanelHdrH, PanelFootLine
    global CGreen, CMuted, CText, CDim, CBlue
    used := 0
    today := LogicalDay()
    ; Right to left: the streak sits against the card's right edge, the week of
    ; dots against the streak, and the name takes whatever is left. Turn the
    ; dots off in the .ini and the name simply gets their room.
    numX  := CardR - 8 - HabNumW
    dotsW := HabitDays ? HabitDays * HabDotD + (HabitDays - 1) * HabDotGap : 0
    dotsX := numX - 8 - dotsW
    nameX := CardL + 30
    nameW := dotsX - 6 - nameX
    if (nameW < 40)                      ; an absurdly narrow panel: name wins
        nameW := 40
    dy := 0
    for i, hb in Habits {
        ; behind the pinned header, or below the pinned footer - skip it, but
        ; still walk past the room it takes, or everything below it would move
        if (y < PanelHdrH || y + RowH > PanelFootLine) {
            y += RowH + RowGap
            continue
        }
        if (used >= HabPool)
            break
        r := ++used
        HabRow[r] := i
        Cards.Push({y: y, kind: "H", pool: r})

        did := HabitDidToday(hb)
        ; Into a variable first - see the same note in PlaceRows.
        ;
        ; The NAME does not dim when it is done, which is where a habit parts
        ; company with a task. A finished task is business closed and greys out
        ; to get out of the way; a habit ticked today is a win, and the row
        ; should light up rather than fade. The tick, the last dot and the
        ; number carry the green.
        ; Frozen today: a blue snowflake where the box was, the same blue as its
        ; dot, so a freeze is visible on the row and not only in the dots.
        frozen := (!did && HabitRested(hb, today))
        chkCol := did ? CGreen : frozen ? CBlue : CMuted
        txtCol := CText
        numCol := HabitStreakColour(hb)

        GuiControl, Panel:Move, HabChk%r%, % "x" (CardL + 6) " y" y
        GuiControl, Panel:+c%chkCol%, HabChk%r%
        GuiControl, Panel:, HabChk%r%, % did ? Chr(0x2713) : frozen ? Chr(0x2744) : Chr(0x2610)
        GuiControl, Panel:Show, HabChk%r%

        GuiControl, Panel:Move, HabTxt%r%, % "x" nameX " y" y " w" nameW
        GuiControl, Panel:+c%txtCol%, HabTxt%r%
        GuiControl, Panel:, HabTxt%r%, % hb.text
        GuiControl, Panel:Show, HabTxt%r%

        GuiControl, Panel:Move, HabNum%r%, % "x" numX " y" y " w" HabNumW
        GuiControl, Panel:+c%numCol%, HabNum%r%
        GuiControl, Panel:, HabNum%r%, % HabitStreakText(hb)
        GuiControl, Panel:Show, HabNum%r%

        ; Each dot remembers which habit and which day it stands for, because
        ; it is also a button - OnPanelClick hit-tests this list. A dot is not a
        ; control, so a click on one reaches the window, not a g-label.
        dy := y + (RowH - HabDotD) // 2
        Loop % HabitDays {
            day := DayShift(today, A_Index - HabitDays)
            st  := HabitDayState(hb, day, today)
            if (st = "none")             ; before this habit existed: no dot
                continue
            Dots.Push({x: dotsX + (A_Index - 1) * (HabDotD + HabDotGap)
                     , y: dy, c: HabitDotColour(st), hab: i, day: day})
        }
        y += RowH + RowGap
    }
    if (used)
        y += 2
    return used
}

HideHab(n) {
    GuiControl, Panel:Hide, HabChk%n%
    GuiControl, Panel:Hide, HabTxt%n%
    GuiControl, Panel:Hide, HabNum%n%
}

; Recount, recolour the +, then lay out.
Refresh() {
    global
    nOpen := 0, nToday := 0, nLong := 0, nMiss := 0, nShort := 0
    for _, t in Tasks {
        if (t.list = "T") {
            nToday++
            if (t.status = "open")
                nOpen++
        } else if (t.list = "M")
            nMiss++
        else if (t.list = "S")
            nShort++
        else
            nLong++
    }
    GuiControl, Panel:, MissCnt, %nMiss%
    GuiControl, Panel:, TodayCnt, %nOpen%
    GuiControl, Panel:, ShortCnt, %nShort%
    GuiControl, Panel:, LongCnt, %nLong%
    ; Habits count DOWN to nothing left, which is the opposite of the task
    ; lists and is the point: "3/5" is a thing you finish, and it goes green
    ; the moment you do.
    nHab := Habits.Length()
    if (nHab) {
        nDone := HabitsDone()
        hcol := (nDone >= nHab) ? CGreen : CMuted
        GuiControl, Panel:+c%hcol%, HabCnt
        GuiControl, Panel:, HabCnt, % nDone "/" nHab
    } else {
        GuiControl, Panel:+c%CMuted%, HabCnt
        GuiControl, Panel:, HabCnt,
    }
    ; the + IS the indicator now: amber means the list is empty. What yesterday
    ; left undone has a section of its own - MISSED - rather than a light.
    owed := (nToday = 0)
    col := owed ? CAmber : CMuted
    GuiControl, Panel:+c%col%, AddBtn
    GuiControl, Panel:, AddBtn, +
    JrnPanelCount()
    LastShownMin := 9999
    UpdateTimerText()
    SetStatusText()
    Relayout()
}

