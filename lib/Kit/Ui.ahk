;================================================================================
; Ui.ahk (kit) - the small parts every window is made of
;================================================================================
;   KitS(n)             a size in the design's pixels -> real pixels (Theme.Scale)
;   KitP(x, y, w, h)    the same for a control's place: "x22 y14 w556 h26 "
;   KitUi.Link(c, fn)   a text that clicks, with the hand cursor
;   KitUi.Drop(g)       destroys a window and forgets its links
;   KitUi.WorkArea()    the usable part of the monitor the pointer is on
;   KitSwitch           a drawn on/off switch (Windows' own checkbox draws its
;                       text black whatever the colour - useless on dark)
;   KitPick             a few choices side by side, one lit
;   KitPane             a content area that scrolls with the wheel
;
; Every window here is made with -DPIScale and placed in real pixels, so the
; sizes handed to these parts are real pixels too: wrap them in KitS().
;================================================================================
#Requires AutoHotkey v2.0

KitS(n) => Round(n * Theme.Scale)

KitP(x := "", y := "", w := "", h := "") {
    return ((x != "") ? "x" KitS(x) " " : "") ((y != "") ? "y" KitS(y) " " : "")
        . ((w != "") ? "w" KitS(w) " " : "") ((h != "") ? "h" KitS(h) " " : "")
}

KitJoin(arr, sep) {
    out := ""
    for i, x in arr
        out .= (i > 1 ? sep : "") x
    return out
}

class KitUi {
    static links := Map(), hooked := false

    ; once, at start: the hand cursor over links, the wheel for panes
    static Hook() {
        if KitUi.hooked
            return
        KitUi.hooked := true
        OnMessage(0x20, KitSetCursor)           ; WM_SETCURSOR
        OnMessage(0x20A, KitPaneWheel)          ; WM_MOUSEWHEEL
    }

    static Link(ctrl, fn) {
        ctrl.OnEvent("Click", fn)
        KitUi.links[ctrl.Hwnd] := true
        return ctrl
    }

    ; A window that is rebuilt forgets its links with it - otherwise the list
    ; would grow all day, and a handle Windows hands out again later could get
    ; the hand cursor.
    static Drop(g) {
        try {
            for ctrl in g
                if KitUi.links.Has(ctrl.Hwnd)
                    KitUi.links.Delete(ctrl.Hwnd)
        }
        try g.Destroy()
    }

    ; [left, top, right, bottom] of the work area of the monitor the pointer is on
    static WorkArea() {
        pt := Buffer(8, 0)
        DllCall("GetCursorPos", "ptr", pt)
        x := NumGet(pt, 0, "int"), y := NumGet(pt, 4, "int")
        loop MonitorGetCount() {
            MonitorGet(A_Index, &l, &t, &r, &b)
            if (x >= l && x < r && y >= t && y < b) {
                MonitorGetWorkArea(A_Index, &l, &t, &r, &b)
                return [l, t, r, b]
            }
        }
        MonitorGetWorkArea(MonitorGetPrimary(), &l, &t, &r, &b)
        return [l, t, r, b]
    }

