;================================================================================
; WinBtns.ahk (kit) - the window buttons: settings, on top, minimise, close
;================================================================================
; One small row of line icons for the top right of a panel, the same on every
; panel of the family (2026-11-13, the user's choice "A" for settings: two
; short lines, each with a knob). Drawn here with GDI+, so they are sharp at
; any size and take the panel's own colours - no picture files.
;
;   btns := KitWinBtns.Add(gui, x, y, {settings: fn, top: fn, min: fn, close: fn
;       , bg: "1B1D24", dim: "5F677D", hot: "EBEEF5", on: "FFB300"
;       , tips: {settings: "Settings", ...}})
;   btns.Place(x, y)        move the row (the Gui's own units, like Add)
;   btns.SetTop(on)         the pin bright (on) or dim
;   btns.Width              how wide the row is, in the Gui's own units
;
; A button whose function is left out is not there. The pin is "on" colour
; while on top is on. Hover brightens a button and, after a moment, shows its
; tip. Size: o.size (13) and o.gap (5), in the Gui's own units.
;================================================================================
#Requires AutoHotkey v2.0

class KitWinBtns {
    static kinds := ["settings", "top", "min", "close"]
    static owner := Map()                ; control hwnd -> its row
    static hotHwnd := 0, hotSince := 0, tipShown := false
    static cache := Map(), token := 0

    static Add(g, x, y, o) => KitWinBtnRow(g, x, y, o)

    ; The picture of one button, px square, as an icon handle (kept for reuse).
    static Glyph(kind, col, bg, px) {
        k := kind "|" col "|" bg "|" px
        if KitWinBtns.cache.Has(k)
            return KitWinBtns.cache[k]
        if !KitWinBtns.token {
            DllCall("LoadLibrary", "str", "gdiplus", "ptr")
            si := Buffer(24, 0), NumPut("uint", 1, si)
            DllCall("gdiplus\GdiplusStartup", "ptr*", &tok := 0, "ptr", si, "ptr", 0)
            KitWinBtns.token := tok
        }
        ; drawn 4 times bigger, then shrunk smoothly: a thin line drawn at its
        ; real size loses whole pixels and looks broken
        big := 0, bmp := 0, gr := 0, gs := 0, pen := 0, br := 0, h := 0
        bp := px * 4
        DllCall("gdiplus\GdipCreateBitmapFromScan0", "int", bp, "int", bp, "int", 0, "int", 0x26200A, "ptr", 0, "ptr*", &big)
        DllCall("gdiplus\GdipGetImageGraphicsContext", "ptr", big, "ptr*", &gr)
        DllCall("gdiplus\GdipSetSmoothingMode", "ptr", gr, "int", 4)
        s := bp / 14                                         ; drawn on a 14-unit square
        DllCall("gdiplus\GdipCreatePen1", "uint", 0xFF000000 | Integer("0x" col), "float", Max(4.8, 1.5 * s), "int", 2, "ptr*", &pen)
        DllCall("gdiplus\GdipSetPenStartCap", "ptr", pen, "int", 2)
        DllCall("gdiplus\GdipSetPenEndCap", "ptr", pen, "int", 2)
        DllCall("gdiplus\GdipSetPenLineJoin", "ptr", pen, "int", 2)
        line := (x1, y1, x2, y2) => DllCall("gdiplus\GdipDrawLine", "ptr", gr, "ptr", pen
            , "float", x1 * s, "float", y1 * s, "float", x2 * s, "float", y2 * s)
        switch kind {
            case "settings":                                 ; two lines, a knob on each
                line(2, 4.5, 12, 4.5), line(2, 9.5, 12, 9.5)
                DllCall("gdiplus\GdipCreateSolidFill", "uint", 0xFF000000 | Integer("0x" bg), "ptr*", &br)
                for c in [[5, 4.5], [9, 9.5]] {
                    DllCall("gdiplus\GdipFillEllipse", "ptr", gr, "ptr", br, "float", (c[1] - 1.8) * s, "float", (c[2] - 1.8) * s, "float", 3.6 * s, "float", 3.6 * s)
                    DllCall("gdiplus\GdipDrawEllipse", "ptr", gr, "ptr", pen, "float", (c[1] - 1.8) * s, "float", (c[2] - 1.8) * s, "float", 3.6 * s, "float", 3.6 * s)
                }
            case "top":                                      ; a bar, an arrow up to it
                line(2.5, 2.5, 11.5, 2.5), line(7, 5.5, 7, 12), line(4, 8.5, 7, 5.5), line(7, 5.5, 10, 8.5)
            case "min":
                line(3, 7, 11, 7)
            case "close":
                line(3.5, 3.5, 10.5, 10.5), line(10.5, 3.5, 3.5, 10.5)
        }
        DllCall("gdiplus\GdipCreateBitmapFromScan0", "int", px, "int", px, "int", 0, "int", 0x26200A, "ptr", 0, "ptr*", &bmp)
        DllCall("gdiplus\GdipGetImageGraphicsContext", "ptr", bmp, "ptr*", &gs)
        DllCall("gdiplus\GdipSetInterpolationMode", "ptr", gs, "int", 7)    ; high-quality bicubic
        DllCall("gdiplus\GdipSetPixelOffsetMode", "ptr", gs, "int", 4)
        DllCall("gdiplus\GdipDrawImageRectI", "ptr", gs, "ptr", big, "int", 0, "int", 0, "int", px, "int", px)
        DllCall("gdiplus\GdipCreateHICONFromBitmap", "ptr", bmp, "ptr*", &h)
        if br
            DllCall("gdiplus\GdipDeleteBrush", "ptr", br)
        DllCall("gdiplus\GdipDeletePen", "ptr", pen)
        DllCall("gdiplus\GdipDeleteGraphics", "ptr", gr)
        DllCall("gdiplus\GdipDeleteGraphics", "ptr", gs)
        DllCall("gdiplus\GdipDisposeImage", "ptr", big)
        DllCall("gdiplus\GdipDisposeImage", "ptr", bmp)
        if h
            KitWinBtns.cache[k] := h
        return h
    }

    ; WM_MOUSEMOVE over one of the buttons: it lights up; a timer watches for
    ; the pointer leaving, and shows the tip after a moment's rest.
    static OnMove(hwnd) {
        if !KitWinBtns.owner.Has(hwnd) || (hwnd = KitWinBtns.hotHwnd)
            return
        KitWinBtns.Leave()
        KitWinBtns.hotHwnd := hwnd, KitWinBtns.hotSince := A_TickCount
        KitWinBtns.owner[hwnd].Paint(hwnd, true)
        SetTimer(KitWinBtnsTick, 80)
    }

    static Tick() {
        h := KitWinBtns.hotHwnd
        under := 0
        try {
            CoordMode("Mouse", "Screen")
            MouseGetPos(, , , &under, 2)
        }
        if (under != h)
            return KitWinBtns.Leave()
        if (!KitWinBtns.tipShown && A_TickCount - KitWinBtns.hotSince > 500) {
            KitWinBtns.tipShown := true
            tip := KitWinBtns.owner[h].TipOf(h)
            if (tip != "") {
                tt := ToolTip(tip, , , 17)
                ; over an on-top panel the tip must be lifted, or it is drawn under it
                try DllCall("SetWindowPos", "ptr", tt, "ptr", -1, "int", 0, "int", 0, "int", 0, "int", 0, "uint", 0x13)
            }
        }
    }

    static Leave() {
        h := KitWinBtns.hotHwnd
        KitWinBtns.hotHwnd := 0
        SetTimer(KitWinBtnsTick, 0)
        if KitWinBtns.tipShown
            ToolTip(, , , 17)
        KitWinBtns.tipShown := false
        if (h && KitWinBtns.owner.Has(h))
            try KitWinBtns.owner[h].Paint(h, false)
    }
}

class KitWinBtnRow {
    __New(g, x, y, o) {
        this.g := g, this.o := o, this.ctl := Map(), this.kindOf := Map(), this.onTop := false
        this.size := o.HasProp("size") ? o.size : 13
        this.gap := o.HasProp("gap") ? o.gap : 5
        this.bg := o.HasProp("bg") ? o.bg : "1B1D24"
        this.dim := o.HasProp("dim") ? o.dim : "8C94AA"
        this.hot := o.HasProp("hot") ? o.hot : "EBEEF5"
        this.on := o.HasProp("on") ? o.on : "FFB300"
        this.order := []
        for k in KitWinBtns.kinds
            if o.HasProp(k)
                this.order.Push(k)
        this.Width := this.order.Length * this.size + Max(0, this.order.Length - 1) * this.gap
        static hooked := false
        if !hooked {
            OnMessage(0x200, KitWinBtnsOnMove)   ; WM_MOUSEMOVE
            hooked := true
        }
        for i, k in this.order {
            c := g.Add("Picture", "x" (x + (i - 1) * (this.size + this.gap)) " y" y " w" this.size " h" this.size " BackgroundTrans")
            fn := o.%k%
            c.OnEvent("Click", KitWinBtnRow.Fire.Bind(KitWinBtnRow, fn))
            c.OnEvent("DoubleClick", KitWinBtnRow.Fire.Bind(KitWinBtnRow, fn))
            try KitUi.links[c.Hwnd] := true          ; the hand pointer, as over any link
            this.ctl[k] := c, this.kindOf[c.Hwnd] := k
            KitWinBtns.owner[c.Hwnd] := this
            this.Paint(c.Hwnd, false)
        }
    }

    static Fire(fn, *) {
        KitWinBtns.Leave()
        fn.Call()
    }

    Place(x, y) {
        for i, k in this.order
            this.ctl[k].Move(x + (i - 1) * (this.size + this.gap), y)
    }

    SetTop(on) {
        this.onTop := !!on
        if this.ctl.Has("top")
            this.Paint(this.ctl["top"].Hwnd, this.ctl["top"].Hwnd = KitWinBtns.hotHwnd)
    }

    SetVisible(show) {
        for k, c in this.ctl
            c.Visible := show
    }

    TipOf(hwnd) {
        k := this.kindOf[hwnd]
        if (this.o.HasProp("tips") && this.o.tips.HasProp(k))
            return this.o.tips.%k%
        return (k = "settings") ? "Settings" : (k = "top") ? (this.onTop ? "Always on top: on" : "Always on top: off")
            : (k = "min") ? "Minimise" : "Close"
    }

    Paint(hwnd, isHot) {
        k := this.kindOf[hwnd]
        col := isHot ? this.hot : (k = "top" && this.onTop) ? this.on : this.dim
        rc := Buffer(16, 0)
        DllCall("GetClientRect", "ptr", hwnd, "ptr", rc)
        px := NumGet(rc, 8, "int")
        if (px < 4)
            return
        if (h := KitWinBtns.Glyph(k, col, this.bg, px))
            this.ctl[k].Value := "HICON:*" h
    }
}

KitWinBtnsOnMove(wParam, lParam, msg, hwnd) {
    if KitWinBtns.owner.Has(hwnd)
        KitWinBtns.OnMove(hwnd)
}
KitWinBtnsTick() => KitWinBtns.Tick()
