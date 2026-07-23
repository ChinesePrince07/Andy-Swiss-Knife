<p align="center">
  <img src="./assets/readme/hero.svg" width="100%" alt="Andy's Swiss Knife, a brutalist iPhone dashboard for school, tasks, files, and daily life">
</p>

<p align="center">
  <strong>One iPhone app for the school day.</strong><br>
  Schedule, Canvas assignments, dining, athletics, files, photos, focus sessions, and personal tools—organized around what matters now.
</p>

## See today at a glance

<p align="center">
  <img src="./docs/screenshots/dashboard.png" width="360" alt="Andy's Swiss Knife Today dashboard showing classes, tasks, dining, and countdown cards">
</p>

The customizable **Today** dashboard is the center of the app. It surfaces the next class, unfinished work, meals, reminders, countdowns, weather, and other cards without making you open a stack of separate apps.

## What is inside

- **School** — class schedule, Canvas assignment sync, dining menus, school events, and athletics across Suffield teams.
- **Get things done** — ordered to-dos, personal reminders, countdowns, calendar import, and a Pomodoro timer with a Live Activity.
- **Your stuff** — file browsing and sharing, photo albums, a blog editor, and a FitCheck web view.
- **On court** — an experimental badminton view with camera-based player and shuttle analysis.
- **At a glance** — Home Screen widgets for tasks, reminders, lunch, and the next class.

Tabs and dashboard cards are configurable, so the app can stay narrow even as the project grows.

## Design

The interface uses a deliberately blunt visual system: zero-radius cards, heavy rules, uppercase mono labels, and six switchable themes.

`STARK WHITE` · `CREAM` · `INK` · `ACID` · `HAZARD` · `TOXIC`

## Project map

```text
Sources/
├── Models/        SwiftData models and cached remote data
├── Services/      sync, networking, timers, widgets, and integrations
├── Styles/        brutalist themes and shared UI primitives
└── Views/         dashboard plus feature tabs
Widgets/           Home Screen widgets and Live Activity
```

The app stores its local data with SwiftData. Remote school, site, and publishing features depend on their corresponding services and user configuration; the core dashboard and personal tools can still run without every integration enabled.

## Status

This is a personal, school-specific iOS project. Some defaults and integrations are tailored to Suffield Academy, and the badminton analysis is experimental. Expect to replace school endpoints or data sources when adapting it elsewhere.
