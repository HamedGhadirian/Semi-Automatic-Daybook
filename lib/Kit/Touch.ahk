;================================================================================
; Touch.ahk (kit) - a made-up finger
;================================================================================
; Windows' touch injection (InjectTouchInput, Windows 8 and later, no
; administrator needed): one contact that goes down, moves, and lifts. A
; program that takes touch pans its page the way a finger would - the page
; follows the contact, and glides on when it lifts. A program that does NOT
; take touch is handed it as a left-button drag instead.
;
;   KitTouch.Ready()        can this PC do it at all? (asked once)
;   KitTouch.Down(x, y)     the finger goes down; true when Windows took it
;   KitTouch.Move(x, y)     ... moves ...
;   KitTouch.Up()           ... and lifts where it last was
;   KitTouch.active         is it down now;  KitTouch.at  when it went down
;
; x, y are real screen pixels: the caller's thread must be per-monitor DPI
; aware while it reads the pointer and calls these (Up sees to that itself,
; because it is also called from places that are not).
;
; One finger, with the glide. More fingers, and lifting without a glide, are
; for the day something needs them.
;================================================================================
#Requires AutoHotkey v2.0

class KitTouch {
    static active := false, at := 0, x := 0, y := 0
    static tried := false, ok := false
    static fake := ""                ; the tests: a function that gets the finger instead of Windows

    static Ready() {
        if KitTouch.fake
            return true
        if !KitTouch.tried {
            KitTouch.tried := true
            try KitTouch.ok := DllCall("InitializeTouchInjection", "uint", 1, "uint", 3) != 0   ; one contact, no feedback dots
        }
        return KitTouch.ok
    }

    static Down(x, y) {
        if !KitTouch.Ready()
            return false
        KitTouch.x := x, KitTouch.y := y, KitTouch.at := A_TickCount
        return KitTouch.active := KitTouch.Send(0x10006, x, y) != 0      ; DOWN | INRANGE | INCONTACT
    }

    static Move(x, y) {
        if !KitTouch.active
            return false
        KitTouch.x := x, KitTouch.y := y
        return KitTouch.Send(0x20006, x, y) != 0                       ; UPDATE | INRANGE | INCONTACT
    }

    static Up() {
        if !KitTouch.active
            return
        KitTouch.active := false
        ctx := DllCall("SetThreadDpiAwarenessContext", "ptr", -4, "ptr")
        KitTouch.Send(0x40000, KitTouch.x, KitTouch.y)                  ; UP
        DllCall("SetThreadDpiAwarenessContext", "ptr", ctx, "ptr")
    }

    ; One POINTER_TOUCH_INFO (144 bytes on 64-bit): a touch pointer, id 0, its
    ; flags and spot, and a 4-pixel contact area some programs ask for.
    static Send(flags, x, y) {
        if KitTouch.fake
            return KitTouch.fake.Call(flags, x, y)
        info := Buffer(144, 0)
        NumPut("uint", 2, info, 0)                          ; PT_TOUCH
        NumPut("uint", flags, info, 12)
        NumPut("int", x, "int", y, info, 32)
        NumPut("uint", 1, info, 100)                        ; TOUCH_MASK_CONTACTAREA
        NumPut("int", x - 2, "int", y - 2, "int", x + 2, "int", y + 2, info, 104)
        return DllCall("InjectTouchInput", "uint", 1, "ptr", info)
    }
}
