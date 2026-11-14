;================================================================================
; The passive log
;================================================================================
#Requires AutoHotkey v2.0

SampleApp() {
    if (!LogApps || !Present())
        return
    exe := ""
    try exe := WinGetProcessName("A")
    if (exe = "")
        return
    exe := RegExReplace(exe, "i)\.exe$")
    secs := SampleMs // 1000
    AppSec[exe] := (AppSec.Has(exe) ? AppSec[exe] : 0) + secs
    hk := A_Hour "|" exe
    HourSec[hk] := (HourSec.Has(hk) ? HourSec[hk] : 0) + secs
}

; Biggest first. Zero-padding makes a text sort numerically correct, which is
; cheaper than writing a comparator.
TopApps(limit := 0) {
    lines := ""
    for exe, sec in AppSec
        lines .= Format("{:09}", sec) "`t" exe "`n"
    lines := Sort(lines, "R")
    out := []
    loop parse lines, "`n", "`r" {
        if (A_LoopField = "")
            continue
        p := StrSplit(A_LoopField, "`t")
        out.Push({exe: p[2], sec: Integer(p[1])})
        if (limit && out.Length >= limit)
            break
    }
    return out
}

HumanTime(sec) {
    h := sec // 3600, m := Mod(sec // 60, 60)
    return h ? h "h " m "m" : m "m"
}

TotalLogged() {
    total := 0
    for exe, sec in AppSec
        total += sec
    return total
}

UpdateStats() {
    ; the heading carries the accumulation of everything under it, so the number
    ; is there whether or not the drawer is open
    PanelGui["StatsTotal"].Text := HumanTime(TotalLogged())
    names := "", vals := ""
    for a in TopApps(StatsTop) {
        names .= (names != "" ? "`n" : "") a.exe
        vals  .= (vals  != "" ? "`n" : "") HumanTime(a.sec)
    }
    PanelGui["StatsTxt"].Text := (names = "" ? "nothing yet" : names)
    PanelGui["StatsVal"].Text := vals
}

StatsLines() {
    n := TopApps(StatsTop).Length
    return n ? n : 1
}

; One line per hour, widest app first, one block per 5 minutes. Markdown only:
; this is something you read when reviewing, not while working.
HourStrip() {
    ; Keys are prefixed with "h": the hours are kept as text all the way, so
    ; "09" sorts before "10" - see the sort below for the order they go in.
    hours := Map()
    for k, sec in HourSec {
        p := StrSplit(k, "|")
        if (p.Length < 2)
            continue
        if (!hours.Has("h" p[1]))
            hours["h" p[1]] := Map()
        hours["h" p[1]][p[2]] := sec
    }
    ; Sorted by hours since the day began, not by the clock: the day runs from
    ; DayStartHour to DayStartHour, so 01:00 comes AFTER 23:00, and a plain sort
    ; put the small hours at the top of the strip as if they started the day.
    keys := ""
    for h in hours
        keys .= Format("{:02}", Mod(Integer(SubStr(h, 2)) + 24 - DayStartHour, 24)) "`t" h "`n"
    keys := Sort(keys)
    out := ""
    loop parse keys, "`n", "`r" {
        if (A_LoopField = "")
            continue
        key := SubStr(A_LoopField, InStr(A_LoopField, "`t") + 1)
        h := SubStr(key, 2)
        lines := ""
        for exe, sec in hours[key]
            lines .= Format("{:09}", sec) "`t" exe "`n"
        lines := Sort(lines, "R")
        row := "", n := 0
        loop parse lines, "`n", "`r" {
            if (A_LoopField = "")
                continue
            if (++n > 3)
                break
            p := StrSplit(A_LoopField, "`t")
            bars := Round(Integer(p[1]) / 300)
            if (bars < 1)
                continue
            block := ""
            loop bars
                block .= Chr(0x2588)
            row .= (row != "" ? "  " : "") block " " p[2]
        }
        if (row != "")
            out .= "       " h "  " row "`n"
    }
    return out
}
