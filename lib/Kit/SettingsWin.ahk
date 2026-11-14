;================================================================================
; SettingsWin.ahk (kit) - the settings window, built from a table of rows
;================================================================================
; Tray menu > Settings. A window that scrolls and can be made shorter or
; taller. Everything is kept in the script's .ini and saved the moment it
; changes - there is no Save button.
;
; THE ORDER, the same in every script
;   GENERAL   Theme, Start with Windows, Run as administrator, Look for updates
;   KEYS      every action with a key, and a "change" beside it (Keys.ahk)
;   ...       the script's own parts, from its "rows" function
;   and a link that opens the .ini, for people who like the file.
;
; A ROW is one line of the table. Adding a setting is adding one:
;   {kind: "head", label: "SCROLLING"}
;   {kind: "bool", sect: "Scroll", key: "Sideways", def: 1, label: "...", hint: "..."}
;   {kind: "num",  sect, key, def, min, max, unit, label, hint}
;   {kind: "list", sect, key, def, choices: ["wheel", "touch"], names: ["Wheel steps", "Touch"], label, hint}
;   {kind: "pick", ...the same as list, shown side by side - for two or three choices}
;   {kind: "text", sect, key, def, label, hint, cue: "grey words in the empty box"}
;   {kind: "path", sect, key, def, label, hint, pick: "folder", title: "..."}
;       a folder (or with pick: "file" and filter: "Images (*.png)", a file):
;       a box the full width and "pick" beside its label. A folder is only
;       saved once it is there (or the box is empty): half a path typed on
;       the way to the real one is not a folder anybody asked for
;   {kind: "note", label: "a paragraph of plain words"}
;   {kind: "custom", add: (c, y) => y, sync: () => ...}
;       a row the script draws itself (a key box with a "test" beside it):
;       add puts its controls on c from y down, with KitS() pixels, and
;       returns the y below them; sync, if given, shows what is saved now
; sect and key name the line in the .ini; def is what an absent line means.
; ini (any row with sect and key): another settings file than the script's
; own - for a script that keeps more than one.
; KitSettings.Reveal(ctrl) scrolls a control into view and gives it the focus.
;
; WHEN A CHANGE IS USED. A script that gave Kit.Start an "apply" function is
; told after every change and uses it at once. One that did not reloads when
; the window closes. The line under the title says which, so it never
; surprises. The GENERAL rows and the keys always work at once; administrator
; alone needs the script to start again, and does that itself.
;
; A number that is not a number is not saved, and the box goes back to what
; was there; one out of range is pulled into it.
;================================================================================
#Requires AutoHotkey v2.0

class KitSettings {
    static g := "", pane := "", W := 608         ; 600 of content plus the scroll thumb
    static sub := "", updateNote := "", syncs := [], savers := []
    static loading := false, needReload := false, applier := ""

    static Show() {
        if !this.g
            this.Build()
        this.Sync()
        if DllCall("IsWindowVisible", "ptr", this.g.Hwnd) {
            WinActivate(this.g.Hwnd)
            return
        }
        ; as tall as its content, or as the screen allows
        wa := KitUi.WorkArea(), w := KitS(this.W)
        h := Min(this.pane.contentH, wa[4] - wa[2] - KitS(80))
        this.g.Show("w" w " h" h " " KitUi.Centre(w, h))
    }

    ; A frame that can be made shorter or taller - not wider - around one
    ; pane that scrolls with the wheel. Everything in it is laid out in Fill.
    static Build() {
        w := KitS(this.W)
        g := Gui("+Resize -MaximizeBox -MinimizeBox -DPIScale +MinSize" w "x" KitS(200), Kit.name " settings")
        g.BackColor := Theme.Bg
        g.MarginX := 0, g.MarginY := 0
        this.g := g
        this.pane := KitPane(g, Theme.Bg)
        h := this.pane.Build(w, (c, cw) => KitSettings.Fill(c))
        g.Opt("+MaxSize" w "x" h)
        this.pane.Show(h)
        g.OnEvent("Size", (gui, minMax, cw, ch) => KitSettings.pane.Show(ch))
        g.OnEvent("Close", (*) => KitSettings.Close())
        g.OnEvent("Escape", (*) => KitSettings.Close())
        Theme.TitleBar(g.Hwnd)
        KitTaskbar.Id(g.Hwnd)
    }

