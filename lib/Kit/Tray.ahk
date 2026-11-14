;================================================================================
; Tray.ahk (kit) - the tray icon and its menu, the same order in every script
;================================================================================
;   1. the script's own items (its "menu" function adds them)
;   2. Settings...                 - a double-click on the icon opens it too,
;                                    unless the script names another "default"
;   3. Start with Windows   (tick)
;   4. Run as administrator (tick)
;   5. Look for updates now
;   6. Help                        - the README on GitHub
;   7. Reload, Exit
; Two items come and go by themselves: "Get version X..." above Settings when
; a newer version is out, and "Finish Start with Windows..." when the startup
; entry still needs one administrator OK (Startup.ahk).
;
; The menu is built again from the top whenever something in it changes - a
; tick, a key (the tip lists the keys), a new version - rather than patched.
;================================================================================
#Requires AutoHotkey v2.0

class KitTray {
    ; the icon: the first of the script's icons (Icons.ahk - a file beside the
    ; script unless its .ini line names another). A missing or unusable file
    ; is logged; the script runs anyway.
    ; tray: false - no icon at all (a panel whose right-click shows this same
    ; menu: A_TrayMenu.Show()). Notices then come as a tooltip (Kit.Notice).
    static Icon() {
        if !Kit.Opt("tray", true) {
            A_IconHidden := true
            return
        }
        path := KitIcons.Path()
        if (path = "")
            return
        try TraySetIcon(path)
        catch
            Kit.Log("Tray icon: cannot use " path)
    }

    ; THE ICON CAN GO MISSING AT SIGN-IN. AutoHotkey adds it once, at the
    ; very start. A script started by the logon task can be faster than the
    ; taskbar: Windows then drops the icon without an error that reaches the
    ; script, and later never asks for it again - the script runs, with no
    ; icon to exit it from (seen once, 2026-11-13). AutoHotkey itself only puts
    ; the icon back when Explorer restarts (TaskbarCreated - it does reach a
    ; script running as administrator; tested). So for the first five minutes
    ; Guard asks Windows a few times whether the icon is there, and adds it
    ; again when it is not. Each repair is written to errors.log.
    static Guard(step := 1) {
        static marks := [2, 10, 30, 60, 120, 300]          ; seconds after start
        if (!A_IconHidden && !KitTray.Shown()) {
            A_IconHidden := true                            ; off and on = added again
            A_IconHidden := false
            Kit.Log("Tray icon: missing " marks[step] " s after start - added again"
                . (KitTray.Shown() ? "" : ", still missing"))
        }
        if (step < marks.Length)
            SetTimer(() => KitTray.Guard(step + 1), -(marks[step + 1] - marks[step]) * 1000)
    }

    ; Is the icon in the tray? A change that changes nothing (NIM_MODIFY with
    ; no flags) succeeds only for an icon Windows has. AutoHotkey's icon is
    ; the script window's icon number 0x404 (AHK_NOTIFYICON).
    static Shown() {
        nid := Buffer(A_PtrSize = 8 ? 976 : 956, 0)         ; NOTIFYICONDATAW
        NumPut("uint", nid.Size, nid, 0)
        NumPut("ptr", A_ScriptHwnd, nid, A_PtrSize)
        NumPut("uint", 0x404, nid, A_PtrSize * 2)
        return DllCall("shell32\Shell_NotifyIconW", "uint", 1, "ptr", nid, "int") != 0
    }

    static Build() {
        tm := A_TrayMenu
        tm.Delete()
        if Kit.app.HasProp("menu") {
            try Kit.app.menu.Call(tm)
            catch as e
                Kit.Log("Tray menu: " e.Message)
            if DllCall("GetMenuItemCount", "ptr", tm.Handle) > 0
                tm.Add()
        }
        if KitUpdate.found
            tm.Add("Get version " KitUpdate.found["version"] "...", (*) => KitInstall.Offer(KitUpdate.found))
        tm.Add("Settings...", (*) => KitSettings.Show())
        if (KitStartup.left != "")
            tm.Add("Finish Start with Windows...", (*) => KitStartup.Finish())
        tm.Add("Start with Windows", (*) => KitStartup.Toggle())
        tm.Add("Run as administrator", (*) => KitAdmin.Toggle())
        if KitStartup.Wanted()
            tm.Check("Start with Windows")
        if KitAdmin.Wanted()
            tm.Check("Run as administrator")
        if (Kit.repo != "")
            tm.Add("Look for updates now", (*) => KitUpdate.Check(true))
        if (Kit.Opt("help") != "" || Kit.repo != "")
            tm.Add("Help", (*) => Run(Kit.Opt("help", Kit.RepoUrl "#readme")))
        tm.Add()
        tm.Add("Reload", (*) => Kit.Restart())
        tm.Add("Exit", (*) => ExitApp())
        d := Kit.Opt("default", "Settings...")
        try tm.Default := HasMethod(d) ? d.Call() : d       ; a function, when the item's text changes
        A_IconTip := KitTray.Tip()
    }

    ; The tip: name and version, then the keys. A tray tip holds 127
    ; characters: the keys come first, the version and then the name only if
    ; there is room, and past that whole lines are dropped.
    ; A script that says what it is doing (a "tip" function) gives the whole
    ; tip itself.
    static Tip() {
        if Kit.app.HasProp("tip") {
            try return SubStr(Kit.app.tip.Call(), 1, 127)
            catch as e
                Kit.Log("Tray tip: " e.Message)
        }
        lines := ""
        for a in KitKeys.List()
            if (KitKeys.Cur(a.id) != "" && !KitKeys.IsPaused(a.id))
                lines .= "`n" KitKeys.Label(KitKeys.Cur(a.id), true) " " (a.HasProp("short") ? a.short : a.name)
        for tip in [Trim(Kit.name " " Kit.version) lines, Kit.name lines]
            if (StrLen(tip) <= 127)
                return tip
        tip := SubStr(lines, 2)
        while (StrLen(tip) > 127)
            tip := SubStr(tip, 1, InStr(tip, "`n", , -1) - 1)
        return tip
    }
}
