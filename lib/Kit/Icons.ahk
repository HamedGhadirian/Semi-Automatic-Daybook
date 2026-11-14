;================================================================================
; Icons.ahk (kit) - the tray icons: files beside the script, named in the .ini
;================================================================================
; THE RULE (the user, 2026-11-13): every script's icons are files in its own
; folder. Each has a line in the .ini's [Icons] section, with a comment saying
; what it is for - so a different picture is one line in the .ini, never a
; hunt through the code. The Settings window has no icon rows.
;
;   [Icons]
;   ; Recording. Blank = rec.png beside MyApp.ahk.
;   Recording=
;
; A line's value: blank (the file named in its comment), a file name beside
; the script, or a full path. A file that is not there is logged; the script
; runs on with AutoHotkey's own icon.
;
; WHAT THE SCRIPT HANDS Kit.Start
;   icon     one file: the tray icon (the line is "Tray")
;   icons    several, in order: [{key, file, name}] - one per state; the first
;            is the one the tray shows at the start
;   iconWas  [section, key]: where the first one's line used to be. Its value
;            is carried over once, and the old line (with its comment) goes.
;
; THE SECTION KEEPS ITSELF RIGHT. At every start the [Icons] section is
; written as it should be - the comments, every line in order - keeping each
; value that is there. A file without the section gets it.
;
; The paths are read once, at the start: after editing the .ini by hand,
; reload the script (as for every line of it).
;================================================================================
#Requires AutoHotkey v2.0

class KitIcons {
    static paths := Map()

    ; the script's icons: [{key, file, name}]
    static List() {
        list := Kit.Opt("icons", [])
        if (!list.Length && Kit.Opt("icon") != "")
            list := [{key: "Tray", file: Kit.Opt("icon"), name: "The tray icon"}]
        return list
    }

    ; the full path of an icon - the first one unless a key is named; "" when
    ; the script has none
    static Path(key := "") {
        if !KitIcons.paths.Count
            KitIcons.Load()
        list := KitIcons.List()
        if !list.Length
            return ""
        k := (key != "") ? key : list[1].key
        return KitIcons.paths.Has(k) ? KitIcons.paths[k] : ""
    }

    static Load() {
        KitIcons.paths := Map()
        KitIcons.paths.CaseSense := "Off"
        for i in KitIcons.List() {
            v := Trim(CfgStr(Kit.ini, "Icons", i.key, ""))
            f := (v != "") ? v : i.file
            f := RegExMatch(f, "^([A-Za-z]:|\\\\)") ? f : A_ScriptDir "\" f
            KitIcons.paths[i.key] := KitIcons.Paired(f)
        }
    }

    ; A picture drawn pixel by pixel for the tray (the user, 2026-11-13): when
    ; "name_16x16.png" sits beside "name.png", the two are packed into one .ico
    ; (in Temp, made again when either changes). Windows then shows the 16 px
    ; one in the tray and the big one on the taskbar. Without it: the file.
    static Paired(f) {
        SplitPath(f, , &dir, &ext, &base)
        small := dir "\" base "_16x16.png"
        if (ext != "png" || !FileExist(f) || !FileExist(small))
            return f
        out := A_Temp "\AhkKitIcons\" RegExReplace(dir "\" base, "[\\/:]+", "_") "-2.ico"   ; -2: the big one first (2026-11-14)
        try {
            t := FileGetTime(out, "M")
            if (t >= FileGetTime(f, "M") && t >= FileGetTime(small, "M"))
                return out
        }
        try {
            DirCreate(A_Temp "\AhkKitIcons")
            ; the big one FIRST: a window's icon (a taskbar button) takes the
            ; first picture, and was a blurry 16 blown up; the tray still finds its 16
            KitIcons.WriteIco(out, [[f, 0], [small, 16]])
            return out
        } catch as e {
            Kit.Log("Could not pack " small " with " f ": " e.Message)
            return f
        }
    }

    ; An .ico holding PNG pictures as they are (Windows reads PNG inside an
    ; .ico since Vista). parts: [[file, size]] - size 0 = read from the PNG.
    static WriteIco(out, parts) {
        datas := []
        for p in parts
            datas.Push(FileRead(p[1], "RAW"))
        h := FileOpen(out ".tmp", "w")
        head := Buffer(6 + 16 * parts.Length, 0)
        NumPut("ushort", 0, "ushort", 1, "ushort", parts.Length, head)
        off := head.Size
        for n, d in datas {
            w := NumGet(d, 16, "uint"), hh := NumGet(d, 20, "uint")    ; IHDR width, height (big-endian)
            w := ((w & 0xFF) << 24 | (w & 0xFF00) << 8 | (w >> 8) & 0xFF00 | (w >> 24) & 0xFF)
            hh := ((hh & 0xFF) << 24 | (hh & 0xFF00) << 8 | (hh >> 8) & 0xFF00 | (hh >> 24) & 0xFF)
            e := 6 + 16 * (n - 1)
            NumPut("uchar", w >= 256 ? 0 : w, "uchar", hh >= 256 ? 0 : hh, "uchar", 0, "uchar", 0
                , "ushort", 1, "ushort", 32, "uint", d.Size, "uint", off, head, e)
            off += d.Size
        }
        h.RawWrite(head)
        for d in datas
            h.RawWrite(d)
        h.Close()
        FileMove(out ".tmp", out, true)
    }

