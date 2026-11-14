;================================================================================
; Update.ahk (kit) - is there a newer version?
;================================================================================
; Once a day, quietly, the script's releases on GitHub are asked for (one
; small request to its public API, no account). If one is newer than the
; version running, a tray notice says so and the tray menu gets "Get version
; X..."; either opens the update window (Install.ahk): what is new, "Update
; now", or the download page. Nothing is downloaded or changed without that
; click, and nothing ever takes the focus.
;
; Which releases count: a test version (a version with a dash, 1.1.0-beta.2)
; only for someone already running one. Everyone else hears about finished
; versions only - the same rule GitHub's "latest release" link follows.
;
; Settings > GENERAL switches the daily check off ([General] CheckUpdates=0)
; and has "check now"; the tray menu has "Look for updates now". A check by
; hand always answers, "up to date" included; the daily one only speaks when
; there is news, and says nothing at all when GitHub cannot be reached.
;
; "Once a day" means once per calendar day that GitHub answered, not once per
; start: a script that starts with Windows can run for a week, so Daily() is
; asked again every hour and does nothing unless the date has changed. The
; date of the last look is kept in the temp folder, not in the .ini - it
; means nothing on another PC, and the .ini holds only what you set.
;================================================================================
#Requires AutoHotkey v2.0

class KitUpdate {
    static req := "", poller := "", manual := false, onDone := "", found := "", retried := false

    static Start() {
        if (Kit.repo = "")
            return
        SetTimer(() => KitUpdate.Daily(), -20000)
        SetTimer(() => KitUpdate.Daily(), 3600000)
    }

    static Stamp() => A_Temp "\" Kit.Slug "-update-check.txt"

    ; once a day, unless switched off
    static Daily() {
        if !CfgBool(Kit.ini, "General", "CheckUpdates", true)
            return
        last := ""
        try last := FileRead(KitUpdate.Stamp())
        if (SubStr(last, 1, 8) = FormatTime(, "yyyyMMdd"))
            return
        KitUpdate.Check(false)
    }

    ; manual: asked for by hand - always answers. onDone(text, found) gets the
    ; answer as well, for the settings window's own line. The newer version,
    ; when there is one, is kept in KitUpdate.found for the update window.
    static Check(manual := true, onDone := "") {
        if (Kit.repo = "" || KitUpdate.req)     ; one check at a time
            return
        KitUpdate.manual := manual, KitUpdate.onDone := onDone, KitUpdate.retried := false
        KitUpdate.Ask()
    }

    static Ask() {
        KitUpdate.req := KitHttp("https://api.github.com/repos/" Kit.repo "/releases?per_page=20"
            , {timeout: 10000, headers: Map("Accept", "application/vnd.github+json")})
        if !KitUpdate.poller
            KitUpdate.poller := ObjBindMethod(KitUpdate, "Poll")
        SetTimer(KitUpdate.poller, 200)
    }

    static Poll() {
        if !KitUpdate.req.Poll()
            return
        SetTimer(KitUpdate.poller, 0)
        r := KitUpdate.req
        ; no connection at all (not an answer like 404): once more, a few
        ; seconds later - a first connection sometimes fails where the second
        ; works. req stays set meanwhile, so no second check starts.
        if (r.err != "" && !KitUpdate.retried) {
            KitUpdate.retried := true
            SetTimer(() => KitUpdate.Ask(), -3000)
            return
        }
        KitUpdate.req := ""
        news := ""
        if r.Ok {
            try {
                FileOpen(KitUpdate.Stamp(), "w").Write(FormatTime(, "yyyyMMdd"))
            }
            try news := KitUpdate.Newest(KitJson.Parse(r.text), Kit.version)
        }
        if (!r.Ok || news = "") {
            ok := r.Ok && news = ""
            text := ok ? "You have the newest version, " Kit.version "."
                : (r.status = 404) ? "No published version of " Kit.name " yet."
                ; GitHub answers 60 questions an hour per address without an
                ; account; past that, 403 or 429 until the hour is over
                : (r.status = 403 || r.status = 429) ? "GitHub is busy with this PC for now (too many questions this hour). Try again later."
                : "Could not reach GitHub (" r.Why ")."
            if (!ok && r.status != 404 && KitUpdate.manual)     ; the quiet daily look stays quiet in the log too
                Kit.Log("Update check: " r.Why)
            if KitUpdate.manual
                Kit.Notice(text)
            KitUpdate.Tell(text, false)
            return
        }
        KitUpdate.found := news
        KitTray.Build()                         ; "Get version X..."
        Kit.Notice(Kit.name " " news["version"] " is out - you have " Kit.version
            . ". Click to see what is new and update.", Kit.name ": a new version", () => KitInstall.Offer(news))
        KitUpdate.Tell(Kit.name " " news["version"] " is out.", true)
    }