    ; After the theme changed: the same window, in the new colours, where it was.
    static Rebuild() {
        if !this.g
            return
        vis := DllCall("IsWindowVisible", "ptr", this.g.Hwnd)
        x := 0, y := 0, h := 0, was := this.pane.scroll
        if vis {
            WinGetPos(&x, &y, , , this.g.Hwnd)
            WinGetClientPos(, , , &h, this.g.Hwnd)
        }
        this.Drop()
        if !vis
            return
        this.Build()
        this.Sync()
        this.g.Show("x" x " y" y " w" KitS(this.W) " h" Min(h, this.pane.contentH))
        this.pane.ScrollBy(was)
    }

    static Drop() {
        this.Flush()
        KitKeysWin.Stop()
        this.pane.Forget()
        KitUi.Drop(this.g)
        this.g := "", this.pane := "", this.sub := "", this.updateNote := ""
        this.syncs := [], this.savers := []
    }

    static Close() {
        this.Flush()                            ; a change typed a moment ago
        KitKeysWin.Stop()
        this.g.Hide()
        if this.needReload {
            this.needReload := false
            Kit.Restart()
        }
    }

    static Flush() {
        for f in this.savers {
            try f.Call()
        }
    }

    ; every control shows what is in force now - on opening, and after a tick
    ; changed in the tray menu while the window was open
    static Sync() {
        if !this.g
            return
        this.loading := true
        for f in this.syncs {
            try f.Call()
        }
        this.loading := false
        KitKeysWin.Refresh()
    }

    ;----------------------------------------------------------------------------
    ; The table
    ;----------------------------------------------------------------------------
    static AllRows() {
        rows := [{kind: "head", label: "GENERAL"}
            , {kind: "pick", sect: "General", key: "Theme", def: "dark", label: "Theme"
                , choices: ["dark", "light"], names: ["Dark", "Light"]
                , after: (v) => SetTimer(() => Kit.SetTheme(v), -1)}
            , {kind: "bool", label: "Start with Windows"
                , get: () => KitStartup.Wanted(), put: (v) => KitStartup.Set(v)
                , hint: "Starts when you sign in. With Run as administrator on, it starts as administrator without asking."}
            , {kind: "bool", label: "Run as administrator"
                , get: () => KitAdmin.Wanted(), put: (v) => KitAdmin.Set(v, true)
                , hint: Kit.Opt("adminWhy", "So it also works over programs that run as administrator.")
                    . " Windows asks once when you start it by hand. " Kit.name " starts again to switch it on."}]
        if (Kit.repo != "")
            rows.Push({kind: "updates", sect: "General", key: "CheckUpdates", def: 1, label: "Look for updates"})
        if KitKeys.List().Length
            rows.Push({kind: "head", label: "KEYS"}, {kind: "keys"})
        if Kit.app.HasProp("rows")
            for r in Kit.app.rows.Call()
                rows.Push(r)
        return rows
    }

    ; every part, top to bottom, into the pane's content c; returns its height
    static Fill(c) {
        this.syncs := [], this.savers := []
        c.OnEvent("Escape", (*) => KitSettings.Close())     ; Esc while a box in it has the focus
        c.SetFont("s12 Bold c" Theme.Text, Theme.Font)
        c.Add("Text", KitP(22, 14) "BackgroundTrans +0x80", "Settings")
        c.SetFont("s9 Norm c" Theme.Dim, Theme.Font)
        c.Add("Text", KitP(278, 20, 300) "Right BackgroundTrans +0x80", Trim(Kit.name " " Kit.version))
        c.SetFont("s9 Norm c" Theme.Muted, Theme.Font)
        this.sub := c.Add("Text", KitP(22, 42, 556, 34) "BackgroundTrans +0x80", this.SubText())
        y := KitS(70)
        for r in this.AllRows()
            y := this.AddRow(c, r, y)
        y += KitS(6)
        c.SetFont("s9 Norm c" Theme.Blue, Theme.Font)
        KitUi.Link(c.Add("Text", "x" KitS(22) " y" y " BackgroundTrans +0x80", "Open the settings file")
            , (*) => CfgOpen(Kit.ini))
        return y + KitS(36)
    }

    static SubText() => Kit.app.HasProp("apply")
        ? "Saved as you change them, and used straight away."
        : "Saved as you change them. " Kit.name " reloads when you close this window, to use them."

    static Say(msg, color := "") {
        if !this.sub
            return
        this.sub.SetFont("c" (color != "" ? color : Theme.Muted))
        this.sub.Text := msg
    }

