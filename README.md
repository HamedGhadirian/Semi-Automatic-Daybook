# Semi-Automatic Daybook

A day panel for Windows. Habits, tasks, and a sit timer that
only counts time you were actually there - all of it written out as plain
markdown, one file per day.

Semi-automatic: it keeps the half of a journal that is counting, and leaves the
half that is thinking to you.

AutoHotkey v1 · Windows only · **no internet, no account** - everything stays
in two folders on your PC

![The panel: habits with their streaks, missed tasks, today's and long term tasks, and where the day went](https://raw.githubusercontent.com/HamedPhixer/Semi-Automatic-Daybook/main/docs/images/panel.png)

## What it does

**Habits.** A tick box, a week of dots and a streak. Green done, red missed,
blue a rest day. **Every dot is a button** - click Tuesday's and Tuesday is
ticked, for the evening you did the thing and forgot to say so. Every day,
every few days, or so many times a week; rest days for when you are sick or
away - click a dot again and a done day turns blue, frozen; once more and it
is empty. Right-click a habit for its calendar, where you can also bring in a
streak you kept somewhere else.

![A habit's calendar: three times a week, every week kept, with the streak in weeks](https://raw.githubusercontent.com/HamedPhixer/Semi-Automatic-Daybook/main/docs/images/calendar.png)

**Tasks.** One list for today, one for the short term (pick a deadline on a
small calendar, or none), one for later. Tick or cross one and a small box opens to say why. Anything unfinished waits under MISSED: say which day you did
it, drop it, or put it back on today.

**A sit timer.** Green, amber at 30 minutes, red and breathing at 45. It only
counts time you were there: it watches Windows' own display state, so a film
counts and an empty chair does not.

**An app log.** Which program was in front, by process name, and only while you
were at the desk.

<details>
<summary><b>When does the sit clock reset?</b></summary>

It only counts while you are there. A dark screen, a lock screen or a
screensaver means gone, and so does five minutes without touching anything.
Sound playing counts as sitting - you are watching something - for up to two
hours after your last keypress, so a player left running overnight does not
hold the clock open.

**Five minutes away resets it to zero.** Less than five and it carries on from
where it was, so a coffee or a lock screen never wipes the time you built up,
and a red bar stays red until you actually take the whole five. Come back early
from a break you started while already red and the digits say `break cut
short`.

`Win + F1` declares a break by hand, and that outranks every sensor above - for
when no signal can tell sitting from standing. It ends when you type or click,
but not on mouse movement, so nudging the mouse to keep the screen awake does
not end it.

Amber at 30 minutes and red at 45, five minutes for a break: all settings.

</details>

## The journal

Plain markdown files, one `YYYY-MM-DD.md` per day, in `Documents\Daybook journal`
unless you pick another folder. Give a day a title and it goes after the date -
`2026-10-14 world cup.md`; Daybook only looks at the date, so rename freely.
Notepad opens them; **Obsidian is optional** -
point the folder at your vault and they show up there.

The top of each note is your journal; Daybook keeps a summary of the day at
the bottom, and rewrites only that part:

```
## journal

A long day. The bike can wait.

%% daybook: written by Daybook ... %%
### tasks
- ✓ buy milk  — got the oat one
- ✗ fix the bike  — shop was closed
### habits
- ✓ painting  · 3 in a row
### time at the machine
active 6h 12m
%% /daybook %%
```

**JOURNAL** on the panel opens that top part in a window - any day, saved as
you type, a `- ` list carried on by Enter. It keeps no copy of its own: the
note is the only place the words live, so Obsidian and the window are two ways
into the same text. If both change it at once, it asks which one stays and
keeps the other in `backups\journal-conflicts`.

Right-click a task to give it a note - a line on why it was done, dropped or
missed; it lands beside the task. Tick a habit for yesterday and yesterday's
note is corrected.

**`Daybook.md`** beside them is where things stand: your lists, the streaks,
two weeks of habits. Change things on the panel; Obsidian follows.

**Weeks and months** (Settings → on; off until you turn it on). Each week that
ends gets `2026-W42.md`; each month that ends is packed into
`2026\2026-10 October\` with a note of its own; `2026\2026 year.md` has a
line a month. Numbers only - the days you wrote (linked, never copied), the
time at the machine, the tasks, a habit grid - with a few questions on top for
you. Files are moved, never deleted; tray → **Write the summaries again**
rebuilds them.

Don't want any of it? Settings → **Keep a journal** → no. JOURNAL leaves the
panel, and the panel, timer and streaks carry on.

## Keys

| | |
| --- | --- |
| `Win + F6` | hidden → solid → dim → ghost → hidden |
| `Win + F1` | start or end a break |

Everything else is a click on the panel.

## Install

From [Releases](https://github.com/HamedPhixer/Semi-Automatic-Daybook/releases),
either one:

- **`-portable.zip`** - unzip it, run `Start Daybook.bat`. AutoHotkey is in the
  folder; nothing is installed and nothing is left behind.
- **the plain zip** - run `Daybook.ahk`, if you already have
  [AutoHotkey v1.1](https://www.autohotkey.com/download/) (not v2).

It makes its own `Daybook.ini` next to itself, with every setting commented.
Tray icon → **Settings** is the same thing in a window.

![Settings: every setting in one window, each with a line saying what it does](https://raw.githubusercontent.com/HamedPhixer/Semi-Automatic-Daybook/main/docs/images/settings.png)

<details>
<summary><b>Does it spy on me?</b></summary>

No, and here is how to check.

It installs a keyboard hook - and **records nothing from it**. The hook is only
there so Windows keeps its "how long since any input" counters up to date,
which is how the timer knows you are present. No key is read or stored; see
`lib/Presence.ahk`.

**No network, ever.** No update check, no telemetry, no account. Grep for
`WinHttp` or `UrlDownload` and you will find nothing. The one COM object it
creates is Windows' own audio meter, asked whether a sound is playing.

**It writes in two places:** its own folder, and the journal folder you pick.
Everything it knows is in one file there, `Daybook-state.txt`, with a backup a
day in `backups\`.

**Process names, not window titles** - titles carry document names and page
titles, and that folder may be syncing to your phone.

Administrator is off by default. Turning it on (`[General] RunAsAdmin`) buys
one thing: the two keys keep working over windows that are themselves elevated.

</details>

<details>
<summary><b>Not yet</b></summary>

- Weeks, months and years: rolling the daily notes up into a weekly file, then
  monthly, then yearly, with the days moved to an archive.

</details>

## The code

`Daybook.ahk` only starts things; everything else is in `lib/`, listed in
[`lib/All.ahk`](lib/All.ahk). Tests: `tests/run-tests.ps1`. Both zips are built
on GitHub from the tag, by `build.ps1`, after those tests pass.

MIT - see [LICENSE](LICENSE).
