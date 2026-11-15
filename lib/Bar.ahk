;================================================================================
; Sit timer -> the top bar
;================================================================================
#Requires AutoHotkey v2.0

ApplySitState() {
    global EdgeState
    if (BreakMode)
        want := 3
    else if (Away)
        want := 4
    else {
        mins := SitSec / 60
        want := (mins >= SitBreakMin) ? 2 : (mins >= SitWarnMin) ? 1 : 0
    }
    if (want != EdgeState) {
        EdgeState := want
        if (want = 3)
            SetBarColour(CBreak)
        else if (want = 4)
            SetBarColour(CDim)
        else if (want < 2)
            SetBarColour(want ? CAmber : CGreen)
        SetStatusText()
    }
    ; the fill moves with the clock even when the colour has not changed
    pct := BreakMode ? 0 : Round(SitSec / (SitBreakMin * 60) * 100)
    PanelGui["TopBar"].Value := (pct > 100 ? 100 : pct)
    ; NagLevel > 0 would escalate from here.
}

; Each status has shorter forms for a narrow panel (FitTopRow), longest first.
SetStatusText() {
    global StatusWords
    if (EdgeState = 3)
        StatusWords := ["ON A BREAK", "BREAK"], col := CBreak
    else if (EdgeState = 4)
        StatusWords := ["AWAY", "AWAY"], col := CDim
    else if (EdgeState = 2)
        StatusWords := CutShort ? ["BREAK CUT SHORT", "CUT SHORT", "OVERDUE"] : ["BREAK OVERDUE", "OVERDUE"], col := CRed
    else if (EdgeState = 1)
        StatusWords := ["SITTING " SitWarnMin "M+", "SITTING"], col := CAmber
    else
        StatusWords := ["FOCUS", "FOCUS"], col := CGreen
    PSay("StatusTxt", StatusWords[1], col)
    FitTopRow()
    SetBreakBtn()
}

; The top row has little room since the window buttons came (2026-11-13), so
; the status says why and the minutes only say how many. The status is as wide
; as its words, and the minutes take what is left up to the mode circle - so
; the two never sit on top of each other. When the minutes would not fit (a
; narrow panel, a long status), the status takes its short form: the number
; is the one thing that must always show.
FitTopRow() {
    if !IsObject(PanelBtns) || !IsObject(StatusWords)
        return
    s := PanelGui["StatusTxt"], t := PanelGui["TimerTxt"]
    dpi := 96 / A_ScreenDPI                                      ; the panel moves in 96-dpi units
    need := Ceil(TextWidth(t.Hwnd, t.Text) * dpi)
    right := PanelW - 8 - PanelBtns.Width - 56                   ; just before the mode circle
    ; not a for: v2 puts a for's variable back as it was when the loop ends
    loop StatusWords.Length {
        words := StatusWords[A_Index]
        w := Ceil(TextWidth(s.Hwnd, words) * dpi) + 2
        x := 12 + w + 6
        if (right - x >= need)
            break
    }
    if (s.Text != words)
        s.Text := words
    s.Move(, , w)
    t.Move(x, , (right > x) ? right - x : 0)
}

; the button in the header says what pressing it will do
SetBreakBtn() {
    PSay("BreakBtn", BreakMode ? "back" : "break", BreakMode ? CBreak : CDim)
}

; Same shape as the break switch above: the word says what the panel is, and
; the colour is what makes it readable at a glance from across the desk.
SetLockBtn() {
    PSay("LockBtn", PanelLocked ? "locked" : "lock", PanelLocked ? CText : CDim)
}

; The two switches beside the lock. The mode is spelled out here because the
; circle beside the minutes goes away while the panel is not on top; the on-top
; switch is bright while it is on, the way the lock is bright while locked.
SetFootBtns() {
    PanelGui["ModeBtn"].Text := StrLower(ModeName())
    if IsObject(PanelBtns)
        PanelBtns.SetTop(PanelOnTop)              ; the pin among the window buttons
}

SetBarColour(colour) {
    PanelGui["TopBar"].Opt("c" colour)
}

; The only animation, and it gives up on an empty chair. One tick per shade over
; eight shades is a ~1.2s cycle - still breathing rather than blinking, but with
; some urgency to it.
Breathe() {
    global BreathStep
    if (EdgeState != 2)
        return
    if (SeenMs() > RedQuietMin * 60000) {
        SetBarColour(CRed)
        return
    }
    BreathStep := Mod(BreathStep, CBreathe.Length) + 1
    SetBarColour(CBreathe[BreathStep])
}

; Counts DOWN inside the 45 minutes, UP once past it. Minutes only, repainted
; once a minute - see the note at the top of Daybook.ahk about why there are no
; seconds here. LastShownMin is a key for what is on screen, prefixed by state,
; so switching state always repaints even when the minute number happens to
; match.
UpdateTimerText() {
    global LastShownMin
    if (BreakMode || Away) {
        if (BreakMode)
            m := (A_TickCount - BreakStart) // 60000, col := CBreak
        else {
            s := AwayIdleMs // 1000
            m := ((s > AwaySec) ? s : AwaySec) // 60, col := CDim
        }
        key := (BreakMode ? "b" : "a") m
        if (key == String(LastShownMin))
            return
        LastShownMin := key
        PSay("TimerTxt", "away " m "m", col)
        FitTopRow()
        return
    }
    left := SitBreakMin * 60 - SitSec
    m := (left >= 0) ? Ceil(left / 60) : -Floor(left / 60)
    key := ((left >= 0) ? "l" : CutShort ? "c" : "o") m
    if (key == String(LastShownMin))
        return
    LastShownMin := key
    ; Overdue, or back early from a break: just the minutes over. The status
    ; beside it says which (SetStatusText) - the row has no room for both.
    if (left >= 0)
        txt := m "m left"
    else
        txt := "+" m "m"
    PSay("TimerTxt", txt, (left >= 0) ? CText : CRed)
    FitTopRow()                          ; a longer number may need a shorter status
}
