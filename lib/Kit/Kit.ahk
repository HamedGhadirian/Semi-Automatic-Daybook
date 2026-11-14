;================================================================================
; Kit.ahk - what every script needs around its own work, written once
;================================================================================
; AutoHotkey v2. One look, one tray menu, one settings window, keys you can
; change, Start with Windows, Run as administrator, and updates - the same in
; every script that includes this. The plan and its rules: AHK\SYSTEM.md.
;
; USE, at the top of a script:
;     #Include %A_LineFile%\..\lib\Kit\Kit.ahk
;     Kit.Start({name: "Global Scroller", version: "0.2.0", repo: "Owner/Global-Scroller"
;         , icon: "icon.png", template: MyIniTemplate()
;         , init: () => MyStart()
;         , keys: [{id: "Start", name: "Start scrolling", short: "scroll"
;                 , def: "#!RButton", fn: (hk) => MyAction()}]
;         , rows: () => MySettingsRows(), apply: () => MyReadSettings()})
;
; WHAT THE SCRIPT HANDS OVER (only name is needed)
;   name       what it is called, everywhere it is shown
;   version    MAJOR.MINOR.PATCH; a dash makes it a test version (1.2.0-beta.1)
;   repo       "Owner/Name" on GitHub: updates, and the Help item
;   ini        the settings file; without it, <script name>.ini beside the script
;   template   that file's first contents, written once when it is not there
;              (Kit.IniGeneral() is the [General] part every script shares)
;   icon       the tray icon: a file beside the script, or a full path. It
;              gets its line in the .ini's [Icons] (Icons.ahk), so a
;              different picture is one line there
;   icons      several, one per state: [{key, file, name}] (Icons.ahk);
;              KitIcons.Path(key) is the one to show
;   iconWas    [section, key]: where the icon's .ini line used to be
;   init       called once the settings file is there and administrator is
;              settled, BEFORE the keys are switched on - the script's own
;              start-up goes here, so a key can never find it half made
;   keys       the actions with a key: {id, name, short, def, fn, cond, shift}
;              (Keys.ahk); every one can be changed in Settings
;   rows       a function giving the settings window's own rows (SettingsWin.ahk)
;   apply      called after a setting changed, to use it at once. Without it,
;              the script reloads when the settings window closes.
;   menu       a function (menu) that adds the script's own tray items first
;   default    the tray item a double-click runs; Settings... unless named
;              (or a function giving its text, when the text changes)
;   tray       false: no tray icon. The menu still exists - a panel shows it
;              on right-click (A_TrayMenu.Show()); notices become tooltips
;   tip        a function giving the tray tip, for a script that shows what
;              it is doing there; name, version and keys unless given
;   onTheme    called after the theme changed, to redraw the script's own windows
;   help       the page the Help item opens; the repo's README unless named
;   adminWhy   one line: what Run as administrator is good for in this script
;   keep       files and folders beside the script that are the user's own, so
;              an update never writes them (the .ini and errors.log always are)
;   repoWas    earlier "Owner/Name"s of the same repo, after a rename
;   nameWas    earlier names of the script itself (its name and its .ahk
;              file were the same): at the first start under the new name
;              the old copy is closed, the old .ini taken over, and the old
;              Start with Windows shortcut or task removed
;   appId      the taskbar's name tag for the script's windows (Taskbar.ahk);
;              keep the old one when a script moves, so a pinned button holds
;   agent      the User-Agent its web requests send; name/version unless named
;   ownExe     false: run on the AutoHotkey that started it, not <script>.exe
;              (Exe.ahk - on unless said)
;
; THE PARTS, in the order they load
;   Exe          the script runs as <script>.exe, a copy of AutoHotkey with its
;                name - so Windows tells its tray icon apart from the others
;   Ini          reading and seeding the settings file (the Cfg functions)
;   Icons        the tray icons: files beside the script, a line each in [Icons]
;   Json, Http   reading GitHub's answers; one request that never waits
;   Theme        the colours, dark and light
;   Ui           links, switches, the scrolling pane
;   Taskbar      a taskbar button of the script's own
;   Admin        Run as administrator
;   Startup      Start with Windows - the rule in SYSTEM.md section 5
;   Tray         the tray menu, the same order everywhere
;   Keys         the keys, and recording new ones
;   SettingsWin  the settings window, built from a table of rows
;   Update       is there a newer version? (GitHub, once a day)
;   Swap         putting a new version's files in place, with a backup
;   Install      the update window; download, check, hand over to the helper
;   Touch        a made-up finger (Windows touch injection)
;   Osd          the coloured readout box (OsdNew, OsdShow)
;   Monitors     one monitor described, monitors in desk order (MonInfo)
;   SeenAt       is this window the one you see at a point (WindowSeenAt)
;   WinBtns      a panel's window buttons: settings, on top, minimise, close
; The Cfg, Osd, Mon and WindowSeenAt functions keep their v1 names, so a
; script moving from v1 keeps every line that calls them.
; Not included: Updater.ahk, the helper Install starts to swap the files
; while the script is closed - a script of its own.
;
; ONE MASTER, SYNCED COPIES. The master is AHK\lib\Kit. A script published on
; its own carries a copy in its lib\Kit, because a download must work alone.
; Tools\Sync-Kit.ps1 copies the master over the copies; never edit a copy.
;================================================================================
#Requires AutoHotkey v2.0
#Include %A_LineFile%\..\Exe.ahk
#Include %A_LineFile%\..\Ini.ahk
#Include %A_LineFile%\..\Icons.ahk
#Include %A_LineFile%\..\Json.ahk
#Include %A_LineFile%\..\Http.ahk
#Include %A_LineFile%\..\Theme.ahk
#Include %A_LineFile%\..\Ui.ahk
#Include %A_LineFile%\..\Taskbar.ahk
#Include %A_LineFile%\..\Admin.ahk
#Include %A_LineFile%\..\Startup.ahk
#Include %A_LineFile%\..\Tray.ahk
#Include %A_LineFile%\..\Keys.ahk
#Include %A_LineFile%\..\SettingsWin.ahk
#Include %A_LineFile%\..\Update.ahk
#Include %A_LineFile%\..\Swap.ahk
#Include %A_LineFile%\..\Install.ahk
#Include %A_LineFile%\..\Touch.ahk
#Include %A_LineFile%\..\Osd.ahk
#Include %A_LineFile%\..\Monitors.ahk
#Include %A_LineFile%\..\SeenAt.ahk
#Include %A_LineFile%\..\WinBtns.ahk

