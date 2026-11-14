;================================================================================
; Look.ahk - pictures of Daybook's windows, to check the look by eye
;================================================================================
; Builds the panel, the habit window, the journal window, the deadline
; calendar and the settings window with made-up tasks and habits, in dark and
; in light, and saves each as a PNG next to this file (look-*.png). The windows
; are shown far off the screen and never take the focus; the settings and the
; state live in a scratch folder in Temp, and the journal in tests\journal\look.
;
;   AutoHotkey64.exe Look.ahk
;================================================================================
#Requires AutoHotkey v2.0
#SingleInstance Off
#NoTrayIcon
#Include %A_LineFile%\..\..\lib\Kit\Kit.ahk
#Include %A_LineFile%\..\..\lib\All.ahk

; each theme in a run of its own: a window built a second time in one run
; is not always drawn by the time its picture is taken
if !A_Args.Length {
    for name in ["dark", "light"]
        RunWait('"' A_AhkPath '" "' A_ScriptFullPath '" ' name)
    ExitApp
}

T := A_Temp "\Daybook-look-" A_TickCount
DirCreate(T)
IniFile := T "\Daybook.ini", StateFile := T "\Daybook-state.txt"
Kit.Adopt({name: "Daybook", version: DaybookVersion, repo: "Someone/Daybook", ini: IniFile, quiet: true
    , appId: "Ahk.Daybook", keys: DaybookKeys(), rows: () => DaybookRows(), apply: (*) => 0})
CfgSeed(IniFile, DaybookIniTemplate())
KitStartup.Dir := T, KitStartup.Folder := "\DaybookLook" A_TickCount
KitKeys.Start()
KitKeys.AllOff()
DaybookLoad(true)
JournalDir := A_ScriptDir "\journal\look"
try DirDelete(JournalDir, true)
DirCreate(JournalDir)
StateQuiet := 1, BoardOn := false, PanelMaxH := 640

; ---- made-up days ------------------------------------------------------------
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
Mk("M", "call the bank about the card", {carry: 2, since: DayShift(today, -1)})
Mk("T", "buy milk", {status: "done", doneOn: today})
Mk("T", "write the chapter summary for the reading group, all of it")
Mk("T", "fix the bike", {status: "failed", doneOn: today})
Mk("S", "book the dentist", {due: DayShift(today, 1)})
Mk("S", "renew the passport", {due: DayShift(today, 40)})
Mk("L", "learn to draw hands")
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
H("read 20 pages", "D", 1, 40, "-xxxxxxxxxx")
H("exercise", "W", 3, 30, "xx-r-x-x")
H("non-fiction", "D", 2, 20, "x-x-x-r-")
AppSec["firefox"] := 6000, AppSec["code"] := 4000, AppSec["obsidian"] := 1800
OpenStats := 1, OpenLong := 1, PanelMode := 0, PanelOnTop := 1

for name in [A_Args[1]] {
    Theme.Use(name)
    DaybookColours()
    PanelX := -9000, PanelY := -9000
    BuildPanel()
    BuildCapture()
    BuildNote()
    Refresh()
    Sleep(900)
    Snap(PanelHwnd, A_ScriptDir "\look-panel-" name ".png")
    PanelGui.Hide()

    HabEdBuild()
    HabEdName := "exercise", HabEdMonth := SubStr(today, 1, 7)
    HabEdLoad()
    HabEdGui.Show("NoActivate x-9000 y-9000")
    Sleep(900)
    Snap(HabEdHwnd, A_ScriptDir "\look-habit-" name ".png")
    HabEdGui.Hide()

    JrnBuild()
    JrnLoad(today)
    JrnGui["JrnEdit"].Value := "- woke early`n- read in the park`n`nA good, slow day."
    JrnGui.Show("NoActivate x-9000 y-9000")
    Sleep(900)
    Snap(JrnHwnd, A_ScriptDir "\look-journal-" name ".png")
    JrnGui.Hide()

    DueBuild()
    DueMonth := SubStr(today, 1, 7), DueWas := DayShift(today, 5)
    DueGui["DueWhat"].Text := "deadline for:  book the dentist"
    DuePaint()
    DueGui.Show("NoActivate x-9000 y-9000")
    Sleep(900)
    Snap(DueHwnd, A_ScriptDir "\look-due-" name ".png")
    DueGui.Hide()

    KitSettings.Build()
    KitSettings.Sync()
    KitSettings.g.Show("NoActivate x-9000 y-9000 w" KitS(KitSettings.W) " h" Min(KitSettings.pane.contentH, 1400))
    Sleep(400)
    Snap(KitSettings.g.Hwnd, A_ScriptDir "\look-settings-" name ".png")
    KitSettings.Drop()

    for g in [PanelGui, CapGui, NoteGui, HabEdGui, JrnGui, DueGui]
        g.Destroy()
    PanelGui := "", CapGui := "", NoteGui := "", HabEdGui := "", JrnGui := "", DueGui := ""
}
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
