;================================================================================
; Exe.ahk (kit) - each script runs as a program of its own: <script>.exe
;================================================================================
; WHY. Windows tells tray icons apart by the program file that made them. Every
; v2 script runs on the same AutoHotkey64.exe, so to Windows they are one
; program with many icons: hiding one in the tray's overflow hides them all,
; dragging one moves them all, and Task Manager lists them all as AutoHotkey.
;
; WHAT. At the very start (the first thing Kit.Start does), a script started
; by any other AutoHotkey starts itself again with a copy of AutoHotkey that
; carries its own name - Global-Scroller.ahk runs as Global-Scroller.exe, in
; its own folder - and the first one ends. The copy is AutoHotkey itself,
; except its description, which is the script's name (Task Manager and the
; tray settings show that). It is NOT a compiled script: the .ahk stays the
; code, edited and reloaded as always.
;
; SAFE. A copy is used only after it has loaded the script once (/Validate).
; Anything that fails - a folder that cannot be written, no AutoHotkey to copy
; - is logged to errors.log and the script simply runs on as it was started.
;
; ITS OWN ICON. The copy carries the script's tray icon (the first in
; [Icons]) in place of AutoHotkey's green H, so Task Manager, Explorer, the
; taskbar's tray-icon list, the administrator prompt and the volume mixer show
; the script's picture. A fingerprint of the icon file is written into the
; copy too (its version block, "KitIcon"). An icon that cannot be written is
; logged once; the copy keeps the H until the icon file changes.
;
; THE DOWNLOAD MARK. Windows marks files that came from the internet (a
; hidden "Zone.Identifier" beside the file), and a copy of a marked file is
; marked too - so in a portable download every new copy would be an unknown
; program from the internet, which Windows may stop with "Windows protected
; your PC". The copy is made on this PC, by the script itself, so the mark is
; taken off it.
;
; KEPT FRESH. The copy is made again when AutoHotkey was updated (the version
; differs), the script's name changed, or its icon file changed (a new
; icon.png: at the next start or Reload, by itself). A copy cannot be replaced while it
; runs, so a running stale copy renames itself <name>.old.exe, makes the new
; one and starts again; the .old.exe goes at the next start.
;
; WHICH AUTOHOTKEY is copied: the one that started the script; when that is
; the copy itself, the AutoHotkey64.exe beside the script (a portable
; download), else the installed one (the registry's InstallDir). The UI Access
; edition (_UIA) only runs from Program Files, so its plain twin is copied.
;
; NOT DONE for a compiled script, in the tests (Kit.Adopt starts nothing), or
; with Kit.Start's ownExe: false.
;================================================================================
#Requires AutoHotkey v2.0

class KitExe {
    ; <folder>\<script name>.exe, for a script file
    static For(script := A_ScriptFullPath) => RegExReplace(script, "\.[^.\\]*$") ".exe"

    ; what should run a script file: its own copy when it has one
    static Program(script) => FileExist(KitExe.For(script)) ? KitExe.For(script) : A_AhkPath

    static Start() {
        if (A_IsCompiled || !Kit.Opt("ownExe", true))
            return
        own := KitExe.For()
        old := RegExReplace(own, "\.exe$") ".old.exe"
        try FileDelete(old)
        src := KitExe.Source()
        fresh := FileExist(own) && (src = "" || KitExe.Fresh(own, src))
        ; A copy made in the last minute is never made again at once: if its
        ; freshness ever read differently twice in a row, the script would
        ; otherwise make and restart itself over and over.
        if (!fresh && A_AhkPath = own && KitExe.Young(own))
            fresh := true
        if (A_AhkPath = own) {
            if fresh
                return
            ; stale, and running: step aside, put a new one in place, start it
            try FileMove(own, old, 1)
            catch as e {
                Kit.Log("Own program: could not set the old copy aside (" e.Message ")")
                return
            }
            if !KitExe.Make(src, own) {
                try FileMove(old, own)
                return
            }
        } else if (!fresh && !KitExe.Make(src, own) && !FileExist(own))
            return
        KitExe.Hop(own)
    }

    ; the same script again, run by its own copy; this one ends
    static Hop(own) {
        Kit.restarting := true
        args := Kit.ArgText()
        try Run('"' own '" /restart "' A_ScriptFullPath '"' ((args != "") ? " " args : ""), A_WorkingDir)
        catch as e {
            Kit.restarting := false
            Kit.Log("Own program: could not start " own " (" e.Message ")")
            return
        }
        ExitApp()
    }

    ; made less than a minute ago
    static Young(file) {
        try return DateDiff(A_Now, FileGetTime(file, "M"), "Seconds") < 60
        return false
    }

    ; the AutoHotkey to copy
    static Source() {
        src := ""
        if (!A_IsCompiled && A_AhkPath != KitExe.For())
            src := A_AhkPath
        else {
            bits := (A_PtrSize = 8) ? "64" : "32"
            if FileExist(A_ScriptDir "\AutoHotkey" bits ".exe")
                src := A_ScriptDir "\AutoHotkey" bits ".exe"
            else try {
                dir := RegRead("HKLM\SOFTWARE\AutoHotkey", "InstallDir")
                if FileExist(dir "\v2\AutoHotkey" bits ".exe")
                    src := dir "\v2\AutoHotkey" bits ".exe"
            }
        }
        if (InStr(src, "_UIA") && FileExist(StrReplace(src, "_UIA")))
            src := StrReplace(src, "_UIA")
        return src
    }

    ; the copy matches this AutoHotkey, this name and this icon. An icon that
    ; could not be written ("failed:" + its mark) is not tried again until the
    ; icon file changes.
    static Fresh(own, src) {
        try {
            mark := KitExe.IconMark(), had := KitExe.Str(own, "KitIcon")
            return FileGetVersion(own) = FileGetVersion(src) && KitExe.Desc(own) == Kit.name
                && (had == mark || had == "failed:" mark)
        }
        return false
    }

    ; the icon the copy carries: the script's first icon, when its file is there
    static IconFile() {
        try {
            f := KitIcons.Path()
            if (f != "" && FileExist(f) && RegExMatch(f, "i)\.(png|ico)$"))
                return f
        }
        return ""
    }

    ; the icon file's fingerprint: its bytes' CRC-32, or "none"
    static IconMark() {
        f := KitExe.IconFile()
        if (f = "")
            return "none"
        b := FileRead(f, "RAW")
        return Format("{:08x}", DllCall("ntdll\RtlComputeCrc32", "uint", 0, "ptr", b, "uint", b.Size, "uint"))
    }

    ; copy, name, prove it loads the script, put in place. True when done.
    static Make(src, own) {
        if (src = "")
            return false
        tmp := RegExReplace(own, "\.exe$") ".new.exe"
        try {
            FileCopy(src, tmp, 1)
            DllCall("DeleteFileW", "str", tmp ":Zone.Identifier")     ; the download mark
            mark := KitExe.IconMark()
            if (mark != "none") {
                try KitExe.SetIcon(tmp, KitExe.IconFile())
                catch as e {
                    Kit.Log("Own program: its icon could not be written (" e.Message ")")
                    mark := "failed:" mark
                }
            }
            KitExe.Brand(tmp, Kit.name, mark)
            code := RunWait('"' tmp '" /Validate /ErrorStdOut "' A_ScriptFullPath '"', A_ScriptDir, "Hide")
            if (code != 0)
                throw Error("the copy did not load the script (exit code " code ")")
            FileMove(tmp, own, 1)
            ; Explorer: draw this file's icon again
            DllCall("shell32\SHChangeNotify", "int", 0x2000, "uint", 0x5, "wstr", own, "ptr", 0)
            return true
        } catch as e {
            try FileDelete(tmp)
            Kit.Log("Own program: could not make " own " (" e.Message ")")
            return false
        }
    }

    ;----------------------------------------------------------------------------
    ; The description: the version resource written again, with the script's
    ; name. Everything else - the fixed part with the version numbers, the
    ; language - is taken over from AutoHotkey's own.
    ;----------------------------------------------------------------------------
    static Brand(file, name, iconMark := "none") {
        info := KitExe.Info(file)
        if !DllCall("version\VerQueryValueW", "ptr", info, "str", "\", "ptr*", &pFixed := 0, "uint*", &nFixed := 0) || !nFixed
            throw Error("no fixed version part")
        fixed := Buffer(nFixed)
        DllCall("RtlMoveMemory", "ptr", fixed, "ptr", pFixed, "uptr", nFixed)
        lang := 0x0409, cp := 0x04B0
        if (DllCall("version\VerQueryValueW", "ptr", info, "str", "\VarFileInfo\Translation", "ptr*", &pT := 0, "uint*", &nT := 0) && nT >= 4)
            lang := NumGet(pT, 0, "ushort"), cp := NumGet(pT, 2, "ushort")
        ver := FileGetVersion(file)
        SplitPath(file, , , , &base)
        base := RegExReplace(base, "\.new$")
        strs := []
        for pair in [["CompanyName", "AutoHotkey Foundation LLC"], ["FileDescription", name], ["FileVersion", ver]
            , ["InternalName", base], ["OriginalFilename", base ".exe"], ["ProductName", name], ["ProductVersion", ver]
            , ["Comments", "AutoHotkey " ver ", running " A_ScriptName], ["KitIcon", iconMark]]
            strs.Push(KitExe.Node(pair[1], pair[2], 1))
        tr := Buffer(4)
        NumPut("ushort", lang, "ushort", cp, tr)
        root := KitExe.Node("VS_VERSION_INFO", fixed, 0
            , [KitExe.Node("StringFileInfo", "", 1, [KitExe.Node(Format("{:04x}{:04x}", lang, cp), "", 1, strs)])
            , KitExe.Node("VarFileInfo", "", 1, [KitExe.Node("Translation", tr, 0)])])
        resLang := KitExe.ResLang(file, lang, 16, 1)
        h := DllCall("BeginUpdateResourceW", "str", file, "int", false, "ptr")
        if !h
            throw Error("the copy cannot be changed (" A_LastError ")")
        ok := DllCall("UpdateResourceW", "ptr", h, "ptr", 16, "ptr", 1, "ushort", resLang, "ptr", root, "uint", root.Size)
        if !DllCall("EndUpdateResourceW", "ptr", h, "int", !ok) || !ok
            throw Error("the description was not written (" A_LastError ")")
    }

    ; the version block of a file, as Windows reads it
    static Info(file) {
        size := DllCall("version\GetFileVersionInfoSizeW", "str", file, "ptr", 0, "uint")
        if !size
            throw Error("no version information in " file)
        info := Buffer(size, 0)
        if !DllCall("version\GetFileVersionInfoW", "str", file, "uint", 0, "uint", size, "ptr", info)
            throw Error("the version information cannot be read")
        return info
    }

    ; the description a file carries ("" when none)
    static Desc(file) => KitExe.Str(file, "FileDescription")

    ; one text of a file's version block ("" when none)
    static Str(file, key) {
        try {
            info := KitExe.Info(file)
            lang := 0x0409, cp := 0x04B0
            if (DllCall("version\VerQueryValueW", "ptr", info, "str", "\VarFileInfo\Translation", "ptr*", &pT := 0, "uint*", &nT := 0) && nT >= 4)
                lang := NumGet(pT, 0, "ushort"), cp := NumGet(pT, 2, "ushort")
            if DllCall("version\VerQueryValueW", "ptr", info, "str", Format("\StringFileInfo\{:04x}{:04x}\{}", lang, cp, key)
                , "ptr*", &p := 0, "uint*", &n := 0) && n
                return StrGet(p, "UTF-16")
        }
        return ""
    }

    ; the language a resource is stored under - written back under the same
    ; one, so the file keeps one of it, not two. type 16 id 1: the version block
    static ResLang(file, lang, type, id) {
        hMod := DllCall("LoadLibraryExW", "str", file, "ptr", 0, "uint", 0x22, "ptr")   ; as an image resource + data file
        if !hMod
            throw Error("the copy cannot be read (" A_LastError ")")
        found := ""
        for l in [lang, 0x0409, 0x0000, 0x0809, 0x0400]
            if DllCall("FindResourceExW", "ptr", hMod, "ptr", type, "ptr", id, "ushort", l, "ptr") {
                found := l
                break
            }
        DllCall("FreeLibrary", "ptr", hMod)
        if (found = "")
            throw Error("no resource " type "/" id " in the copy")
        return found
    }

    ;----------------------------------------------------------------------------
    ; The icon: AutoHotkey's main icon group (159, what Windows shows for the
    ; file) written again, pointing at the script's pictures, stored as new
    ; icon resources from 900 on. AutoHotkey's other icons (paused, suspended)
    ; stay. ico: a .png (one picture) or an .ico (each of its pictures).
    ;----------------------------------------------------------------------------
    static SetIcon(file, ico) {
        data := FileRead(ico, "RAW")
        pics := []                                      ; [{w, h, bpp, bytes}]
        if (NumGet(data, 0, "uint") = 0x474E5089) {     ; a PNG
            w := KitExe.BigEndian(NumGet(data, 16, "uint")), h := KitExe.BigEndian(NumGet(data, 20, "uint"))
            pics.Push({w: w, h: h, bpp: 32, bytes: data})
        } else {
            if (NumGet(data, 0, "ushort") != 0 || NumGet(data, 2, "ushort") != 1)
                throw Error(ico " is not an icon")
            loop NumGet(data, 4, "ushort") {
                e := 6 + 16 * (A_Index - 1)
                size := NumGet(data, e + 8, "uint"), off := NumGet(data, e + 12, "uint")
                b := Buffer(size)
                DllCall("RtlMoveMemory", "ptr", b, "ptr", data.Ptr + off, "uptr", size)
                w := NumGet(data, e, "uchar"), h := NumGet(data, e + 1, "uchar")
                pics.Push({w: w ? w : 256, h: h ? h : 256, bpp: NumGet(data, e + 6, "ushort") || 32, bytes: b})
            }
        }
        if !pics.Length
            throw Error(ico " holds no picture")
        lang := KitExe.ResLang(file, 0x0409, 14, 159)
        group := Buffer(6 + 14 * pics.Length, 0)        ; GRPICONDIR
        NumPut("ushort", 0, "ushort", 1, "ushort", pics.Length, group)
        h := DllCall("BeginUpdateResourceW", "str", file, "int", false, "ptr")
        if !h
            throw Error("the copy cannot be changed (" A_LastError ")")
        ok := true
        for i, p in pics {
            e := 6 + 14 * (i - 1)
            NumPut("uchar", p.w >= 256 ? 0 : p.w, "uchar", p.h >= 256 ? 0 : p.h, "uchar", 0, "uchar", 0
                , "ushort", 1, "ushort", p.bpp, "uint", p.bytes.Size, "ushort", 899 + i, group, e)
            ok := ok && DllCall("UpdateResourceW", "ptr", h, "ptr", 3, "ptr", 899 + i, "ushort", lang     ; RT_ICON
                , "ptr", p.bytes, "uint", p.bytes.Size)
        }
        ok := ok && DllCall("UpdateResourceW", "ptr", h, "ptr", 14, "ptr", 159, "ushort", lang          ; RT_GROUP_ICON
            , "ptr", group, "uint", group.Size)
        if !DllCall("EndUpdateResourceW", "ptr", h, "int", !ok) || !ok
            throw Error("the icon was not written (" A_LastError ")")
    }

    static BigEndian(v) => (v & 0xFF) << 24 | (v & 0xFF00) << 8 | (v >> 8) & 0xFF00 | (v >> 24) & 0xFF

    ; One piece of a version resource: a 6-byte head (its length, its value's
    ; length, text or not), its key, its value, then its children - each on a
    ; 4-byte boundary. value: text (type 1), a Buffer (type 0), or "" (none).
    static Node(key, value := "", type := 1, kids := []) {
        n := (6 + (StrLen(key) + 1) * 2 + 3) & ~3
        vOff := n, vBytes := 0, vLen := 0
        if (value is Buffer)
            vBytes := value.Size, vLen := value.Size
        else if (value != "")
            vBytes := (StrLen(value) + 1) * 2, vLen := StrLen(value) + 1
        n += vBytes
        offs := []
        for k in kids {
            n := (n + 3) & ~3
            offs.Push(n), n += k.Size
        }
        b := Buffer(n, 0)
        NumPut("ushort", n, "ushort", vLen, "ushort", type, b)
        StrPut(key, b.Ptr + 6, "UTF-16")
        if (value is Buffer)
            DllCall("RtlMoveMemory", "ptr", b.Ptr + vOff, "ptr", value, "uptr", vBytes)
        else if (value != "")
            StrPut(value, b.Ptr + vOff, "UTF-16")
        for i, k in kids
            DllCall("RtlMoveMemory", "ptr", b.Ptr + offs[i], "ptr", k, "uptr", k.Size)
        return b
    }
}