class Kit {
    static app := {}, name := "", version := "", repo := "", ini := ""
    static noticeClick := "", noticeHooked := false, lastNotice := "", restarting := false

    static Start(o) {
        Kit.Adopt(o)
        KitExe.Start()                          ; may start again as <script>.exe
        Persistent()
        Kit.TakeOldIni()
        CfgSeed(Kit.ini, Kit.Opt("template", Kit.IniGeneral()))
        KitIcons.Mend()                         ; the [Icons] lines, as they should be
        KitAdmin.Elevate()                     ; may start again as administrator
        Kit.CloseOld()
        Theme.Load()
        KitUi.Hook()
        KitTray.Icon()
        if o.HasProp("init")
            o.init.Call()
        KitKeys.Start()
        KitTray.Build()
        if Kit.Opt("tray", true)
            SetTimer(() => KitTray.Guard(), -2000)  ; the icon can go missing at sign-in
        ; the rest can wait until the keys work: Task Scheduler and GitHub are slow
        SetTimer(() => KitStartup.Fix(false), -1500)
        KitUpdate.Start()
        KitInstall.Started()
        if Kit.HasArg("--settings")
            SetTimer(() => KitSettings.Show(), -300)
    }

    ; the script's own facts, without starting anything - Start, and the tests
    static Adopt(o) {
        Kit.app := o
        Kit.name := o.name
        Kit.version := o.HasProp("version") ? o.version : ""
        Kit.repo := o.HasProp("repo") ? o.repo : ""
        Kit.ini := o.HasProp("ini") ? o.ini
            : A_ScriptDir "\" RegExReplace(A_ScriptName, "\.[^.]+$") ".ini"
    }

