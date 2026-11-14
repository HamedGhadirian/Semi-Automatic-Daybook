;================================================================================
; Startup.ahk (kit) - Start with Windows
;================================================================================
; THE RULE: what is on disk always matches the two ticks, and nothing else.
;
;   Start with Windows   Run as administrator   on disk
;   off                  either                 nothing - no shortcut, no task
;   on                   off                    the Startup-folder shortcut only
;   on                   on                     the Task Scheduler task only
;
; The task ("\AutoHotkey\<name>") is used with administrator because a Startup
; shortcut to a script that wants administrator would ask "Allow?" at every
; sign-in. The task starts only this one script, only when you sign in, as
; administrator without asking, with no time limit.
;
; Whatever changes - a tick in the tray, a tick in Settings, the .ini edited
; by hand, the folder moved, AutoHotkey updated to a new folder, the script
; moved from AutoHotkey v1 to v2 - the next Fix makes it so: it removes what
; should not be there (or points at another file) and makes what should. It
; runs at every start and after every change. The wish itself is
; [General] StartWithWindows in the .ini.
;
; ADMINISTRATOR. Making or removing the task needs it. On a click, Windows
; asks once (canAsk). At start nothing is ever asked - a start must never
; interrupt - so whatever is left is said once, and a tray item, "Finish
; Start with Windows...", does it. Until the task can be made, the shortcut
; stands in for it: the script still starts at sign-in, it just asks for
; administrator first.
;
; A NEW NAME. A script that was renamed lists its old names in Kit.Start's
; "nameWas". Fix removes their shortcut and task too - left behind, the old
; task would start a file that is no longer there, and AutoHotkey would greet
; you with "script not found" at every sign-in.
;
; THE WAIT. The task starts the script 20 s after you sign in (Delay). Sooner,
; the taskbar may not be ready and Windows drops the tray icon (Tray.ahk,
; Guard, puts it back either way). A task made with another wait counts as
; "else" and is made again. The Startup-folder shortcut needs no wait:
; Windows opens that folder only once the desktop and its taskbar are up.
;================================================================================
#Requires AutoHotkey v2.0

class KitStartup {
    static Dir := A_Startup                 ; the tests point these two elsewhere
    static Folder := "\AutoHotkey"
    static left := ""                       ; what still needs administrator, in words
    static Delay := "PT20S"                 ; the task's wait after sign-in

    static Lnk(name := Kit.name) => KitStartup.Dir "\" name ".lnk"
    static TaskName(name := Kit.name) => KitStartup.Folder "\" name

    ; what starts this script: the program, and what it is handed
    static Program() => A_IsCompiled ? A_ScriptFullPath : A_AhkPath
    static Args() => A_IsCompiled ? "" : '"' A_ScriptFullPath '"'

    ; The wish. Before the setting existed, what is on disk says it.
    static Wanted() {
        v := CfgStr(Kit.ini, "General", "StartWithWindows", "")
        if (v != "0" && v != "1") {
            v := (FileExist(KitStartup.Lnk()) || KitStartup.TaskHere() != "") ? "1" : "0"
            try IniWrite(v, Kit.ini, "General", "StartWithWindows")
        }
        return v = "1"
    }

    static Set(want) {
        try IniWrite(want ? 1 : 0, Kit.ini, "General", "StartWithWindows")
        KitStartup.Fix(true)
        KitSettings.Sync()
    }

    static Toggle() => KitStartup.Set(!KitStartup.Wanted())

    ; Makes the disk match the two ticks. True when nothing is left to do.
    static Fix(canAsk) {
        want := !KitStartup.Wanted() ? "" : KitAdmin.Wanted() ? "task" : "lnk"
        left := "", lnk := KitStartup.Lnk()
        if (FileExist(lnk) && (want != "lnk" || !KitStartup.LnkHere()))
            try FileDelete(lnk)
        task := KitStartup.TaskHere()
        if (task != "" && (want != "task" || task != "here")) {
            KitStartup.Schtasks('/delete /f /tn "' KitStartup.TaskName() '"', canAsk)
            if (KitStartup.TaskHere() != "")
                left := "remove its old Task Scheduler task"
        }
        if (want = "task" && KitStartup.TaskHere() != "here" && !KitStartup.TaskMake(canAsk)) {
            left := "make its Task Scheduler task"
            want := "lnk"                           ; the stand-in, until then
        }
        if (want = "lnk" && !FileExist(lnk))
            KitStartup.LnkMake()
        for old in Kit.Opt("nameWas", []) {         ; what the old names left
            if FileExist(KitStartup.Lnk(old))
                try FileDelete(KitStartup.Lnk(old))
            if (KitStartup.TaskHere(old) != "") {
                KitStartup.Schtasks('/delete /f /tn "' KitStartup.TaskName(old) '"', canAsk)
                if (KitStartup.TaskHere(old) != "" && left = "")
                    left := "remove the task of its old name, " old
            }
        }
        said := KitStartup.left
        KitStartup.left := left
        KitTray.Build()
        if (left != "" && left != said)
            Kit.Notice("Start with Windows needs one administrator OK to " left
                . ". Tray menu > Finish Start with Windows.")
        return left = ""
    }

