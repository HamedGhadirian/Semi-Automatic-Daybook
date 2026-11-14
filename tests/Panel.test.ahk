; Panel.test.ahk - the panel and its windows, built for real, far off the screen
;
; What a click would do, done by calling what the click calls: the tick box,
; the cross, the headings, the mode and lock switches, the capture box's Enter,
; the habit window's calendar, the deadline calendar. Then what the panel shows
; is read back from its controls. Nothing takes the focus: no window here is
; ever activated, and the boxes that would take it are only built.
#Requires AutoHotkey v2.0
#Include %A_LineFile%\..\Harness.ahk

FakeToday := "2026-11-11"                    ; a Wednesday
today := LogicalDay(), CurDay := today
DaybookColours()
PanelX := -9000, PanelY := -9000, PanelMaxH := 900
BuildPanel()
BuildCapture()
BuildNote()
g := PanelGui
Shown(name) => DllCall("IsWindowVisible", "ptr", PanelGui[name].Hwnd)

; ---- empty -------------------------------------------------------------------
Refresh()
Ok("empty: the + is amber - the list is empty", g["AddBtn"].Text "|" NToday, "+|0")
Ok("empty: no MISSED heading",       Shown("MissHdr"), 0)
Ok("empty: TODAY'S TASKS heading",   g["TodayHdr"].Text, Chr(0x25BE) " TODAY'S TASKS")
Ok("empty: no cards",                Cards.Length, 0)
; the keys are switched on after the panel is built; the tray menu, made
; then, puts them on the footer (here: the keys as if switched on)
KitKeys.now["Panel"] := "#F6", KitKeys.now["Break"] := "#F1"
DaybookTray(Menu())
Ok("the keys on the footer",         g["FootTxt"].Text, "Win+F6 panel   " Chr(0x00B7) "   Win+F1 break")

; ---- tasks -------------------------------------------------------------------
AddTask("buy milk")
AddTask("call mom")
AddTask("a very long task name that will never fit on a panel three hundred pixels wide")
AddTask("learn to draw", "L")
AddTask("book the dentist", "S", "open", DayShift(today, 1))
Ok("tasks: today's count",           g["TodayCnt"].Text, 3)
Ok("tasks: a card each (long term closed)", Cards.Length, 4)
Ok("tasks: the first row",           g["RowTxt1"].Text, "buy milk")
Ok("tasks: the short term row wears its deadline", g["RowTxt4"].Text, "1d  book the dentist")
Ok("tasks: due tomorrow is amber",   RowColour(4), CAmber)

; the tick box, as clicked
RowAction(1, "done")
Ok("tick: done",                     Tasks[1].status, "done")
Ok("tick: the box shows it",         g["RowChk1"].Text, Chr(0x2713))
Ok("tick: the note box asks",        NoteAsked, "anything worth remembering?  (optional)")
Ok("tick: pending, not written yet", PendMarkKind PendMarkTask, "T1")
; Enter on the note box
NoteGui["NoteEdit"].Value := "the oat one"
NoteFor := {id: Tasks[1].id, day: today, drop: false}
SaveNote()
Ok("note: on the task",              TaskNote(Tasks[1], today), "the oat one")
Ok("note: the mark is written now",  PendMarkTask, 0)
; the same box again takes it back
RowAction(1, "done")
Ok("tick again: open again",         Tasks[1].status, "open")
; Drop, from the right-click menu: the one box shows the cross
TaskMark(2, "failed", 0)
Ok("drop: failed",                   Tasks[2].status, "failed")
Ok("drop: the box shows the cross, red", g["RowChk2"].Text "|" RowColour(2, "RowChk"), Chr(0x2715) "|" CRed)
Ok("drop: the note box asks why",    NoteAsked, "what blocked it?  (optional)")
Ok("drop: the name has the room the X had", RowLeft(2), CardL + 30)
; the box of a dropped task takes the drop back - it never ticks it
RowAction(2, "done")
Ok("drop: the box undoes it",        Tasks[2].status, "open")
TaskMark(2, "failed", 0)
; a click on a row whose task is gone does nothing
RowAction(30, "done")
Ok("a pool row with no task: nothing", Tasks.Length, 5)

