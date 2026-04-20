# Andy's Swiss Knife

A single-user iOS app that consolidates one student's daily-life tools into one dashboard: a todo list (the hero feature), today's next class, today's dining menu, a pomodoro timer, and upcoming school events. Canvas assignments are imported into the todo list so everything due today lives in one place.

Personal project — not meant for other users.

---

## Status

**Design phase complete.** Ready for implementation plan.

## Goals

- Replace five separate daily touchpoints (Reminders app, paper schedule, dining website, a pomodoro app, school calendar) with one dashboard.
- Ship to personal TestFlight in a weekend or two.
- Zero infrastructure to maintain.

## Non-goals

- Multi-user, auth, cloud sync, account recovery.
- Publishable-quality generic app — the data sources, schedule, and styling are hardcoded to one user and one school.
- Customizable pomodoro durations, class reminder notifications, widgets, Live Activities, Siri Shortcuts, editable settings beyond view-only status.
- Editable class schedule UI — changes happen in Xcode by editing `Schedule.swift`.

## Stack & targets

- Swift 6, SwiftUI
- Minimum iOS 17 (required for SwiftData)
- iPhone only, portrait only
- Distribution: personal TestFlight build via Xcode

## Visual style

Minimal / Bauhaus. White background, black text, hairline dividers, SF system font, one accent red used only for overdue / DUE TODAY flags. Light mode only — dark mode is out of scope. No emoji, no gradients, no rounded shadows. Equal-weight cards with thin borders rather than colored chips.

## Repository layout

```
AndySwissKnife/
├── AndySwissKnife.xcodeproj
├── Schedule.swift              # user-edited per semester
├── Config/
│   ├── Secrets.xcconfig        # gitignored
│   └── Secrets.xcconfig.example
├── Sources/
│   ├── Models/                 # SwiftData @Models + value types
│   ├── Services/               # Dining, Events, AssignmentsSync, Notifications, Pomodoro
│   ├── Views/
│   │   ├── Dashboard/
│   │   ├── Todos/
│   │   ├── Classes/
│   │   ├── Pomodoro/
│   │   ├── Events/
│   │   ├── Meal/
│   │   └── Settings/
│   └── Styles/                 # typography, colors, modifiers
└── Tests/
    └── ServiceTests/           # fixtures for HTML + ICS parsing
```

One Swift package target. No sub-packages.

## Data model

### SwiftData @Model types

```swift
@Model
final class PersonalEvent {
    var id: UUID
    var title: String
    var date: Date
    var notes: String?
    var notificationID: String?
    var isAllDay: Bool
    var createdAt: Date
}

@Model
final class Todo {
    var id: UUID
    var title: String
    var isDone: Bool
    var dueDate: Date?
    var createdAt: Date
    var notificationID: String?   // set when a local notification is scheduled
    var source: TodoSource        // .manual or .canvas
    var externalID: String?       // Canvas VEVENT UID, nil for manual
}

enum TodoSource: String, Codable { case manual, canvas }

@Model
final class CachedMenu {
    var dateKey: String           // "2026-04-20", primary key in effect
    var fetchedAt: Date
    var breakfast: String
    var lunch: String
    var dinner: String
}

@Model
final class CachedEvent {
    var id: String                // VEVENT UID
    var title: String
    var start: Date
    var end: Date
    var location: String?
}
```

### Value types

```swift
struct ClassPeriod {
    let name: String
    let room: String?
    let teacher: String?
    let daysOfWeek: [Int]         // ISO: 1=Mon ... 7=Sun
    let startTime: DateComponents // hour + minute
    let endTime: DateComponents
}
```

Hardcoded in `Schedule.swift` as `let schedule: [ClassPeriod] = [...]`. No editor UI.

### UserDefaults keys

- `pomodoro.state` — encoded `PomodoroState` for foreground restoration
- `lastSync.menu`, `lastSync.events`, `lastSync.canvas` — ISO timestamps shown in Settings
- `onboarding.done`

## Services

Each service is independently testable. All depend only on `URLSession` (injectable for tests) and, where needed, `ModelContext`.

### `DiningService`

```swift
func todaysMeal(now: Date = .now) async throws -> Meal
```