    static AddRow(c, r, y) {
        switch r.kind {
            case "head":    return this.Head(c, r, y)
            case "bool":    return this.Bool(c, r, y)
            case "num":     return this.Num(c, r, y)
            case "list":    return this.List(c, r, y)
            case "pick":    return this.Pick(c, r, y)
            case "text":    return this.Text(c, r, y)
            case "path":    return this.Path(c, r, y)
            case "note":    return KitUi.Para(c, KitS(22), y, KitS(556), r.label, "s9 Norm", Theme.Muted) + KitS(16)
            case "keys":    return KitKeysWin.AddTo(c, y)
            case "updates": return this.Updates(c, r, y)
            case "custom":
                y := r.add.Call(c, y)
                if r.HasProp("sync")
                    this.syncs.Push(r.sync)
                return y
        }
        return y
    }

    ; a control of the window scrolled into view, with the focus
    static Reveal(ctrl) {
        if !this.g
            return
        try {
            ctrl.GetPos(, &cy)                  ; within the pane's content
            this.pane.ScrollBy(cy - this.pane.scroll - KitS(90))
            ctrl.Focus()
        }
    }

    ;----------------------------------------------------------------------------
    ; Reading and writing one row
    ;----------------------------------------------------------------------------
    ; the row's file: its own "ini", for a script that keeps several, or the script's
    static Ini(r) => r.HasProp("ini") ? r.ini : Kit.ini

    static Get(r) {
        if r.HasProp("get")
            return r.get.Call() ? 1 : 0
        def := r.HasProp("def") ? r.def : ""
        if (r.kind = "bool" || r.kind = "updates")
            return CfgBool(this.Ini(r), r.sect, r.key, def ? true : false) ? 1 : 0
        v := CfgStr(this.Ini(r), r.sect, r.key, def)
        return (r.kind = "num" && !IsNumber(v)) ? this.Plain(def) : v
    }

    ; a number as people write it: 1.6, not the 1.6000000000000001 a float prints as
    static Plain(v) => (v is Float) ? Format("{:.10g}", v) : v

    static Put(r, v) {
        if this.loading
            return
        if r.HasProp("put") {
            r.put.Call(v)
            return
        }
        v := this.Plain(v)
        if (String(v) == String(this.Get(r)))
            return
        try IniWrite(v, this.Ini(r), r.sect, r.key)
        catch as e {
            this.Say("Could not write the settings file: " e.Message, Theme.Red)
            return
        }
        if r.HasProp("after")
            r.after.Call(v)
        else
            this.Changed()
    }

    ; one of the script's own settings changed
    static Changed() {
        if !Kit.app.HasProp("apply") {
            this.needReload := true
            return
        }
        if !this.applier
            this.applier := () => KitSettings.Apply()
        SetTimer(this.applier, -100)
    }

    static Apply() {
        try Kit.app.apply.Call()
        catch as e
            Kit.Log("Settings: " e.Message)
    }

    ; which of a row's choices is in force (the first, if none is)
    static Index(r) {
        v := this.Get(r)
        for i, ch in r.choices
            if (ch = v)
                return i
        return 1
    }

    static Names(r) {
        names := []
        for i, ch in r.choices
            names.Push((r.HasProp("names") && i <= r.names.Length) ? r.names[i] : ch)
        return names
    }

    ;----------------------------------------------------------------------------
    ; Drawing the rows. y in real pixels; each returns the y below itself.
    ;----------------------------------------------------------------------------
    static Head(c, r, y) {
        y += KitS(8)
        c.SetFont("s8 Bold c" Theme.Blue, Theme.Font)
        c.Add("Text", "x" KitS(22) " y" y " BackgroundTrans +0x80", r.label)
        c.Add("Text", "x" KitS(22) " y" (y + KitS(20)) " w" KitS(556) " h" Max(1, KitS(1)) " Background" Theme.Track)
        return y + KitS(34)
    }

    static Label(c, y, text, w := 266) {
        c.SetFont("s10 Norm c" Theme.Text, Theme.Font)
        return c.Add("Text", "x" KitS(22) " y" (y + KitS(3)) " w" KitS(w) " BackgroundTrans +0x80", text)
    }

    static Hint(c, x, y, w, r) {
        if !(r.HasProp("hint") && r.hint != "")
            return y
        return KitUi.Para(c, x, y, w, r.hint, "s8 Norm", Theme.Dim)
    }

