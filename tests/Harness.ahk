;================================================================================
; Harness.ahk - what every test file starts with
;================================================================================
; The whole of Daybook is included - the kit and every file in lib\ - but
; nothing of Daybook.ahk's start-up runs: no panel, no tray menu, no keys. With
; no panel, Refresh() and Relayout() only count, and the note box only says
; what it would have asked (NoteAsked). The settings file and the state file
; are in a scratch folder in Temp, never the real ones; the journal is off
; until a test points it at a folder of its own under tests\.
;
;   Ok(name, got, want)     passes when got = want (case does not count)
;   Has(name, hay, needle)  passes when hay holds needle (case counts)
;   Hasnt(name, hay, needle)
;   Count(hay, needle)      how many times needle is in hay
;   Done()                  writes "DONE" and exits
;
; Results go to results-<test name>.txt, one "PASS name" or "FAIL name: ..."
; per line and "DONE" at the end - run-tests.ps1 reads them.
;================================================================================
#Requires AutoHotkey v2.0
#SingleInstance Off
#NoTrayIcon
#Include %A_LineFile%\..\..\lib\Kit\Kit.ahk
#Include %A_LineFile%\..\..\lib\All.ahk

global T_Out := A_ScriptDir "\results-" RegExReplace(A_ScriptName, "\.test\.ahk$") ".txt"
try FileDelete(T_Out)

; an error in a test is a failed test, not a dialog that stops the run
OnError(T_Crash)
T_Crash(e, mode) {
    FileAppend("FAIL crashed: " e.Message " " e.Extra " (" e.What ", " RegExReplace(e.File, ".*\\") " line " e.Line ")`nDONE`n"
        , T_Out, "UTF-8")
    ExitApp 1
}

T_Line(s) => FileAppend(s "`n", T_Out, "UTF-8")

Ok(name, got, want) {
    if (String(got) = String(want))
        T_Line("PASS " name)
    else
        T_Line("FAIL " name ":`n    got:  [" String(got) "]`n    want: [" String(want) "]")
}

Has(name, hay, needle) {
    if InStr(hay, needle, true)
        T_Line("PASS " name)
    else
        T_Line("FAIL " name ":`n    missing: [" needle "]`n    in:      [" SubStr(hay, 1, 600) "]")
}

Hasnt(name, hay, needle) => Ok(name, InStr(hay, needle, true) ? 1 : 0, 0)

Count(hay, needle) {
    StrReplace(hay, needle, needle, true, &n)
    return n
}

Done() {
    T_Line("DONE")
    ExitApp 0
}

; ---- a scratch place for the settings and the state --------------------------
global T_Dir := A_Temp "\Daybook-test-" A_TickCount
DirCreate(T_Dir)
IniFile := T_Dir "\Daybook.ini"
StateFile := T_Dir "\Daybook-state.txt"
Kit.Adopt({name: "Daybook", version: DaybookVersion, ini: IniFile, quiet: true, appId: "Ahk.Daybook"
    , keys: DaybookKeys()})
CfgSeed(IniFile, DaybookIniTemplate())
DaybookLoad(true)
JournalOn := false, BoardOn := false, RollupOn := false
StateQuiet := 1
Journalled := []
OnExit((*) => (DirExist(T_Dir) ? DirDelete(T_Dir, true) : 0))
