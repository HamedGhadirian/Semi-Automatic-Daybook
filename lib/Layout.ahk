;================================================================================
; Laying the panel out - where every section and row ends up
;================================================================================
; Lay out whatever is open, top to bottom: JOURNAL (while the journal is on),
; HABITS, MISSED (only when there is something in it), TODAY'S TASKS, SHORT
; TERM TASKS, LONG TERM TASKS, TIME AT THE MACHINE.
;
; The journal heads the panel - one line, the door to the day's writing. Then
; habits, because they are the part that is the same every morning -
; a list you glance at and clear, above the list you think about. The task
; lists share one pool of row controls, so a row's index in the pool has
; nothing to do with which task is in it.
;================================================================================
#Requires AutoHotkey v2.0

Relayout() {
    global RowY, RowTask, Cards, Dots, PanelFootLine, PanelContentH, PanelScrollMax
    global PanelScrollY, PanelRelaying, PanelH, StatsShown
    if !IsObject(PanelGui)
        return
    g := PanelGui
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
    g["StatusTxt"].Move(, y)
    ; The window buttons take the right end; the minutes, the circle and the
    ; break switch sit in the middle, ending just before them.
    bx := PanelW - 8 - PanelBtns.Width
    PanelBtns.Place(bx, y - 1)
    g["BreakBtn"].Move(bx - 40, y + 1, 32)
    g["ModeTxt"].Move(bx - 54, y, 12)
    g["TimerTxt"].Move(bx - 128, y, 72)
    y += 24

    ; From here down, everything is placed against y - so starting y further up
    ; the page IS the scroll, and every card rectangle, dot and hit test comes
    ; out right without knowing anything about it. The four controls above keep
    ; their own y and never move: the bar and the minutes are what the panel is
    ; for, and a readout you have to scroll to is not a readout.
    y -= PanelScrollY

    ; ---- Journal - first, a heading that opens a window, nothing under it
    if (JournalOn) {
        PlaceHdr(y, 20, [["JrnHdr", "", y], ["JrnCnt", HdrNumR - 96, y + 2, 96]])
        y += 22
    } else {
        g["JrnHdr"].Visible := false
        g["JrnCnt"].Visible := false
    }

    ; ---- Habits
    PlaceHdr(y, 20, [["HabHdr", "", y], ["HabCnt", HdrNumR - 112, y + 2, 36], ["HabAdd", HdrNumR - 24, y - 2, 24]])
    g["HabHdr"].Text := Caret(OpenHabits) " HABITS"
    y += 22
    if (OpenHabits)
        habUsed := PlaceHabits(&y)
    loop HabPool {
        if (A_Index > habUsed)
            HideHab(A_Index)
    }

    ; ---- Missed - just above Today, because what it asks is what goes on it
    if (NMiss) {
        PlaceHdr(y, 20, [["MissHdr", "", y], ["MissCnt", HdrNumR - 102, y + 2, 26]])
        g["MissHdr"].Text := Caret(OpenMissed) " MISSED"
        y += 22
        if (OpenMissed)
            used := PlaceRows("M", &y, used)
    } else {
        g["MissHdr"].Visible := false
        g["MissCnt"].Visible := false
    }

    ; ---- Today
    PlaceHdr(y, 20, [["TodayHdr", "", y], ["TodayCnt", HdrNumR - 102, y + 2, 26], ["AddBtn", HdrNumR - 24, y - 2, 24]])
    g["TodayHdr"].Text := Caret(OpenToday) " TODAY'S TASKS"
    y += 22
    if (OpenToday)
        used := PlaceRows("T", &y, used)

    ; ---- Short term - a deadline each, soonest first
    PlaceHdr(y, 20, [["ShortHdr", "", y], ["ShortCnt", HdrNumR - 102, y + 2, 26], ["ShortAdd", HdrNumR - 24, y - 2, 24]])
    g["ShortHdr"].Text := Caret(OpenShort) " SHORT TERM TASKS"
    y += 22
    if (OpenShort)
        used := PlaceRows("S", &y, used)

    ; ---- Long term
    PlaceHdr(y, 20, [["LongHdr", "", y], ["LongCnt", HdrNumR - 102, y + 2, 26], ["LongAdd", HdrNumR - 24, y - 2, 24]])
    g["LongHdr"].Text := Caret(OpenLong) " LONG TERM TASKS"
    y += 22
    if (OpenLong)
        used := PlaceRows("L", &y, used)

    ; ---- Today so far
    PlaceHdr(y, 20, [["StatsHdr", "", y], ["StatsTotal", HdrNumR - 96, y + 2, 96]])
    g["StatsHdr"].Text := Caret(OpenStats) " TIME AT THE MACHINE"
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
            g["StatsTxt"].Move(CardL, y, valX - CardL - 8, fit)
            g["StatsVal"].Move(valX, y, valW, fit)
            g["StatsTxt"].Visible := true
            g["StatsVal"].Visible := true
        } else {
            g["StatsTxt"].Visible := false
            g["StatsVal"].Visible := false
        }
        y += h + 6
    } else {
        g["StatsTxt"].Visible := false
        g["StatsVal"].Visible := false
    }

    ; ---- park the unused pool rows off-panel
    loop RowPool {
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
        try Relayout()
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
        g.Show("NoActivate w" PanelW " h" panH)
    ApplyPanelShape()
    ; Two repaint problems in one call. Moving or shrinking a control does not
    ; repaint the space it left, so a list that got shorter leaves its old rows
    ; painted where they land on the next heading and look real. And now that
    ; the background is painted by hand, the parent paints straight over its own
    ; children, so the labels have to be redrawn after it.
    ; RDW_INVALIDATE|RDW_ERASE|RDW_ALLCHILDREN|RDW_UPDATENOW - the ALLCHILDREN
    ; is the part a plain redraw does not do, and without it rows come back
    ; blank.
    DllCall("RedrawWindow", "ptr", PanelHwnd, "ptr", 0, "ptr", 0, "uint", 0x185)
}

