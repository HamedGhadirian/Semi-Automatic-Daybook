;================================================================================
; Keys.ahk (kit) - the keys, and the rows that change them
;================================================================================
; A script hands Kit.Start its actions:
;     keys: [{id: "Start", name: "Start scrolling", short: "scroll"
;           , def: "#!RButton", fn: (hk) => ..., cond: (hk) => ...}]
;   id      the line's name in the .ini, under [Keys]
;   name    what the settings window calls it; short is for the tray tip
;   def     the key a new download starts with, as an AutoHotkey key name
;   fn      what the key does
;   cond    (optional) the key only counts while this is true. Keep it for
;           keys held with a modifier: a condition on a bare click would be
;           asked on every click in every program.
;   shift   (optional) true: the same key with Shift does it too - fn is
;           handed the key pressed, so it can tell (Alt+Tab, Alt+Shift+Tab)
;
; PAUSED. KitKeys.Pause(id, true) switches one action's key off without
; forgetting it - for a script setting that hands the key back to Windows
; for a while. Pause(id, false) switches it on again. A paused key stays off
; through a recording and through being changed.
;
; Settings > KEYS. Click "change" beside an action and press the new keys:
; hold Ctrl, Alt, Shift or Win and press a key, or click a mouse button. It
; is checked, used straight away, and kept in the .ini under [Keys]. Only
; keys that differ from the default are written there, so "default" simply
; deletes the line. "off" leaves an action with no key at all (written as
; "none").
;
; EVERY KEY IS SWITCHED ON WITH ITS ACTION, EVERY TIME. The Hotkey function
; keeps one action per key: whoever named the key last owns it. Passing the
; action each time means a key can never be left running another part's code.
;
; HOW THE RECORDING WORKS
; AutoHotkey's own Hotkey box cannot record the Win key or a mouse click. So
; while one row is recording:
;   the keyboard    an InputHook catches every key and blocks it - the Win key
;                   too, so pressing it does not open the Start menu. The key
;                   that is not a modifier ends the recording; the modifiers
;                   held at that moment are read from their physical state.
;   the mouse       five temporary hotkeys (*LButton ... *XButton2), live only
;                   while a modifier is held, so the plain click on "change"
;                   and any other ordinary click go through untouched.
;   the script's    keys are switched off, so pressing the current key
;                   records it instead of running it.
; Everything is switched back once the modifiers are let go - letting go of
; Win with its hotkey already live again could still trip the Start menu.
;
; WHAT IS REFUSED, AND WHAT ONLY GETS A WARNING
;   refused   a key on its own that is needed for typing or clicking (a letter,
;             Space, Enter, a plain click); the same with only Shift; keys
;             Windows keeps for itself (Win + L, Alt + Tab, Alt + F4,
;             Ctrl + Alt + Del, Ctrl + Shift + Esc); Ctrl + A, C, V, X, Y or
;             Z, which every program needs; and a key another action has.
;             Alt + Tab is not refused for an action whose own default it
;             is - a window switcher made to take its place.
;   warned    a key on its own that is not for typing (F9, a mouse side
;             button); anything with Ctrl or Alt that programs may use; Win
;             with a key Windows may use. These work - the script just takes
;             them over while it runs, and the window says so
;
; Character keys are stored by key position (vkC0 is the key left of 1), not
; by the character, so they keep working when the keyboard layout changes.
; The window shows them as the English character.
;================================================================================
#Requires AutoHotkey v2.0

class KitKeys {
    static now := Map()             ; id -> the hotkey in use now ("" = none)
    static paused := Map()          ; id -> true while its key is paused

    static List() => Kit.Opt("keys", [])
    static Cur(id) => KitKeys.now.Has(id) ? KitKeys.now[id] : ""

    ; Registers every action's key: the one in the .ini when it is still
    ; usable, the default otherwise. A hand-edited line that does not work is
    ; logged and reported once, and the default takes over.
    static Start() {
        bad := []
        for a in KitKeys.List()
            KitKeys.now[a.id] := ""
        for a in KitKeys.List() {
            hk := CfgStr(Kit.ini, "Keys", a.id, "")
            if (hk = "none")                    ; switched off in Settings
                continue
            if (hk != "") {
                c := KitKeys.Check(hk, a.id)
                if (c.err != "" || !KitKeys.Try(hk, a)) {
                    Kit.Log("Keys: " a.id "=" hk " in the settings file is not usable ("
                        . (c.err != "" ? c.err : "AutoHotkey refused it") "), using the default")
                    bad.Push(a.name)
                    hk := ""
                }
            }
            if (hk = "") {
                hk := a.def
                if (hk != "" && (KitKeys.Check(hk, a.id).err != "" || !KitKeys.Try(hk, a))) {
                    Kit.Log("Keys: the default " hk " for " a.id " is taken, so it has no key")
                    bad.Push(a.name)
                    hk := ""
                }
            }
            KitKeys.now[a.id] := hk
        }
        if bad.Length
            Kit.Notice("Some keys in the settings file could not be used:`n" KitJoin(bad, ", ")
                . "`nTray menu > Settings", , () => KitSettings.Show(), 2)
    }