- Cache TTL: 3 hours. If `CachedMenu` for today's `dateKey` is fresher, return it.
- Otherwise fetch `https://www.suffieldacademy.org/suffieldfamilies/apppost`, parse out the block matching today's day-of-week, save a new `CachedMenu`, return it.
- Parser is regex/tag-based, tolerant of whitespace and order variations. Any throw from parsing surfaces as "Menu unavailable" in the UI with a "Open in Safari" link.

### `EventsService`

```swift
func upcomingEvents(now: Date = .now, days: Int = 7) async throws -> [Event]
```

- Fetches `https://www.suffieldacademy.org/calendar/calendar_352.ics`.
- In-repo `.ics` parser (~100 LOC, no third-party dependency) extracts VEVENTs. Supports basic RRULE expansion for weekly/daily recurrence within the requested window.
- Upserts `CachedEvent`s keyed by UID; deletes cached events outside the window.
- Re-fetches at most once per 24 hours unless pull-to-refresh forces it.

### `AssignmentsSyncService`

```swift
func syncCanvas() async throws
```

- Reads Canvas `.ics` URL from `Config.canvasFeedURL` (injected via xcconfig → Info.plist).
- For each VEVENT, upserts a `Todo` keyed by `externalID = VEVENT.UID`:
  - New UID → insert `Todo(source: .canvas, title: SUMMARY, dueDate: DTEND, isDone: false)`.
  - Existing UID → update `title`, `dueDate` only if the todo has never been edited manually. Never toggle `isDone`.
- **Never auto-deletes.** If a VEVENT disappears from the feed, the imported todo stays until manually removed.
- Runs on app foreground and on pull-to-refresh.

### `NotificationService`

```swift
func schedule(for todo: Todo) async
func cancel(for todo: Todo) async
```

- Permission requested lazily on first save of a todo with a `dueDate`. Not at app launch.
- Schedules one `UNNotificationRequest` per todo, identifier stored back on `Todo.notificationID`.
- If permission denied, saves silently — the due-date field still functions visually.

### `PomodoroTimer`

```swift
@Observable final class PomodoroTimer {
    enum State { case idle, focus, shortBreak, paused }
    var state: State { get }
    var remainingSeconds: Int { get }
    func start()
    func pause()
    func reset()
}
```

- Fixed durations: 25 min focus, 5 min break.
- Backed by a single repeating `Timer`. Remaining time computed from an anchor `Date` stored in `UserDefaults`, so returning from background after any elapsed duration produces correct remaining seconds (no drift).
- Tests inject a `Clock` protocol; production uses `Date.now`.

## Screens

The app uses a 3-tab bottom bar: **Today** (dashboard), **Canvas** (assignments), **Calendar** (personal reminders). Each tab is its own `NavigationStack`.

### Today tab — Dashboard (root)

```
┌───────────────────────────────┐
│ Today · Tue Apr 20       ⚙   │
│ 5 tasks · 2 done              │
│                               │
│ ── TO DO ──                   │
│ ○ English essay       DUE     │
│ ○ Study bio ch. 7             │
│ ○ Email Mr. Davis             │
│ ● Calc pset (strikethrough)   │
│ + add task                    │
│                               │
│ ┌─────────┬─────────┐         │
│ │ NEXT    │ LUNCH   │         │
│ │ English │ Chicken │         │
│ │ 9:25    │ + tats  │         │
│ ├─────────┼─────────┤         │
│ │ POMO    │ EVENTS  │         │
│ │ Start   │ Soccer  │         │
│ │ 25 min  │ 4pm     │         │
│ └─────────┴─────────┘         │
└───────────────────────────────┘
```

- The dashboard todo list shows **manual todos only** — Canvas assignments live in the Canvas tab.
- Pull-to-refresh runs `DiningService`, `EventsService`, `AssignmentsSyncService` in parallel.
- Tap a todo row to toggle. Swipe left to delete. Tap `+` → add sheet.
- Todo ordering: open items first, sorted by due date ascending (no due date sinks to the bottom of open). Completed items render below in strikethrough, newest first.
- Tap any glance card → push to the corresponding detail screen (Classes, Meal, Pomodoro, School Events).

### Canvas tab