    static Edit(c, x, y, w, opts := "") {
        c.SetFont("s10 Norm c" Theme.Text, Theme.Font)
        e := c.Add("Edit", "x" x " y" y " w" w " h" KitS(26) " -E0x200 -Wrap r1 " opts " Background" Theme.CardHi)
        SendMessage(0xD3, 3, KitS(6) | (KitS(6) << 16), e)              ; EM_SETMARGINS
        return e
    }

    ; a box shows what is saved, without that counting as a change
    static Settle(e, r) {
        was := this.loading
        this.loading := true
        try e.Value := this.Get(r)
        this.loading := was
    }

    static Bool(c, r, y) {
        sw := KitSwitch(c, KitS(22), y + KitS(1), this.Get(r), (on) => KitSettings.Put(r, on ? 1 : 0))
        c.SetFont("s10 Norm c" Theme.Text, Theme.Font)
        KitUi.Link(c.Add("Text", "x" KitS(72) " y" y " BackgroundTrans +0x80", r.label), (*) => sw.Toggle())
        this.syncs.Push(() => sw.Value := KitSettings.Get(r))
        y := this.Hint(c, KitS(72), y + KitS(24), KitS(506), r)
        return y + KitS(16)
    }

    static Num(c, r, y) {
        this.Label(c, y, r.label)
        e := this.Edit(c, KitS(300), y, KitS(80))
        if (r.HasProp("unit") && r.unit != "") {
            c.SetFont("s9 Norm c" Theme.Muted, Theme.Font)
            c.Add("Text", "x" KitS(388) " y" (y + KitS(4)) " BackgroundTrans +0x80", r.unit)
        }
        st := {dirty: false}
        save := () => (st.dirty ? (st.dirty := false, KitSettings.SaveNum(r, e)) : 0)
        e.OnEvent("Change", (*) => (KitSettings.loading ? 0 : (st.dirty := true, SetTimer(save, -600))))
        e.OnEvent("LoseFocus", (*) => (save(), KitSettings.Settle(e, r)))
        this.savers.Push(save)
        this.syncs.Push(() => e.Value := KitSettings.Get(r))
        y := this.Hint(c, KitS(22), y + KitS(32), KitS(556), r)
        return y + KitS(16)
    }

    static SaveNum(r, e) {
        v := Trim(e.Value)
        if !IsNumber(v)
            return
        n := Number(v)
        if (r.HasProp("min") && n < r.min)
            v := r.min
        else if (r.HasProp("max") && n > r.max)
            v := r.max
        this.Put(r, v)
    }

    static List(c, r, y) {
        this.Label(c, y, r.label)
        c.SetFont("s10 Norm c" Theme.Text, Theme.Font)
        d := c.Add("DropDownList", "x" KitS(300) " y" y " w" KitS(278) " r12", this.Names(r))
        Theme.Skin(d)
        d.OnEvent("Change", (*) => (KitSettings.loading ? 0 : KitSettings.Put(r, r.choices[d.Value])))
        this.syncs.Push(() => d.Value := KitSettings.Index(r))
        y := this.Hint(c, KitS(22), y + KitS(34), KitS(556), r)
        return y + KitS(16)
    }

    static Pick(c, r, y) {
        this.Label(c, y, r.label)
        p := KitPick(c, KitS(300), y, this.Names(r), this.Index(r), (i) => KitSettings.Put(r, r.choices[i]))
        this.syncs.Push(() => p.Value := KitSettings.Index(r))
        y := this.Hint(c, KitS(22), y + KitS(34), KitS(556), r)
        return y + KitS(16)
    }

    static Text(c, r, y) {
        this.Label(c, y - KitS(3), r.label, 556)
        e := this.Edit(c, KitS(22), y + KitS(24), KitS(556))
        if (r.HasProp("cue") && r.cue != "")
            SendMessage(0x1501, 1, StrPtr(r.cue), e)                    ; EM_SETCUEBANNER
        st := {dirty: false}
        save := () => (st.dirty ? (st.dirty := false, KitSettings.Put(r, Trim(e.Value))) : 0)
        e.OnEvent("Change", (*) => (KitSettings.loading ? 0 : (st.dirty := true, SetTimer(save, -600))))
        e.OnEvent("LoseFocus", (*) => save())
        this.savers.Push(save)
        this.syncs.Push(() => e.Value := KitSettings.Get(r))
        y := this.Hint(c, KitS(22), y + KitS(56), KitS(556), r)
        return y + KitS(16)
    }

