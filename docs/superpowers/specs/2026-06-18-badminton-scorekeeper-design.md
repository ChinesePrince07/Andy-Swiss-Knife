# Badminton — camera shuttle tracking, speed, and auto-scorekeeper

**Date:** 2026-06-18
**Repo:** Andy-Swiss-Knife (iOS)
**Status:** Approved design, pending implementation plan

## Summary

A new **Badminton** section in the Swiss Knife app that points the iPhone camera
at a court and, on-device, **tracks the shuttlecock**, **estimates how hard each
shot is hit** (speed), and ultimately **keeps score automatically**. Inspired by
a Twitter demo (`@mountain_mal`, 2026-06-15) that overlays per-player pose
skeletons, a top-down shuttle minimap, a rally HUD (`IN PLAY · rally seconds ·
shots: n`), and a live score on a side-on indoor singles match.

All inference is **on-device via Core ML** — the personal-site backend is
serverless (Vercel) with no GPU, and the experience must work pointing a phone
at a court live. Player pose uses **Ultralytics YOLO11-pose**; shuttle tracking
uses **TrackNetV3** (converted to Core ML). No app-extension, entitlement, or
app-group changes, so the existing OTA build/sign/publish pipeline is unaffected.

The build is **phased**, and — per the owner not having full-court access soon —
**motion detection + speed estimation are prioritised first**, with the
court-dependent scoring work deferred until a court is available.

## Context

