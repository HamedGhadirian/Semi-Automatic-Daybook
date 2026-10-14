# Changelog

Notable changes, newest first. The version is in `lib\Config.ahk`
(`DaybookVersion`).

## 1.1.0

- **A journal window** - JOURNAL on the panel (or the tray) opens your part of the day's note; any day, saved as you type.
- **One copy only** - the window reads and writes the note itself, so what you write in Obsidian is what it shows.
- **Tasks start open** - Shift+Enter "already did it" is gone; what happened goes in the journal.

<details>
<summary>Everything that changed</summary>

- New notes open with `## journal`; older ones with `## my notes` are still read.
- Enter carries a `- ` / `1. ` / `- [ ] ` list on; Enter on an empty item ends it.
- Changed in two places at once, the window asks which one stays and keeps the other in `backups\journal-conflicts`.
- Today's word count beside the JOURNAL heading.
- With the journal off, JOURNAL leaves the panel and its tray items are greyed out.

</details>

## 1.0.1

- **No tips through other windows** - a panel under another app no longer lights up, shows its tooltip or takes the mouse wheel.
- **A taskbar button of its own** - no longer grouped with other AutoHotkey scripts' windows.
- **Tips stay in front of the panel** while it is on top.

<details>
<summary>Everything that changed</summary>

- The settings and habit windows share the panel's taskbar button.
- Scrolling over a window that covers the panel scrolls that window, not the panel.

</details>

## 1.0.0

- **Out of beta.**
- **A taskbar button and Alt+Tab** - the panel is an ordinary window; Settings > On the taskbar switches back to the overlay.
- **Never pops up by itself** - timers and updates don't raise, restore or focus it.

<details>
<summary>Everything that changed</summary>

- A minimised panel stays minimised; Win+F6 or its taskbar button brings it back.
- A hidden panel no longer comes back on its own when the day rolls over.
- Two settings hints no longer cut off.

</details>

## 0.9.0-beta.3

- **Missed tasks** - unfinished tasks wait in their own section: did it (on which day), drop, or back to today.
- **One question, not a queue** - bringing a task back asks why once, however long it waited.
- **Weekly habits show red** from the day a week can no longer be made.

<details>
<summary>Everything that changed</summary>

- Tasks already carried over move to Missed the first time this version starts.
- A "why?" answer goes on the day the task was meant for.
- Dropping a missed task asks first, and Esc keeps it.
- The ×N count sits in front of the name and counts days left undone.
- The + is amber only when today's list is empty; the old "why not?" review is gone.
- Daybook.md shows the missed list, and its habit grid no longer marks days off or rest days with a cross.

</details>

## 0.9.0-beta.2

- **Day notes are a summary** - your writing on top, Daybook's block of the day below.
- **Notes on tasks** - right-click to add or edit, hover to read.
- **Habit rules** - every day, every N days or N times a week, with rest days.
- **Edit habit** - a calendar for any day, and bring in a streak you already had.
- **Safer data** - checked saves and a backup a day.

<details>
<summary>Everything that changed</summary>

- Daybook only rewrites its own block in a day note; what you write is never touched.
- A late "why not?" answer lands on the day it is about.
- Daybook.md shows where things stand and replaces Habits.md (safe to delete).
- The click log moved out of the vault, to `log\` beside Daybook.
- Finished long-term tasks leave the panel at the end of the day; the note keeps them.
- Long names end in "..." and show in full on hover.
- The note and task boxes wrap and grow instead of scrolling sideways.
- Streaks are worked out from the whole history, so late ticks and old streaks come out right.
- Weekly habits count weeks (112w), or days if you switch them.
- The dots say which day they are and what a click does.
- Ticking an earlier day fixes that day's note too.
- A damaged state file is set aside and the newest good backup loaded.
- Fixed: time at the machine froze while collapsed; the hour strip put 01:00 first;
  case-only renames were ignored; tick-then-cross logged both.

</details>

## 0.9.0-beta.1

First release. Beta because it has only ever run on one machine: everything
here works and is tested, but nothing has met a second screen size, a second
Windows, or anyone else's habits yet.

- **Habits.** A tick box, a week of dots and a streak. Every dot is a button,
  so an evening you forgot can still be ticked, and streaks are worked out from
  the calendar rather than counted up - they survive a reboot or a week away.
- **Tasks**, for today and for the long term. Unfinished ones carry over and
  ask; ticking or dropping one opens a small box to say why.
- **A sit timer** that only counts time you were actually at the desk, and an
  app log by process name.
- **The journal.** One markdown file a day, append-only, closing with a
  `## habits` block of real Dataview checkboxes. It can be switched off
  entirely, and then nothing is written and nothing already there is touched.
- **A settings window** (tray -> Settings) for everything in `Daybook.ini`,
  saved as you change it and in force at once.
- **The panel scrolls** once it outgrows the screen, with the timer pinned to
  the top, and the lock and on-top switches pinned to the bottom.
- **Administrator is off by default**, so a first run opens with no UAC prompt.
- **Two downloads, built on GitHub from the tag** - portable with AutoHotkey in
  the folder, or the app on its own - neither published unless the tests pass.
