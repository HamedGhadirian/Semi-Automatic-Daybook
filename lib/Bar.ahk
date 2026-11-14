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

SetStatusText() {
    if (EdgeState = 3)
        txt := "ON A BREAK", col := CBreak
    else if (EdgeState = 4)
        txt := "AWAY", col := CDim
    else if (EdgeState = 2)
        txt := "BREAK OVERDUE", col := CRed
    else if (EdgeState = 1)
        txt := "SITTING " SitWarnMin "M+", col := CAmber
    else
        txt := "FOCUS", col := CGreen
    PSay("StatusTxt", txt, col)
    SetBreakBtn()
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
        return
    }
    left := SitBreakMin * 60 - SitSec
    m := (left >= 0) ? Ceil(left / 60) : -Floor(left / 60)
    key := ((left >= 0) ? "l" : CutShort ? "c" : "o") m
    if (key == String(LastShownMin))
        return
    LastShownMin := key
    ; Overdue and back early from a break: still counting up, but saying why the
    ; bar is still red rather than looking as if the break never happened.
    if (left >= 0)
        txt := m "m left"
    else
        txt := CutShort ? "break cut short +" m "m" : "+" m "m over"
    PSay("TimerTxt", txt, (left >= 0) ? CText : CRed)
}
