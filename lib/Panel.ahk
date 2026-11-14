;================================================================================
; The panel
;================================================================================
;   WS_EX_NOACTIVATE, and there is no MsgBox anywhere in this file on purpose:
;   MsgBox is modal and steals focus, which is the single thing that makes a
;   tool like this unbearable to have running while you are in something else.
;
;   Rows are a fixed POOL of controls that get moved, recoloured and hidden.
;   Building a row per task would mean making and destroying controls all day;
;   a pool means a redraw is a few Move calls instead of rebuilding a list.
;
;   Every control has a name, and is reached as PanelGui["Name"]. PSay() is a
;   control's colour and text in one go: a colour change on a Text control
;   only shows once its text is set again, so the two always go together.
;================================================================================
#Requires AutoHotkey v2.0

PSay(name, text, col) {
    c := PanelGui[name]
    c.SetFont("c" col)
    c.Text := text
    PanelColours[name] := col            ; what it was given - the tests read it
}

; A control's colour alone - it shows at the next repaint.
PColor(name, col) => PanelGui[name].SetFont("c" col)

BuildPanel() {
    global PanelGui, PanelHwnd, PanelKind
    ; +MinimizeBox only so a taskbar click can minimise it - there is no
    ; caption to show the box on. The overlay kind is a tool window instead,
    ; which keeps it off the taskbar and out of Alt+Tab. See ApplyWindowKind().
    g := Gui("+AlwaysOnTop -Caption " (PanelTaskbar ? "+MinimizeBox" : "+ToolWindow +E0x08000000"), "Daybook")
    PanelGui := g, PanelHwnd := g.Hwnd
    PanelKind := PanelTaskbar
    ; Daybook's own taskbar button - the habit and journal windows join it
    KitTaskbar.Id(PanelHwnd)
    g.MarginX := 0, g.MarginY := 0
    g.BackColor := CBg
    txt := (opts, text := "", click := "") => PanelAdd("Text", opts, text, click)

    ; the sit bar. -Theme is required before a Progress will take custom colours
    g.Add("Progress", "vTopBar x0 y0 w" PanelW " h5 -E0x200 -Theme Background" CTrack " c" CGreen, 0)

    ; The status and the minutes are always on. There is no hide-the-digits
    ; toggle any more: the digits only move once a minute, so there was nothing
    ; left to be distracted by, and the slot is worth more as the break switch.
    ; Top row: the status, then the minutes sitting right next to the break
    ; switch rather than floating in the middle of the row.
    g.SetFont("s8 Bold", "Segoe UI")
    txt("vStatusTxt x12 y13 w96 h15 c" CGreen, "FOCUS", DragPanel)
    g.SetFont("s8 Norm", "Segoe UI")
    txt("vTimerTxt x108 y13 w118 h15 Right c" CText)
    txt("vModeTxt x228 y13 w12 h15 Center c" CDim)
    txt("vBreakBtn x242 y13 w48 h16 Right c" CDim, "break", (*) => ToggleBreak())
    ; The window buttons at the right end of the top row - settings, on top,
    ; minimise, close - the kit's, the same on every panel (2026-11-13). The
    ; minutes and the break switch moved to the middle for them (Relayout).
    ; Close hides the panel, as its key does; it never exits Daybook.
    global PanelBtns := KitWinBtns.Add(g, PanelW - 8 - 67, 12, {settings: () => KitSettings.Show()
        , top: () => ToggleOnTop(), min: () => PanelMinimise(), close: () => PanelHideBtn()
        , bg: CBg, dim: CMuted, hot: CText, on: CAmber
        , tips: {min: PanelTaskbar ? "Minimise" : "Hide", close: "Hide"}})

    ; ---- headings.  There are no collapse buttons: the HEADING is the button,
    ;      and the caret in front of it says which way it is. That frees the
    ;      whole right-hand column, so + sits at the edge and the numbers line
    ;      up in one column under it.
    ; MISSED has no +: nothing is added to it by hand, a day's end puts things
    ; there. Its heading is amber, and it is not on the panel while it is empty.
    g.SetFont("s9 Bold", "Segoe UI")
    txt("vMissHdr x12 y36 w160 h17 c" CAmber, "MISSED", (*) => ToggleOpen("OpenMissed"))
    g.SetFont("s8 Norm", "Segoe UI")
    txt("vMissCnt x176 y38 w26 h14 Center c" CAmber)

    g.SetFont("s9 Bold", "Segoe UI")
    txt("vTodayHdr x12 y36 w160 h17 c" CText, "TODAY", (*) => ToggleOpen("OpenToday"))
    g.SetFont("s8 Norm", "Segoe UI")
    txt("vTodayCnt x176 y38 w26 h14 Center c" CMuted)
    g.SetFont("s12 Norm", "Segoe UI")
    ; the + doubles as the "I need something from you" light: it turns amber
    ; when the list is empty
    txt("vAddBtn x266 y34 w24 h20 Right c" CMuted, "+", (*) => QuickAdd("T"))

    ; between Today and Long term: what has a day to be done by
    g.SetFont("s9 Bold", "Segoe UI")
    txt("vShortHdr x12 y60 w160 h17 c" CText, "SHORT TERM", (*) => ToggleOpen("OpenShort"))
    g.SetFont("s8 Norm", "Segoe UI")
    txt("vShortCnt x176 y62 w26 h14 Center c" CMuted)
    g.SetFont("s12 Norm", "Segoe UI")
    txt("vShortAdd x266 y58 w24 h20 Right c" CMuted, "+", (*) => QuickAdd("S"))

    g.SetFont("s9 Bold", "Segoe UI")
    txt("vLongHdr x12 y60 w160 h17 c" CText, "LONG TERM", (*) => ToggleOpen("OpenLong"))
    g.SetFont("s8 Norm", "Segoe UI")
    txt("vLongCnt x176 y62 w26 h14 Center c" CMuted)
    g.SetFont("s12 Norm", "Segoe UI")
    txt("vLongAdd x266 y58 w24 h20 Right c" CMuted, "+", (*) => QuickAdd("L"))

    ; ---- habits.  Same heading shape as the two task lists, and the count in
    ;      the middle is "how many of them are ticked today" rather than a
    ;      total - which is the only number a habit list has to answer.
    g.SetFont("s9 Bold", "Segoe UI")
    txt("vHabHdr x12 y84 w160 h17 c" CText, "HABITS", (*) => ToggleOpen("OpenHabits"))
    g.SetFont("s8 Norm", "Segoe UI")
    txt("vHabCnt x166 y86 w36 h14 Center c" CMuted)
    g.SetFont("s12 Norm", "Segoe UI")
    txt("vHabAdd x266 y82 w24 h20 Right c" CMuted, "+", (*) => QuickAdd("H"))

    ; ---- the journal.  Not a list and nothing to fold: the heading is a button
    ;      that opens the journal window, with a pencil where a caret would be,
    ;      and today's words on the right. Gone while the journal is off.
    g.SetFont("s9 Bold", "Segoe UI")
    txt("vJrnHdr x12 y84 w160 h17 c" CText, Chr(0x270E) " JOURNAL", (*) => JrnShow())
    g.SetFont("s8 Norm", "Segoe UI")
    txt("vJrnCnt x176 y86 w86 h14 Right c" CMuted, "", (*) => JrnShow())

    g.SetFont("s9 Bold", "Segoe UI")
    txt("vStatsHdr x12 y84 w160 h17 c" CText, "TIME", (*) => ToggleOpen("OpenStats"))
    g.SetFont("s8 Norm", "Segoe UI")
    ; the day's total and the per-app times share one right edge, which is 8px
    ; inside the + column - the same inset the app names have from the heading
    ; on the left
    txt("vStatsTotal x176 y86 w86 h14 Right c" CMuted)
    ; Two columns rather than one string with tabs in it: a Static control does
    ; not expand tab stops, so the times came out ragged.
    txt("vStatsTxt x20 y104 w140 h120 c" CMuted)
    txt("vStatsVal x164 y104 w98 h120 Right c" CDim)

    ; ---- footer: the two keys on the left, three switches on the right
    g.SetFont("s7 Norm", "Segoe UI")
    ; 154 is what the row has left once the three switches have theirs. The
    ; line below fits well inside it; lengthen it and it clips.
    txt("vFootTxt x12 y230 w154 h13 c" CDim, KeyFootText(), DragPanel)
    ; The switches end on HdrNumR like every other right-hand thing on the
    ; panel, each right-aligned in a box of its own, so a word changing length
    ; never moves its neighbours - Relayout() places them:
    ;   mode    the mode spelled out - click to swap solid and dim. Never
    ;           ghost: that would be a click you could not click back from
    ;   (on top moved to the pin among the window buttons, 2026-11-13)
    ;   lock    30 wide because "locked" measures 25. You set it once when the
    ;           panel is where you want it, and a button you have to go and
    ;           find is the right shape for a decision like that.
    txt("vModeBtn x172 y230 w32 h13 Right c" CDim, "", (*) => SetPanelMode(PanelMode = 0 ? 1 : 0))
    txt("vLockBtn x248 y230 w30 h13 Right c" CDim, "lock", (*) => ToggleLock())

    ; ---- the row pool
    ; No background control per row: the cards are painted straight into the
    ; window in OnErase(). A Progress bar was the obvious way to get a coloured
    ; rectangle, but with transparent Text sitting on top of it, it drew its
    ; classic 1px 3D edge - a grey line above and a white line below every task.
    ; Painting the rectangles ourselves removes both the border and 22 controls.
    loop RowPool {
        n := A_Index
        ; the tick box gets its own larger font - it is the thing you aim at
        g.SetFont("s12 Norm", "Segoe UI")
        txt("vRowChk" n " x26 y400 w22 h" RowH " Center c" CMuted " +0x200", "", RowAction.Bind(n, "done"))
        g.SetFont("s9 Norm", "Segoe UI")
        ; A MISSED row's second button: back onto Today's list, which is below.
        ; Dropping and deleting are on the right-click menu, not buttons: they
        ; are rare, and the name gets the room.
        txt("vRowGo" n " x50 y400 w18 h" RowH " Center c" CDim " +0x200", Chr(0x2193), RowGoClick.Bind(n))
        ; +0x4000 is SS_ENDELLIPSIS: a name longer than the card ends in "..."
        ; drawn by Windows, instead of being cut mid-letter with nothing to
        ; say so. The whole of it is on hover - see HoverTip().
        txt("vRowTxt" n " x72 y400 w1 h" RowH " c" CText " +0x4200")
    }
    ; ---- the habit row pool
    ; A habit row is a tick box, a name, and the streak. The week of dots in
    ; between is not a control at all - it is painted in OnErase, because seven
    ; coloured circles per row would otherwise be seventy controls that all
    ; have to be moved and recoloured on every layout.
    loop HabPool {
        n := A_Index
        g.SetFont("s12 Norm", "Segoe UI")
        ; done or not done, nothing else: freezing is the dots' job (a click
        ; goes done -> frozen -> not done, see HabitCycleDay)
        txt("vHabChk" n " x26 y400 w22 h" RowH " Center c" CMuted " +0x200", "", HabChkClick.Bind(n))
        g.SetFont("s9 Norm", "Segoe UI")
        txt("vHabTxt" n " x50 y400 w1 h" RowH " c" CText " +0x4200")
        g.SetFont("s9 Bold", "Segoe UI")
        txt("vHabNum" n " x200 y400 w" HabNumW " h" RowH " Right c" CDim " +0x200")
    }
    g.OnEvent("ContextMenu", PnlContextMenu)
    g.OnEvent("Size", PnlSize)
    OnMessage(0x14,  OnErase)            ; WM_ERASEBKGND
    OnMessage(0x201, OnPanelClick)       ; WM_LBUTTONDOWN
    ShowPanel()
}

