;================================================================================
; The note box - opens flush against the row it belongs to, so it reads as part
; of that task rather than as a dialog that appeared somewhere.
;================================================================================
BuildNote() {
    global
    Gui, Note:New, +AlwaysOnTop -Caption +ToolWindow +HwndNoteHwnd
    ShapeWindow(NoteHwnd, PanelRound)    ; the same corners as the panel
    Gui, Note:Margin, 12, 10
    Gui, Note:Color, %CBg%, %CCard%
    Gui, Note:Font, s8 Norm, Segoe UI
    Gui, Note:Add, Text, vNoteHdr w300 c%CAmber% +0x4000,   ; "..." when a long name will not fit
    Gui, Note:Font, s10, Segoe UI
    ; wraps and grows as you write - see BoxFit() in Capture.ahk
    Gui, Note:Add, Edit, vNoteEdit gNoteGrow w300 h26 c%CText% -E0x200 +Multi -VScroll +0x40
    Gui, Note:Font, s8, Segoe UI
    Gui, Note:Add, Text, vNoteHint w300 c%CDim%, % "Enter save  " Chr(0x00B7) " Esc skip"
    BoxRemember("Note")
}

ShowNote(header, rowY := 0, prefill := "", hint := "") {
    global
    GuiControl, Note:, NoteEdit, %prefill%
    GuiControl, Note:, NoteHdr, %header%
    GuiControl, Note:, NoteHint, % (hint != "") ? hint : "Enter save  " Chr(0x00B7) " Esc skip"
    LivePanel(px, py, pw, ph)
    w := (pw > NoteW) ? pw : NoteW
    GuiControl, Note:Move, NoteEdit, % "w" (w - 24)
    GuiControl, Note:Move, NoteHdr,  % "w" (w - 24)
    GuiControl, Note:Move, NoteHint, % "w" (w - 24)
    x := px - w - 8                       ; beside the panel, on whichever side
    if (x < 10)                           ; has room
        x := px + pw + 8
    y := py + (rowY ? rowY - 8 : 40)      ; level with the row it belongs to
    ClampWin(x, y, w, 96)
    BoxReset("Note")
    SideOnTop("Note")
    Gui, Note:Show, x%x% y%y% AutoSize, Daybook note
    GuiControl, Note:Focus, NoteEdit
    if (prefill != "") {                  ; caret at the end, to add to it
        GuiControlGet, hEd, Note:Hwnd, NoteEdit
        SendMessage, 0xB1, -1, -1, , ahk_id %hEd%   ; EM_SETSEL
    }
    BoxFit("Note")                        ; a long note opens tall enough
}

; Right after a tick or a cross. If the task already has a note today it is
; there to add to - saving replaces it, it never piles a second one on.
OpenNote(i, mode, rowY := 0) {
    global NoteFor, CurDay
    t := Tasks[i]
    NoteFor := {id: t.id, day: CurDay}
    ShowNote((mode = "failed") ? "what blocked it?  (optional)"
                               : "anything worth remembering?  (optional)"
           , rowY, TaskNote(t, CurDay))
}

; Right-click -> Edit note. The same box, with the note in it; clear it and
; press Enter and the note is gone.
EditNote(i) {
    global NoteFor, CurDay, RowTask, RowY
    t := Tasks[i]
    if (!t)
        return
    NoteFor := {id: t.id, day: CurDay}
    rowY := 0
    for n, ti in RowTask
        if (ti = i)
            rowY := RowY[n]
    ShowNote("note on: " t.text, rowY, TaskNote(t, CurDay))
}

#IfWinActive Daybook note ahk_class AutoHotkeyGUI
Enter::SaveNote()
NumpadEnter::SaveNote()
Escape::SkipNote()
#IfWinActive

; The note goes onto the task, for the day it is about - see TaskSetNote(). An
; answer about a MISSED task is about the day it was left undone, so it goes
; onto THAT day, and that day's note in Obsidian is rewritten to carry it.
SaveNote() {
    global NoteFor
    GuiControlGet, txt, Note:, NoteEdit
    Gui, Note:Hide
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
    Gui, Note:Hide
}