; the capture box's Enter, Ctrl+Enter, and a rename
CapMode := "add", CapList := "T"
CapGui["CapEdit"].Value := "post the letter"
CommitAdd("", "open")
Ok("capture: Enter adds to today",   Tasks[Tasks.Length].text "|" Tasks[Tasks.Length].list, "post the letter|T")
CapMode := "add", CapList := "T"
CapGui["CapEdit"].Value := "someday"
CommitAdd("L", "open")
Ok("capture: Ctrl+Enter, long term", Tasks[Tasks.Length].list, "L")
StartRename(1)
CapGui["CapEdit"].Value := "buy oat milk"
CapGui.Hide()
CommitAdd("", "open")
Ok("capture: rename",                Tasks[1].text, "buy oat milk")

; ---- headings open and close -------------------------------------------------
n := Cards.Length
ToggleOpen("OpenToday")
Ok("heading: today closed",          Cards.Length < n ? 1 : 0, 1)
Ok("heading: its caret",             SubStr(g["TodayHdr"].Text, 1, 1), Chr(0x25B8))
ToggleOpen("OpenToday")
ToggleOpen("OpenLong")
Ok("heading: long term open",        Cards.Length, n + 2)
ToggleOpen("OpenLong")

; ---- habits ------------------------------------------------------------------
HabitAdd("read")
HabitAdd("exercise")
Habits[1].born := DayShift(today, -10), Habits[2].born := DayShift(today, -10)
HabitCompute(Habits[1]), HabitCompute(Habits[2])
Refresh()
Ok("habits: count",                  g["HabCnt"].Text, "0/2")
Ok("habits: a row each",             g["HabTxt1"].Text "|" g["HabTxt2"].Text, "read|exercise")
Ok("habits: seven dots a row",       Dots.Length, 14)
HabChkClick(1)
Ok("habit tick: done today",         HabitDidToday(Habits[1]) ? 1 : 0, 1)
Ok("habit tick: the count",          g["HabCnt"].Text, "1/2")
Ok("habit tick: its box",            g["HabChk1"].Text, Chr(0x2713))
; a dot, clicked: the one before today on the first row
d := ""
for x in Dots
    if (x.hab = 1 && x.day = DayShift(today, -1))
        d := x
OnPanelClick(0, (d.y + 2) << 16 | (d.x + 2), 0x201, PanelHwnd)
Ok("dot click: yesterday done",      HabitDid(Habits[1], DayShift(today, -1)) ? 1 : 0, 1)
Ok("dot hint",                       InStr(DotHint(1, DayShift(today, -1)), "done. Click to freeze it instead.") ? 1 : 0, 1)

; ---- the switches -----------------------------------------------------------
SetPanelMode(0)
Ok("mode: solid",                    g["ModeBtn"].Text "|" g["ModeTxt"].Text, "solid|" Chr(0x2B24))
CycleMode()
Ok("mode: dim",                      g["ModeBtn"].Text, "dim")
ToggleLock()
Ok("lock: locked",                   g["LockBtn"].Text, "locked")
ToggleLock()
ToggleOnTop()
Ok("on top off: no circle, pin dim",  (PanelBtns.onTop ? 1 : 0) "|" g["ModeTxt"].Text, "0|")
ToggleOnTop()
StartBreak()
Ok("break: the status",              g["StatusTxt"].Text "|" g["BreakBtn"].Text, "ON A BREAK|back")
EndBreak()
Ok("break: over",                    g["BreakBtn"].Text, "break")

; ---- shown, hidden, and back -------------------------------------------------
CyclePanel()                                  ; dim -> ghost
Ok("panel key: ghost",               PanelMode, 2)
CyclePanel()                                  ; ghost -> hidden
Ok("panel key: hidden",              PanelVisible "|" DllCall("IsWindowVisible", "ptr", PanelHwnd), "0|0")
CyclePanel()                                  ; hidden -> solid
Ok("panel key: back, solid",         PanelVisible "|" PanelMode, "1|0")

