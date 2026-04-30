# Andy's Swiss Knife

A single iOS app that replaces eight daily apps: todo list, class schedule, dining menu, pomodoro timer, school events, athletics schedule, Canvas assignments, AP exam countdown.

<p align="center">
  <img src="docs/screenshots/dashboard.png" alt="Dashboard" width="320"/>
</p>

## Features

**To-do list**
- Inline add with one tap — no popup
- Inline title editing on manual todos; read-only view for Canvas imports
- Things3-style drag reorder — long-press to lift, drag up/down
- Optional due date + local notifications; OVERDUE / DUE TODAY / TOMORROW badges
- Completed tasks locked from editing; trash button on manual todos only

**Reminders**
- Separate from todos — for personal events like "pick up suit Sunday"
- Flat list sorted by date; no bucket headers
- Inline title editor directly in the row
- Optional time — toggle "Include time" in the date sheet
- Date + time shown left of content (time shown only when set)
- Add from dashboard: tap the calendar icon on the add row to pre-set a date/time before saving

**Next class**
- Auto-updates through the day — shows the current or next upcoming period
- Switches to tomorrow's schedule automatically when today's last class has ended
- Editable period grid in Settings → Schedule (add, edit, delete individual periods)
- Import schedule via **photo** (Vision OCR, spatial row reconstruction) or text-selectable PDF
- Reset to built-in default at any time

**Canvas assignments**
- Paste your Canvas calendar feed URL in Settings → Canvas (editable; no hardcoded default)
- Assignments appear as todos keyed by VEVENT UID — never duplicates on re-sync
- Dashboard card shows "N today · M tmrw" and total open count
- Dedicated Canvas screen grouped by due date

**Dining menu**
- Fetches Suffield dining site; caches 3 h
- Card rolls Lunch → Dinner after 1 pm; rolls to **tomorrow's** menu after 7 pm
- Header shows day-of-week, date, and current meal label (LUNCH / DINNER)

**Athletics schedule**
- 49 Suffield teams; picker grouped by Fall / Winter / Spring season
- Toggle **multiple teams** simultaneously — all games merge into one feed
- Home / Away badge on each game row
- Per-team event count shown in empty state

**School events**
- Reads school public ICS feed (URL editable in Settings)
- Continuous scroll grouped by day

**AP Exams**
- 37 AP exams from the 2026 exam calendar, hardcoded
- Settings → AP Exams: checkbox picker grouped by date
- Dashboard card shows selected exams with a large day-countdown number on the left

**Countdown**
- Pick any school calendar event as your countdown target (Settings → Countdown)
- Inline name editor directly on the dashboard card — tap to rename
- Large day number displayed prominently; big-number style matches AP Exams card

**Weather**
- Live high / low in °C via Open-Meteo (no API key required)
- Displayed in the dashboard header with a matching SF Symbol icon

**Apple Calendar import**
- Toggle any Apple Calendar on/off to merge events into the Events tab
- Live EventKit sync on app foreground

**Pomodoro**
- 25 min focus / 5 min break
- Live Activity on Lock Screen + Dynamic Island (counts down live)
- Wall-clock backed — survives background / app kill

**Dashboard customization**
- Long-press any card to lift it; drag to rearrange — springboard-style spring animation
- Active / inactive card lists in Settings → Layout; hide any card and reactivate later

**Widgets**
- Interactive To-do widget (check off tasks from Home Screen via AppIntent)
- Reminders widget
- Lunch / Dinner menu widget
- Next class widget

**Themes**
- Stark White (default) — pure white + black + red accent
- Cream — warm paper background with Claude-purple accent
- Ink — dark mode with yellow accent
- Acid — black + neon green + magenta
- Hazard — yellow warning tape
- Toxic — dark purple + hot magenta + acid green
- All monospaced, sharp corners, thick borders

**Deep links**
- `swissknife://addTodo` and `swissknife://addReminder` open the add panel
- Triggerable from Siri Shortcuts / widgets

**Personal**
- Greets you by name with a time-of-day greeting
- Displays version + build in Settings
- Force-refresh all feeds from one button