- **Target experience (owner's words):** "point a phone at the court → it follows
  the shuttlecock, keeps score, and tells you how hard you're whacking it." The
  v1 win condition chosen is the **full auto-scorekeeper**, built in layers.
- **Camera vantage:** **side-on at net height** (phone on a net post / chair /
  small tripod), fixed during play. Favourable for shuttle tracking and speed
  (motion is mostly in the image plane); weaker for far-side line calls
  (foreshortening) — so scoring is **assisted** (auto call + one-tap override).
- **Test device:** **iPhone 15 Pro / 16 / 17 class** (A17 Pro+ Neural Engine,
  1080p120/240 capture). Sets a generous perf budget for dual-model inference and
  high-fps landing capture.
- **The demo is almost certainly offline video processing** (visible frame
  counter, spotless overlays) — i.e. a script over a recorded clip, not live
  on-device AR. Live-on-phone is materially harder; Phase 1 measures the true
  on-device frame rate, and record-then-analyse is the proven fallback that
  reproduces exactly what the demo is.
- **Existing app conventions** (from codebase scan): sections are added via the
  `DashboardCard` enum + `TodayDashboardView` wiring, or the `AppTab` enum.
  Features are **Model + `@Observable @MainActor` Service + View**, with services
  injected through a `Services` singleton (`Sources/Views/SwissKnifeApp.swift`).
  iOS 17+, SwiftData + UserDefaults + App-Group `SharedStorage`. Brutalist theme
  (`Sources/Styles/Theme.swift`, `Style.swift`): sharp corners, thick borders,
  monospaced fonts, per-theme accent. **No camera/CV infrastructure exists yet**
  (only `SchedulePDFParser` touches Vision for OCR); this is net-new capability.

### Reference demo forensics (ffmpeg, 2026-06-18)

Frame-by-frame analysis of the demo clip confirmed:

- **Effective processing rate ≈ 30 fps:** the on-screen frame counter advances
  exactly 150 frames / 5 s and 300 / 10 s (drifting to ~40 late in the clip).
  With the visible counter, this is **offline processing of a ~30 fps recording**,
  not live AR. **30 fps is the live design target.**
- **HUD format:** a green-on-black bar `IN PLAY · <rally seconds>s · shots: <n>`,
  above a scoreboard panel labelling the two sides (e.g. `P0 — MAY` / `MAL — P1`)
  with the running score.
- **TOP VIEW minimap** (top-right): a top-down court with the shuttle as a dot +
  short trail — a court homography projection (matches the deferred court phase).
- **No speed / km·h readout appears anywhere** in the clip. Despite the tweet's
  "measures shot velocity" claim, the visible overlay shows only tracking + shot
  count + score. **The speed readout is our own headline feature (P2), not a copy
  of the demo** — so it gets first-class UI treatment.
- The compressed clip could not resolve the raw shuttle pixels in a montage;
  classical-vs-TrackNet detector viability is settled empirically on P1 footage.

## Decisions (resolved during brainstorming)

| Question | Decision |
| --- | --- |
| Inference location | **On-device, Core ML** (no server option is viable for live) |
| v1 goal | **Auto-scorekeeper**, built in layers (tracking → speed → in/out → scoring) |
| Camera setup | **Side-on at net height**, fixed |
| Test device | **iPhone 15 Pro+** |
| Capture/scoring pipeline | **B** — live ~30 fps tracking + 120 fps rolling buffer for fast landings |
| First priority | **Motion detection + speed** (no full court needed) |
| Player count (v1) | **Singles first**; doubles deferred |
| Court calibration | **Manual tap** (deferred); **speed uses a 1-segment reference scale** |
| Default speed reference | **Net height = 1.55 m** (post tops) |
| Scoring style | **Assisted**: auto call + one-tap override |
| Speed units | Default **km/h** (badminton convention), toggle to mph |

## Goals

1. **P1:** Point the phone at a moving shuttle → a live **trail** follows it on a
   full-screen camera preview, with the real on-device **frame rate** shown.
2. **P2:** Calibrate a real-world scale from one tapped segment (net height) →
   a plausible **per-shot speed** readout in km/h (last + max).
3. **P0 (parallel):** Produce **validated Core ML** versions of YOLO11-pose and
   TrackNetV3, swappable behind detector protocols.
4. **Later (court-gated):** full court homography, top-down minimap, in/out
   landing, rally segmentation, **auto-scoring**, then doubles + stats.

## Non-goals (v1)

- No backend / personal-site changes. Everything is on-device and client-only.
- No doubles, no stats/heatmaps, no match-history sync in the first phases.
- No claim of radar-gun accuracy — speed is an **honest estimate** (see caveats).
- No fully-autonomous refereeing — far-line calls are assisted, not trusted blindly.
- No new app-extension / widget / entitlement / app-group changes.

## Architecture

Small, single-purpose units. Pure-math + rules units are unit-testable in CI
(no device needed), which is essential given the maintainer cannot run the live
camera on a physical device.

**Capture**
- `CameraSession` — wraps `AVCaptureSession`; configures the capture format and
  vends `(CVPixelBuffer, CMTime timestamp)` frames to consumers. Owns an optional
  high-fps **rolling ring buffer** (for P3 landing capture). Camera is started
  only while the Badminton view is active.

**Inference** — each behind a protocol so it is swappable and mockable:
- `protocol ShuttleDetector` — `func detect(...) -> ShuttleObservation?` (image
  point + confidence + timestamp).
  - `MotionShuttleDetector` — classical CV (frame-differencing / brightness blob,
    optionally optical flow), gated by size/speed/locality heuristics. No model;
    runs immediately and cheaply (can run at high fps). Ships P1.
  - `TrackNetShuttleDetector` — Core ML TrackNetV3; keeps a 3-frame input ring
    buffer; peak-finds the output heatmap to a sub-pixel point. Swapped in P0/P1+.
- `protocol PoseDetector` → `PlayerPose[]` (box + 17 keypoints).
  - `YOLOPoseDetector` — Core ML YOLO11-pose. Added once shuttle tracking is solid.

**Geometry** (pure, unit-tested)
- `ReferenceScale` — from two tapped image points + a known real distance, derive
  metres-per-pixel at the reference plane. The 1-segment special case of a homography.
- `Homography` — general solve + project (court-phase; shares code with `ReferenceScale`).
- `SpeedEstimator` — shuttle image-track + scale + frame timestamps → per-shot speed.

**Analysis**
- `ShuttleTrajectory` — smooths per-frame observations into a trajectory; flags
  events: **hit**, apex, descent, **landing**. Tolerates dropped frames (gaps).
- `ShotDetector` — velocity-direction reversal near a player → discrete shot
  events. Drives the `shots:` counter and each speed-measurement window.
- `LandingDetector` (court-phase) — on descent, reads the high-fps buffer slice →
  landing point on the court plane → in/out vs the singles lines + confidence.

**Scoring** (pure, unit-tested; court-phase)
- `RallyStateMachine` — segments serve → rally → end (shuttle/pose cues + timeout).
- `BadmintonScorekeeper` — rules engine: rally-point to 21, win-by-2, cap at 30,
  server/side tracking, game + match state. No CV dependency.
- `MatchStore` — match-history persistence (UserDefaults; SwiftData if it grows).

**Presentation**
- `BadmintonEngine` (`@Observable @MainActor`, lazily created in `Services`) — the
  conductor: drives the frame pipeline off the main thread and publishes UI state
  on main. Holds the camera only while active.
- `BadmintonView` (state machine: Setup → Calibrate → Live) + `OverlayRenderer`
  (trail, marker, skeletons, court lines) + `SpeedReadout` + `RallyHUD` +
  `TopViewMinimap` (court-phase) + scoreboard (court-phase) + calibration flow +
  session/match summary. All brutalist-themed.

**Live data flow:** camera → (`ShuttleDetector` ‖ `PoseDetector`) per processed
frame → `ShuttleTrajectory` / `ShotDetector` update → `OverlayRenderer` +
`SpeedReadout` draw → (court-phase) on descent `LandingDetector` reads the high-fps
buffer → `RallyStateMachine` fires rally-end → `BadmintonScorekeeper` awards a
point → scoreboard updates with a one-tap override.

## Design by phase

The **first implementation plan covers P0–P2** (model conversion + live tracking +
speed). P3+ (court homography, in/out, scoring, doubles) is deferred until court
access and gets its own later spec refinement + plan; it is sketched here only to
confirm the early units (`Homography`, `SpeedEstimator`, the detector protocols)
generalise cleanly and nothing built now is thrown away.

### P0 — Model conversion (offline, parallel, does not block P1)

- **YOLO11-pose → Core ML:** Ultralytics official export
  (`yolo export model=yolo11n-pose.pt format=coreml`). Low risk; nano model for
  real-time Neural-Engine inference.
- **TrackNetV3 → Core ML (the main risk):** pull public pretrained weights,
  rebuild the network in PyTorch, export via `coremltools` (torch converter or
  ONNX path). Input = 3 consecutive RGB frames resized to model resolution (e.g.
  288×512) stacked to `[1, 9, 288, 512]`; output = per-frame heatmap(s). The
  3-frame ring buffer and sub-pixel peak-find (weighted centroid around the
  heatmap max) run in **Swift**. The **trajectory-rectification / inpainting**
  module is **offline-only** (record-then-analyse), skipped in the live path.
- **Validation:** run identical sample frames through original PyTorch vs the
  Core ML model; assert shuttle-coordinate agreement within tolerance. Also run
  the converted models over the **Twitter demo clip** + other badminton video and
  eyeball that the trail locks onto the shuttle. Conversion + validation run
  off-device (coremltools on Linux/CI); the final `.mlpackage` compiles to
  `.mlmodelc` in the macOS CI build.
- **DoD:** validated `.mlpackage`s for both models, with a recorded
  coordinate-agreement metric on sample clips.

### P1 — Camera + live shuttle trail (classical detector)

- `BadmintonView` scaffold + dashboard card + camera permission.
- `CameraSession` streaming 1080p (30 or 60 fps) frames.
- `MotionShuttleDetector` → `ShuttleTrajectory` → `OverlayRenderer` draws the live
  **trail + current marker** over the preview.
- **fps HUD**: surface measured processing fps on-device immediately.
- **Debug-record** toggle: save the session video + a JSON sidecar of per-frame
  observations to app documents / Files, so the maintainer can iterate from real
  clips (the blind-loop lifeline).
- **DoD:** install via OTA → point at a moving shuttle → trail follows it; fps
  shown; debug clip exports.

### P2 — Reference-scale calibration + speed

- **Calibration flow:** "Tap the top of each net post" (default 1.55 m), or pick a
  preset (taped 1 m marker / racket 0.68 m / own height) or enter a custom
  distance. Show the two points + segment; confirm; persist
  `ReferenceScale` (metres-per-pixel + the chosen distance + units) to UserDefaults.
- `ShotDetector` flags hits; for each hit, `SpeedEstimator` takes shuttle image
  positions over the **~80 ms window after the hit**, converts pixel displacement
  to metres via the scale, divides by Δt (precise frame timestamps), and reports
  the **peak instantaneous speed** of that window. Surface **last + max** speed.
- **Higher-fps option:** the cheap `MotionShuttleDetector` can run at high capture
  fps (e.g. 120) for finer speed sampling even before TrackNet is in; the heavier
  TrackNet runs at a lower cadence for the robust trail. Default P2 capture: 60 fps.
- **Honest caveats in the UI:** speed is an estimate; accuracy degrades as the
  shuttle's distance from the camera differs from the calibration plane and for
  shots angled toward/away from the camera; measuring at the hit (side-on) is the
  best-case geometry. A short "?" explainer.
- **DoD:** calibrate via net height → plausible per-shot km/h; `SpeedEstimator`
  unit tests (synthetic trajectory at known speed → recovered within tolerance)
  green in CI.

### P3+ — Court-gated (deferred, specced light)

- **Court homography:** tap the visible court corners/key line points →
  `Homography` (generalises `ReferenceScale`); enables the **TopViewMinimap** and
  metric positions.
- **In/out landing:** `LandingDetector` over the 120 fps rolling buffer → landing
  point on the court plane → in/out vs singles lines + confidence.
- **Rally + scoring:** `RallyStateMachine` + `BadmintonScorekeeper` (built and
  unit-tested early, independent of CV) → assisted scoreboard with one-tap
  override + `RallyHUD` + match history.
- **P5:** doubles (4 players, doubles lines, serve rotation), stats/heatmaps,
  polish.

## UI / UX

- Entry: a **"Badminton" dashboard card** → full-screen `BadmintonView`.
- View state machine:
  1. **Setup** — start tracking immediately (trail only); speed shows `—` until
     calibrated. Buttons: Start, Calibrate, Settings.
  2. **Calibrate** — tap two reference points; live segment preview; Confirm.
  3. **Live** — camera preview + overlays: shuttle trail + marker; pose skeletons
     (when added); a large monospaced **speed readout** (`LAST 243 · MAX 290
     km/h`); a HUD (`shots: n`; rally timer added in the scoring phase). Controls:
     Start/Stop, Recalibrate, Units (km/h ⁄ mph), Debug-record.
- **Theme:** monospaced readouts in sharp-cornered, thick-bordered panels with a
  semi-opaque dark backing for legibility over video; trail + speed in the active
  theme accent (`AppColors.accent`). Reuse `AppType.mono`, `SectionLabel`,
  hairline/border styling from `Style.swift`.

## App integration / files touched

- `Sources/Services/DashboardLayout.swift` — add `.badminton` case (label + SF
  Symbol).
- `Sources/Views/Dashboard/TodayDashboardView.swift` — wire the card content +
  navigation destination switches.
- **New** `Sources/Views/Badminton/` — `BadmintonView.swift` + subviews
  (`OverlayRenderer`, `SpeedReadout`, `CalibrationView`, `RallyHUD`/minimap later).
- **New** `Sources/Services/Badminton/` — `BadmintonEngine.swift`,
  `CameraSession.swift`, `ShuttleDetector.swift` (+ `MotionShuttleDetector`,
  `TrackNetShuttleDetector`), `PoseDetector.swift` (`YOLOPoseDetector`),
  `ReferenceScale.swift`, `Homography.swift`, `SpeedEstimator.swift`,
  `ShuttleTrajectory.swift`, `ShotDetector.swift`, and the scoring units later.
- `Sources/Views/SwissKnifeApp.swift` — add a lazily-created `BadmintonEngine` to
  the `Services` singleton (camera not started until the view appears).
- `project.yml` —
  - `info.properties`: add `NSCameraUsageDescription` ("Swiss Knife uses the
    camera to track the shuttlecock and measure your shot speed.").
  - bundle the `.mlpackage`(s) as app resources (a `Sources/Models/` resource
    path or similar). **App target only — not the widget extension.**
- **New tests** in the `AndySwissKnifeTests` target for the pure-logic units.
- **CI:** add an `xcodebuild test` step (the publish workflow currently only
  builds) so unit tests run on every push.

## Testing — engineered around a blind iteration loop

The maintainer cannot run the live camera on a device, so testability is designed
in:

- **Pure-logic unit tests** (XCTest, `AndySwissKnifeTests`): `ReferenceScale` /
  `Homography` math; `SpeedEstimator` (synthetic constant-speed trajectory →
  recovered speed within tolerance; verify peak-window logic); `ShotDetector`
  (synthetic direction reversals); `BadmintonScorekeeper` rules (rally-point,
  win-by-2, cap-30, serve sides) in the scoring phase.
- **Offline clip validation**: process the Twitter demo clip + other badminton
  video through the converted Core ML models off-device and confirm the trail
  tracks the shuttle and speeds are plausible — before any install.
- **On-device empirical loop**: OTA install → owner points at a moving shuttle →
  debug-record exports a clip + observation sidecar → maintainer iterates. Expect
  a few rounds, especially on detector thresholds and shot detection.
- **fps instrumentation** from P1 so the live perf budget is known early.
- **Build:** `xcodegen` + compile clean (Swift 6, iOS 17 target), on `macos-15`
  CI with the model resources bundled.

## Risk register

| Risk | Mitigation |
| --- | --- |
| TrackNetV3 conversion is hard or numerically off | `MotionShuttleDetector` ships P1 regardless; numerical validation gate; rectification kept offline |
| On-device perf below real-time (dual model) | Classical detector is cheap; TrackNet at reduced res/cadence; adaptive fps; record-then-analyse fallback (Pipeline C) |
| Speed inaccurate without a court | Labelled an estimate; measured at the hit; net-height reference in the play plane; recalibration; full homography later |
| Cluttered real-world backgrounds early | TrackNet designed for clutter; classical detector may need a calm-ish background until TrackNet lands |
| Blind iteration loop (no device for maintainer) | Debug clip capture + offline clip validation + heavy unit tests + on-device fps HUD |
| High-fps + ML-tap AVFoundation complexity | Isolated in `CameraSession`; start 1080p30/60, add the 120 fps ring buffer only at P3 |
| IPA size growth from bundled models | YOLO11n-pose (~6 MB) + TrackNetV3 (tens of MB) is acceptable for OTA; monitor |

## Definition of done (near-term)

- **P0:** validated `.mlpackage`s for YOLO11-pose + TrackNetV3, with a recorded
  coordinate-agreement metric on sample clips.
- **P1:** OTA install → point at a moving shuttle → live trail follows it; fps
  shown; debug-record exports a clip + sidecar.
- **P2:** calibrate via net height → plausible per-shot km/h (last + max); speed
  unit tests green in CI.

## Open questions / future

- Exact TrackNetV3 source repo + checkpoint to standardise on (pick during P0).
- Whether to run the classical detector at high fps purely for speed while
  TrackNet handles the trail at a lower cadence (decide empirically in P2).
- Court-phase calibration UX detail and in/out confidence thresholds (revisit when
  court access is available).