; ---- the overlay kind and back -----------------------------------------------
PanelTaskbar := false
ApplyWindowKind()
Ok("overlay: a tool window",         (WinGetExStyle(PanelHwnd) & 0x80) ? 1 : 0, 1)
PanelTaskbar := true
ApplyWindowKind()
Ok("taskbar window again",           (WinGetExStyle(PanelHwnd) & 0x80) ? 1 : 0, 0)

; ---- more than fits: it scrolls ----------------------------------------------
PanelMaxH := 300
loop 8
    AddTask("filler " A_Index)
Ok("scroll: there is more than fits", PanelScrollMax > 0 ? 1 : 0, 1)
before := Cards[1].y
PanelScroll(1)
Ok("scroll: down a notch",           Cards[1].y < before || PanelScrollY > 0 ? 1 : 0, 1)
Ok("scroll: the header stays",       Shown("StatusTxt"), 1)
Ok("scroll: nothing under the header", Cards[1].y >= PanelHdrH ? 1 : 0, 1)
PanelScroll(-1)
PanelMaxH := 900
Refresh()

; ---- the habit window ---------------------------------------------------------
HabEdBuild()
HabEdName := "exercise", HabEdMonth := SubStr(today, 1, 7)
HabEdLoad()
Ok("habit window: its name",         HabEdGui["HabEdNameBox"].Value, "exercise")
Ok("habit window: every day lit",    HabEdGui["HabEdDot1"].Text, Chr(0x25CF))
k := 0
for i, day in HabEdCells
    if (day = DayShift(today, -2))
        k := i
HabEdDayClick(k)
Ok("habit window: a day clicked is done", HabitDid(Habits[2], DayShift(today, -2)) ? 1 : 0, 1)
HabEdDayClick(k)
Ok("habit window: again, a rest day", HabitRested(Habits[2], DayShift(today, -2)) ? 1 : 0, 1)
HabEdGui["HabEdN3"].Value := 3
HabEdPick(3)
Ok("habit window: 3 times a week",   Habits[2].kind Habits[2].n, "W3")
Ok("habit window: the week column",  HabEdGui["HabEdWkHead"].Visible, 1)
HabEdMove(-1)
Ok("habit window: not before it began", HabEdMonth, SubStr(today, 1, 7))
HabEdGui["HabEdNameBox"].Value := "exercise daily"
HabEdApplyName()
Ok("habit window: renamed",          Habits[2].text "|" HabEdName, "exercise daily|exercise daily")
HabEdGui["HabEdImp"].Value := 30
HabEdBringIn()
Ok("habit window: a streak brought in", Habits[2].total >= 30 ? 1 : 0, 1)
HabEdMove(-1)
Ok("habit window: now it goes a month back", HabEdMonth, CalMonthShift(SubStr(today, 1, 7), -1))

; ---- the deadline calendar ----------------------------------------------------
DueBuild()
DueMode := "move", DueId := Tasks[1].id, DueMonth := SubStr(today, 1, 7), DueWas := ""
DuePaint()
k := 0
for i, day in DueCells
    if (day = DayShift(today, 3))
        k := i
DueDayClick(k)
Ok("deadline: picked",               Tasks[TaskIndex(DueId)].list "|" Tasks[TaskIndex(DueId)].due, "S|" DayShift(today, 3))
DueMove(-1)
Ok("deadline: no month before this", DueMonth, SubStr(today, 1, 7))
past := 0
for i, day in DueCells
    if (day != "" && StrCompare(day, today) < 0)
        past++
Ok("deadline: a day gone is no button", past, 0)

; ---- the right-click menus are made (not shown) -------------------------------
Ok("a card under no pointer",        CardUnderCursor(), 0)

PanelGui.Destroy()
Done()

; the colour a row's text was last given (PSay keeps it)
RowColour(n, pre := "RowTxt") => PanelColours[pre n]
; where a row's name starts
RowLeft(n) {
    PanelGui["RowTxt" n].GetPos(&x)
    return x
}
