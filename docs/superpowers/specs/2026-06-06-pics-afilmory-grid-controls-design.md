# PICS — Afilmory-parity grid controls

**Date:** 2026-06-06
**Repo:** Andy-Swiss-Knife (iOS)
**Status:** Approved scope, pending implementation

## Summary

Bring the PICS tab's photo grid closer to the Afilmory photo site
(`pics.andypandy.org`) by adding an adjustable **column-count control** to the
masonry and simplifying the sort bar to Afilmory's **newest / oldest** order
toggle. Client-only — no changes to `personal-site` or the `/api/admin/r2-photos`
contract.

## Context

- iOS PICS already has an Afilmory-style masonry (`PhotoMasonry`: shortest-column
  packing + persistent `PhotoRatioCache`) and a 6-option sort bar
  (`PhotoSort`: newest/oldest/nameAsc/nameDesc/largest/smallest).
- The masonry column count is currently **hard-coded to `2`** at the call site in
  `PhotoGalleryView.grid`.
- Afilmory's gallery settings are minimal: sort by **date** with a
  newest/oldest order toggle; a **column-count** control (`auto`, or 3–5 on
  mobile); and a masonry/list view toggle that is **desktop-only**.
- The photo list payload (`R2Photo`) carries only `key, size, lastModified, url,
  thumbnailUrl` — no EXIF capture date or dimensions. Afilmory's rich
  `photos-manifest.json` (width/height/`DateTimeOriginal`) is bundled into the
  Afilmory web build and is **not** in R2, so true capture-date sorting is out of
  scope for this client-only change. `lastModified` is exactly Afilmory's own
  fallback when an EXIF date is missing, so newest/oldest stays faithful.

## Goals

1. User can change the masonry column count from the PICS toolbar.
2. Sort bar matches Afilmory semantics: a clean **NEWEST / OLDEST** toggle.

## Non-goals

- No `personal-site` / backend API changes.
- No capture-date (EXIF) sorting — needs data the list API doesn't expose.
- No masonry/list view-mode toggle (Afilmory omits it on mobile; explicitly
  deferred).
- No change to the masonry packing algorithm or `PhotoRatioCache`.

## Design

### 1. Column-count control

- New persisted setting: `@AppStorage("photos.columns.v1")` storing a raw string,
  default `"auto"`.
- A small enum models the choice:

  ```swift
  enum PhotoColumns: String, CaseIterable, Identifiable {
      case auto, two = "2", three = "3", four = "4", five = "5"
      var id: String { rawValue }
      var label: String { self == .auto ? "AUTO" : rawValue }
      /// Resolve to a concrete column count for a given container width.
      func resolved(width: CGFloat) -> Int {
          switch self {
          case .auto:  return min(5, max(2, Int((width / 180).rounded())))
          case .two:   return 2
          case .three: return 3
          case .four:  return 4
          case .five:  return 5
          }
      }
  }
  ```

- UI: a brutalist chip group labelled `COLS` rendered in the existing control
  row, to the right of `SORT`, reusing the exact chip styling already used by the
  sort bar (monospaced, heavy, selected = filled `AppColors.primary`). On narrow
  widths the row stays horizontally scrollable as it is today.
- `PhotoGalleryView.grid` passes `columns: columnChoice.resolved(width: geo.size.width)`
  into `PhotoMasonry` instead of the literal `2`. `PhotoMasonry` already accepts a
  `columns` parameter and re-flows on change; no change needed inside it.

### 2. Sort bar → newest/oldest

- Reduce `PhotoSort` to two cases: `.newest`, `.oldest` (drop `nameAsc`,
  `nameDesc`, `largest`, `smallest`).
- `sortedPhotos` keeps only the `lastModified` comparison branches.
- The `@AppStorage("photos.sort.v1")` default (`newest`) is unchanged; any
  previously-persisted value that is now invalid falls back to `.newest` via the
  existing `PhotoSort(rawValue:) ?? .newest` guard — no migration needed.
- The `SORT` chip row keeps its current look, now with two chips.

## Files touched

- `Sources/Views/Photos/PhotoGalleryView.swift`
  - Trim `PhotoSort` enum + `sortedPhotos`.
  - Add `PhotoColumns` enum, `columnsRaw` AppStorage + derived `columnChoice`.
  - Add `COLS` chip group to the sort/control row.
  - Pass resolved column count into `PhotoMasonry`.
- (No other files; `PhotoMasonry.swift` is already parameterized.)

## Edge cases

- **Very wide / future iPad widths:** `auto` clamps to 2–5; explicit choices are
  honored as-is.
- **Stale persisted sort value** (e.g. `largest` from a prior build): guarded
  fallback to `.newest`.
- **Single / few photos:** masonry already handles sparse columns; higher column
  counts just leave empty columns, which is acceptable.
- **Aspect-ratio cache:** unaffected; ratios are keyed by photo `key`, not column
  count, so changing columns reuses cached ratios with no reload.

## Testing

- Manual: toggle each COLS option (AUTO/2/3/4/5) and confirm the grid re-flows
  without reloading thumbnails; rotate / different device widths to confirm AUTO
  resolves sensibly.
- Manual: toggle NEWEST/OLDEST and confirm order flips; confirm a prior
  `largest`-persisted install opens on NEWEST.
- Build: `xcodegen` + compile (Swift 6, iOS 17 target) clean.