    ; "x.. y.." that puts a w x h window in the middle of that work area
    static Centre(w, h) {
        wa := KitUi.WorkArea()
        return "x" (wa[1] + Max(0, (wa[3] - wa[1] - w) // 2)) " y" (wa[2] + Max(0, (wa[4] - wa[2] - h) // 2))
    }

    ; Adds a text that wraps inside w and returns the y below it. The height
    ; is whatever the words need: AutoHotkey sizes a Text with no height given.
    static Para(g, x, y, w, text, font, color) {
        g.SetFont(font " c" color, Theme.Font)
        t := g.Add("Text", "x" x " y" y " w" w " BackgroundTrans +0x80", text)
        t.GetPos(, , , &h)
        return y + h
    }
}

KitSetCursor(wParam, lParam, msg, hwnd) {
    static hand := DllCall("LoadCursor", "ptr", 0, "ptr", 32649, "ptr")
    if KitUi.links.Has(wParam) {
        DllCall("SetCursor", "ptr", hand)
        return true
    }
}

;--------------------------------------------------------------------------------
; A switch: a small picture drawn here - a pill, green with the knob at the
; right when on, grey with the knob at the left when off - so its edges are
; smooth and it looks the same on dark and light. x, y in real pixels. The
; pictures are made once per theme and state, and shared by every switch.
;--------------------------------------------------------------------------------
class KitSwitch {
    static W := 38, H := 20, made := Map(), gdip := 0

    __New(g, x, y, on, onChange := "") {
        this.on := !!on, this.fn := onChange
        this.c := g.Add("Picture", "x" x " y" y " w" KitS(KitSwitch.W) " h" KitS(KitSwitch.H)
            , "HBITMAP:*" KitSwitch.Picture(this.on))
        this.c.OnEvent("Click", (*) => this.Toggle())
        this.c.OnEvent("DoubleClick", (*) => this.Toggle())   ; a quick second click
        KitUi.links[this.c.Hwnd] := true
    }

    Value {
        get => this.on
        set {
            if (this.on != !!value)
                this.on := !!value, this.Draw()
        }
    }

    Toggle() {
        this.on := !this.on
        this.Draw()
        if this.fn
            this.fn.Call(this.on)
    }

    Draw() {
        this.c.Value := "HBITMAP:*" KitSwitch.Picture(this.on)
    }

    ; the bitmap for this theme and state (kept: the controls only borrow it)
    static Picture(on) {
        key := Theme.name "|" (on ? 1 : 0) "|" Theme.Scale
        if KitSwitch.made.Has(key)
            return KitSwitch.made[key]
        if !KitSwitch.gdip {
            DllCall("LoadLibrary", "str", "gdiplus", "ptr")
            si := Buffer(24, 0)
            NumPut("uint", 1, si)
            DllCall("gdiplus\GdiplusStartup", "ptr*", &token := 0, "ptr", si, "ptr", 0)
            KitSwitch.gdip := token
        }
        w := KitS(KitSwitch.W), h := KitS(KitSwitch.H), pad := Max(3, KitS(4))
        argb := (hex) => 0xFF000000 | Integer("0x" hex)
        pill := on ? Theme.Green : Theme.Track
        knob := on ? Theme.OnColor : (Theme.dark ? "AEB5C8" : "FFFFFF")
        DllCall("gdiplus\GdipCreateBitmapFromScan0", "int", w, "int", h, "int", 0, "int", 0x26200A, "ptr", 0, "ptr*", &bmp := 0)
        DllCall("gdiplus\GdipGetImageGraphicsContext", "ptr", bmp, "ptr*", &gfx := 0)
        DllCall("gdiplus\GdipSetSmoothingMode", "ptr", gfx, "int", 4)              ; smooth edges
        DllCall("gdiplus\GdipSetPixelOffsetMode", "ptr", gfx, "int", 2)
        DllCall("gdiplus\GdipGraphicsClear", "ptr", gfx, "uint", argb(Theme.Bg))
        DllCall("gdiplus\GdipCreateSolidFill", "uint", argb(pill), "ptr*", &br := 0)
        DllCall("gdiplus\GdipFillEllipse", "ptr", gfx, "ptr", br, "float", 0, "float", 0, "float", h, "float", h)
        DllCall("gdiplus\GdipFillEllipse", "ptr", gfx, "ptr", br, "float", w - h, "float", 0, "float", h, "float", h)
        DllCall("gdiplus\GdipFillRectangle", "ptr", gfx, "ptr", br, "float", h / 2, "float", 0, "float", w - h, "float", h)
        DllCall("gdiplus\GdipDeleteBrush", "ptr", br)
        DllCall("gdiplus\GdipCreateSolidFill", "uint", argb(knob), "ptr*", &br := 0)
        d := h - 2 * pad
        DllCall("gdiplus\GdipFillEllipse", "ptr", gfx, "ptr", br, "float", on ? w - pad - d : pad, "float", pad, "float", d, "float", d)
        DllCall("gdiplus\GdipDeleteBrush", "ptr", br)
        DllCall("gdiplus\GdipDeleteGraphics", "ptr", gfx)
        DllCall("gdiplus\GdipCreateHBITMAPFromBitmap", "ptr", bmp, "ptr*", &hbm := 0, "uint", argb(Theme.Bg))
        DllCall("gdiplus\GdipDisposeImage", "ptr", bmp)
        return KitSwitch.made[key] := hbm
    }
}

;--------------------------------------------------------------------------------
; A few choices side by side, the chosen one lit. x, y, w (each one's width)
; in real pixels; onChange gets the new index.
;--------------------------------------------------------------------------------
class KitPick {
    __New(g, x, y, names, index, onChange := "", w := 0) {
        this.index := index, this.fn := onChange, this.items := []
        w := w ? w : KitS(92)
        g.SetFont("s9 Norm c" Theme.Text, Theme.Font)
        for i, n in names
            this.Add(g, x + (i - 1) * (w + KitS(4)), y, w, i, n)
        this.Draw()
    }

    Add(g, x, y, w, i, name) {
        c := g.Add("Text", "x" x " y" y " w" w " h" KitS(26) " Center +0x200 +0x80", name)
        c.OnEvent("Click", (*) => this.Choose(i))
        c.OnEvent("DoubleClick", (*) => this.Choose(i))
        KitUi.links[c.Hwnd] := true
        this.items.Push(c)
    }

    Value {
        get => this.index
        set {
            this.index := value
            this.Draw()
        }
    }

    Choose(i) {
        if (i = this.index)
            return
        this.index := i
        this.Draw()
        if this.fn
            this.fn.Call(i)
    }

    Draw() {
        for i, c in this.items {
            c.Opt("Background" (i = this.index ? Theme.Blue : Theme.CardHi))
            c.SetFont("c" (i = this.index ? "FFFFFF" : Theme.Muted))
            c.Redraw()
        }
    }
}

;--------------------------------------------------------------------------------
; A content area that scrolls with the wheel: a child window inside a host
; window, moved up and down, with a thin thumb at the right. Build() lays the
; content out and returns its height, so the caller can size the host first;
; Show() puts it in and keeps the scroll position.
;--------------------------------------------------------------------------------
class KitPane {
    static byHost := Map()          ; host window -> its pane, for the wheel

    __New(host, bg := "") {
        this.host := host, this.content := "", this.next := "", this.nextH := 0
        this.scroll := 0, this.contentH := 0, this.w := 0, this.h := 0
        this.bg := (bg != "") ? bg : Theme.Card
        this.bar := host.Add("Text", "x0 y0 w" KitS(3) " h10 Hidden Background" Theme.Dim)
        KitPane.byHost[host.Hwnd] := this
    }

    ; the pane under a point, if any: the window there, or the nearest of its
    ; parents that hosts a pane
    static At(mx, my) {
        h := DllCall("WindowFromPoint", "int64", (my << 32) | (mx & 0xFFFFFFFF), "ptr")
        while h {
            if KitPane.byHost.Has(h)
                return KitPane.byHost[h]
            h := DllCall("GetAncestor", "ptr", h, "uint", 1, "ptr")      ; GA_PARENT
        }
        return ""
    }

    ; for a host that is about to go for good
    Forget() {
        if this.content
            KitUi.Drop(this.content)
        this.content := ""
        try KitPane.byHost.Delete(this.host.Hwnd)
    }

    ; draw(g, width) lays out the content and returns its height
    Build(w, draw) {
        if this.next
            KitUi.Drop(this.next)
        c := Gui("+Parent" this.host.Hwnd " -Caption -DPIScale")
        c.BackColor := this.bg
        c.MarginX := 0, c.MarginY := 0
        this.next := c, this.w := w
        return this.nextH := draw.Call(c, w - KitS(8))
    }

    Show(h) {
        old := ""
        if this.next {
            old := this.content
            this.content := this.next, this.contentH := this.nextH, this.next := ""
        }
        this.h := h
        if !this.content
            return
        this.scroll := Max(0, Min(this.scroll, this.contentH - h))
        this.content.Show("NoActivate x0 y" (-this.scroll) " w" (this.w - KitS(8)) " h" Max(this.contentH, h))
        if old
            KitUi.Drop(old)
        this.UpdateBar()
    }

    ScrollBy(dy) {
        s := Max(0, Min(this.scroll + dy, this.contentH - this.h))
        if (s = this.scroll || !this.content)
            return
        this.scroll := s
        DllCall("SetWindowPos", "ptr", this.content.Hwnd, "ptr", 0, "int", 0, "int", -s, "int", 0, "int", 0, "uint", 0x15)
        this.UpdateBar()
    }

    UpdateBar() {
        if (this.contentH <= this.h) {
            this.bar.Visible := false
            return
        }
        th := Max(KitS(24), Round(this.h * this.h / this.contentH))
        this.bar.Move(this.w - KitS(5), Round((this.h - th) * this.scroll / (this.contentH - this.h)), KitS(3), th)
        this.bar.Visible := true
    }
}

; The wheel scrolls whichever pane is under the pointer, and otherwise leaves
; the message alone.
KitPaneWheel(wParam, lParam, msg, hwnd) {
    pt := Buffer(8, 0)
    DllCall("GetCursorPos", "ptr", pt)
    delta := (wParam >> 16) & 0xFFFF
    if (delta > 0x7FFF)
        delta -= 0x10000
    if (sp := KitPane.At(NumGet(pt, 0, "int"), NumGet(pt, 4, "int"))) {
        sp.ScrollBy(Round(-delta / 120 * KitS(60)))
        return 0
    }
}
