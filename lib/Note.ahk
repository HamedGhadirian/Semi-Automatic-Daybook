;================================================================================
; The note box - opens flush against the row it belongs to, so it reads as part
; of that task rather than as a dialog that appeared somewhere.
;================================================================================
#Requires AutoHotkey v2.0

BuildNote() {
    global NoteGui, NoteHwnd
    g := Gui("+AlwaysOnTop -Caption +ToolWindow", "Daybook note")
    NoteGui := g, NoteHwnd := g.Hwnd
    ShapeWindow(NoteHwnd)    ; round, like the panel
    g.MarginX := 12, g.MarginY := 10
    g.BackColor := CBg
    g.SetFont("s8 Norm c" CAmber, "Segoe UI")
    g.Add("Text", "vNoteHdr w300 +0x4000")   ; "..." when a long name will not fit
    g.SetFont("s10 c" CText, "Segoe UI")
    ; wraps and grows as you write - see BoxFit() in Capture.ahk
    e := g.Add("Edit", "vNoteEdit w300 h26 -E0x200 +Multi -VScroll +0x40 Background" CCard)
    e.OnEvent("Change", (*) => BoxFit("Note"))
    g.SetFont("s8 c" CDim, "Segoe UI")
    g.Add("Text", "vNoteHint w300", "Enter save  " Chr(0x00B7) " Esc skip")
    BoxRemember("Note")
}

ShowNote(header, rowY := 0, prefill := "", hint := "") {
    global NoteAsked := header           ; what it asked - the tests read it
    if !IsObject(NoteGui)                ; the tests: no box to show
        return
    g := NoteGui
    g["NoteEdit"].Value := prefill
    g["NoteHdr"].Text := header
    g["NoteHint"].Text := (hint != "") ? hint : "Enter save  " Chr(0x00B7) " Esc skip"
    LivePanel(&px, &py, &pw, &ph)
    w := (pw > NoteW) ? pw : NoteW
    for name in ["NoteEdit", "NoteHdr", "NoteHint"]
        g[name].Move(, , w - 24)
    x := px - w - 8                       ; beside the panel, on whichever side
    if (x < 10)                           ; has room
        x := px + pw + 8
    y := py + (rowY ? rowY - 8 : 40)      ; level with the row it belongs to
    ClampWin(&x, &y, w, 96)
    BoxReset("Note")
    SideOnTop(g)
    g.Show("x" x " y" y " AutoSize")
    g["NoteEdit"].Focus()
    if (prefill != "")                    ; caret at the end, to add to it
        SendMessage(0xB1, -1, -1, g["NoteEdit"])   ; EM_SETSEL
    BoxFit("Note")                        ; a long note opens tall enough
}

; Right after a tick or a cross. If the task already has a note today it is
; there to add to - saving replaces it, it never piles a second one on.
OpenNote(i, mode, rowY := 0) {
    global NoteFor
    t := TaskAt(i)
    if (!t)
        return
    NoteFor := {id: t.id, day: CurDay, drop: false}
    ShowNote((mode = "failed") ? "what blocked it?  (optional)"
                               : "anything worth remembering?  (optional)"
           , rowY, TaskNote(t, CurDay))
}

; Right-click -> Edit note. The same box, with the note in it; clear it and
; press Enter and the note is gone.
EditNote(i) {
    global NoteFor
    t := TaskAt(i)
    if (!t)
        return
    NoteFor := {id: t.id, day: CurDay, drop: false}
    ShowNote("note on: " t.text, RowYOf(i), TaskNote(t, CurDay))
}

#HotIf WinActive("Daybook note ahk_class AutoHotkeyGUI")
Enter::SaveNote()
NumpadEnter::SaveNote()
Escape::SkipNote()
#HotIf

; The note goes onto the task, for the day it is about - see TaskSetNote(). An
; answer about a MISSED task is about the day it was left undone, so it goes
; onto THAT day, and that day's note in Obsidian is rewritten to carry it.
SaveNote() {
    global NoteFor
    txt := NoteGui["NoteEdit"].Value
    NoteGui.Hide()
    txt := Trim(RegExReplace(txt, "[\r\n\t]+", " "))
    f := NoteFor, NoteFor := ""
    if (!IsObject(f))
        return
    if (f.drop) {                         ; Enter is what drops it - see MissDropAsk
        MissDropNow(f.id, f.day, txt)
        return
    }
    if (txt != "") {
        CommitMark()          ; you typed something, so you meant the mark
        JournalNote(txt)
    }
    TaskSetNote(f.id, f.day, txt)         ; empty takes a note away
}

; Esc. For a drop that means keep it: nothing happens at all.
SkipNote() {
    global NoteFor
    NoteFor := ""
    NoteGui.Hide()
}
