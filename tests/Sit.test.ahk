; Sit.test.ahk - how long you were gone, and what that makes a break
;
; The sensors themselves (the screen, the lock, the keyboard) are the real
; machine's and are not faked here. What is tested is the sum made from them:
; how long you were away, counted from the last thing that said you were here.
#Requires AutoHotkey v2.0
#Include %A_LineFile%\..\Harness.ahk

BreakLenMin := 5, SitBreakMin := 45

; ---- the film: an hour of no input while sound played ---------------------------
; The sound stopped 30 seconds ago. You were not gone for an hour - you were
; gone, at most, since the sound stopped.
AudioCapMin := 120
LastSoundAt := A_TickCount - 30000
Ok("film: gone since the sound, not since the last touch", GoneMs() <= 30100 ? 1 : 0, 1)
SitSec := 3600, CutShort := 0
Away := 1, AwaySec := 1, AwayIdleMs := GoneMs()
ReturnFromAway()
Ok("film: a touch after it is no break - the clock stays", SitSec, 3600)
Ok("film: and the digits say it was cut short",         CutShort, 1)

; ---- a real break: five minutes and more away -------------------------------------
SitSec := 3600, CutShort := 0
Away := 1, AwaySec := 0, AwayIdleMs := 6 * 60000
ReturnFromAway()
Ok("a whole break clears the clock",  SitSec, 0)
Ok("and it was not cut short",         CutShort, 0)

; ---- the time Daybook took to notice counts as break -------------------------------
; Noticed at 5 minutes, back at 7: AwaySec only saw 2, the last touch says 7.
SitSec := 3600
Away := 1, AwaySec := 120, AwayIdleMs := 7 * 60000
ReturnFromAway()
Ok("the minutes before it noticed are break too", SitSec, 0)

; ---- with sound switched off, only input counts ------------------------------------
AudioCapMin := 0
LastSoundAt := A_TickCount
a := GoneMs(), b := SeenMs()
Ok("sound off: the last touch alone", Abs(a - b) < 200 ? 1 : 0, 1)

; ---- no sound heard yet ------------------------------------------------------------
AudioCapMin := 120, LastSoundAt := 0
a := GoneMs(), b := SeenMs()
Ok("no sound yet: the last touch alone", Abs(a - b) < 200 ? 1 : 0, 1)

Done()