    static Find(id) {
        for a in KitKeys.List()
            if (a.id = id)
                return a
    }

    ; the condition this action's key lives under, or none
    static Scope(a) {
        if (a.HasProp("cond") && a.cond)
            HotIf(a.cond)
        else
            HotIf()
    }

    static On(hk, a) {
        ok := false
        try {
            KitKeys.Scope(a)
            Hotkey(hk, a.fn, "On")
            if ((sh := KitKeys.Shifted(hk, a)) != "")
                Hotkey(sh, a.fn, "On")
            ok := true
        }
        HotIf()
        return ok
    }

    static Off(hk, a) {
        if (hk = "")
            return
        try {
            KitKeys.Scope(a)
            Hotkey(hk, "Off")
        }
        try {
            if ((sh := KitKeys.Shifted(hk, a)) != "")
                Hotkey(sh, "Off")
        }
        HotIf()
    }

    ; at start: switched on - or, for a paused one, only proved acceptable
    static Try(hk, a) {
        if !KitKeys.IsPaused(a.id)
            return KitKeys.On(hk, a)
        ok := false
        try {
            KitKeys.Scope(a)
            Hotkey(hk, a.fn, "Off")
            ok := true
        }
        HotIf()
        return ok
    }

    ; the same key with Shift, for an action that wants it too ("" if not,
    ; or when the key has Shift already)
    static Shifted(hk, a) {
        if !(a.HasProp("shift") && a.shift) || InStr(KitKeys.Parse(hk).mods, "+")
            return ""
        return "+" hk
    }

    static IsPaused(id) => KitKeys.paused.Has(id)

    ; Off without forgetting it, or on again
    static Pause(id, yes) {
        a := KitKeys.Find(id)
        if (!IsObject(a) || (yes ? true : false) = KitKeys.IsPaused(id))
            return
        if yes {
            KitKeys.paused[id] := true
            KitKeys.Off(KitKeys.Cur(id), a)
        } else {
            KitKeys.paused.Delete(id)
            if (KitKeys.Cur(id) != "" && !KitKeysWin.rec && !KitKeysWin.waiting)
                KitKeys.On(KitKeys.Cur(id), a)
        }
        KitTray.Build()
    }

    static AllOff() {
        for a in KitKeys.List()
            KitKeys.Off(KitKeys.Cur(a.id), a)
    }

    static AllOn() {
        for a in KitKeys.List()
            if (KitKeys.Cur(a.id) != "" && !KitKeys.IsPaused(a.id))
                KitKeys.On(KitKeys.Cur(a.id), a)
    }

    ; Gives an action a new key and keeps it. live = the keys are switched on
    ; right now (false while recording, when they are all off anyway).
    ; Returns "" or why AutoHotkey would not take it.
    static Set(id, hk, live := true) {
        a := KitKeys.Find(id)
        old := KitKeys.Cur(id)
        if (hk = "") {                      ; off: no key at all, kept as "none"
            if live
                KitKeys.Off(old, a)
            KitKeys.now[id] := ""
            try IniWrite("none", Kit.ini, "Keys", id)
            KitTray.Build()
            return ""
        }
        ok := false
        try {
            KitKeys.Scope(a)
            Hotkey(hk, a.fn, "Off")         ; only proves AutoHotkey accepts the name
            ok := true
        }
        HotIf()
        if !ok
            return "AutoHotkey does not accept " KitKeys.Label(hk)
        if (live && KitKeys.IsPaused(id)) {
            KitKeys.Off(old, a)             ; stays off: only the key changes
        } else if live {
            KitKeys.Off(old, a)
            if !KitKeys.On(hk, a) {
                if (old != "")
                    KitKeys.On(old, a)
                return "AutoHotkey does not accept " KitKeys.Label(hk)
            }
        }
        KitKeys.now[id] := hk
        try {
            if (hk = a.def)
                IniDelete(Kit.ini, "Keys", id)
            else
                IniWrite(hk, Kit.ini, "Keys", id)
        }
        KitTray.Build()
        return ""
    }

