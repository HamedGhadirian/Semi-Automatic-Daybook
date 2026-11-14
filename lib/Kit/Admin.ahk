;================================================================================
; Admin.ahk (kit) - Run as administrator
;================================================================================
; Windows keeps an ordinary script's keys away from programs that run as
; administrator. [General] RunAsAdmin=1 asks for administrator at the start
; (one Windows prompt), so the script works there too. Off unless chosen: a
; new download never asks.
;
; ON, from the tray or Settings: written, then the script starts again and
; Windows asks. That elevated start moves Start with Windows over to its task
; by itself (Startup.ahk), so Windows asks only once. A "no" to the prompt
; leaves the script running without.
;
; OFF: written, and Start with Windows moves back to its shortcut at once. The
; script itself stays elevated until its next start - a program that runs as
; administrator cannot start an ordinary copy of itself.
;================================================================================
#Requires AutoHotkey v2.0

class KitAdmin {
    static Wanted() => CfgBool(Kit.ini, "General", "RunAsAdmin", false)

    ; At start, before anything else. A "no" to the prompt throws, and the
    ; script just carries on without.
    static Elevate() {
        if (A_IsAdmin || !KitAdmin.Wanted())
            return
        try {
            Run("*RunAs " Kit.CmdLine(Kit.ArgText()), A_ScriptDir)
            ExitApp()
        }
    }

    ; reopen says the settings window is open and should come back after
    static Set(want, reopen := false) {
        try IniWrite(want ? 1 : 0, Kit.ini, "General", "RunAsAdmin")
        catch as e {
            Kit.Log("RunAsAdmin: " e.Message)
            return
        }
        if (want && !A_IsAdmin) {
            Kit.Restart(reopen ? "--settings" : "")
            return
        }
        KitStartup.Fix(true)
        KitTray.Build()
        KitSettings.Sync()
        if (!want && A_IsAdmin)
            Kit.Notice("Without administrator from the next start.")
    }

    static Toggle() => KitAdmin.Set(!KitAdmin.Wanted())
}
