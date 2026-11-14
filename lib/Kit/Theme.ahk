;================================================================================
; Theme.ahk (kit) - the colours, dark and light
;================================================================================
; One palette for every window of every script: Daybook's and Vocab's dark one,
; and a light one that matches it. [General] Theme in the script's .ini says
; which (dark unless it says light); Settings > GENERAL changes it.
;
; A window never names a colour itself. It asks for a role:
;   Theme.Bg       the window                Theme.Text    what you read
;   Theme.Card     a card or a list          Theme.Muted   the quieter text
;   Theme.CardHi   an input box, a key box   Theme.Dim     hints
;   Theme.Track    thin lines, a switch that is off
;   Theme.Green / Amber / Red / Blue         done / warning / wrong / a link
;
; Theme.Scale is the screen's scaling (1 at 100%, 1.5 at 150%). The kit's
; windows are laid out in pixels with DPI scaling switched off, and every
; number goes through KitS() (Ui.ahk) - so a window is the same shape at any
; scaling, and its fonts, which Windows sizes by itself, still fit.
;================================================================================
#Requires AutoHotkey v2.0

class Theme {
    static Font := "Segoe UI", Scale := A_ScreenDPI / 96
    static name := "dark", dark := true
    static Bg := "", Card := "", CardHi := "", Track := "", Text := "", Muted := "", Dim := ""
    static Green := "", Amber := "", Red := "", Blue := "", OnColor := ""

    static Palettes := Map(
        "dark", {Bg: "181B24", Card: "202430", CardHi: "2A3040", Track: "2A2F40"
            , Text: "EBEEF5", Muted: "8C94AA", Dim: "5F677D"
            , Green: "00E676", Amber: "FFB300", Red: "FF4D6D", Blue: "3D9BE9", OnColor: "0F1218"},
        "light", {Bg: "F5F6F9", Card: "FFFFFF", CardHi: "E6E9F1", Track: "CDD2DE"
            , Text: "1C1F2A", Muted: "5B6379", Dim: "858CA0"
            , Green: "0A9F5B", Amber: "B36B00", Red: "D33A55", Blue: "1D6FD0", OnColor: "FFFFFF"})

    static __New() {
        Theme.Use("dark")
    }

    ; the colours only - nothing of Windows is touched
    static Use(name) {
        name := (StrLower(Trim(name)) = "light") ? "light" : "dark"
        Theme.name := name, Theme.dark := (name = "dark")
        for k, v in Theme.Palettes[name].OwnProps()
            Theme.%k% := v
    }

    ; the colours, and Windows' own parts with them: menus, lists, scroll bars
    static Set(name) {
        Theme.Use(name)
        Theme.AppMode()
    }

    static Load() => Theme.Set(CfgStr(Kit.ini, "General", "Theme", "dark"))

    ; Tells Windows which skin this program's menus and themed controls get.
    ; (uxtheme's unnamed entries 135 and 136: SetPreferredAppMode, with
    ; 2 = always dark and 3 = always light, and FlushMenuThemes.)
    static AppMode() {
        static ux := DllCall("LoadLibrary", "str", "uxtheme.dll", "ptr")
        static setMode := ux ? DllCall("GetProcAddress", "ptr", ux, "ptr", 135, "ptr") : 0
        static flush := ux ? DllCall("GetProcAddress", "ptr", ux, "ptr", 136, "ptr") : 0
        try {
            if setMode
                DllCall(setMode, "int", Theme.dark ? 2 : 3)
            if flush
                DllCall(flush)
        }
    }

    ; a dark title bar in dark mode
    static TitleBar(hwnd) {
        buf := Buffer(4)
        NumPut("int", Theme.dark ? 1 : 0, buf)
        try DllCall("dwmapi\DwmSetWindowAttribute", "ptr", hwnd, "uint", 20, "ptr", buf, "uint", 4)
    }

    ; A control Windows draws by itself - a drop-down list, a list view - in
    ; its dark or light skin. kind: "CFD" for a drop-down or an edit box,
    ; "Explorer" for a list.
    static Skin(ctrl, kind := "CFD") {
        static ux := DllCall("LoadLibrary", "str", "uxtheme.dll", "ptr")
        static allow := ux ? DllCall("GetProcAddress", "ptr", ux, "ptr", 133, "ptr") : 0   ; AllowDarkModeForWindow
        try {
            if allow
                DllCall(allow, "ptr", ctrl.Hwnd, "int", Theme.dark ? 1 : 0)
            DllCall("uxtheme\SetWindowTheme", "ptr", ctrl.Hwnd, "str", Theme.dark ? "DarkMode_" kind : "Explorer", "ptr", 0)
        }
    }
}
