;================================================================================
; Osd.ahk (kit) - the coloured readout box a script flashes on the screen
;================================================================================
; "GATHERED 4 WINDOWS", "NEXT OUTPUT - Speakers": one box, drawn by this file
; for every script that has one. Each makes its own NAMED readout, with its
; own settings, and shows text on it:
;
;     OsdNew("Pie-Alt-Tab", ini, 1800)         ; once, at start
;     OsdShow("Pie-Alt-Tab", "GATHERED 4 WINDOWS", "2980B9")
;
; The settings come from the [Osd] section of the ini it is handed - Ms,
; Width, Height, X, Y, FontSize, Alpha, TopmostMs - so each script keeps its
; own. OsdIniTemplate() is that section's text, for the script's template.
; OsdNew again, with the same name, makes it afresh from the settings: that
; is how a changed setting is used at once.
;
; The v2 twin of lib\Osd.ahk, with the same names, like the Cfg functions.
;
; The box never takes the focus (WS_EX_NOACTIVATE) and clicks fall straight
; through it (WS_EX_TRANSPARENT).
;================================================================================
#Requires AutoHotkey v2.0

class KitOsd {
    static all := Map()
}

; Make one readout - or make it again from the settings. Not shown until OsdShow.
OsdNew(name, ini, defMs := 1600) {
    if KitOsd.all.Has(name)
        OsdDrop(name)
    o := {name: name, title: name "Osd"}
    o.ms    := CfgNum(ini, "Osd", "Ms", defMs)
    o.w     := CfgNum(ini, "Osd", "Width", 380)
    o.h     := CfgNum(ini, "Osd", "Height", 52)
    ; Blank = centred on the primary screen. A number pins it there,
    ; negatives included - that is how it goes on a monitor left of or above
    ; the primary one. Blank is an answer here, so this one is CfgStr.
    o.x     := CfgStr(ini, "Osd", "X", "")
    o.y     := CfgNum(ini, "Osd", "Y", 90)
    o.alpha := Min(Max(CfgNum(ini, "Osd", "Alpha", 230), 0), 255)
    o.topMs := CfgNum(ini, "Osd", "TopmostMs", 200)
    font    := CfgNum(ini, "Osd", "FontSize", 11)
    g := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000000 +E0x20", o.title)
    g.MarginX := 0, g.MarginY := 0
    g.BackColor := "2C3E50"
    g.SetFont("s" font " Bold cWhite", Theme.Font)
    o.text := g.Add("Text", "Center BackgroundTrans +0x200 w" o.w " h" o.h, "")
    o.gui := g, o.hwnd := g.Hwnd
    ; One timer each, kept, so showing again restarts the countdown instead
    ; of stacking a second one.
    o.hideFn := OsdHide.Bind(name)
    o.topFn  := OsdTopmost.Bind(name)
    KitOsd.all[name] := o
}

OsdShow(name, text, colour) {
    if !KitOsd.all.Has(name)
        return
    o := KitOsd.all[name]
    if Kit.Opt("quiet", false)                  ; the tests: nothing on screen
        return
    o.gui.BackColor := colour
    o.text.Text := text
    ; the box's width in real pixels: the Gui scales it with the screen
    w := Round(o.w * A_ScreenDPI / 96)
    x := (o.x = "" || !IsNumber(o.x)) ? (A_ScreenWidth - w) // 2 : Integer(o.x)
    o.gui.Show("NoActivate x" x " y" o.y " AutoSize")
    WinSetTransparent(o.alpha, o.hwnd)
    OsdTopmost(name)
    if o.topMs
        SetTimer(o.topFn, o.topMs)
    SetTimer(o.hideFn, -o.ms)                   ; negative = once
}

; +AlwaysOnTop is NOT enough on its own, which is why this exists. Windows
; keeps one "topmost band", and whatever was raised into it last sits at its
; front: click the taskbar, or let another overlay show itself, and the box
; is still flagged always-on-top yet behind it. SetWindowPos(HWND_TOPMOST)
; puts it back in front - once on every show, then on a timer that runs ONLY
; while the box is up. It still cannot beat an exclusive full-screen game, or
; an overlay with UIAccess, which Windows ranks above every ordinary window.
OsdTopmost(name, *) {
    if !KitOsd.all.Has(name)
        return
    DllCall("SetWindowPos", "ptr", KitOsd.all[name].hwnd, "ptr", -1
        , "int", 0, "int", 0, "int", 0, "int", 0, "uint", 0x13)    ; NOSIZE|NOMOVE|NOACTIVATE
}

OsdHide(name, *) {
    if !KitOsd.all.Has(name)
        return
    o := KitOsd.all[name]
    SetTimer(o.topFn, 0)
    o.gui.Hide()
}

OsdDrop(name) {
    o := KitOsd.all[name]
    SetTimer(o.topFn, 0), SetTimer(o.hideFn, 0)
    try o.gui.Destroy()
    KitOsd.all.Delete(name)
}

; Whether hwnd is one of these readouts - a window mover leaves them alone.
OsdIsOne(hwnd) {
    for name, o in KitOsd.all
        if (o.hwnd = hwnd)
            return true
    return false
}

; The [Osd] section of a script's .ini template. what says what the box
; shows; ms is that script's default for how long it stays up. Plain ASCII,
; like every template.
OsdIniTemplate(what, ms) {
    text := "
    (

[Osd]
; @WHAT@
;
; How long it stays up, in milliseconds.
Ms=@MS@
Width=380
Height=52

; BLANK X means centred on the primary screen; a number pins it instead, and
; negative numbers are fine - that is how you put it on a monitor to the left
; of, or above, the primary one.
X=
; Y is measured down from the top of the primary screen.
Y=90

FontSize=11

; 0-255. Lower is more see-through.
Alpha=230

; How often, in milliseconds, the readout pushes itself back in front of other
; windows while it is visible. 0 switches that off.
TopmostMs=200
    )"
    return StrReplace(StrReplace(text, "@WHAT@", what), "@MS@", ms) "`n"
}
