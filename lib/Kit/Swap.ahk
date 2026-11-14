;================================================================================
; Swap.ahk (kit) - putting a new version's files in place, or none of them
;================================================================================
; Used by Updater.ahk, the small helper that runs while the script itself is
; closed (Install.ahk explains the whole update). It needs nothing else from
; the kit, so the helper can run from a copy of itself in the temp folder.
;
; KitSwap.Apply(app, source, files, remove, about)
;   files   the new version's files, as paths relative to its folder
;           ("lib/Scroll.ahk"). Each is copied from source over app - after the
;           file it replaces has been copied into app\previous version\.
;   remove  old code files the new version no longer has (only .ahk files
;           under lib\); they are moved into previous version\ too.
;   If any step fails, everything done so far is undone - the old files come
;   back from previous version\, new ones are deleted - and the reason is
;   returned. "" = done.
;
; What is never touched, whatever a list says: the user's own files - the
; .ini, errors.log and whatever else the script named (KitSwap.Keep) - and
; anything outside the script's folder. SafeRel turns such a path down, and
; the whole update with it.
;
; previous version\ holds the version before the latest update, with a note
; saying which one it was; each update replaces it. Copying its files back
; over the folder is the way back.
;================================================================================
#Requires AutoHotkey v2.0

class KitSwap {
    static BackupName := "previous version"
    static Keep := []               ; the user's own files and folders, by first path part;
                                    ; one ending in * is every name that starts so

    ; true for a path that may be written: relative, inside the folder, and not
    ; one of the user's own files
    static SafeRel(rel) {
        rel := StrReplace(rel, "/", "\")
        if (rel = "" || RegExMatch(rel, "[:*?`"<>|]") || RegExMatch(rel, "^[\\.]"))
            return false
        for part in StrSplit(rel, "\")
            if (part = "" || part = "." || part = ".." || RegExMatch(part, "[. ]$"))
                return false
        first := StrSplit(rel, "\")[1]
        if (first = KitSwap.BackupName || first = ".git" || first = "errors.log" || RegExMatch(first, "i)\.ini$"))
            return false
        for mine in KitSwap.Keep
            if (SubStr(mine, -1) = "*" ? InStr(first, SubStr(mine, 1, -1)) = 1 : first = mine)
                return false
        return true
    }

    ; an old code file an update may set aside: an .ahk under lib\
    static Removable(rel) => RegExMatch(StrReplace(rel, "/", "\"), "i)^lib\\([^\\]+\\)*[^\\]+\.ahk$")

    static Apply(app, source, files, remove, about := "") {
        bak := app "\" KitSwap.BackupName
        for rel in files
            if !KitSwap.SafeRel(rel)
                return "the new version names a file it may not write: " rel
        for rel in remove
            if (!KitSwap.SafeRel(rel) || !KitSwap.Removable(rel))
                return "the new version would remove a file it may not: " rel
        for rel in files
            if !FileExist(source "\" rel)
                return "the download is missing " rel

        try {
            if DirExist(bak)
                DirDelete(bak, true)
            DirCreate(bak)
        } catch as e
            return "could not make the " KitSwap.BackupName " folder (" e.Message ")"

        ; (a for-loop's own variable is not seen inside a () => closure, so
        ; each path is copied into rel first)
        done := [], moved := []
        try {
            for item in remove {
                rel := StrReplace(item, "/", "\")
                if !FileExist(app "\" rel)
                    continue
                KitSwap.Parent(bak "\" rel)
                KitSwap.Retry(() => FileMove(app "\" rel, bak "\" rel, 1))
                moved.Push(rel)
            }
            for item in files {
                rel := StrReplace(item, "/", "\")
                target := app "\" rel
                had := FileExist(target) != ""
                if had {
                    KitSwap.Parent(bak "\" rel)
                    KitSwap.Retry(() => FileCopy(target, bak "\" rel, 1))
                }
                done.Push({rel: rel, had: had})     ; from here on, undo knows about it
                KitSwap.Parent(target)
                KitSwap.Retry(() => FileCopy(source "\" rel, target, 1))
                if (FileGetSize(target) != FileGetSize(source "\" rel))
                    throw Error("the copy of " rel " came out a different size")
            }
        } catch as e {
            left := KitSwap.Undo(app, bak, done, moved)
            why := (e.Message != "") ? e.Message : "a file could not be replaced"
            return why ((left != "") ? " - and putting the old files back failed too (" left
                . "); they are all in the " KitSwap.BackupName " folder" : "")
        }
        try FileAppend(about, bak "\about this folder.txt", "UTF-8")
        return ""
    }

    ; back to how it was: old files copied back, new ones deleted, removed ones
    ; moved back. Returns what could not be undone, or "".
    static Undo(app, bak, done, moved) {
        left := []
        i := done.Length
        while (i >= 1) {
            d := done[i--]
            try {
                if d.had
                    KitSwap.Retry(() => FileCopy(bak "\" d.rel, app "\" d.rel, 1))
                else if FileExist(app "\" d.rel)
                    KitSwap.Retry(() => FileDelete(app "\" d.rel))
            } catch
                left.Push(d.rel)
        }
        for item in moved {
            rel := item
            try KitSwap.Retry(() => FileMove(bak "\" rel, app "\" rel, 1))
            catch
                left.Push(rel)
        }
        out := ""
        for rel in left
            out .= (out = "" ? "" : ", ") rel
        return out
    }

    ; the new version's list against what the folder has: the old code files
    ; under lib\ it no longer has
    static Leftovers(app, files) {
        keep := Map()
        keep.CaseSense := false
        for rel in files
            keep[StrReplace(rel, "/", "\")] := true
        ; both sides in their long form: a folder reached by a short 8.3 name
        ; (C:\Users\RUNNER~1\...) can list its files under the long one, and
        ; cutting by length then lands mid-name ("pp\lib\All.ahk")
        app := KitSwap.LongPath(RTrim(app, "\"))
        out := [], cut := StrLen(app) + 2
        loop files app "\lib\*.ahk", "R" {
            rel := SubStr(KitSwap.LongPath(A_LoopFileFullPath), cut)
            if !keep.Has(rel)
                out.Push(rel)
        }
        return out
    }

    static LongPath(path) {
        buf := Buffer(65534 * 2)
        n := DllCall("GetLongPathNameW", "Str", path, "Ptr", buf, "UInt", 65534, "UInt")
        return (n && n < 65534) ? StrGet(buf, n, "UTF-16") : path
    }

    static Parent(path) {
        SplitPath(path, , &dir)
        if !DirExist(dir)
            DirCreate(dir)
    }

    ; a virus scanner or OneDrive can hold a file for a moment
    static Retry(fn, tries := 6) {
        loop tries {
            try {
                fn()
                return
            } catch as e {
                if (A_Index = tries)
                    throw e
                Sleep(500)
            }
        }
    }
}