    static Finish() => KitStartup.Fix(true)

    ; the shortcut starts this very file with this AutoHotkey
    static LnkHere() {
        try {
            FileGetShortcut(KitStartup.Lnk(), &target, , &args)
            return target = KitStartup.Program() && (A_IsCompiled || InStr(args, A_ScriptFullPath))
        }
        return false
    }

    static LnkMake() {
        try FileCreateShortcut(KitStartup.Program(), KitStartup.Lnk(), A_ScriptDir, KitStartup.Args()
            , "Starts " Kit.name)
        catch as e
            Kit.Log("Start with Windows: the shortcut could not be made (" e.Message ")")
    }

    ; "" no task, "here" a task that starts this very file with this
    ; AutoHotkey after the right wait, "else" a task by that name that starts
    ; something else (a moved folder, an older AutoHotkey) or waits another
    ; time. Read through Task Scheduler's own COM object: no process to start.
    static TaskHere(name := Kit.name) {
        try {
            svc := ComObject("Schedule.Service")
            svc.Connect()
            t := svc.GetFolder(KitStartup.Folder).GetTask(name)
        } catch
            return ""
        try {
            for tr in t.Definition.Triggers
                if (tr.Type = 9 && tr.Delay != KitStartup.Delay)     ; 9: at sign-in
                    return "else"
        }
        try {
            for a in t.Definition.Actions
                if (a.Path = KitStartup.Program() && (A_IsCompiled || InStr(a.Arguments, A_ScriptFullPath)))
                    return "here"
        }
        return "else"
    }

    ; schtasks with these arguments - as this script first, and when that is
    ; refused and a click allows it, once more through Windows' administrator
    ; prompt. The caller looks at the result itself.
    static Schtasks(args, canAsk) {
        code := 1
        try code := RunWait(A_ComSpec " /c schtasks " args " >nul 2>&1", , "Hide")
        if (!code || A_IsAdmin || !canAsk)
            return
        try RunWait("*RunAs " A_ComSpec " /c schtasks " args, , "Hide")
    }

    ; The task: at your sign-in only, as administrator without asking, no time
    ; limit, normal priority, on battery too. True when it is there after.
    static TaskMake(canAsk) {
        dom := EnvGet("USERDOMAIN")
        user := KitStartup.Xml(((dom != "") ? dom "\" : "") A_UserName)
        xml := '<?xml version="1.0" encoding="UTF-16"?>`n'
            . '<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">`n'
            . "<RegistrationInfo><Description>Starts " KitStartup.Xml(Kit.name) " as administrator when you sign in. "
            . "Made by its Start with Windows setting, which also removes it.</Description></RegistrationInfo>`n"
            . "<Triggers><LogonTrigger><Enabled>true</Enabled><UserId>" user "</UserId><Delay>" KitStartup.Delay "</Delay></LogonTrigger></Triggers>`n"
            . '<Principals><Principal id="Author"><UserId>' user "</UserId><LogonType>InteractiveToken</LogonType>"
            . "<RunLevel>HighestAvailable</RunLevel></Principal></Principals>`n"
            . "<Settings><MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>"
            . "<DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>"
            . "<StopIfGoingOnBatteries>false</StopIfGoingOnBatteries><ExecutionTimeLimit>PT0S</ExecutionTimeLimit>"
            . "<Priority>4</Priority></Settings>`n"
            . '<Actions Context="Author"><Exec><Command>' KitStartup.Xml(KitStartup.Program()) "</Command>"
            . "<Arguments>" KitStartup.Xml(KitStartup.Args()) "</Arguments>"
            . "<WorkingDirectory>" KitStartup.Xml(A_ScriptDir) "</WorkingDirectory></Exec></Actions>`n</Task>`n"
        file := A_Temp "\Kit-task-" A_TickCount ".xml"
        try {
            FileAppend(xml, file, "UTF-16")
            KitStartup.Schtasks('/create /f /tn "' KitStartup.TaskName() '" /xml "' file '"', canAsk)
        }
        try FileDelete(file)
        return KitStartup.TaskHere() = "here"
    }

    static Xml(s) => StrReplace(StrReplace(StrReplace(s, "&", "&amp;"), "<", "&lt;"), ">", "&gt;")
}
