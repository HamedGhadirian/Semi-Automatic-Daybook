;================================================================================
; Ini.ahk (kit) - the settings file every script reads, and how it reads it
;================================================================================
; The v2 twin of lib\Settings.ahk, with the same names and the same rules, so
; a script that moves from v1 keeps every line that reads a setting.
;
; Each script seeds a plain .ini beside itself the first time it runs, with a
; comment above every setting. Nothing in the .ini can stop a script from
; starting: a key that is missing, blank, mistyped or nonsense falls back to
; the default the script shipped with.
;
; READING RULES
;   A key that is ABSENT falls back to the default.
;   A key that is PRESENT BUT BLANK is an answer, and CfgStr hands the blank
;   back - several settings use "" to mean something ("every program", "no
;   proxy"). CfgStrDef is for the settings where a blank means "not filled in".
;   Numbers and switches have no use for a blank: blank or unreadable falls
;   back to the default.
;
; ENCODING. IniRead and IniWrite are Windows' own profile API, which knows
; UTF-16 with a BOM, or plain bytes. A UTF-8 file WITH a BOM is neither: the
; BOM sticks to the first section's name and that section can no longer be
; found. So CfgSeed writes UTF-8 without a BOM, and every template is ASCII.
;================================================================================
#Requires AutoHotkey v2.0

; Write the commented default file, once, if it is not there. Returns the path
; either way. It can never overwrite a setting you changed; a setting added to
; a template later simply falls back to its default in an older file.
CfgSeed(path, template) {
    if !FileExist(path) {
        SplitPath(path, , &dir)
        if (dir != "" && !DirExist(dir))
            DirCreate(dir)
        FileAppend(template, path, "`n UTF-8-RAW")
    }
    return path
}

; One string. Absent = the default; blank = blank.
CfgStr(ini, sect, key, def := "") {
    static NOKEY := Chr(1)              ; a byte no .ini line can contain
    try v := IniRead(ini, sect, key, NOKEY)
    catch
        return def
    return (v == NOKEY) ? def : Trim(v)
}

; Like CfgStr, but a blank falls back to the default too.
CfgStrDef(ini, sect, key, def) {
    v := CfgStr(ini, sect, key, "")
    return (v = "") ? def : v
}

; One number. Blank or unreadable falls back.
CfgNum(ini, sect, key, def) {
    v := CfgStr(ini, sect, key, "")
    if (v = "" || !RegExMatch(v, "^-?\d+(\.\d+)?$"))
        return def
    return Number(v)
}

; One on/off switch, spelled however felt natural at the time.
CfgBool(ini, sect, key, def) {
    v := CfgStr(ini, sect, key, "")
    if (v = "1" || v = "true" || v = "yes" || v = "on")
        return true
    if (v = "0" || v = "false" || v = "no" || v = "off")
        return false
    return def
}

; One list, written with "|" between the items; def is a "|" string too.
CfgList(ini, sect, key, def := "") {
    out := []
    for part in StrSplit(CfgStr(ini, sect, key, def), "|") {
        part := Trim(part)
        if (part != "")
            out.Push(part)
    }
    return out
}

; A whole section as a Map of key -> value, for settings that are a table.
; An empty Map for a section that is missing.
CfgSection(ini, sect) {
    out := Map()
    out.CaseSense := false
    try block := IniRead(ini, sect)
    catch
        return out
    loop parse block, "`n", "`r" {
        line := Trim(A_LoopField)
        if (line = "" || SubStr(line, 1, 1) = ";" || !(eq := InStr(line, "=")))
            continue
        out[Trim(SubStr(line, 1, eq - 1))] := Trim(SubStr(line, eq + 1))
    }
    return out
}

; Your Pictures folder, where the tray icons live. From A_MyDocuments - the
; two move together, and both follow OneDrive - never a path with a user name.
CfgPicturesDir() {
    SplitPath(A_MyDocuments, , &parent)
    return parent "\Pictures"
}

; Notepad on purpose: it is everywhere, it cannot reformat the file, and it
; does not hold the .ini open when the script next writes to it.
CfgOpen(ini) {
    Run('notepad.exe "' ini '"')
}