    ;----------------------------------------------------------------------------
    ; Reading a hotkey
    ;----------------------------------------------------------------------------
    ; mods in a fixed order, the key, and a same-key test that ignores how it
    ; was written: "#``" and "#vkC0" are the same key.
    static Parse(hk) {
        if !RegExMatch(hk, "^([~*$<>^!+#]*)(.+)$", &m)
            return {mods: "", key: "", vk: 0, sc: 0, same: ""}
        p := m[1], key := m[2]
        mods := (InStr(p, "^") ? "^" : "") (InStr(p, "!") ? "!" : "")
            . (InStr(p, "+") ? "+" : "") (InStr(p, "#") ? "#" : "")
        vk := 0, sc := 0
        if !InStr(key, " & ")
            try vk := GetKeyVK(key), sc := GetKeySC(key)
        return {mods: mods, key: key, vk: vk, sc: sc, same: mods "|" ((vk || sc) ? vk "|" sc : StrLower(key))}
    }

    static IsModifier(vk) => (vk >= 0x10 && vk <= 0x12) || (vk >= 0xA0 && vk <= 0xA5) || vk = 0x5B || vk = 0x5C

    ; Keys that type something or move the caret, and the two main clicks:
    ; on their own they are what everyone uses all day.
    static IsTyping(vk) {
        return (vk >= 0x30 && vk <= 0x5A) || (vk >= 0x60 && vk <= 0x6F) || (vk >= 0xBA && vk <= 0xC0)
            || (vk >= 0xDB && vk <= 0xDF) || vk = 0xE2 || (vk >= 0x20 && vk <= 0x28) || vk = 0x2E
            || vk = 0x0D || vk = 0x09 || vk = 0x08 || vk = 0x1B || vk = 0x01 || vk = 0x02
    }

    static IsMouse(vk) => (vk >= 0x01 && vk <= 0x06 && vk != 0x03)

    ; The name to store for a key pressed while recording. Character keys go
    ; by position (vkXX) so another keyboard layout does not change them.
    static KeyName(vk, sc) {
        if ((vk >= 0x30 && vk <= 0x39) || (vk >= 0x41 && vk <= 0x5A)
            || (vk >= 0xBA && vk <= 0xC0) || (vk >= 0xDB && vk <= 0xDF) || vk = 0xE2)
            return Format("vk{:X}", vk)
        n := sc ? GetKeyName(Format("sc{:X}", sc)) : ""
        if (n = "")
            n := GetKeyName(Format("vk{:X}", vk))
        return (n != "") ? n : Format("vk{:X}sc{:X}", vk, sc)
    }

    ; "+#LButton" -> "Shift + Win + Click", "#!RButton" -> "Win + Alt +
    ; Right-click" - the order people say them in. tight drops the spaces.
    static Label(hk, tight := false) {
        if (hk = "")
            return "none"
        p := KitKeys.Parse(hk)
        parts := []
        for m in [["^", "Ctrl"], ["+", "Shift"], ["#", "Win"], ["!", "Alt"]]
            if InStr(p.mods, m[1])
                parts.Push(m[2])
        parts.Push(KitKeys.KeyText(p.key, p.vk))
        return KitJoin(parts, tight ? "+" : " + ")
    }

    static KeyText(key, vk) {
        static mouse := Map("lbutton", "Click", "rbutton", "Right-click", "mbutton", "Middle-click"
            , "xbutton1", "Mouse back", "xbutton2", "Mouse forward"
            , "wheelup", "Wheel up", "wheeldown", "Wheel down")
        static oem := Map(0xBA, ";", 0xBB, "=", 0xBC, ",", 0xBD, "-", 0xBE, ".", 0xBF, "/"
            , 0xC0, "``", 0xDB, "[", 0xDC, "\", 0xDD, "]", 0xDE, "'", 0xE2, "\")
        if mouse.Has(StrLower(key))
            return mouse[StrLower(key)]
        if ((vk >= 0x30 && vk <= 0x39) || (vk >= 0x41 && vk <= 0x5A))
            return Chr(vk)
        if oem.Has(vk)
            return oem[vk]
        n := ""
        try n := GetKeyName(key)
        n := (n != "") ? n : key
        return StrUpper(SubStr(n, 1, 1)) SubStr(n, 2)
    }

