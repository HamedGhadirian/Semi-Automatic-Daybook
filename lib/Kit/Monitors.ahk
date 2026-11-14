;================================================================================
; Monitors.ahk (kit) - one monitor described, and monitors in desk order
;================================================================================
; The v2 twin of lib\Monitors.ahk, with the same names, like the Cfg
; functions. Every number is in the caller's DPI context: a script that wants
; real pixels on every monitor switches to per-monitor awareness first.
;================================================================================
#Requires AutoHotkey v2.0

; rcMonitor, rcWork, the primary flag and the device name of one monitor, from
; MONITORINFOEX: cbSize 0, rcMonitor 4, rcWork 20, dwFlags 36, szDevice 40
; (32 characters), 104 bytes. ok is false when Windows did not know the
; handle - the numbers are all 0 then.
;   x y w h       the whole monitor        wx wy ww wh   its work area
;   primary       the main one             device        \\.\DISPLAY1 ...
;   handle        the handle asked about
MonInfo(hMon) {
    mi := Buffer(104, 0)
    NumPut("uint", 104, mi)
    ok := DllCall("GetMonitorInfoW", "ptr", hMon, "ptr", mi)
    m := {x: NumGet(mi, 4, "int"), y: NumGet(mi, 8, "int")
        , wx: NumGet(mi, 20, "int"), wy: NumGet(mi, 24, "int")}
    m.w  := NumGet(mi, 12, "int") - m.x
    m.h  := NumGet(mi, 16, "int") - m.y
    m.ww := NumGet(mi, 28, "int") - m.wx
    m.wh := NumGet(mi, 32, "int") - m.wy
    m.primary := (NumGet(mi, 36, "uint") & 1) ? true : false      ; MONITORINFOF_PRIMARY
    m.device  := StrGet(mi.Ptr + 40, 32, "UTF-16")
    m.handle  := hMon
    m.ok      := ok ? true : false
    return m
}

; The monitor a point is on, or the nearest one (MONITOR_DEFAULTTONEAREST).
; A POINT goes by value: eight bytes, x in the low half.
MonAt(x, y) => DllCall("MonitorFromPoint", "int64", (x & 0xFFFFFFFF) | (y << 32), "uint", 2, "ptr")

; The primary monitor's handle.
MonPrimary() => DllCall("MonitorFromPoint", "int64", 0, "uint", 1, "ptr")

; Left to right, then top to bottom - the order they stand on the desk.
; EnumDisplayMonitors hands them back in whatever order it likes, and that
; order is NOT stable between calls, so anything listing monitors sorts them
; first. Anything with an x and a y sorts.
MonSortByPosition(list) {
    sorted := []
    for m in list {
        pos := sorted.Length + 1
        for i, s in sorted
            if (m.x < s.x || (m.x = s.x && m.y < s.y)) {
                pos := i
                break
            }
        sorted.InsertAt(pos, m)
    }
    return sorted
}

; A monitor's scaling as dots per inch: 96 at 100%, 144 at 150%.
MonDpi(hMon) {
    dx := 96, dy := 96
    try DllCall("shcore\GetDpiForMonitor", "ptr", hMon, "int", 0, "uint*", &dx, "uint*", &dy)
    return dx ? dx : 96
}
