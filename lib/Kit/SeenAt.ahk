;================================================================================
; SeenAt.ahk (kit) - is this window the one you actually see at a point
;================================================================================
; A panel that reacts to the pointer usually asks "is the pointer inside my
; rectangle". That is wrong whenever another window sits on top of the panel:
; the pointer is on THAT window, yet the panel lights up or pops a tooltip
; over somebody else's program.
;
; WindowFromPoint asks Windows which window is really under the point. It
; skips hidden and cloaked windows, and the ones the mouse passes through
; (WS_EX_TRANSPARENT) - so a click-through panel never answers for itself.
; So when the window found is not ours, walk the z-order (the front-to-back
; stacking of windows) from ours towards the front: meeting the window found
; means it is in front of ours and covers it; running out means ours is the
; one on top at that point.
;
; The v2 twin of lib\SeenAt.ahk, with the same name.
;================================================================================
#Requires AutoHotkey v2.0

WindowSeenAt(hwnd, x, y) {
    hit := DllCall("WindowFromPoint", "int64", (y << 32) | (x & 0xFFFFFFFF), "ptr")
    if !hit
        return false
    root := DllCall("GetAncestor", "ptr", hit, "uint", 2, "ptr")       ; GA_ROOT
    if (root = hwnd)
        return true
    w := hwnd
    loop 2000 {
        w := DllCall("GetWindow", "ptr", w, "uint", 3, "ptr")          ; GW_HWNDPREV: one nearer the front
        if !w
            return true
        if (w = root)
            return false
    }
    return true
}