    ;----------------------------------------------------------------------------
    ; Is it a good key?
    ;----------------------------------------------------------------------------
    ; {err: why it is refused, warn: what to know} - both "" when all is well
    static Check(hk, id) {
        p := KitKeys.Parse(hk)
        lbl := KitKeys.Label(hk)
        if (p.key = "")
            return {err: "that is not a key", warn: ""}
        if (!(p.vk || p.sc) && !InStr(p.key, " & "))
            return {err: p.key " is not a key AutoHotkey knows", warn: ""}
        strong := RegExMatch(p.mods, "[\^!#]")
        if (!strong && KitKeys.IsTyping(p.vk))
            return {err: (p.mods = "+")
                ? lbl " is just typing (or Shift-clicking). Hold Ctrl, Alt or Win as well."
                : lbl " on its own is needed for typing and clicking. Hold Ctrl, Alt or Win with it.", warn: ""}
        if (p.mods = "#" && p.vk = 0x4C)
            return {err: "Windows locks the PC on Win + L before any program sees it.", warn: ""}
        a := KitKeys.Find(id)
        altTab := ((p.mods = "!" || p.mods = "!+") && p.vk = 0x09)
        madeFor := altTab && IsObject(a) && KitKeys.Parse(a.def).vk = 0x09 && InStr(KitKeys.Parse(a.def).mods, "!")
        if (altTab && !madeFor)
            return {err: "Alt + Tab switches windows - Windows keeps it.", warn: ""}
        if (p.mods = "!" && p.vk = 0x73)
            return {err: "Alt + F4 closes windows - taking it would be a trap.", warn: ""}
        if ((p.mods = "^!" && p.vk = 0x2E) || (p.mods = "^+" && p.vk = 0x1B))
            return {err: lbl " belongs to Windows.", warn: ""}
        if (p.mods = "^" && p.vk >= 0x41 && p.vk <= 0x5A && InStr("ACVXYZ", Chr(p.vk), true))
            return {err: lbl " is copy, paste or undo in every program.", warn: ""}
        mine := [p.same]
        if (IsObject(a) && (sh := KitKeys.Shifted(hk, a)) != "")
            mine.Push(KitKeys.Parse(sh).same)
        for o in KitKeys.List() {
            if (o.id = id || KitKeys.Cur(o.id) = "")
                continue
            theirs := [KitKeys.Parse(KitKeys.Cur(o.id)).same]
            if ((sh := KitKeys.Shifted(KitKeys.Cur(o.id), o)) != "")
                theirs.Push(KitKeys.Parse(sh).same)
            for x in mine
                for y in theirs
                    if (x = y)
                        return {err: lbl " is already the key for " o.name ".", warn: ""}
        }

        warn := ""
        if madeFor
            warn := "While " Kit.name " runs, " lbl " is its own; Windows' switcher waits. "
                . "Exit " Kit.name ", or set this key off, and Windows has it back."
        else if (p.mods = "")
            warn := "On its own, " lbl " stops doing its usual job everywhere while " Kit.name " runs."
        else if InStr(p.mods, "#") {
            if (!KitKeys.IsMouse(p.vk) && !(p.vk >= 0x70 && p.vk <= 0x87))       ; F1-F24 with Win are free
                warn := "Windows may use " lbl " for something of its own. " Kit.name " takes it over while it runs."
        } else
            warn := "Programs may use " lbl " themselves. While " Kit.name " runs, it does this instead."
        return {err: "", warn: warn}
    }

    static ModsDown() {
        return (GetKeyState("Ctrl", "P") ? "^" : "") (GetKeyState("Alt", "P") ? "!" : "")
            . (GetKeyState("Shift", "P") ? "+" : "")
            . ((GetKeyState("LWin", "P") || GetKeyState("RWin", "P")) ? "#" : "")
    }
}

;================================================================================
; The KEYS part of the settings window (SettingsWin.ahk builds the window)
;================================================================================
class KitKeysWin {
    static rows := Map(), status := "", ih := "", rec := "", waiting := false
    static mouseOn := false, mouseCond := "", mouseFn := "", releaser := ""
    static held := Map(), releaseBy := 0

