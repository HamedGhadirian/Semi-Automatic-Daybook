;================================================================================
; Timers
;================================================================================
#Requires AutoHotkey v2.0

TickFast() {
    Breathe()
    HoverCheck()
}

TickSecond() {
    TickSit()
}

; Counts the time that really passed since the last tick, not one second per
; tick: a timer tick is skipped whenever the script is busy (a drag, a menu, a
; slow write to the synced folder), and counting ticks made the clock run slow.
TickSit() {
    global Away, AwaySec, AwayIdleMs, SitSec
    static last := 0, carryMs := 0
    now := A_TickCount
    dt := last ? now - last : 1000
    last := now
    if (dt > BreakLenMin * 60000) {
        ; The script did not run at all for longer than a break - the machine
        ; was asleep or hibernating. Nobody sat through that. Mark it as time
        ; away, so the first input after waking counts as a whole break.
        carryMs := 0
        if (!BreakMode) {
            Away := 1
            AwaySec += dt // 1000
        }
        dt := 0
    }
    carryMs += dt
    secs := carryMs // 1000
    carryMs -= secs * 1000
    if (BreakMode) {
        ; nothing accrues during a declared break. It ends when you type or
        ; click - not on mouse movement, so nudging the mouse to keep the screen
        ; on does not end it - and only after a guard, so the keypress that
        ; started it does not immediately end it.
        if (now - BreakStart > BreakGuardS * 1000 && IdleMs() < 1500)
            EndBreak()
    } else if (Present()) {
        if (Away)
            ReturnFromAway()
        SitSec += secs
    } else {
        Away := 1
        AwaySec += secs
        gone := GoneMs()                     ; how long you had ACTUALLY been
        if (gone > AwayIdleMs)               ; gone, not just how long we have
            AwayIdleMs := gone               ; known it
    }
    ApplySitState()
    UpdateTimerText()
}

TickSample() {
    SampleApp()
}

MarkTick() {
    CommitMark()
}

TickMinute() {
    global StatsShown
    RollIfNeeded()
    ; UpdateStats() only rewrites the text. The drawer, and the window under it,
    ; were sized for the number of apps there were when the drawer was last laid
    ; out - so the minute a NEW app first shows up in the list, the extra line
    ; is painted into space that does not exist and the footer sits on top of
    ; it. Growing the panel needs a relayout, so ask for one whenever the count
    ; has moved. It stops happening once the list reaches StatsTop, which is why
    ; this only ever looked like an early-day bug. Skipped while the panel is
    ; hidden: Relayout() ends in a Show and would put it back on screen.
    ; ShowPanel() relayouts anyway.
    ;
    ; The text is rewritten whether the drawer is open or not. The total sits
    ; in the HEADING, which is on screen either way - updating it only while the
    ; drawer was open is what left a closed heading showing the morning's total
    ; all afternoon.
    if (OpenStats && PanelVisible && StatsLines() != StatsShown)
        Relayout()
    else
        UpdateStats()
    SaveState()
}