; Put a row of controls where it goes - or take it off the panel, if that is
; behind the pinned header at the top or the pinned footer at the bottom.
; specs: [name, x, y, w] each, "" for "where it is".
;
; Hiding rather than letting it slide under: a control is a window of its own,
; and a window draws over its parent's background whatever the parent paints
; there. Scrolled content would otherwise appear straight through the status
; line. Everything in one row goes or stays together, because half a heading
; peeping out from under the minutes is worse than no heading.
PlaceHdr(y, tall, specs) {
    show := (y >= PanelHdrH && y + tall <= PanelFootLine)
    for sp in specs {
        c := PanelGui[sp[1]]
        if (!show) {
            c.Visible := false
            continue
        }
        c.GetPos(&cx, &cy, &cw)
        c.Move((sp[2] = "") ? cx : sp[2], sp[3], (sp.Length >= 4) ? sp[4] : cw)
        c.Visible := true
    }
    return show
}

; The footer, which is not part of the scrolling page at all. It sits on the
; bottom edge wherever that edge happens to be, and is always shown: the lock
; and the on-top switch are exactly the things you go looking for, and having
; to scroll to the end of a long list to find them would be absurd.
PlaceFoot(y) {
    g := PanelGui
    g["FootTxt"].Move(, y + 2)
    g["ModeBtn"].Move(HdrNumR - 68, y + 2, 32)
    g["LockBtn"].Move(HdrNumR - 30, y + 2, 30)
    for name in ["FootTxt", "ModeBtn", "LockBtn"]
        g[name].Visible := true
}

