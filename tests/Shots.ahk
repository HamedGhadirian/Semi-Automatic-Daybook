;================================================================================
; Shots.ahk - the README's pictures, made again whenever the look changes
;================================================================================
; Daybook's real windows, drawn by Daybook's own code, filled with a made-up
; week: the habits, tasks and programs below are invented, so nothing of
; anyone's real day is ever in a picture. Dark theme, as PUBLISHING.md asks.
; The windows are shown far off the screen and never take the focus.
;
;   AutoHotkey64.exe tests\Shots.ahk     ->  docs\images\panel.png,
;                                            calendar.png, settings.png
;================================================================================
#Requires AutoHotkey v2.0
#SingleInstance Off
#NoTrayIcon
#Include %A_LineFile%\..\..\lib\Kit\Kit.ahk
#Include %A_LineFile%\..\..\lib\All.ahk

out := A_ScriptDir "\..\docs\images"
T := A_Temp "\Daybook-shots-" A_TickCount
DirCreate(T)
IniFile := T "\Daybook.ini", StateFile := T "\Daybook-state.txt"
Kit.Adopt({name: "Daybook", version: DaybookVersion, repo: "Someone/Daybook", ini: IniFile, quiet: true
    , appId: "Ahk.Daybook", keys: DaybookKeys(), rows: () => DaybookRows(), apply: (*) => 0})
CfgSeed(IniFile, DaybookIniTemplate())
KitStartup.Dir := T, KitStartup.Folder := "\DaybookShots" A_TickCount
KitKeys.Start()
KitKeys.AllOff()
DaybookLoad(true)
JournalDir := T "\journal"
DirCreate(JournalDir)
StateQuiet := 1, BoardOn := false, PanelMaxH := 900

; ---- a made-up day -------------------------------------------------------------
today := LogicalDay()
CurDay := today
Mk(list, text, extra := "") {
    global NextTaskId
    t := Rec({list: list, text: text, status: "open", carry: 0, born: today, due: "", id: NextTaskId++
        , notes: DayMap(), doneOn: "", since: ""})
    if IsObject(extra)
        for k, v in extra.OwnProps()
            t.%k% := v
    Tasks.Push(t)
}
Mk("M", "call the bank about the card", {carry: 2, since: DayShift(today, -2)})
Mk("T", "write the weekly review")
Mk("T", "ship the habit tracker", {status: "done", doneOn: today})
Mk("T", "fix the bike", {status: "failed", doneOn: today})
Mk("T", "water the plants")
Mk("S", "book the dentist", {due: DayShift(today, 1)})
Mk("S", "renew the passport", {due: DayShift(today, 40)})
Mk("L", "learn to sail")
Mk("L", "read the Feynman lectures")
; a habit: born so many days back, and a pattern of days walked back from
; today - x done, r a rest day, - nothing
H(name, kind, n, back, pattern) {
    h := HabitNew(name)
    h.kind := kind, h.n := n, h.born := DayShift(today, -back)
    loop back + 1 {
        d := DayShift(today, -(A_Index - 1))
        c := SubStr(pattern, Mod(A_Index - 1, StrLen(pattern)) + 1, 1)
        if (c = "x")
            h.done.Push(d)
        else if (c = "r")
            h.rest.Push(d)
    }
    HabitCompute(h)
    Habits.Push(h)
}
H("read 20 pages", "D", 1, 30, "xxxxxxxxxxxxxxxxxxxxxxxxxxxxx-")
H("workout", "W", 3, 75, "-x-x--x")
H("no sugar", "D", 1, 12, "-xxrxxx--xxx")
H("stretch", "D", 1, 9, "x---xxxx")
AppSec["firefox.exe"] := 6100, AppSec["Code.exe"] := 4400, AppSec["obsidian.exe"] := 1900
AppSec["Explorer.exe"] := 420
SitSec := 31 * 60
OpenStats := 1, OpenLong := 1, PanelMode := 0, PanelOnTop := 1

Theme.Use("dark")
DaybookColours()
PanelX := -9000, PanelY := -9000
BuildPanel()
BuildCapture()
BuildNote()
; the footer as it is with the keys switched on
KitKeys.now["Panel"] := "#F6", KitKeys.now["Break"] := "#F1"
DaybookTray(Menu())
Refresh()
ApplySitState()
UpdateTimerText()
Sleep(900)
Snap(PanelHwnd, out "\panel.png")
PanelGui.Hide()

HabEdBuild()
HabEdName := "workout", HabEdMonth := SubStr(today, 1, 7)
HabEdLoad()
HabEdGui.Show("NoActivate x-9000 y-9000")
Sleep(900)
Snap(HabEdHwnd, out "\calendar.png")
HabEdGui.Hide()

; Settings: the top of it - the window scrolls, and the rest is more of the same
KitSettings.Build()
KitSettings.Sync()
KitSettings.g.Show("NoActivate x-9000 y-9000 w" KitS(KitSettings.W) " h" KitS(640))
Sleep(600)
Snap(KitSettings.g.Hwnd, out "\settings.png")
KitSettings.Drop()

try DirDelete(T, true)
ExitApp

; a window's picture, as Windows draws it (title bar included), into a PNG
Snap(hwnd, path) {
    WinGetPos(, , &w, &h, hwnd)
    hdc := DllCall("GetDC", "ptr", 0, "ptr")
    mdc := DllCall("CreateCompatibleDC", "ptr", hdc, "ptr")
    hbm := DllCall("CreateCompatibleBitmap", "ptr", hdc, "int", w, "int", h, "ptr")
    old := DllCall("SelectObject", "ptr", mdc, "ptr", hbm, "ptr")
    DllCall("PrintWindow", "ptr", hwnd, "ptr", mdc, "uint", 2)          ; PW_RENDERFULLCONTENT
    DllCall("SelectObject", "ptr", mdc, "ptr", old)
    DllCall("LoadLibrary", "str", "gdiplus", "ptr")
    si := Buffer(24, 0)
    NumPut("uint", 1, si)
    DllCall("gdiplus\GdiplusStartup", "ptr*", &token := 0, "ptr", si, "ptr", 0)
    DllCall("gdiplus\GdipCreateBitmapFromHBITMAP", "ptr", hbm, "ptr", 0, "ptr*", &bmp := 0)
    clsid := Buffer(16)
    DllCall("ole32\CLSIDFromString", "wstr", "{557CF406-1A04-11D3-9A73-0000F81EF32E}", "ptr", clsid)   ; PNG
    try FileDelete(path)
    DllCall("gdiplus\GdipSaveImageToFile", "ptr", bmp, "wstr", path, "ptr", clsid, "ptr", 0)
    DllCall("gdiplus\GdipDisposeImage", "ptr", bmp)
    DllCall("gdiplus\GdiplusShutdown", "ptr", token)
    DllCall("DeleteObject", "ptr", hbm)
    DllCall("DeleteDC", "ptr", mdc)
    DllCall("ReleaseDC", "ptr", 0, "ptr", hdc)
}