    ; After a rename: the settings file still has the old name, in the same
    ; folder. It becomes this one's, unless this one already has a file.
    static TakeOldIni() {
        if FileExist(Kit.ini)
            return
        SplitPath(Kit.ini, , &dir)
        for old in Kit.Opt("nameWas", [])
            if FileExist(dir "\" old ".ini") {
                try FileMove(dir "\" old ".ini", Kit.ini)
                return
            }
    }

    static Opt(name, def := "") => Kit.app.HasProp(name) ? Kit.app.%name% : def

    ; the name as part of a file name: TLDR Vocab -> TLDR-Vocab
    static Slug => RegExReplace(Trim(Kit.name), "\s+", "-")
    static RepoUrl => "https://github.com/" Kit.repo

    static HasArg(arg) {
        for a in A_Args
            if (a = arg)
                return true
        return false
    }

    ;----------------------------------------------------------------------------
    ; The [General] part of every script's .ini template: new-download defaults.
    ; Plain ASCII, like every template - see Ini.ahk.
    ;----------------------------------------------------------------------------
    static IniGeneral(adminWhy := "") {
        why := (adminWhy != "") ? adminWhy : "so it also works over programs that run as administrator"
        text := "
        (
[General]
; dark or light - the colours of the settings window and the other windows.
Theme=dark
; 1 = start when you sign in. The script keeps the Startup-folder shortcut, or
; with RunAsAdmin=1 the Task Scheduler task, in step with this by itself.
StartWithWindows=0
; 1 = ask for administrator at the start (one Windows prompt),
; @WHY@. 0 = no prompt.
RunAsAdmin=0
; 1 = look on GitHub once a day for a newer version, and say so. Nothing
; installs without your click.
CheckUpdates=1

[Keys]
; Set in Settings. Only keys that differ from the default are listed;
; delete a line to go back to the default. none = no key at all.

        )"
        return StrReplace(text, "@WHY@", why) "`n"
    }

    ;----------------------------------------------------------------------------
    ; Starting again
    ;----------------------------------------------------------------------------
    ; The command line that starts this script once more, replacing this copy.
    static CmdLine(args := "") {
        cmd := A_IsCompiled ? '"' A_ScriptFullPath '" /restart'
            : '"' A_AhkPath '" /restart "' A_ScriptFullPath '"'
        return cmd ((args != "") ? " " args : "")
    }

    ; this start's own arguments, quoted, to hand on
    static ArgText() {
        out := ""
        for a in A_Args
            out .= (out = "" ? "" : " ") '"' a '"'
        return out
    }

    ; AutoHotkey's own Reload drops the arguments; this one can add some.
    ; Its ExitApp says "Exit" to the script's OnExit, so a script that keeps
    ; things as they are across a reload asks Kit.HandOver(reason) instead.
    static Restart(args := "") {
        Kit.restarting := true
        try Run(Kit.CmdLine(args), A_ScriptDir)
        catch as e {
            Kit.Log("Restart: " e.Message)
            Reload()
            return
        }
        ExitApp()
    }

    ; For a script's OnExit: true when a new copy takes over at once - the
    ; tray's Reload, a restart for administrator or the theme, AutoHotkey's
    ; Reload, or a double-click on the script (#SingleInstance). Then nothing
    ; on screen should be put back first: the new copy carries on from it.
    static HandOver(reason) => Kit.restarting || reason = "Reload" || reason = "Single"

    ; A copy of this same script left running by an OLDER AutoHotkey - the v1
    ; one, on the day a script moves to v2 - is told to close: #SingleInstance
    ; only sees copies run by the same AutoHotkey. After a rename, a copy
    ; running under an old name ("nameWas", any folder) is told too. One
    ; running as administrator does not hear a copy that is not; that is
    ; said, once.
    ; text to match itself in a regular expression
    static RxEsc(s) => RegExReplace(s, "[\\.*?+()\[\]{}|^$]", "\$0")

    static CloseOld() {
        was := DetectHiddenWindows(true)
        mode := A_TitleMatchMode
        SetTitleMatchMode("RegEx")
        mine := A_ScriptHwnd, left := 0, told := []
        ; Each name escaped character by character: \Q...\E would end early at a
        ; folder starting with E (D:\Extras), and nothing would be closed.
        names := Kit.RxEsc(A_ScriptFullPath)
        for old in Kit.Opt("nameWas", [])
            names .= "|.*\\" Kit.RxEsc(old ".ahk")   ; any folder: \ then the file
        try {
            for hwnd in WinGetList("i)^(" names ") - AutoHotkey ahk_class AutoHotkey") {
                if (hwnd = mine)
                    continue
                try {
                    PostMessage(0x10, 0, 0, , hwnd)             ; WM_CLOSE
                    told.Push(hwnd)
                } catch
                    left++
            }
        }
        ; Wait (up to 3 s) until they are gone. The old copy's exit runs on its
        ; own time, and a script that puts things back when it exits (the
        ; screens, a muted mic) would otherwise do it after this one took over.
        end := A_TickCount + 3000
        for hwnd in told
            while (DllCall("IsWindow", "ptr", hwnd) && A_TickCount < end)
                Sleep(50)
        DetectHiddenWindows(was)
        SetTitleMatchMode(mode)
        if left
            SetTimer(() => Kit.Notice("An older copy of " Kit.name " is still running as administrator. "
                . "Exit it from its tray icon, or the keys run twice."), -3000)
    }

    ;----------------------------------------------------------------------------
    ; Saying things without taking the focus
    ;----------------------------------------------------------------------------
    ; A tray notice. onClick runs on a click on the notice itself; only the
    ; latest notice's click counts.
    static Notice(text, title := "", onClick := "", icon := 1) {
        Kit.noticeClick := onClick, Kit.lastNotice := text
        if Kit.Opt("quiet", false)              ; the tests: nothing on screen
            return
        if !Kit.Opt("tray", true) {             ; no icon to hang a balloon on
            ToolTip(((title != "") ? title : Kit.name) ": " text)
            SetTimer(() => ToolTip(), -8000)
            return
        }
        if !Kit.noticeHooked {
            Kit.noticeHooked := true
            OnMessage(0x404, KitNoticeClicked)          ; the tray icon's own messages
        }
        TrayTip(text, (title != "") ? title : Kit.name, icon | 16)     ; 16: no sound
    }

    ; Errors that would otherwise vanish inside a timer end up in errors.log
    ; beside the script - never in a dialog, which would take the focus.
    static Log(msg) {
        try FileAppend(FormatTime(, "yyyy-MM-dd HH:mm:ss") "  " msg "`n", A_ScriptDir "\errors.log", "UTF-8")
    }

    ;----------------------------------------------------------------------------
    ; The theme, changed while running
    ;----------------------------------------------------------------------------
    static SetTheme(name) {
        try IniWrite((StrLower(name) = "light") ? "light" : "dark", Kit.ini, "General", "Theme")
        Theme.Set(name)
        KitSettings.Rebuild()
        KitInstall.Rebuild()
        if Kit.app.HasProp("onTheme")
            try Kit.app.onTheme.Call()
    }
}

KitNoticeClicked(wParam, lParam, *) {
    if ((lParam & 0xFFFF) = 0x405 && Kit.noticeClick) {     ; NIN_BALLOONUSERCLICK
        fn := Kit.noticeClick, Kit.noticeClick := ""
        fn()
    }
}