    ; the section as it should be, with these values
    static Text(vals) {
        list := KitIcons.List()
        out := "[Icons]`r`n"
        if (list.Length = 1) {
            i := list[1]
            return out "; The tray icon, a picture (.png or .ico): a file name beside the script, or a`r`n"
                . "; full path. Blank = " i.file " beside " A_ScriptName ".`r`n" i.key "=" vals[i.key] "`r`n"
        }
        out .= "; The tray icons, one per state - pictures (.png or .ico): a file name beside`r`n; the script, or a full path.`r`n"
        for i in list
            out .= "; " i.name ". Blank = " i.file " beside " A_ScriptName ".`r`n" i.key "=" vals[i.key] "`r`n"
        return out
    }

    ; At the start: the section written as it should be (values kept), the old
    ; line carried over and dropped, then the paths read.
    static Mend() {
        list := KitIcons.List()
        if !list.Length
            return
        ini := Kit.ini
        try {
            f := FileOpen(ini, "r", "UTF-8")        ; a BOM, if any, decides instead
            enc := (f.Pos = 2) ? "UTF-16" : (f.Pos = 3) ? "UTF-8" : "UTF-8-RAW"
            text := f.Read(), f.Close()
        } catch
            return KitIcons.Load()
        vals := Map()
        for i in list
            vals[i.key] := CfgStr(ini, "Icons", i.key, Chr(1))
        was := Kit.Opt("iconWas", "")
        if (was != "") {
            old := CfgStr(ini, was[1], was[2], Chr(1))
            if (old != Chr(1)) {
                if (vals[list[1].key] = Chr(1) || Trim(vals[list[1].key]) = "")
                    vals[list[1].key] := old        ; a blank new line: the old choice stands
                text := KitIcons.DropLine(text, was[1], was[2])
            }
        }
        for k, v in vals
            if (v = Chr(1))
                vals[k] := ""
        new := KitIcons.Place(text, KitIcons.Text(vals))
        if (new !== text) {
            try {
                f := FileOpen(ini, "w", enc)
                f.Write(new)
                f.Close()
            } catch as e
                Kit.Log("Icons: could not write the [Icons] section (" e.Message ")")
        }
        KitIcons.Load()
    }

    ; The section put in the file's text: over the old one - its head down to
    ; its last key line; comments after that belong to the next section - or,
    ; when there is none, before [Saved], or at the end.
    static Place(text, want) {
        lines := StrSplit(StrReplace(text, "`r`n", "`n"), "`n")
        head := 0, last := 0
        for i, ln in lines {
            if RegExMatch(ln, "^\s*\[([^\]]+)\]", &s) {
                if head
                    break
                if (s[1] = "Icons")
                    head := i, last := i
            } else if (head && RegExMatch(ln, "^\s*[^;\s][^=]*="))
                last := i
        }
        want := RTrim(want, "`r`n")
        out := []
        if head {
            for i, ln in lines
                if (i < head || i > last)
                    out.Push(ln)
                else if (i = head) {
                    out.Push(want)
                    if (last < lines.Length && RegExMatch(lines[last + 1], "^\s*\["))
                        out.Push("")                    ; a blank line before the next section
                }
        } else {
            saved := 0
            for i, ln in lines
                if RegExMatch(ln, "i)^\s*\[Saved\]") {
                    saved := i
                    break
                }
            if saved {
                for i, ln in lines {
                    if (i = saved)
                        out.Push(want, "")
                    out.Push(ln)
                }
            } else {
                while (lines.Length && Trim(lines[lines.Length]) = "")
                    lines.Pop()
                for ln in lines
                    out.Push(ln)
                out.Push("", want, "")
            }
        }
        res := ""
        for i, ln in out
            res .= (i > 1 ? "`r`n" : "") ln
        return res
    }

    ; a key's line gone from a section, with the comment lines right above it
    static DropLine(text, sect, key) {
        lines := StrSplit(StrReplace(text, "`r`n", "`n"), "`n")
        cur := "", out := []
        for ln in lines {
            if RegExMatch(ln, "^\s*\[([^\]]+)\]", &s)
                cur := s[1]
            if (cur = sect && RegExMatch(ln, "i)^\s*\Q" key "\E\s*=")) {
                while (out.Length && RegExMatch(out[out.Length], "^\s*;"))
                    out.Pop()
                continue
            }
            out.Push(ln)
        }
        res := ""
        for i, ln in out
            res .= (i > 1 ? "`r`n" : "") ln
        return res
    }
}
