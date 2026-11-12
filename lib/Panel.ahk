;================================================================================
; The panel
;   WS_EX_NOACTIVATE, and there is no MsgBox anywhere in this file on purpose:
;   MsgBox is modal and steals focus, which is the single thing that makes a
;   tool like this unbearable to have running while you are in something else.
;
;   Rows are a fixed POOL of controls that get moved, recoloured and hidden.
;   AHK cannot destroy a control once it exists, so building a row per task
;   would leak controls all day. A pool also means a redraw is a few Move calls
;   instead of rebuilding a list.
;================================================================================
BuildPanel() {
    global
    ; +MinimizeBox only so a taskbar click can minimise it - there is no
    ; caption to show the box on. The overlay kind is a tool window instead,
    ; which keeps it off the taskbar and out of Alt+Tab. See ApplyWindowKind().
    Gui, Panel:New, % "+AlwaysOnTop -Caption +HwndPanelHwnd +LabelPnl "
                   . (PanelTaskbar ? "+MinimizeBox" : "+ToolWindow +E0x08000000")
    PanelKind := PanelTaskbar
    ; Daybook's own taskbar button - the settings and habit windows join it
    TaskbarId(PanelHwnd, "Ahk.Daybook")
    Gui, Panel:Margin, 0, 0
    Gui, Panel:Color, %CBg%

    ; the sit bar. -Theme is required before a Progress will take custom colours
    Gui, Panel:Add, Progress, vTopBar x0 y0 w%PanelW% h5 -E0x200 -Theme Background%CTrack% c%CGreen%, 0

    ; The status and the minutes are always on. There is no hide-the-digits
    ; toggle any more: the digits only move once a minute, so there was nothing
    ; left to be distracted by, and the slot is worth more as the break switch.
    ; Top row: the status, then the minutes sitting right next to the break
    ; switch rather than floating in the middle of the row.
    Gui, Panel:Font, s8 Bold, Segoe UI
    Gui, Panel:Add, Text, vStatusTxt gDragPanel x12 y13 w96 h15 c%CGreen% BackgroundTrans, FOCUS
    Gui, Panel:Font, s8 Norm, Segoe UI
    Gui, Panel:Add, Text, vTimerTxt x108 y13 w118 h15 Right c%CText% BackgroundTrans,
    Gui, Panel:Add, Text, vModeTxt x228 y13 w12 h15 Center c%CDim% BackgroundTrans,
    Gui, Panel:Font, s8 Norm, Segoe UI
    Gui, Panel:Add, Text, vBreakBtn gBreakClick x242 y13 w48 h16 Right c%CDim% BackgroundTrans, break

    ; ---- headings.  There are no collapse buttons: the HEADING is the button,
    ;      and the caret in front of it says which way it is. That frees the
    ;      whole right-hand column, so + sits at the edge and the numbers line
    ;      up in one column under it.
    ; MISSED has no +: nothing is added to it by hand, a day's end puts things
    ; there. Its heading is amber, and it is not on the panel while it is empty.
    Gui, Panel:Font, s9 Bold, Segoe UI
    Gui, Panel:Add, Text, vMissHdr gToggleMissed x12 y36 w160 h17 c%CAmber% BackgroundTrans, MISSED
    Gui, Panel:Font, s8 Norm, Segoe UI
    Gui, Panel:Add, Text, vMissCnt x176 y38 w26 h14 Center c%CAmber% BackgroundTrans,

    Gui, Panel:Font, s9 Bold, Segoe UI
    Gui, Panel:Add, Text, vTodayHdr gToggleToday x12 y36 w160 h17 c%CText% BackgroundTrans, TODAY
    Gui, Panel:Font, s8 Norm, Segoe UI
    Gui, Panel:Add, Text, vTodayCnt x176 y38 w26 h14 Center c%CMuted% BackgroundTrans,
    Gui, Panel:Font, s12 Norm, Segoe UI
    ; the + doubles as the "I need something from you" light: it turns amber
    ; when the list is empty
    Gui, Panel:Add, Text, vAddBtn gAddClick x266 y34 w24 h20 Right c%CMuted% BackgroundTrans, +

    ; between Today and Long term: what has a day to be done by
    Gui, Panel:Font, s9 Bold, Segoe UI
    Gui, Panel:Add, Text, vShortHdr gToggleShort x12 y60 w160 h17 c%CText% BackgroundTrans, SHORT TERM
    Gui, Panel:Font, s8 Norm, Segoe UI
    Gui, Panel:Add, Text, vShortCnt x176 y62 w26 h14 Center c%CMuted% BackgroundTrans,
    Gui, Panel:Font, s12 Norm, Segoe UI
    Gui, Panel:Add, Text, vShortAdd gShortAddClick x266 y58 w24 h20 Right c%CMuted% BackgroundTrans, +

    Gui, Panel:Font, s9 Bold, Segoe UI
    Gui, Panel:Add, Text, vLongHdr gToggleLong x12 y60 w160 h17 c%CText% BackgroundTrans, LONG TERM
    Gui, Panel:Font, s8 Norm, Segoe UI
    Gui, Panel:Add, Text, vLongCnt x176 y62 w26 h14 Center c%CMuted% BackgroundTrans,
    Gui, Panel:Font, s12 Norm, Segoe UI
    Gui, Panel:Add, Text, vLongAdd gLongAddClick x266 y58 w24 h20 Right c%CMuted% BackgroundTrans, +

    ; ---- habits.  Same heading shape as the two task lists, and the count in
    ;      the middle is "how many of them are ticked today" rather than a
    ;      total - which is the only number a habit list has to answer.
    Gui, Panel:Font, s9 Bold, Segoe UI
    Gui, Panel:Add, Text, vHabHdr gToggleHabits x12 y84 w160 h17 c%CText% BackgroundTrans, HABITS
    Gui, Panel:Font, s8 Norm, Segoe UI
    Gui, Panel:Add, Text, vHabCnt x166 y86 w36 h14 Center c%CMuted% BackgroundTrans,
    Gui, Panel:Font, s12 Norm, Segoe UI
    Gui, Panel:Add, Text, vHabAdd gHabAddClick x266 y82 w24 h20 Right c%CMuted% BackgroundTrans, +

    ; ---- the journal.  Not a list and nothing to fold: the heading is a button
    ;      that opens the journal window, with a pencil where a caret would be,
    ;      and today's words on the right. Gone while the journal is off.
    Gui, Panel:Font, s9 Bold, Segoe UI
    Gui, Panel:Add, Text, vJrnHdr gJrnHdrClick x12 y84 w160 h17 c%CText% BackgroundTrans
        , % Chr(0x270E) " JOURNAL"
    Gui, Panel:Font, s8 Norm, Segoe UI
    Gui, Panel:Add, Text, vJrnCnt gJrnHdrClick x176 y86 w86 h14 Right c%CMuted% BackgroundTrans,

    Gui, Panel:Font, s9 Bold, Segoe UI
    Gui, Panel:Add, Text, vStatsHdr gToggleStats x12 y84 w160 h17 c%CText% BackgroundTrans, TIME
    Gui, Panel:Font, s8 Norm, Segoe UI
    ; the day's total and the per-app times share one right edge at 262, which
    ; is 8px inside the + column - the same inset the app names have from the
    ; heading on the left
    Gui, Panel:Add, Text, vStatsTotal x176 y86 w86 h14 Right c%CMuted% BackgroundTrans,
    ; Two columns rather than one string with tabs in it: a Static control does
    ; not expand tab stops, so the times came out ragged.
    Gui, Panel:Add, Text, vStatsTxt x20 y104 w140 h120 c%CMuted% BackgroundTrans,
    Gui, Panel:Add, Text, vStatsVal x164 y104 w98 h120 Right c%CDim% BackgroundTrans,

    ; ---- footer: the two keys on the left, three switches on the right
    Gui, Panel:Font, s7 Norm, Segoe UI
    ; 154 is what the row has left once the three switches have theirs. The
    ; line below fits well inside it; lengthen it and it clips.
    Gui, Panel:Add, Text, vFootTxt gDragPanel x12 y230 w154 h13 c%CDim% BackgroundTrans
        , % "Win+F6 panel   " Chr(0x00B7) "   Win+F1 break"
    ; The switches end on HdrNumR like every other right-hand thing on the
    ; panel, each right-aligned in a box of its own, so a word changing length
    ; never moves its neighbours - Relayout() places them:
    ;   mode    the mode spelled out - click to swap solid and dim. Never
    ;           ghost: that would be a click you could not click back from
    ;   on top  bright "on top" while the panel floats, dim "top" when not
    ;   lock    30 wide because "locked" measures 25. You set it once when the
    ;           panel is where you want it, and a button you have to go and
    ;           find is the right shape for a decision like that.
    Gui, Panel:Add, Text, vModeBtn gModeClick x172 y230 w32 h13 Right c%CDim% BackgroundTrans,
    Gui, Panel:Add, Text, vTopBtn gTopClick x210 y230 w34 h13 Right c%CDim% BackgroundTrans,
    Gui, Panel:Add, Text, vLockBtn gLockClick x248 y230 w30 h13 Right c%CDim% BackgroundTrans, lock

    ; ---- the row pool
    ; No background control per row: the cards are painted straight into the
    ; window in OnErase(). A Progress bar was the obvious way to get a coloured
    ; rectangle, but with transparent Text sitting on top of it, it drew its
    ; classic 1px 3D edge - a grey line above and a white line below every task.
    ; Painting the rectangles ourselves removes both the border and 22 controls.
    Gui, Panel:Font, s9 Norm, Segoe UI
    Loop % RowPool {
        n := A_Index
        ; the tick box gets its own larger font - it is the thing you aim at
        Gui, Panel:Font, s12 Norm, Segoe UI
        Gui, Panel:Add, Text, vRowChk%n% gRowChkClick x26 y400 w22 h%RowH% Center c%CMuted% BackgroundTrans +0x200,
        Gui, Panel:Font, s9 Norm, Segoe UI
        Gui, Panel:Add, Text, vRowX%n%   gRowXClick   x50 y400 w18 h%RowH% Center c%CDim%   BackgroundTrans +0x200, % Chr(0x2715)
        ; a MISSED row's third button: back onto Today's list, which is below
        Gui, Panel:Add, Text, vRowGo%n%  gRowGoClick  x70 y400 w18 h%RowH% Center c%CDim%   BackgroundTrans +0x200, % Chr(0x2193)
        ; +0x4000 is SS_ENDELLIPSIS: a name longer than the card ends in "..."
        ; drawn by Windows, instead of being cut mid-letter with nothing to
        ; say so. The whole of it is on hover - see HoverTip().
        Gui, Panel:Add, Text, vRowTxt%n% x72 y400 w1  h%RowH% c%CText% BackgroundTrans +0x4200,
    }
    ; ---- the habit row pool
    ; A habit row is a tick box, a name, and the streak. The week of dots in
    ; between is not a control at all - it is painted in OnErase, because seven
    ; coloured circles per row would otherwise be seventy controls that all
    ; have to be moved and recoloured on every layout.
    Gui, Panel:Font, s9 Norm, Segoe UI
    Loop % HabPool {
        n := A_Index
        Gui, Panel:Font, s12 Norm, Segoe UI
        Gui, Panel:Add, Text, vHabChk%n% gHabChkClick x26 y400 w22 h%RowH% Center c%CMuted% BackgroundTrans +0x200,
        Gui, Panel:Font, s9 Norm, Segoe UI
        Gui, Panel:Add, Text, vHabTxt%n% x50 y400 w1 h%RowH% c%CText% BackgroundTrans +0x4200,
        Gui, Panel:Font, s9 Bold, Segoe UI
        Gui, Panel:Add, Text, vHabNum%n% x200 y400 w%HabNumW% h%RowH% Right c%CDim% BackgroundTrans +0x200,
        Gui, Panel:Font, s9 Norm, Segoe UI
    }
    OnMessage(0x14,  "OnErase")           ; WM_ERASEBKGND
    OnMessage(0x201, "OnPanelClick")      ; WM_LBUTTONDOWN
    ShowPanel()
}