    ; A folder or a file: the box, and "pick" at the right of the label. The
    ; box saves the way a text row does - once the typing stops - but only a
    ; path that is usable (see SavePath).
    static Path(c, r, y) {
        this.Label(c, y - KitS(3), r.label, 440)
        e := ""                                 ; made below; the link reads it later
        c.SetFont("s9 Norm c" Theme.Blue, Theme.Font)
        KitUi.Link(c.Add("Text", "x" KitS(478) " y" (y - KitS(1)) " w" KitS(100) " Right BackgroundTrans +0x80", "pick")
            , (*) => KitSettings.PathPick(r, e))
        e := this.Edit(c, KitS(22), y + KitS(24), KitS(556))
        if (r.HasProp("cue") && r.cue != "")
            SendMessage(0x1501, 1, StrPtr(r.cue), e)                    ; EM_SETCUEBANNER
        st := {dirty: false}
        save := () => (st.dirty ? (st.dirty := false, KitSettings.SavePath(r, e)) : 0)
        e.OnEvent("Change", (*) => (KitSettings.loading ? 0 : (st.dirty := true, SetTimer(save, -600))))
        e.OnEvent("LoseFocus", (*) => save())
        this.savers.Push(save)
        this.syncs.Push(() => e.Value := KitSettings.Get(r))
        y := this.Hint(c, KitS(22), y + KitS(56), KitS(556), r)
        return y + KitS(16)
    }

    ; true when the path may be saved: anything for a file, and for a folder
    ; an empty box or a folder that is there
    static PathOk(r, v) => !(r.HasProp("pick") && r.pick = "folder" && v != "" && !DirExist(v))

    static SavePath(r, e) {
        v := Trim(e.Value)
        if !this.PathOk(r, v) {
            this.Say("There is no folder " v " yet - pick makes one.", Theme.Amber)
            return
        }
        this.Say(this.SubText())
        this.Put(r, v)
    }

    ; Windows' own folder or file picker, starting where the box points
    static PathPick(r, e) {
        was := Trim(e.Value)
        title := r.HasProp("title") ? r.title : r.label
        this.g.Opt("+OwnDialogs")
        if (r.HasProp("pick") && r.pick = "file")
            got := FileSelect(3, was, title, r.HasProp("filter") ? r.filter : "")
        else
            got := DirSelect((was != "") ? "*" was : "", 3, title)
        if (got = "")                           ; cancelled: leave what was there
            return
        e.Value := got
        this.SavePath(r, e)
    }

    ; "Look for updates": the switch, "check now", and a line for the answer
    static Updates(c, r, y) {
        sw := KitSwitch(c, KitS(22), y + KitS(1), this.Get(r), (on) => KitSettings.Put(r, on ? 1 : 0))
        c.SetFont("s10 Norm c" Theme.Text, Theme.Font)
        KitUi.Link(c.Add("Text", "x" KitS(72) " y" y " BackgroundTrans +0x80", r.label), (*) => sw.Toggle())
        c.SetFont("s9 Norm c" Theme.Blue, Theme.Font)
        KitUi.Link(c.Add("Text", "x" KitS(300) " y" (y + KitS(2)) " BackgroundTrans +0x80", "check now")
            , (*) => KitSettings.CheckNow())
        this.syncs.Push(() => sw.Value := KitSettings.Get(r))
        c.SetFont("s8 Norm c" Theme.Dim, Theme.Font)
        this.updateNote := c.Add("Text", "x" KitS(72) " y" (y + KitS(24)) " w" KitS(506) " h" KitS(30) " BackgroundTrans +0x80"
            , "Once a day it asks GitHub for the newest version and only tells you if there is one.")
        r.after := (v) => 0                     ; read from the .ini each time - nothing to apply
        return y + KitS(24 + 30 + 6)
    }

    ; "check now": the answer goes on the line under it; a new version's line
    ; opens the update window
    static CheckNow() {
        this.updateNote.SetFont("c" Theme.Muted)
        this.updateNote.Text := "asking GitHub" Chr(0x2026)
        KitUpdate.Check(false, ObjBindMethod(KitSettings, "UpdateAnswer"))
    }

    static UpdateAnswer(text, found) {
        if !this.updateNote
            return
        this.updateNote.SetFont("c" (found ? Theme.Green : Theme.Muted))
        this.updateNote.Text := found ? text " Click here to see what is new and update." : text
        if (found && !KitUi.links.Has(this.updateNote.Hwnd))
            KitUi.Link(this.updateNote, (*) => KitUpdate.found && KitInstall.Offer(KitUpdate.found))
    }
}