    ; adds the rows to g from y down (real pixels); returns the y below them
    static AddTo(g, y) {
        this.rows := Map()
        y := KitUi.Para(g, KitS(22), y, KitS(556)
            , "Click change, then press the new keys: hold Ctrl, Alt, Shift or Win and press a key "
            . "or click a mouse button. It works straight away. Esc cancels.", "s9 Norm", Theme.Muted)
        y += KitS(12)
        for a in KitKeys.List()
            y := this.AddRow(g, a, y)
        g.SetFont("s9 Norm c" Theme.Muted, Theme.Font)
        this.status := g.Add("Text", "x" KitS(22) " y" y " w" KitS(556) " h" KitS(34) " BackgroundTrans +0x80", "")
        return y + KitS(38)
    }

    static AddRow(g, a, y) {
        g.SetFont("s10 Norm c" Theme.Text, Theme.Font)
        g.Add("Text", "x" KitS(22) " y" (y + KitS(7)) " w" KitS(190) " BackgroundTrans +0x80", a.name)
        g.SetFont("s10 Bold c" Theme.Text, Theme.Font)
        k := g.Add("Text", "x" KitS(214) " y" y " w" KitS(200) " h" KitS(32) " Center +0x200 +0x80 Background" Theme.CardHi, "")
        g.SetFont("s9 Norm c" Theme.Blue, Theme.Font)
        ch := KitUi.Link(g.Add("Text", "x" KitS(428) " y" (y + KitS(8)) " w" KitS(50) " BackgroundTrans +0x80", "change")
            , ObjBindMethod(KitKeysWin, "Record", a))
        g.SetFont("s9 Norm c" Theme.Dim, Theme.Font)
        off := KitUi.Link(g.Add("Text", "x" KitS(482) " y" (y + KitS(8)) " w" KitS(26) " BackgroundTrans +0x80", "off")
            , ObjBindMethod(KitKeysWin, "TurnOff", a))
        df := KitUi.Link(g.Add("Text", "x" KitS(514) " y" (y + KitS(8)) " w" KitS(60) " BackgroundTrans +0x80", "default")
            , ObjBindMethod(KitKeysWin, "Default", a))
        this.rows[a.id] := {key: k, change: ch, off: off, def: df}
        return y + KitS(42)
    }

    static Refresh() {
        for a in KitKeys.List() {
            if !this.rows.Has(a.id)
                continue
            r := this.rows[a.id], hk := KitKeys.Cur(a.id)
            r.key.Opt("+Background" Theme.CardHi)
            r.key.SetFont("c" (hk = "" ? Theme.Dim : Theme.Text))
            r.key.Text := (hk = "") ? "off" : KitKeys.Label(hk)
            r.off.Visible := (hk != "")
            r.def.Visible := (hk != a.def)
        }
    }

    ; no key at all for this action - for someone who never uses it
    static TurnOff(a, *) {
        if this.rec
            this.Cancel("")
        KitKeys.Set(a.id, "")
        this.Refresh()
        this.Say(a.name ": off. " Chr(0x201C) "change" Chr(0x201D) " or " Chr(0x201C) "default" Chr(0x201D)
            . " brings it back.", Theme.Muted)
    }

    static Say(msg, color := "") {
        if !this.status
            return
        try {
            this.status.SetFont("c" (color != "" ? color : Theme.Muted))
            this.status.Text := msg
        }
    }

    ; the window is closing: a recording in progress is dropped
    static Stop() {
        if this.rec
            this.Cancel("")
        this.Say("")
    }

    static Default(a, *) {
        if this.rec
            this.Cancel("")
        c := KitKeys.Check(a.def, a.id)
        if (c.err != "") {
            this.Say("The default is not free: " c.err, Theme.Red)
            return
        }
        err := KitKeys.Set(a.id, a.def)
        this.Refresh()
        if (err != "")
            this.Say(err, Theme.Red)
        else
            this.Say(a.name ": back to " KitKeys.Label(a.def) ".", Theme.Green)
    }

    ;----------------------------------------------------------------------------
    ; Recording
    ;----------------------------------------------------------------------------
    static Record(a, *) {
        if this.waiting                     ; still waiting for the last one's keys to come up
            return
        if this.rec
            this.Cancel("")
        this.Refresh()
        this.rec := a
        r := this.rows[a.id]
        r.key.Opt("+Background" Theme.Track)
        r.key.SetFont("c" Theme.Blue)
        r.key.Text := "press the keys" Chr(0x2026)
        this.Say("Recording " a.name ". Esc cancels.", Theme.Blue)

        KitKeys.AllOff()
        ih := InputHook("L0 T15")           ; collects no text; gives up after 15 s
        ih.VisibleNonText := false
        ih.KeyOpt("{All}", "NS")            ; tell us about every key, and block it
        ih.OnKeyDown := ObjBindMethod(KitKeysWin, "KeyDown")
        ih.OnKeyUp := ObjBindMethod(KitKeysWin, "KeyUp")
        ih.OnEnd := ObjBindMethod(KitKeysWin, "Ended")
        this.held := Map()
        this.ih := ih
        ih.Start()
        this.Mouse(true)
    }