- Shows only `Todo`s where `externalID != nil` (i.e., imported from the Canvas `.ics` feed).
- Same row UI as manual todos: checkbox + title + due date chip.
- Swipe-to-delete is disabled — deleted canvas items just reappear on next sync.
- Pull-to-refresh calls `AssignmentsSyncService.syncCanvas()`. Sync errors surface in the counter line ("N open · N done · sync error") with a Retry button when the list is empty.

### Calendar tab — Personal reminders

- Separate from school events. For things like "pick up suit Sunday 4pm".
- Backed by the `PersonalEvent` SwiftData model.
- List grouped by day, sorted chronologically. Past events hide automatically.
- Add/edit sheet: title, all-day toggle, date/time, notes, notify toggle.
- Notifications scheduled through the same `NotificationService` as todos.

### Todo detail/add sheet

- Manual: title field + optional due date picker + save/cancel.
- Canvas-sourced: title and due date shown read-only with a small "From Canvas" label. Only the completion checkbox is editable.

### Classes screen

Today's classes only, in chronological order. No weekly grid. Each row: period name, room, time range. If today has no classes (weekend / break), empty state.

### Pomodoro screen

Full-screen circular timer with one button (Start → Pause → Resume). Reset lives behind a long-press or small text link. No task picker, no log.

### Events screen

Flat scrollable list of upcoming 7 days, grouped by date header. Read-only.

### Meal screen

Today's breakfast, lunch, dinner as three text sections. Footer link: "Open full menu in Safari".

### Settings screen

- Notification permission status
- Last-sync timestamps for menu / events / Canvas
- Force refresh button
- App version + build number
- No editable preferences.

## Error handling & offline behavior

| Source | Success | Stale cache < 24h | No cache / parse error |
|---|---|---|---|
| Dining menu | Render cards | Render + "as of Xh ago" | "Menu unavailable" + Safari link |
| Events | Render list | Render cached | Empty state + Retry button |
| Canvas sync | Upsert todos | Keep existing imported todos | Silent; manual todos unaffected |

No blocking spinners. Cards render from cache instantly; a hairline "refreshing…" bar appears during pull-to-refresh.

## Secrets

- Canvas `.ics` URL is a personal token. Stored in `Config/Secrets.xcconfig`, added to `.gitignore`.
- `Config/Secrets.xcconfig.example` is committed with placeholder values and a comment explaining how to obtain the Canvas feed URL.
- `Info.plist` references `$(CANVAS_FEED_URL)` → `Config.swift` reads it from `Bundle.main.infoDictionary`.
- No Keychain needed — the URL is not personally sensitive beyond "someone could read your assignment list".

## Testing

Focus on the brittle parsing layers and the timer.

- `DiningServiceTests` — canned HTML fixtures:
  - Normal current format
  - Day ordering variations
  - Missing meal section for a day
  - Deliberately broken HTML → asserts graceful throw
- `ICSParserTests` — fixtures covering:
  - Multiple VEVENTs in one file
  - RRULE weekly recurrence expansion within window
  - All-day events (DATE vs DATE-TIME)
  - DST boundary crossings
- `AssignmentsSyncServiceTests` — verifies:
  - First sync imports all
  - Second sync with same UIDs updates in place (no duplicates)
  - Disappeared UID → existing todo is untouched
  - User-modified todo is not overwritten on re-sync
- `PomodoroTimerTests` — injects a mock `Clock`:
  - State transitions
  - Wall-clock correctness: simulate advancing time 30 minutes during a 25-min focus → should have transitioned through focus→break
  - Pause/resume preserves remaining time

No SwiftUI view tests.

## Distribution

- Git repo initialized locally; personal remote optional.
- Signed with personal developer certificate.
- Installed via Xcode direct-to-device or uploaded to personal TestFlight.
- No App Store submission planned.

## Deferred follow-ups

Explicitly out of scope for v1, documented here so we don't re-litigate:

- Widgets (Lock Screen, Home Screen)
- Live Activities during pomodoro
- Editable class schedule UI
- Custom pomodoro durations
- Class reminder notifications
- Cross-device sync (iPad, Mac)
- Analytics / crash reporting
- Cloud scraper fallback for dining menu