    static Tell(text, found) {
        if KitUpdate.onDone
            try KitUpdate.onDone.Call(text, found)
    }

    ; The newest release in list (GitHub's answer) that is newer than mine, as
    ; Map(version, url, notes, assets) - assets its files, each Map(name, url,
    ; size, digest) - or "" when there is none. Drafts never count; test
    ; versions count only when mine is one.
    static Newest(list, mine) {
        pre := InStr(mine, "-") > 0
        best := "", files := ""
        if !(list is Array)
            return ""
        for rel in list {
            if Dig(rel, "draft")
                continue
            v := RegExReplace(Dig(rel, "tag_name"), "^v")
            if (v = "" || (Dig(rel, "prerelease") && !pre))
                continue
            if (KitUpdate.Compare(v, mine) > 0 && (!best || KitUpdate.Compare(v, best["version"]) > 0))
                best := Map("version", v, "url", Dig(rel, "html_url"), "notes", Dig(rel, "body"), "assets", [])
                    , files := Dig(rel, "assets")
        }
        if (best && files is Array)
            for a in files
                best["assets"].Push(Map("name", Dig(a, "name"), "url", Dig(a, "browser_download_url")
                    , "size", Dig(a, "size"), "digest", Dig(a, "digest")))
        return best
    }

    ; -1, 0 or 1, the way versions are ordered: 1.2.0 before 1.10.0, and a test
    ; version before the finished one it leads to - 1.1.0-beta.2 < 1.1.0 - with
    ; test versions in order by their number: beta.2 < beta.10.
    static Compare(a, b) {
        pa := StrSplit(a, "-", , 2), pb := StrSplit(b, "-", , 2)
        na := StrSplit(pa[1], "."), nb := StrSplit(pb[1], ".")
        loop Max(na.Length, nb.Length) {
            x := (A_Index <= na.Length && IsInteger(na[A_Index])) ? Integer(na[A_Index]) : 0
            y := (A_Index <= nb.Length && IsInteger(nb[A_Index])) ? Integer(nb[A_Index]) : 0
            if (x != y)
                return (x > y) ? 1 : -1
        }
        ta := (pa.Length > 1) ? pa[2] : "", tb := (pb.Length > 1) ? pb[2] : ""
        if (ta = tb)
            return 0
        if (ta = "" || tb = "")                 ; the finished version comes after its tests
            return (ta = "") ? 1 : -1
        xa := StrSplit(ta, "."), xb := StrSplit(tb, ".")
        loop Max(xa.Length, xb.Length) {
            if (A_Index > xa.Length)
                return -1
            if (A_Index > xb.Length)
                return 1
            s := xa[A_Index], t := xb[A_Index]
            if (IsInteger(s) && IsInteger(t)) {
                if (Integer(s) != Integer(t))
                    return (Integer(s) > Integer(t)) ? 1 : -1
            } else if (s != t)
                return (StrCompare(s, t) > 0) ? 1 : -1
        }
        return 0
    }
}