; How much room the panel has: from where its top edge is to the bottom of the
; work area on that monitor, or PanelMaxH if the .ini names one. Never less than
; a floor, because a panel dragged to the bottom of the screen should still be
; usable rather than a two-row sliver.
PanelRoom() {
    px := PanelX, py := PanelY
    try WinGetPos(&px, &py, , , PanelHwnd)
    best := 0
    loop MonitorGetCount() {
        MonitorGetWorkArea(A_Index, &mLeft, &mTop, &mRight, &mBottom)
        if (px >= mLeft && px <= mRight && py >= mTop && py <= mBottom) {
            best := A_Index
            break
        }
    }
    MonitorGetWorkArea(best ? best : MonitorGetPrimary(), &mLeft, &mTop, &mRight, &mBottom)
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
    global PanelScrollY
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
PanelCanScroll(*) {
    if (!PanelVisible || PanelScrollMax <= 0 || Ghost() || !PanelHwnd)
        return false
    try WinGetPos(&px, &py, &pw, &ph, PanelHwnd)
    catch
        return false
    CoordMode("Mouse", "Screen")
    MouseGetPos(&mx, &my)
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
PlaceRows(list, &y, used) {
    g := PanelGui
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
    for i in rowOrder {
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
        RowTask.Length := n, RowY.Length := n
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

        ; the one box shows the mark: an empty box, a tick, or a dropped task's cross
        chkCol   := done ? CGreen : fail ? CRed : CMuted
        chkMark  := done ? Chr(0x2713) : fail ? Chr(0x2715) : Chr(0x2610)
        txtCol   := (done || fail) ? CDim : CText
        ; due today or tomorrow: amber, the colour that means "this one needs you"
        if (list = "S" && !done && !fail && t.due != "" && DueDays(t.due) <= 1)
            txtCol := CAmber

        g["RowChk" n].Move(CardL + 6, y)
        PSay("RowChk" n, chkMark, chkCol)
        g["RowChk" n].Visible := true

        if (miss) {
            g["RowGo" n].Move(CardL + 28, y)
            g["RowGo" n].Visible := true
        } else
            g["RowGo" n].Visible := false

        txtX := CardL + (miss ? 50 : 30)
        g["RowTxt" n].Move(txtX, y, CardR - txtX - 6)
        PSay("RowTxt" n, label, txtCol)
        g["RowTxt" n].Visible := true

        y += RowH + RowGap
    }
    if (shown)
        y += 2
    return used
}

HideRow(n) {
    for pre in ["RowChk", "RowGo", "RowTxt"]
        PanelGui[pre n].Visible := false
}

; Draw the habits into their own pool of rows, and work out where every dot
; goes while we are here. The dots themselves are painted later, by OnErase,
; out of the Dots list this fills - a circle is not a control.
PlaceHabits(&y) {
    g := PanelGui
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
        HabRow.Length := Max(HabRow.Length, r)
        HabRow[r] := i
        Cards.Push({y: y, kind: "H", pool: r})

        did := HabitDidToday(hb)
        ; The NAME does not dim when it is done, which is where a habit parts
        ; company with a task. A finished task is business closed and greys out
        ; to get out of the way; a habit ticked today is a win, and the row
        ; should light up rather than fade. The tick, the last dot and the
        ; number carry the green.
        ; Frozen today: a blue snowflake where the box was, the same blue as its
        ; dot, so a freeze is visible on the row and not only in the dots.
        frozen := (!did && HabitRested(hb, today))

        g["HabChk" r].Move(CardL + 6, y)
        PSay("HabChk" r, did ? Chr(0x2713) : frozen ? Chr(0x2744) : Chr(0x2610)
            , did ? CGreen : frozen ? CBlue : CMuted)
        g["HabChk" r].Visible := true

        g["HabTxt" r].Move(nameX, y, nameW)
        PSay("HabTxt" r, hb.text, CText)
        g["HabTxt" r].Visible := true

        g["HabNum" r].Move(numX, y, HabNumW)
        PSay("HabNum" r, HabitStreakText(hb), HabitStreakColour(hb))
        g["HabNum" r].Visible := true

        ; Each dot remembers which habit and which day it stands for, because
        ; it is also a button - OnPanelClick hit-tests this list. A dot is not a
        ; control, so a click on one reaches the window, not a control.
        dy := y + (RowH - HabDotD) // 2
        loop HabitDays {
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
    for pre in ["HabChk", "HabTxt", "HabNum"]
        PanelGui[pre n].Visible := false
}

; Recount, recolour the +, then lay out.
Refresh() {
    global NOpen, NToday, NLong, NMiss, NShort, LastShownMin
    NOpen := 0, NToday := 0, NLong := 0, NMiss := 0, NShort := 0
    for t in Tasks {
        if (t.list = "T") {
            NToday++
            if (t.status = "open")
                NOpen++
        } else if (t.list = "M")
            NMiss++
        else if (t.list = "S")
            NShort++
        else
            NLong++
    }
    if !IsObject(PanelGui)               ; the tests: no panel to show it on
        return
    g := PanelGui
    g["MissCnt"].Text := NMiss
    g["TodayCnt"].Text := NOpen
    g["ShortCnt"].Text := NShort
    g["LongCnt"].Text := NLong
    ; Habits count DOWN to nothing left, which is the opposite of the task
    ; lists and is the point: "3/5" is a thing you finish, and it goes green
    ; the moment you do.
    nHab := Habits.Length
    if (nHab) {
        nDone := HabitsDone()
        PSay("HabCnt", nDone "/" nHab, (nDone >= nHab) ? CGreen : CMuted)
    } else
        PSay("HabCnt", "", CMuted)
    ; the + IS the indicator now: amber means the list is empty. What yesterday
    ; left undone has a section of its own - MISSED - rather than a light.
    PSay("AddBtn", "+", (NToday = 0) ? CAmber : CMuted)
    JrnPanelCount()
    LastShownMin := 9999
    UpdateTimerText()
    SetStatusText()
    Relayout()
}