; Drag from anywhere empty.
;
; This only ever fires for clicks that reach the WINDOW - a control with a
; g-label swallows its own clicks, so the +, the headings, the tick boxes and
; the break switch all keep working. Plain labels (the minutes, the counts, the
; app list) have no g-label, and a static control without SS_NOTIFY is
; transparent to hit-testing, so clicks on those fall through to here as well.
; The net effect is that everything that is not a button is a drag handle.
OnPanelClick(wParam, lParam, msg, hwnd) {
    global PanelHwnd, PanelLocked, PanelOnTop, SetupHwnd
    ; lParam carries the click in client coordinates, packed two signed 16-bit
    ; numbers to a word.
    cx := lParam & 0xFFFF
    cy := (lParam >> 16) & 0xFFFF
    if (cx > 32767)
        cx -= 65536
    if (cy > 32767)
        cy -= 65536
    ; One WM_LBUTTONDOWN handler for the script, the same as OnErase above.
    if (hwnd = SetupHwnd && SetupHwnd) {
        SetupBarClick(cx, cy)
        return
    }
    if (hwnd != PanelHwnd || Ghost())
        return
    if (DotHit(cx, cy))
        return
    ; With always-on-top off, ApplyOnTop() has already taken WS_EX_NOACTIVATE
    ; off the window, so Windows activates and raises it on this click by
    ; itself - the same as any other window. The lift below is the belt to that
    ; brace: it costs nothing, and it covers the click that lands on a control
    ; with its own g-label, which never reaches this handler at all.
    if (!PanelOnTop)
        DllCall("SetWindowPos", "Ptr", PanelHwnd, "Ptr", 0
            , "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x13)
    if (PanelLocked)                                ; locked still comes forward
        return
    PostMessage, 0xA1, 2, , , ahk_id %PanelHwnd%   ; WM_NCLBUTTONDOWN, HTCAPTION
}

; Which habit dot the click landed on, if any. The target is the dot plus a
; pixel either side - nine of the ten pixels between one dot and the next - and
; the whole height of the card, so it is aimed at horizontally and not
; vertically. Returns true if it took the click.
DotHit(cx, cy) {
    d := DotAt(cx, cy)
    if (!IsObject(d))
        return false
    ToolTip, , , , 7                     ; its hint described the day before the click
    ; done -> frozen -> not done; when the blue step was skipped, say why - a
    ; click that does something other than expected looks like a broken panel
    if (HabitCycleDay(d.hab, d.day) = "nofreeze") {
        FormatTime, mname, % StrReplace(d.day, "-") "000000", MMMM
        FreezeSay("No freezes left in " mname ", so it went back to not done.")
    }
    return true
}

; The dot at a point in the panel, or "". Clicks and the hover hint both ask.
DotAt(cx, cy) {
    global Dots, HabDotD, RowH
    top := (RowH - HabDotD) // 2         ; how far a dot sits below its card
    for _, d in Dots {
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
; NOTE: this function is deliberately NOT assume-global, and its loop counters
; are deliberately not called "n".
;
; It runs as a message handler, so it fires in the MIDDLE of other code - every
; GuiControl call that moves or shows a control triggers a repaint, and AHK
; dispatches this between them. When it was assume-global its "n := A_Index"
; overwrote the same global "n" that PlaceRows was iterating with, and the rest
; of that iteration wrote its text into whatever row this had last painted.
; Rows came out holding another task's label, or empty.
;
; Cards and Dots are both built by Relayout(), so this only ever reads. Windows
; clips the device context to the part being repainted, so drawing all of it
; when only one row changed costs nothing - the rest is thrown away by GDI.
OnErase(wParam, lParam, msg, hwnd) {
    global PanelHwnd, Cards, Dots, RowH, CardL, CardR, HotCard, CBg, CCard, CCardHi, HabDotD
    global PanelW, PanelScrollY, PanelScrollMax, PanelContentH, PanelHdrH, CTrack, CDim
    global PanelLocked, SetupHwnd, PanelFootH
    ; OnMessage takes ONE function per message for the whole script, so every
    ; window of ours that paints its own background is answered from here.
    if (hwnd = SetupHwnd && SetupHwnd)
        return SetupErase(wParam)
    if (hwnd != PanelHwnd)
        return
    hdc := wParam
    VarSetCapacity(rc, 16, 0)
    DllCall("GetClientRect", "ptr", hwnd, "ptr", &rc)
    ch := NumGet(rc, 12, "int")
    FillRc(hdc, rc, CBg)
    for k, card in Cards {
        NumPut(CardL,          rc, 0,  "int")
        NumPut(card.y,         rc, 4,  "int")
        NumPut(CardR,          rc, 8,  "int")
        NumPut(card.y + RowH,  rc, 12, "int")
        FillRc(hdc, rc, (k = HotCard) ? CCardHi : CCard)
    }
    for _, d in Dots
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
        NumPut(PanelW - 6, rc, 0, "int"), NumPut(PanelHdrH + 6,      rc, 4,  "int")
        NumPut(PanelW - 3, rc, 8, "int"), NumPut(ch - PanelFootH - 6, rc, 12, "int")
        FillRc(hdc, rc, CTrack)
        NumPut(PanelW - 6, rc, 0, "int"), NumPut(ty,            rc, 4,  "int")
        NumPut(PanelW - 3, rc, 8, "int"), NumPut(ty + thumb,    rc, 12, "int")
        FillRc(hdc, rc, CDim)
    }
    return 1
}

; Rounded corners, asked for rather than drawn.
;
; A window with no title bar and no frame is not rounded by Windows 11 unless
; it says it wants to be - DWMWA_WINDOW_CORNER_PREFERENCE is attribute 33, and
; 2 means round, 1 means do not. Windows 10 has no such attribute and ignores
; the call, which is why there is nothing here to check a version with.
;
; This is the cheap half of what the note at the top of this file calls "not in
; this version": the corners, without the drop shadow, and without having to
; draw the whole panel as one layered bitmap to get them.
ApplyPanelShape() {
    global PanelHwnd, PanelRound
    ShapeWindow(PanelHwnd, PanelRound)
}

ShapeWindow(hwnd, round) {
    VarSetCapacity(pref, 4, 0)
    NumPut(round ? 2 : 1, pref, 0, "int")
    DllCall("dwmapi\DwmSetWindowAttribute", "ptr", hwnd, "int", 33
          , "ptr", &pref, "int", 4)
}

FillRc(hdc, ByRef rc, hex) {
    ; GDI wants BGR, the rest of this file writes colours as RGB
    bgr := "0x" SubStr(hex, 5, 2) SubStr(hex, 3, 2) SubStr(hex, 1, 2)
    br := DllCall("CreateSolidBrush", "uint", bgr + 0, "ptr")
    DllCall("FillRect", "ptr", hdc, "ptr", &rc, "ptr", br)
    DllCall("DeleteObject", "ptr", br)
}

; One habit dot: a filled circle, d across, with its top-left at x,y.
;
; NULL_PEN (stock object 8) rather than a pen of the same colour, because
; Ellipse outlines with the current pen and the default is a black 1px one -
; which on a 7px circle is most of the circle. With no pen at all the shape
; comes out one pixel short on the right and bottom, hence the +1s.
FillDot(hdc, x, y, d, hex) {
    bgr := "0x" SubStr(hex, 5, 2) SubStr(hex, 3, 2) SubStr(hex, 1, 2)
    br  := DllCall("CreateSolidBrush", "uint", bgr + 0, "ptr")
    oBr := DllCall("SelectObject", "ptr", hdc, "ptr", br, "ptr")
    oPn := DllCall("SelectObject", "ptr", hdc
                 , "ptr", DllCall("GetStockObject", "int", 8, "ptr"), "ptr")
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
; Also explicitly scoped, for the same reason as OnErase: it is reached from a
; timer and must not disturb whatever is halfway through laying the panel out.
InvalidateCard(k) {
    global PanelHwnd, Cards, RowH, CardL, CardR
    card := Cards[k]
    if (!k || !card)
        return
    VarSetCapacity(rc, 16, 0)
    NumPut(CardL,         rc, 0,  "int")
    NumPut(card.y,        rc, 4,  "int")
    NumPut(CardR,         rc, 8,  "int")
    NumPut(card.y + RowH, rc, 12, "int")
    DllCall("InvalidateRect", "ptr", PanelHwnd, "ptr", &rc, "int", true)
    names := (card.kind = "H") ? ["HabChk", "HabTxt", "HabNum"]
                               : ["RowChk", "RowX", "RowTxt"]
    for _, pre in names {
        GuiControlGet, h, Panel:Hwnd, % pre card.pool
        if (h)
            DllCall("InvalidateRect", "ptr", h, "ptr", 0, "int", true)
    }
}

ShowPanel() {
    global
    Gui, Panel:Show, NoActivate x%PanelX% y%PanelY% w%PanelW% h200, Daybook
    PanelVisible := 1
    Hot := false
    ApplyPanelMode()
    ApplyOnTop()
    SetLockBtn()
    Relayout()
}

; A mode is two things: whether the mouse can see the window at all, and the
; pair of alphas it wears. WS_EX_TRANSPARENT (0x20) is the first - the same flag
; AudioSwitch.ahk's readout uses - and GHOST is the only mode that sets it.
; Hover detection survives that because HoverCheck polls the cursor rather than
; waiting for messages the window will no longer receive.
ApplyPanelMode() {
    global
    WinSet, ExStyle, % (Ghost() ? "+" : "-") "0x20", ahk_id %PanelHwnd%
    GuiControl, Panel:, ModeTxt, % ModeGlyph()
    SetFootBtns()
    WinSet, Transparent, % RestAlpha(), ahk_id %PanelHwnd%
    Hot := false
}

; GHOST is the only mode the mouse cannot touch, so everything that asks "can
; this be clicked or dragged" asks this rather than comparing numbers.
Ghost() {
    global PanelMode
    return (PanelMode = 2)
}

; The two ends of a mode: at rest, and with the pointer on it.
RestAlpha() {
    global PanelMode, PanelAlpha, PanelAlphaSol
    return (PanelMode = 0) ? PanelAlphaSol : PanelAlpha
}

HotAlpha() {
    global PanelMode, PanelAlphaSol, PanelAlphaHot, PanelAlphaGho
    if (PanelMode = 0)
        return PanelAlphaSol
    return (PanelMode = 2) ? PanelAlphaGho : PanelAlphaHot
}

; The circle beside the minutes, and the only thing that says which mode you
; are in. Filled, half, hollow - as much of the panel as the mouse can see.
ModeGlyph() {
    global PanelMode, PanelOnTop
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