    ; The modifiers held right now: as seen by this hook, or physically down.
    ; Both, because Windows marks keys from remote desktop or an on-screen
    ; keyboard as not physical, and a modifier pressed before recording
    ; started never came past the hook.
    static Mods() {
        m := KitKeys.ModsDown()
        for vk, sym in Map(0x11, "^", 0xA2, "^", 0xA3, "^", 0x12, "!", 0xA4, "!", 0xA5, "!"
                , 0x10, "+", 0xA0, "+", 0xA1, "+", 0x5B, "#", 0x5C, "#")
            if (this.held.Has(vk) && !InStr(m, sym))
                m .= sym
        return (InStr(m, "^") ? "^" : "") (InStr(m, "!") ? "!" : "") (InStr(m, "+") ? "+" : "") (InStr(m, "#") ? "#" : "")
    }

    static KeyUp(ih, vk, sc) {
        if this.held.Has(vk)
            this.held.Delete(vk)
    }

    static KeyDown(ih, vk, sc) {
        if KitKeys.IsModifier(vk)
            this.held[vk] := true
        if (!this.rec || this.waiting || KitKeys.IsModifier(vk))
            return
        mods := this.Mods()
        if (vk = 0x1B && mods = "") {
            this.Cancel("Nothing changed.")
            return
        }
        this.Got(mods KitKeys.KeyName(vk, sc))
    }

    ; the temporary mouse hotkeys: live only while recording and while a
    ; modifier is held (or for the middle and side buttons, which are fine alone)
    static Mouse(on) {
        if !this.mouseCond {
            this.mouseCond := (hk) => KitKeysWin.rec && !KitKeysWin.waiting
                && (KitKeysWin.Mods() != "" || !RegExMatch(hk, "i)[LR]Button$"))
            this.mouseFn := ObjBindMethod(KitKeysWin, "Clicked")
        }
        if (on = this.mouseOn)
            return
        HotIf(this.mouseCond)
        for b in ["*LButton", "*RButton", "*MButton", "*XButton1", "*XButton2"]
            try Hotkey(b, this.mouseFn, on ? "On" : "Off")
        HotIf()
        this.mouseOn := on
    }

    static Clicked(hk) {
        this.Got(this.Mods() SubStr(hk, 2))
    }

    static Got(hk) {
        a := this.rec
        c := KitKeys.Check(hk, a.id)
        if (c.err != "") {
            this.Finish()
            this.Say("Not changed. " c.err, Theme.Red)
            return
        }
        if (KitKeys.Cur(a.id) != "" && KitKeys.Parse(hk).same = KitKeys.Parse(KitKeys.Cur(a.id)).same) {
            this.Finish()
            this.Say(a.name " already uses " KitKeys.Label(hk) ".", Theme.Muted)
            return
        }
        err := KitKeys.Set(a.id, hk, false)
        this.Finish()
        if (err != "")
            this.Say("Not changed. " err, Theme.Red)
        else
            this.Say(a.name ": " KitKeys.Label(hk) " - works now." (c.warn != "" ? "`n" c.warn : "")
                , (c.warn != "") ? Theme.Amber : Theme.Green)
    }

    static Cancel(msg) {
        this.Finish()
        if (msg != "")
            this.Say(msg, Theme.Muted)
    }

    ; Stop listening, but keep blocking keys until every modifier is up, then
    ; switch the script's keys back on.
    static Finish() {
        this.Mouse(false)
        this.rec := ""
        this.Refresh()
        this.waiting := true
        if !this.releaser
            this.releaser := ObjBindMethod(KitKeysWin, "Release")
        this.releaseBy := A_TickCount + 3000
        SetTimer(this.releaser, 30)
    }

    static Release() {
        if (this.Mods() != "" && A_TickCount < this.releaseBy)
            return
        SetTimer(this.releaser, 0)
        if this.ih {
            ih := this.ih
            this.ih := ""
            ih.Stop()
        }
        KitKeys.AllOn()
        this.waiting := false
    }

    static Ended(ih) {
        if (ih.EndReason = "Timeout" && this.rec)
            this.Cancel("Nothing was pressed, so nothing changed.")
    }
}
