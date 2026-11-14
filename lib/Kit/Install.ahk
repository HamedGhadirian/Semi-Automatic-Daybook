;================================================================================
; Install.ahk (kit) - the update window, and updating with one click
;================================================================================
; When Update.ahk finds a newer version, its notice, the tray item or
; Settings > "check now" opens one small window, the same in every script:
; what is new, "Update now", "Download page", "Not now".
;
; "Update now", step by step. Nothing in the script's folder changes until
; step 7, and a failure anywhere before that only leaves a message.
;   1. the release's manifest.json: name, version, and the size and SHA-256
;      (a fingerprint of a file, which proves it arrived whole) of both zips
;      and of every file in them - the release build writes it
;   2. the zip this copy needs - portable if AutoHotkey64.exe is next to the
;      script, plain if not - into the temp folder
;   3. its size and SHA-256 checked against the manifest, and against the
;      digest GitHub itself keeps for the file
;   4. unpacked (Windows' own tar), in the temp folder
;   5. every file checked against the manifest again, one by one
;   6. the new main script loaded by AutoHotkey's syntax check, with the
;      AutoHotkey that will run it - a version that needs a newer AutoHotkey
;      stops here
;   7. Updater.ahk starts from a copy in the temp folder, the script closes,
;      and the helper swaps the files (Swap.ahk: backup first, undo on any
;      failure), starts the new version and waits for it to say it started
;      (KitInstall.Started) - or puts the old one back.
;
; A RELEASE, for this to work: <Name>-<version>.zip and
; <Name>-<version>-portable.zip (spaces in the name as dashes), each holding
; one folder called <Name>, and manifest.json.
;
; What it never does: touch the .ini, errors.log or anything the script
; named as the user's own ("keep"); ask for administrator; download from
; anywhere but the script's own GitHub releases; go back to an older
; version; update without being asked. A folder that is a git repository is
; left to git.
;
; What it trusts: GitHub, over HTTPS. The files are checked to be exactly the
; ones published, not that the person who published them is who they say -
; that would need a paid code-signing certificate.
;================================================================================
#Requires AutoHotkey v2.0

class KitInstall {
    static g := "", notes := "", status := "", goLink := "", rel := "", busy := false
    static req := "", poller := "", step := "", dir := "", manAsset := "", zipAsset := "", kind := "", manifest := ""
    static ask := "", retried := false

    static Root() => A_Temp "\" Kit.Slug "-update"
    static Marker() => KitInstall.Root() "\started.txt"
    static Portable() => FileExist(A_ScriptDir "\AutoHotkey64.exe") != ""

    ; where a release's files may come from: this repo, under its name now or
    ; an earlier one (an account that was renamed)
    static Allowed() {
        out := [Kit.RepoUrl "/releases/download/"]
        for was in Kit.Opt("repoWas", [])
            out.Push("https://github.com/" was "/releases/download/")
        return out
    }

    ; the user's own files and folders beside the script, never written
    static Keep() {
        SplitPath(Kit.ini, &ini)
        out := [ini, "errors.log"]
        for k in Kit.Opt("keep", [])
            out.Push(k)
        return out
    }

    ; Why this copy cannot update itself, or "" when it can
    static Blocker() {
        if A_IsCompiled
            return "This copy is a single .exe file."
        if FileExist(A_ScriptDir "\.git")
            return "This copy is a git repository - update it with git instead."
        probe := A_ScriptDir "\update-check.tmp"
        try {
            FileAppend("", probe)
            FileDelete(probe)
        } catch
            return "Windows does not let " Kit.name " change its own folder (" A_ScriptDir ")."
        return ""
    }

    ; the window: what is new, and the three ways on. (where: Show options of
    ; the caller's own - the tests put it off the screen.)
    static Offer(rel, where := "") {
        if !IsObject(rel)
            return
        if (KitInstall.busy && KitInstall.g) {
            WinActivate(KitInstall.g.Hwnd)
            return
        }
        KitInstall.rel := rel
        if KitInstall.g
            KitInstall.Drop()
        g := Gui("-MaximizeBox -MinimizeBox -DPIScale", Kit.name " update")
        g.BackColor := Theme.Bg
        g.MarginX := KitS(22), g.MarginY := KitS(16)
        w := KitS(456), x := KitS(22)
        g.SetFont("s12 Bold c" Theme.Text, Theme.Font)
        g.Add("Text", "x" x " y" KitS(16) " w" w " BackgroundTrans", Kit.name " " rel["version"] " is out")
        g.SetFont("s9 Norm c" Theme.Muted, Theme.Font)
        g.Add("Text", "x" x " y+" KitS(2) " w" w " BackgroundTrans", "You have " Kit.version ". What is new:")
        g.SetFont("s9 Norm c" Theme.Text, Theme.Font)
        KitInstall.notes := g.Add("Edit", "x" x " y+" KitS(8) " w" w " h" KitS(190) " ReadOnly -E0x200 VScroll Background" Theme.Card
            , KitInstall.NotesText(rel.Has("notes") ? rel["notes"] : ""))
        Theme.Skin(KitInstall.notes, "Explorer")
        g.SetFont("s8 Norm c" Theme.Dim, Theme.Font)
        g.Add("Text", "x" x " y+" KitS(10) " w" w " BackgroundTrans"
            , "Your settings are not touched. The version you have now is kept in the "
            . Chr(0x201C) KitSwap.BackupName Chr(0x201D) " folder, in case you want it back.")
        KitInstall.status := g.Add("Text", "x" x " y+" KitS(10) " w" w " h" KitS(34) " BackgroundTrans", "")
        g.SetFont("s10 Bold c" Theme.Green, Theme.Font)
        KitInstall.goLink := KitUi.Link(g.Add("Text", "x" x " y+" KitS(4) " BackgroundTrans", "Update now")
            , (*) => KitInstall.Start())
        g.SetFont("s10 Norm c" Theme.Blue, Theme.Font)
        KitUi.Link(g.Add("Text", "x+" KitS(28) " yp BackgroundTrans", "Download page"), (*) => Run(rel["url"]))
        g.SetFont("s10 Norm c" Theme.Muted, Theme.Font)
        KitUi.Link(g.Add("Text", "x+" KitS(28) " yp BackgroundTrans", "Not now"), (*) => KitInstall.Close())
        g.OnEvent("Close", (*) => KitInstall.Close())
        g.OnEvent("Escape", (*) => KitInstall.Close())
        KitInstall.g := g
        Theme.TitleBar(g.Hwnd)
        KitTaskbar.Id(g.Hwnd)
        g.Show("w" KitS(500) " " where)
        SendMessage(0xB1, 0, 0, KitInstall.notes)               ; EM_SETSEL: no text selected
        if ((why := KitInstall.Blocker()) != "") {
            KitInstall.goLink.Visible := false
            KitInstall.Say(why " The download page has the new version to unzip over this folder.", Theme.Amber)
        }
    }

    ; after the theme changed: the same window again, unless it is mid-update
    static Rebuild() {
        if (KitInstall.g && !KitInstall.busy && KitInstall.rel) {
            KitInstall.Drop()
            KitInstall.Offer(KitInstall.rel)
        }
    }

    static Close() {
        KitInstall.Stop()
        KitInstall.Drop()
    }

    static Drop() {
        if KitInstall.g
            KitUi.Drop(KitInstall.g)
        KitInstall.g := ""
    }

    static Say(text, color := "") {
        if !KitInstall.g
            return
        KitInstall.status.SetFont("c" (color != "" ? color : Theme.Muted))
        KitInstall.status.Text := text
    }

    ; GitHub's notes are Markdown; the window shows them as plain text
    static NotesText(md) {
        ; the release page's "Which zip?" lines, down to their --- line, are
        ; for someone downloading; the update window picks the zip itself
        t := RegExReplace(StrReplace(md, "`r"), "s)^\s*\*\*Which zip\?\*\*.*?\n-{3,}[ \t]*(\n|$)")
        t := StrReplace(t, "**")
        t := RegExReplace(t, "\n[ \t]+(?![-*\s])", " ")         ; a wrapped line joins the one before
        t := RegExReplace(t, "m)^#+\s*(.*)$", "$U1")
        ; a part GitHub shows folded: its summary is its heading, the tags go
        t := RegExReplace(t, "im)^[ \t]*<summary>(.*?)</summary>[ \t]*$", "<h>$1")
        t := RegExReplace(t, "i)</?(details|b|strong)>")
        t := RegExReplace(t, "m)^<h>(.*)$", "$U1")
        t := RegExReplace(t, "\n{3,}", "`n`n")
        t := RegExReplace(t, "m)^(\s*)[-*] ", "$1" Chr(0x2022) " ")
        t := RegExReplace(t, "\[([^\]]+)\]\([^)]+\)", "$1")
        t := StrReplace(t, "``")
        t := Trim(t, "`n ")
        return StrReplace((t != "") ? t : "(no notes)", "`n", "`r`n")
    }

    ;--- the steps ------------------------------------------------------------

    static ZipName(version, kind) => Kit.Slug "-" version (kind = "portable" ? "-portable" : "") ".zip"

    static Start() {
        if KitInstall.busy
            return
        if ((why := KitInstall.Blocker()) != "")
            return KitInstall.Say(why, Theme.Amber)
        rel := KitInstall.rel, v := rel["version"]
        if (KitUpdate.Compare(v, Kit.version) <= 0)
            return KitInstall.Say("That is not newer than " Kit.version ".", Theme.Amber)
        KitInstall.kind := KitInstall.Portable() ? "portable" : "plain"
        KitInstall.manAsset := KitInstall.Asset(rel, "manifest.json")
        KitInstall.zipAsset := KitInstall.Asset(rel, KitInstall.ZipName(v, KitInstall.kind))
        if (!KitInstall.manAsset || !KitInstall.zipAsset)
            return KitInstall.Fail("This version cannot be installed from here - please use the download page.")
        KitInstall.busy := true
        KitInstall.goLink.Visible := false
        KitInstall.dir := KitInstall.Root() "\" v
        try {
            if DirExist(KitInstall.dir)
                DirDelete(KitInstall.dir, true)
            DirCreate(KitInstall.dir)
        } catch as e
            return KitInstall.Fail("Could not make a folder for the download (" e.Message ").")
        KitInstall.Say("Downloading" Chr(0x2026))
        KitInstall.Get(KitInstall.manAsset["url"], "manifest", {timeout: 20000})
    }

    ; the release's file named name, as Map(url, size, digest) - only from
    ; this script's own releases, for this version
    static Asset(rel, name) {
        if !rel.Has("assets")
            return ""
        for a in rel["assets"]
            if (a["name"] = name) {
                for base in KitInstall.Allowed()
                    if (a["url"] == base "v" rel["version"] "/" name)
                        return a
                return ""
            }
        return ""
    }

    static Get(url, step, opts, retried := false) {
        KitInstall.step := step, KitInstall.ask := [url, step, opts], KitInstall.retried := retried
        KitInstall.req := KitHttp(url, opts)
        if !KitInstall.poller
            KitInstall.poller := ObjBindMethod(KitInstall, "Poll")
        SetTimer(KitInstall.poller, 150)
    }

    static Stop() {
        if KitInstall.poller
            SetTimer(KitInstall.poller, 0)
        if (KitInstall.req && KitInstall.req.req)
            try KitInstall.req.req.Abort()
        KitInstall.req := "", KitInstall.busy := false
    }

    static Poll() {
        if !KitInstall.busy
            return SetTimer(KitInstall.poller, 0)
        if !KitInstall.req.Poll()
            return
        SetTimer(KitInstall.poller, 0)
        r := KitInstall.req, KitInstall.req := ""
        if (r.err != "" && !KitInstall.retried) {               ; no connection: once more (KitUpdate.Poll)
            a := KitInstall.ask
            SetTimer(() => KitInstall.busy && KitInstall.Get(a[1], a[2], a[3], true), -3000)
            return
        }
        if !r.Ok
            return KitInstall.Fail("The download failed (" r.Why "). Nothing was changed.")
        try {
            if (KitInstall.step = "manifest") {
                KitInstall.manifest := KitJson.Parse(LTrim(r.text, Chr(0xFEFF)))
                if ((why := KitInstall.CheckManifest(KitInstall.manifest, KitInstall.rel["version"], KitInstall.kind)) != "")
                    return KitInstall.Fail("The new version's file list is not right (" why "). Nothing was changed.")
                KitInstall.Get(KitInstall.zipAsset["url"], "zip", {raw: true, timeout: 300000})
            } else if (KitInstall.step = "zip") {
                path := KitInstall.dir "\update.zip"
                KitHttp.Write(r.raw, path)
                KitInstall.Finish(path)
            }
        } catch as e
            KitInstall.Fail("Something went wrong (" e.Message "). Nothing was changed.")
    }

    ; steps 3 to 7
    static Finish(zipPath) {
        m := KitInstall.manifest, want := m["zips"][KitInstall.kind]
        KitInstall.Say("Checking the download" Chr(0x2026))
        size := FileGetSize(zipPath), hash := KitSha256(zipPath)
        digest := (KitInstall.zipAsset is Map && KitInstall.zipAsset.Has("digest"))
            ? RegExReplace(KitInstall.zipAsset["digest"], "i)^sha256:") : ""
        if (size != want["size"] || hash != want["sha256"] || (digest != "" && StrLower(digest) != hash))
            return KitInstall.Fail("The download is not the file that was published (its check sum differs). Nothing was changed.")

        ; RunWait below lets the window's clicks through: "Not now" there
        ; clears busy, and the update stops at the next step
        KitInstall.Say("Unpacking" Chr(0x2026))
        out := KitInstall.dir "\new"
        ok := KitInstall.Unzip(zipPath, out)
        if !KitInstall.busy
            return
        if !ok
            return KitInstall.Fail("The download could not be unpacked. Nothing was changed.")
        src := out "\" Kit.name
        files := KitInstall.Files(m, KitInstall.kind)
        for f in files {
            p := src "\" StrReplace(f["path"], "/", "\")
            if (!FileExist(p) || FileGetSize(p) != f["size"] || KitSha256(p) != f["sha256"])
                return KitInstall.Fail("An unpacked file is not what was published (" f["path"] "). Nothing was changed.")
        }

        KitInstall.Say("Checking that the new version loads" Chr(0x2026))
        ahk := (KitInstall.kind = "portable") ? src "\AutoHotkey64.exe" : A_AhkPath
        code := RunWait('"' ahk '" /Validate /ErrorStdOut "' src "\" A_ScriptName '"', src, "Hide")
        if !KitInstall.busy
            return
        if (code != 0)
            return KitInstall.Fail("The new version does not load with this AutoHotkey (" A_AhkVersion
                . ") - it may need a newer one. Nothing was changed.")

        KitInstall.Say("Closing and updating" Chr(0x2026))
        if KitInstall.g
            KitInstall.g.Opt("+Disabled")                       ; past the point of "Not now"
        try KitInstall.HandOver(src, files)
        catch as e {
            if KitInstall.g
                KitInstall.g.Opt("-Disabled")
            return KitInstall.Fail("Could not start the update (" e.Message "). Nothing was changed.")
        }
        ExitApp()
    }

    ; the helper, its AutoHotkey and the plan into the temp folder, then start it
    static HandOver(src, files) {
        help := KitInstall.dir "\helper"
        DirCreate(help)
        ; the UI Access edition only runs from Program Files; its plain twin
        ; sits beside it
        exe := A_AhkPath
        if (InStr(exe, "_UIA") && FileExist(StrReplace(exe, "_UIA")))
            exe := StrReplace(exe, "_UIA")
        FileCopy(exe, help "\AutoHotkey64.exe", 1)
        SplitPath(A_LineFile, , &here)                  ; this file's folder: the kit
        FileCopy(here "\Updater.ahk", help "\Updater.ahk", 1)
        FileCopy(here "\Swap.ahk", help "\Swap.ahk", 1)
        rels := []
        for f in files
            rels.Push(f["path"])
        SplitPath(Kit.ini, &ini)
        plan := "app=" A_ScriptDir "`nscript=" A_ScriptName "`nini=" ini "`nname=" Kit.name
            . "`nsource=" src "`nrun=" A_AhkPath "`npid=" ProcessExist()
            . "`nfrom=" Kit.version "`nto=" KitInstall.rel["version"] "`npage=" KitInstall.rel["url"]
            . "`nmarker=" KitInstall.Marker() "`n"
        for k in KitInstall.Keep()
            plan .= "keep=" k "`n"
        for rel in rels
            plan .= "file=" rel "`n"
        for rel in KitSwap.Leftovers(A_ScriptDir, rels)
            plan .= "remove=" rel "`n"
        try FileDelete(KitInstall.dir "\plan.txt")
        FileAppend(plan, KitInstall.dir "\plan.txt", "UTF-8")
        Run('"' help '\AutoHotkey64.exe" "' help '\Updater.ahk" "' KitInstall.dir '\plan.txt"', help)
    }

    static Unzip(zip, out) {
        main := out "\" Kit.name "\" A_ScriptName
        try DirCreate(out)
        try RunWait('tar.exe -xf "' zip '" -C "' out '"', out, "Hide")
        if FileExist(main)
            return true
        try {                                   ; no tar (older Windows 10): the Explorer way
            sh := ComObject("Shell.Application")
            sh.NameSpace(out).CopyHere(sh.NameSpace(zip).Items(), 4 | 16 | 1024)
        }
        return FileExist(main) != ""
    }

    static Fail(text) {
        KitInstall.Stop()
        Kit.Log("Update: " text)
        KitInstall.Say(text, Theme.Red)
        if KitInstall.g
            KitInstall.goLink.Visible := false
    }

    ;--- checks, kept apart so the tests can reach them -----------------------

    ; "" when the manifest is one this can install from, else what is wrong
    static CheckManifest(m, version, kind) {
        if !(m is Map)
            return "not a list"
        if (Dig(m, "name") != Kit.name)
            return "another app's"
        if (Dig(m, "version") != version)
            return "it is for " Dig(m, "version") ", not " version
        z := Dig(m, "zips", kind)
        if (!(z is Map) || !IsInteger(Dig(z, "size")) || !RegExMatch(Dig(z, "sha256"), "^[0-9a-f]{64}$"))
            return "no check sum for the " kind " zip"
        files := KitInstall.Files(m, kind)
        if !files.Length
            return "no files"
        KitSwap.Keep := KitInstall.Keep()
        seen := Map()
        seen.CaseSense := false
        for f in files {
            p := Dig(f, "path")
            if (!KitSwap.SafeRel(p) || !IsInteger(Dig(f, "size")) || !RegExMatch(Dig(f, "sha256"), "^[0-9a-f]{64}$"))
                return "a file it may not write, or without a check sum: " p
            seen[StrReplace(p, "\", "/")] := true
        }
        for need in [A_ScriptName, "lib/Kit/Kit.ahk", "lib/Kit/Updater.ahk", "lib/Kit/Swap.ahk"]
            if !seen.Has(need)
                return "no " need
        if (kind = "portable" && !seen.Has("AutoHotkey64.exe"))
            return "no AutoHotkey64.exe"
        return ""
    }

    ; the files this copy gets: the script, plus AutoHotkey and its starter
    ; for a portable copy
    static Files(m, kind) {
        out := []
        for key in (kind = "portable") ? ["files", "portable"] : ["files"]
            if (Dig(m, key) is Array)
                for f in m[key]
                    out.Push(f)
        return out
    }

    ;--- after an update ------------------------------------------------------

    ; At start. Started with --updated-from=<old> by the helper: say so to
    ; the helper (the marker file) and to the user. The temp folder is
    ; cleared a few minutes later, when the helper is long gone.
    static Started() {
        for a in A_Args
            if RegExMatch(a, "^--updated-from=(.+)$", &m) {
                try FileAppend(Kit.version, KitInstall.Marker(), "UTF-8")
                Kit.Notice(Kit.name " is now " Kit.version " (was " m[1] "). Click to see what is new."
                    , Kit.name ": updated", () => Run(Kit.RepoUrl "/releases/tag/v" Kit.version))
            }
        SetTimer(() => KitInstall.Cleanup(), -180000)
    }

    static Cleanup() {
        if (DirExist(KitInstall.Root()) && !KitInstall.busy)
            try DirDelete(KitInstall.Root(), true)
    }
}

; SHA-256 of a file, as 64 lowercase hex digits - Windows' own CNG
KitSha256(path) {
    f := FileOpen(path, "r")
    if !f
        throw Error("cannot read " path)
    f.Pos := 0                          ; FileOpen steps past a text file's BOM; the hash needs every byte
    data := Buffer(Max(f.Length, 1)), n := f.RawRead(data, f.Length)
    f.Close()
    alg := 0, h := 0, out := Buffer(32)
    if DllCall("bcrypt\BCryptOpenAlgorithmProvider", "ptr*", &alg, "wstr", "SHA256", "ptr", 0, "uint", 0, "uint")
        throw Error("SHA-256 is not available")
    try {
        if DllCall("bcrypt\BCryptCreateHash", "ptr", alg, "ptr*", &h, "ptr", 0, "uint", 0, "ptr", 0, "uint", 0, "uint", 0, "uint")
            throw Error("SHA-256 failed")
        ok := !DllCall("bcrypt\BCryptHashData", "ptr", h, "ptr", data, "uint", n, "uint", 0, "uint")
            && !DllCall("bcrypt\BCryptFinishHash", "ptr", h, "ptr", out, "uint", 32, "uint", 0, "uint")
        DllCall("bcrypt\BCryptDestroyHash", "ptr", h)
        if !ok
            throw Error("SHA-256 failed")
    } finally
        DllCall("bcrypt\BCryptCloseAlgorithmProvider", "ptr", alg, "uint", 0)
    hex := ""
    loop 32
        hex .= Format("{:02x}", NumGet(out, A_Index - 1, "uchar"))
    return hex
}
