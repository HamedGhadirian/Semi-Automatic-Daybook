; Log.test.ahk - the day's totals and the hour strip
;
; The strip is what the closing day's note carries, and the one thing it has
; to get right is order: a day runs from DayStartHour to DayStartHour, so the
; small hours come LAST.
#Requires AutoHotkey v2.0
#Include %A_LineFile%\..\Harness.ahk

Hours() {
    order := ""
    loop parse HourStrip(), "`n"
        if (A_LoopField != "")
            order .= SubStr(Trim(A_LoopField), 1, 2) " "
    return Trim(order)
}

; ---- the hour strip runs in the order the day did ---------------------------
DayStartHour := 3
HourSec["01|firefox"] := 600
HourSec["23|claude"]  := 600
HourSec["03|WINWORD"] := 600
HourSec["09|ck3"]     := 600
HourSec["02|Telegram"] := 600
Ok("03 first, the small hours last", Hours(), "03 09 23 01 02")

DayStartHour := 0
Ok("a day starting at midnight is the clock", Hours(), "01 02 03 09 23")

; ---- under five minutes in an hour draws nothing ---------------------------
HourSec := DayMap(), HourSec["10|notepad"] := 60
Ok("a minute is not a block", HourStrip(), "")

; ---- totals --------------------------------------------------------------
AppSec := DayMap(), AppSec["a"] := 3600, AppSec["b"] := 60, AppSec["c"] := 7200
Ok("total",          TotalLogged(), 10860)
Ok("biggest first",  TopApps(1)[1].exe, "c")
Ok("human time",     HumanTime(3660), "1h 1m")
Ok("under an hour",  HumanTime(59 * 60), "59m")
; one program however Windows spelled its name that minute
AppSec["Chrome"] := 30, AppSec["chrome"] += 30
Ok("one program, whatever its case", AppSec["CHROME"], 60)

Done()
