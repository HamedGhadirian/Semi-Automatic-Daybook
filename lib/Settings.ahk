;================================================================================
; Settings.ahk - the settings file every script reads, and how it reads it
;================================================================================
; Lives in AHK\lib and is #Include'd by every script in the AHK folder that has
; a settings file. It holds no settings of its own - it is the half-dozen
; functions they all need in order to have one.
;
; WHY THE SETTINGS LIVE IN A .INI AND NOT AT THE TOP OF EACH SCRIPT
;   They used to live at the top of each script, which meant changing one was
;   editing code: you had to find the right line among a thousand, get the
;   quoting right, and not break the file. Those scripts deliberately have no
;   "Edit Script" in their tray menu, so that was not even offered.
;
;   Now each script seeds a plain .ini in its own folder the first time it runs,
;   with a comment above every setting saying what it does and what else it
;   will take, and its tray menu has one item that opens that file in Notepad.
;   Nothing in the .ini can stop a script from starting: a key that is missing,
;   blank, mistyped or nonsense falls back to the same default the script
;   shipped with. The worst a bad edit does is leave one setting at its default.
;
;   Vocab.ahk has worked this way for a while - this is the same idea, spread
;   to the rest, with the reading put in one place instead of six.
;
; MORE THAN ONE COPY OF THIS FILE EXISTS, and they are meant to be identical.
; The scripts published on their own cannot #Include a file from outside their
; folder, so each carries a copy in its own lib\ - Daybook, WindowTools and
; AutoScroll (WindowTools also carries Osd.ahk and Monitors.ahk). Change one
; and copy it to the others, or the day they differ will be a long one. Not every script uses
; every reader here; a function with no caller in one copy is not dead code.
;
;
; WHAT IS DELIBERATELY *NOT* IN A .INI
;   Hotkeys. Almost every hotkey in these scripts is written as "#F2::" at the
;   top level, which AutoHotkey resolves when it LOADS the file - there is no
;   moment at which a string out of an .ini could be substituted in. Making
;   them configurable means rewriting each one as a Hotkey command plus a
;   label, and then a typo in the .ini becomes a runtime error at startup
;   instead of a setting that quietly falls back. The one exception is
;   MicControl's in-game key, which was ALREADY registered that way and so
;   costs nothing to expose - it is in MicControl.ini.
;
; READING RULES - the part worth knowing before you use these
;   A key that is ABSENT falls back to the default.
;   A key that is PRESENT BUT BLANK is an answer, not an absence, and CfgStr
;   hands the blank back. That distinction is the whole point of the Chr(1)
;   sentinel below: several settings use "" to mean something specific ("use
;   whatever Windows calls the default microphone", "never use a proxy"), and
;   a reader that turned a blank back into its default would make those
;   unsayable.
;   Numbers and switches have no such use for a blank, so for those a blank -
;   or anything unparseable - falls back to the default.
;
; A NOTE ON ENCODING, WHICH HAS BITTEN THIS FOLDER ONCE ALREADY
;   IniRead/IniWrite are Windows' own profile API. It understands two kinds of
;   file: UTF-16 with a BOM, and "bytes" (which for ASCII content is any of
;   ANSI / UTF-8-without-BOM). A UTF-8 file WITH a BOM is neither: the three
;   BOM bytes end up glued to the front of the first section name, so that
;   section becomes unreachable and the next IniWrite appends a SECOND section
;   with the same name underneath. MicControl.ini was in exactly that state.
;   So CfgSeed writes UTF-8-RAW - no BOM - and every template below is ASCII.
;================================================================================

; The folder a bare name's .ini lands in: the one THIS file is in.
;
; In practice every script passes the whole path - each keeps its .ini in its
; own folder, beside the script - so this is only the fallback. A_LineFile, not
; A_ScriptDir: an #Include'd file's A_ScriptDir is the folder of whichever
; script started the process, and A_LineFile is always this file.
CfgDir() {
    return RegExReplace(A_LineFile, "\\[^\\]+$")
}

; CfgPath("X") -> "<this file's folder>\X.ini"
;
; A name that is already a path is handed straight back, which is how every
; script uses it: the .ini beside the SCRIPT, not beside this file. A script
; that is #Include'd builds that path from its own A_LineFile.
CfgPath(name) {
    if (InStr(name, "\") || InStr(name, ":"))
        return name
    return CfgDir() "\" name ".ini"
}

; Write the commented default file, once, if it is not there. Returns the path
; either way, so callers can say  ini := CfgSeed(dir "\TTS.ini", TtsIniTemplate()).
;
; Only ever called with a missing file, so it can never overwrite settings you
; have changed. A setting ADDED to a template later will not appear in an .ini
; that already exists - it simply falls back to its default, and the script
; goes on working. That is the trade for never touching a file you have edited.
CfgSeed(name, template) {
    path := CfgPath(name)
    if (!FileExist(path))
        FileAppend, %template%, %path%, UTF-8-RAW
    return path
}

; One string. See READING RULES above for why absent and blank differ.
CfgStr(ini, sect, key, def := "") {
    static NOKEY := Chr(1)          ; a byte no .ini line can contain
    IniRead, v, %ini%, %sect%, %key%, %NOKEY%
    if (v = NOKEY || v = "ERROR")   ; not there, or the file is unreadable
        return def
    return Trim(v)
}

; Like CfgStr, except a BLANK value falls back to the default as well.
;
; The two exist because a blank means opposite things depending on the setting.
; For a file path or a device name it means "I did not fill this in" and the
; default is what you want. For MonitorMic, Proxy, DefaultTarget and GameApps
; it means something specific and deliberate - "use whatever Windows calls the
; default", "never use a proxy", "every window" - and turning it back into the
; default would make those unsayable. Each setting picks the reader that
; matches what a blank means for it, and the .ini comment says which it is.
CfgStrDef(ini, sect, key, def) {
    v := CfgStr(ini, sect, key, "")
    return (v = "") ? def : v
}

; One number. Blank or unparseable falls back - a setting that expects a count
; of milliseconds has no use for "".
CfgNum(ini, sect, key, def) {
    v := CfgStr(ini, sect, key, "")
    if (v = "" || !RegExMatch(v, "^-?\d+(\.\d+)?$"))
        return def
    return v + 0
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

; One list, written with "|" between the items. "|" rather than "," because
; several of the things listed have commas or spaces in them - a window's exe
; name, a device name - and a separator you have to escape is a separator that
; will be got wrong.
;
; def is a "|" string too, so a caller states its default in the same shape the
; .ini uses and there is only one spelling of it to read.
CfgList(ini, sect, key, def) {
    out := []
    for i, part in StrSplit(CfgStr(ini, sect, key, def), "|") {
        part := Trim(part)
        if (part != "")
            out.Push(part)
    }
    return out
}

; A whole section as a key -> value object, for the settings that are a TABLE
; rather than a value: "which capture mode does each app want", say. IniRead
; with no key hands back the section as "key=value" lines.
;
; Returns an empty object for a section that is missing, so a caller can always
; just use it.
CfgSection(ini, sect) {
    out := {}
    IniRead, block, %ini%, %sect%
    if (block = "" || block = "ERROR")
        return out
    Loop, Parse, block, `n, `r
    {
        line := Trim(A_LoopField)
        if (line = "" || SubStr(line, 1, 1) = ";")
            continue
        eq := InStr(line, "=")
        if (!eq)
            continue
        out[Trim(SubStr(line, 1, eq - 1))] := Trim(SubStr(line, eq + 1))
    }
    return out
}

; Your Pictures folder, which is where every tray icon in this folder lives.
;
; Derived from A_MyDocuments - the two move together, and both follow OneDrive
; when it redirects them - rather than written out with a user name in it,
; which is the first thing that breaks on somebody else PC.
;
; SplitPath rather than the RegExReplace this used to be, in four copies. That
; regex needed FOUR backslashes in the source to match one separator in the
; path and had two, so it matched the word Documents WITHOUT the separator in
; front of it and the result carried a doubled one:
;     C:\Users\you\OneDrive\\Pictures
; Windows quietly accepts that, which is why it went unnoticed for as long as
; it did. Taking the parent folder has no escaping to get wrong, and it still
; does the right thing on a Windows whose Documents folder is not in English.
CfgPicturesDir() {
    SplitPath, A_MyDocuments, , parent
    return parent "\Pictures"
}

; The tray item every script has. Notepad rather than anything cleverer on
; purpose: it is installed everywhere, it cannot reformat the file, and it will
; not be holding the .ini open when the script next writes a window position
; into it.
CfgOpen(ini) {
    Run, notepad.exe "%ini%"
}