; One control on the panel: transparent over the painted cards, and a click
; handler if it is a button. A text with no handler has no SS_NOTIFY, so it is
; transparent to the mouse - a click on it is a click on the panel, which is
; a drag (see OnPanelClick).
PanelAdd(type, opts, text, click) {
    c := PanelGui.Add(type, opts " BackgroundTrans", text)
    if (click != "")
        OnClicks(c, click)
    return c
}

; A text that works as a button. Windows calls a quick second click on one a
; double-click, and only says "clicked" for the first - so both are taken, or
; ticking a box and unticking it at once would lose the second click.
OnClicks(c, fn) {
    c.OnEvent("Click", fn)
    c.OnEvent("DoubleClick", fn)
    return c
}

; Drag from anywhere empty.
;
; This only ever fires for clicks that reach the WINDOW - a control with a
; click handler swallows its own clicks, so the +, the headings, the tick boxes
; and the break switch all keep working. Plain labels (the minutes, the counts,
; the app list) have no handler, and a static control without SS_NOTIFY is
; transparent to hit-testing, so clicks on those fall through to here as well.
; The net effect is that everything that is not a button is a drag handle.
OnPanelClick(wParam, lParam, msg, hwnd) {
    if (hwnd != PanelHwnd || Ghost())
        return
    ; lParam carries the click in client coordinates, packed two signed 16-bit
    ; numbers to a word.
    cx := lParam & 0xFFFF
    cy := (lParam >> 16) & 0xFFFF
    if (cx > 32767)
        cx -= 65536
    if (cy > 32767)
        cy -= 65536
    if (DotHit(cx, cy))
        return
    ; With always-on-top off, ApplyOnTop() has already taken WS_EX_NOACTIVATE
    ; off the window, so Windows activates and raises it on this click by
    ; itself - the same as any other window. The lift below is the belt to that
    ; brace: it costs nothing, and it covers the click that lands on a control
    ; with its own handler, which never reaches this one at all.
    if (!PanelOnTop)
        DllCall("SetWindowPos", "Ptr", PanelHwnd, "Ptr", 0
            , "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x13)
    if (PanelLocked)                                ; locked still comes forward
        return
    PostMessage(0xA1, 2, , , PanelHwnd)             ; WM_NCLBUTTONDOWN, HTCAPTION
}

; The status and the keys line: a drag, the same as the empty panel.
DragPanel(*) {
    if (!Ghost() && !PanelLocked)
        PostMessage(0xA1, 2, , , PanelHwnd)         ; WM_NCLBUTTONDOWN, HTCAPTION
}

; Which habit dot the click landed on, if any. The target is the dot plus a
; pixel either side - nine of the ten pixels between one dot and the next - and
; the whole height of the card, so it is aimed at horizontally and not
; vertically. Returns true if it took the click.
DotHit(cx, cy) {
    d := DotAt(cx, cy)
    if (!IsObject(d))
        return false
    ToolTip(, , , 7)                     ; its hint described the day before the click
    ; done -> frozen -> not done; when the blue step was skipped, say why - a
    ; click that does something other than expected looks like a broken panel
    if (HabitCycleDay(d.hab, d.day) = "nofreeze")
        FreezeSay("No freezes left in " DayWords(d.day, "MMMM") ", so it went back to not done.")
    return true
}

; The dot at a point in the panel, or "". Clicks and the hover hint both ask.
DotAt(cx, cy) {
    top := (RowH - HabDotD) // 2         ; how far a dot sits below its card
    for d in Dots {
        if (cx < d.x - 1 || cx > d.x + HabDotD + 1)
            continue
        if (cy < d.y - top || cy >= d.y - top + RowH)
            continue
        return d
    }
    return ""
}

; The panel background, painted by hand: the flat canvas, one filled rectangle
; per visible card, then the habit dots on top of them. Returning 1 tells
; Windows we have erased it.
;
; It runs as a message handler, so it fires in the MIDDLE of other code - every
; control that moves or shows triggers a repaint, and AutoHotkey dispatches
; this between them. So it only ever reads: Cards and Dots are both built by
; Relayout(). Windows clips the device context to the part being repainted, so
; drawing all of it when only one row changed costs nothing - the rest is
; thrown away by GDI.
OnErase(wParam, lParam, msg, hwnd) {
    if (hwnd != PanelHwnd)
        return
    hdc := wParam
    rc := Buffer(16, 0)
    DllCall("GetClientRect", "ptr", hwnd, "ptr", rc)
    ch := NumGet(rc, 12, "int")
    FillRc(hdc, rc, CBg)
    for k, card in Cards {
        NumPut("int", CardL, "int", card.y, "int", CardR, "int", card.y + RowH, rc)
        FillRc(hdc, rc, (k = HotCard) ? CCardHi : CCard)
    }
    for d in Dots
        FillDot(hdc, d.x, d.y, HabDotD, d.c)
    ; A slim bar down the right margin, and only while there is something to
    ; scroll. A real scrollbar would be the wrong object on a panel with no
    ; frame and no title - this says the same thing and takes three pixels.
    if (PanelScrollMax > 0) {
        ; Against the scrolling part only - the pinned header is not page you
        ; can move through, so counting it would make the thumb lie.
        seen := ch - PanelHdrH - PanelFootH
        all  := PanelContentH - PanelHdrH - PanelFootH
        thumb := (all > 0) ? Round(seen * seen / all) : seen
        if (thumb < 24)
            thumb := 24
        span := seen - 12 - thumb
        if (span < 0)
            span := 0
        ty := PanelHdrH + 6 + Round(span * PanelScrollY / PanelScrollMax)
        NumPut("int", PanelW - 6, "int", PanelHdrH + 6, "int", PanelW - 3, "int", ch - PanelFootH - 6, rc)
        FillRc(hdc, rc, CTrack)
        NumPut("int", PanelW - 6, "int", ty, "int", PanelW - 3, "int", ty + thumb, rc)
        FillRc(hdc, rc, CDim)
    }
    return 1
}

; Rounded corners, always, like every panel of the family - no setting (the
; user, 2026-11-13; v1's RoundedCorners is gone). A window with no title bar
; is not rounded by Windows 11 unless it asks: DWMWA_WINDOW_CORNER_PREFERENCE
; is attribute 33, and 2 is round. Every window of Daybook's own asks, so none
; disagrees with another. Windows 10 has no such attribute and ignores it.
ApplyPanelShape() {
    ShapeWindow(PanelHwnd)
}

ShapeWindow(hwnd) {
    pref := Buffer(4, 0)
    NumPut("int", 2, pref)
    DllCall("dwmapi\DwmSetWindowAttribute", "ptr", hwnd, "int", 33, "ptr", pref, "int", 4)
}

; GDI wants BGR, the rest of this file writes colours as RGB
Bgr(hex) => Integer("0x" SubStr(hex, 5, 2) SubStr(hex, 3, 2) SubStr(hex, 1, 2))

FillRc(hdc, rc, hex) {
    br := DllCall("CreateSolidBrush", "uint", Bgr(hex), "ptr")
    DllCall("FillRect", "ptr", hdc, "ptr", rc, "ptr", br)
    DllCall("DeleteObject", "ptr", br)
}

; One habit dot: a filled circle, d across, with its top-left at x,y.
;
; NULL_PEN (stock object 8) rather than a pen of the same colour, because
; Ellipse outlines with the current pen and the default is a black 1px one -
; which on a 7px circle is most of the circle. With no pen at all the shape
; comes out one pixel short on the right and bottom, hence the +1s.
FillDot(hdc, x, y, d, hex) {
    br  := DllCall("CreateSolidBrush", "uint", Bgr(hex), "ptr")
    oBr := DllCall("SelectObject", "ptr", hdc, "ptr", br, "ptr")
    oPn := DllCall("SelectObject", "ptr", hdc, "ptr", DllCall("GetStockObject", "int", 8, "ptr"), "ptr")
    DllCall("Ellipse", "ptr", hdc, "int", x, "int", y, "int", x + d + 1, "int", y + d + 1)
    DllCall("SelectObject", "ptr", hdc, "ptr", oPn)
    DllCall("SelectObject", "ptr", hdc, "ptr", oBr)
    DllCall("DeleteObject", "ptr", br)
}

; Repaint one card's strip - used when the pointer moves between rows, so
; hovering costs one band instead of the whole panel.
;
; That card's three Text controls have to be invalidated too - which three
; depends on whether it is a task or a habit. They are BackgroundTrans,
; which means the PARENT paints what shows behind their glyphs; repainting the
; card underneath without repainting them leaves the text sitting on the old
; colour. (WS_CLIPCHILDREN would be the usual answer and is exactly wrong here -
; it would stop the parent painting under them at all, punching holes in the
; card where every label is.)
InvalidateCard(k) {
    if (!k || k > Cards.Length)
        return
    card := Cards[k]
    rc := Buffer(16, 0)
    NumPut("int", CardL, "int", card.y, "int", CardR, "int", card.y + RowH, rc)
    DllCall("InvalidateRect", "ptr", PanelHwnd, "ptr", rc, "int", true)
    names := (card.kind = "H") ? ["HabChk", "HabTxt", "HabNum"] : ["RowChk", "RowGo", "RowTxt"]
    for pre in names
        try DllCall("InvalidateRect", "ptr", PanelGui[pre card.pool].Hwnd, "ptr", 0, "int", true)
}

ShowPanel() {
    global PanelVisible, Hot
    PanelGui.Show("NoActivate x" PanelX " y" PanelY " w" PanelW " h200")
    PanelVisible := 1
    Hot := false
    ApplyPanelMode()
    ApplyOnTop()
    SetLockBtn()
    Relayout()
}

; A mode is two things: whether the mouse can see the window at all, and the
; pair of alphas it wears. WS_EX_TRANSPARENT (0x20) is the first, and GHOST is
; the only mode that sets it. Hover detection survives that because HoverCheck
; polls the cursor rather than waiting for messages the window will no longer
; receive.
ApplyPanelMode() {
    global Hot
    try WinSetExStyle((Ghost() ? "+" : "-") "0x20", PanelHwnd)
    PanelGui["ModeTxt"].Text := ModeGlyph()
    SetFootBtns()
    try WinSetTransparent(RestAlpha(), PanelHwnd)
    Hot := false
}

; GHOST is the only mode the mouse cannot touch, so everything that asks "can
; this be clicked or dragged" asks this rather than comparing numbers.
Ghost() {
    return (PanelMode = 2)
}

; The two ends of a mode: at rest, and with the pointer on it.
RestAlpha() {
    return (PanelMode = 0) ? PanelAlphaSol : PanelAlpha
}

HotAlpha() {
    if (PanelMode = 0)
        return PanelAlphaSol
    return (PanelMode = 2) ? PanelAlphaGho : PanelAlphaHot
}

; The circle beside the minutes, and the only thing that says which mode you
; are in. Filled, half, hollow - as much of the panel as the mouse can see.
ModeGlyph() {
    ; Nothing at all while the panel is an ordinary window. The circle is a
    ; badge for sitting over your work, so its absence is the tell - and the
    ; mode it would have shown moves to the tray menu, which spells it out.
    if (!PanelOnTop)
        return ""
    if (PanelMode = 0)
        return Chr(0x2B24)          ; solid
    if (PanelMode = 1)
        return Chr(0x25D0)          ; dim
    return Chr(0x25CB)              ; ghost
}
