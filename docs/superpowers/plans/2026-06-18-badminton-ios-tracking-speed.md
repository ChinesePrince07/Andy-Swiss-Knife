# Badminton iOS — Live Shuttle Tracking + Speed (P1–P2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Badminton section to the Swiss Knife iOS app that points the camera at play, draws a live shuttle trail, and estimates per-shot speed — without needing a full court (speed scale comes from one tapped reference length).

**Architecture:** A `BadmintonEngine` (`@Observable @MainActor`) drives a frame pipeline off the main thread: `CameraSession` (AVFoundation) → `ShuttleDetector` (a classical `MotionShuttleDetector` for now, TrackNetV3 later) → `ShuttleTrajectory` + `ShotDetector` → published UI state. Pure-logic units (`ShuttleTrajectory`, `ShotDetector`, `MotionBlobFinder`, `ReferenceScale`, `SpeedEstimator`, `FPSCounter`) are unit-tested in `AndySwissKnifeTests`; camera/SwiftUI glue is build- and device-verified. Speed = pixel displacement → metres via a one-segment `ReferenceScale`, divided by precise frame timestamps, peak over the post-hit window.

**Tech Stack:** Swift 6, SwiftUI, AVFoundation, CoreVideo, SwiftData (existing), XCTest, XcodeGen, GitHub Actions (`macos-15`).

## Global Constraints

- **Swift 6**, **iOS deployment target 17.0** (from `project.yml`).
- **On-device only.** No personal-site / backend changes. No network calls in this feature.
- **No app-extension / entitlement / app-group / widget changes** — keeps the OTA build/sign/publish pipeline (`zsign -E`) unaffected. New code and the camera-usage string live in the **app target only**, never `SwissKnifeWidgets`.
- New source files under `Sources/` and tests under `Tests/` are auto-picked-up by XcodeGen (whole-directory source paths) — **no `project.yml` change is needed except** adding `NSCameraUsageDescription` (Task 8).
- Follow existing conventions: `@Observable @MainActor final class` services injected via the `Services` singleton; views take `services: Services`; tests are `XCTest` with `@testable import AndySwissKnife` and dependency injection (cf. `PomodoroTimer(clock:)`).
- Styling: brutalist — `AppColors.*`, `AppType.mono`, `ThemedBackground`, `SectionLabel`, sharp corners, thick borders, monospaced.
- Speed units default **km/h**, toggle to mph. Speed is presented as an **estimate** (UI caveat copy).
- Image coordinates are **pixels, origin top-left**, throughout.

---

## File structure

Created (app target):
- `Sources/Services/Badminton/Model/ShuttleObservation.swift` — value types shared across the pipeline.
- `Sources/Services/Badminton/Analysis/ShuttleTrajectory.swift` — accumulates + prunes recent samples; exposes trail + velocity.
- `Sources/Services/Badminton/Analysis/ShotDetector.swift` — horizontal-velocity reversal → shot events + count.
- `Sources/Services/Badminton/Analysis/FPSCounter.swift` — rolling processed-frame rate.
- `Sources/Services/Badminton/Geometry/ReferenceScale.swift` — one-segment pixels↔metres.
- `Sources/Services/Badminton/Geometry/SpeedEstimator.swift` — peak post-hit speed.
- `Sources/Services/Badminton/Detect/ShuttleDetector.swift` — `ShuttleDetector` protocol.
- `Sources/Services/Badminton/Detect/MotionBlobFinder.swift` — pure blob finder over a diff buffer.
- `Sources/Services/Badminton/Detect/MotionShuttleDetector.swift` — frame-diff detector (wraps `MotionBlobFinder`).
- `Sources/Services/Badminton/Capture/CameraSession.swift` — AVFoundation capture.
- `Sources/Services/Badminton/Capture/PixelBufferGray.swift` — pixel-buffer → grayscale helper.
- `Sources/Services/Badminton/BadmintonEngine.swift` — the conductor (`@Observable`).
- `Sources/Services/Badminton/BadmintonSettings.swift` — persisted scale + units.
- `Sources/Views/Badminton/BadmintonView.swift` — Setup → Calibrate → Live state machine.
- `Sources/Views/Badminton/CameraPreview.swift` — `UIViewRepresentable` preview layer.
- `Sources/Views/Badminton/OverlayRenderer.swift` — Canvas trail/marker + fps HUD.
- `Sources/Views/Badminton/CalibrationView.swift` — tap two points → scale.
- `Sources/Views/Badminton/SpeedReadout.swift` — LAST/MAX speed panel.

Modified:
- `Sources/Services/DashboardLayout.swift` — add `.badminton` card.
- `Sources/Views/Dashboard/TodayDashboardView.swift` — wire card content + destination.
- `Sources/Views/SwissKnifeApp.swift` — add `badminton` to `Services`.
- `project.yml` — add `NSCameraUsageDescription` (app target only).
- `.github/workflows/publish-ios.yml` — add a unit-test step (Task 12).

Tests:
- `Tests/BadmintonTrajectoryTests.swift`, `Tests/BadmintonShotDetectorTests.swift`, `Tests/BadmintonFPSCounterTests.swift`, `Tests/BadmintonBlobFinderTests.swift`, `Tests/BadmintonReferenceScaleTests.swift`, `Tests/BadmintonSpeedEstimatorTests.swift`, `Tests/BadmintonSettingsTests.swift`.

**Build/test commands** (CI uses `macos-15`; locally requires a Mac with Xcode 16):
- Generate project: `xcodegen generate`
- Run one test: `xcodebuild test -project AndySwissKnife.xcodeproj -scheme AndySwissKnife -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:AndySwissKnifeTests/<Class>/<method>`
- Build app: `xcodebuild build -project AndySwissKnife.xcodeproj -scheme AndySwissKnife -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO`

> Note for the executor: the maintainer cannot run a simulator/device locally. Pure-logic tasks are verified by the CI test job (Task 12, build it early if you want green checks sooner). Camera/UI tasks are verified by a clean `xcodebuild build` plus on-device smoke testing after an OTA publish.

---

## P1 — Live shuttle tracking foundation

### Task 1: ShuttleObservation + ShuttleTrajectory

**Files:**
- Create: `Sources/Services/Badminton/Model/ShuttleObservation.swift`
- Create: `Sources/Services/Badminton/Analysis/ShuttleTrajectory.swift`
- Test: `Tests/BadmintonTrajectoryTests.swift`

**Interfaces:**
- Produces:
  - `struct ShuttleObservation { let point: CGPoint; let confidence: Double; let time: TimeInterval }`
  - `struct TrajectorySample: Equatable { let point: CGPoint; let time: TimeInterval }`
  - `final class ShuttleTrajectory { init(trailWindow: TimeInterval = 1.0, maxGap: TimeInterval = 0.3); func add(_ obs: ShuttleObservation); var samples: [TrajectorySample] { get }; var trail: [CGPoint] { get }; func velocity() -> CGVector? }`
  - `velocity()` returns pixels/second from the last two samples, or `nil` if fewer than two or the gap exceeds `maxGap`.

- [ ] **Step 1: Write the failing test**

```swift
// Tests/BadmintonTrajectoryTests.swift
import XCTest
@testable import AndySwissKnife

final class BadmintonTrajectoryTests: XCTestCase {
    private func obs(_ x: Double, _ y: Double, _ t: TimeInterval, conf: Double = 1) -> ShuttleObservation {
        ShuttleObservation(point: CGPoint(x: x, y: y), confidence: conf, time: t)
    }

    func testTrailKeepsOnlyWindow() {
        let traj = ShuttleTrajectory(trailWindow: 1.0, maxGap: 0.3)
        traj.add(obs(0, 0, 0.0))
        traj.add(obs(10, 0, 0.5))
        traj.add(obs(20, 0, 1.2))   // 1.2s; prunes the 0.0s sample (older than 1.0s window)
        XCTAssertEqual(traj.trail, [CGPoint(x: 10, y: 0), CGPoint(x: 20, y: 0)])
    }

    func testVelocityFromLastTwoSamples() {
        let traj = ShuttleTrajectory()
        traj.add(obs(0, 0, 0.0))
        traj.add(obs(100, 0, 0.1))    // 100px in 0.1s -> 1000 px/s on x
        let v = traj.velocity()
        XCTAssertNotNil(v)
        XCTAssertEqual(v!.dx, 1000, accuracy: 0.001)
        XCTAssertEqual(v!.dy, 0, accuracy: 0.001)
    }

    func testVelocityNilAcrossLargeGap() {
        let traj = ShuttleTrajectory(trailWindow: 5.0, maxGap: 0.3)
        traj.add(obs(0, 0, 0.0))
        traj.add(obs(100, 0, 1.0))    // gap 1.0s > maxGap -> no velocity
        XCTAssertNil(traj.velocity())
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project AndySwissKnife.xcodeproj -scheme AndySwissKnife -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:AndySwissKnifeTests/BadmintonTrajectoryTests`
Expected: FAIL — `cannot find 'ShuttleTrajectory' in scope`.

- [ ] **Step 3: Write the implementation**

```swift
// Sources/Services/Badminton/Model/ShuttleObservation.swift
import CoreGraphics
import Foundation

/// A single detected shuttle position in image pixels (origin top-left).
struct ShuttleObservation {
    let point: CGPoint
    let confidence: Double   // 0...1
    let time: TimeInterval   // monotonic seconds
}
```

```swift
// Sources/Services/Badminton/Analysis/ShuttleTrajectory.swift
import CoreGraphics
import Foundation

struct TrajectorySample: Equatable {
    let point: CGPoint
    let time: TimeInterval
}

/// Accumulates recent shuttle observations, prunes anything older than
/// `trailWindow`, and exposes the trail + instantaneous velocity.
final class ShuttleTrajectory {
    let trailWindow: TimeInterval
    let maxGap: TimeInterval
    private(set) var samples: [TrajectorySample] = []

    init(trailWindow: TimeInterval = 1.0, maxGap: TimeInterval = 0.3) {
        self.trailWindow = trailWindow
        self.maxGap = maxGap
    }

    func add(_ obs: ShuttleObservation) {
        samples.append(TrajectorySample(point: obs.point, time: obs.time))
        let cutoff = obs.time - trailWindow
        samples.removeAll { $0.time < cutoff }
    }

    var trail: [CGPoint] { samples.map(\.point) }

    /// Pixels/second from the last two samples, or nil if too few or gap too large.
    func velocity() -> CGVector? {
        guard samples.count >= 2 else { return nil }
        let a = samples[samples.count - 2]
        let b = samples[samples.count - 1]
        let dt = b.time - a.time
        guard dt > 0, dt <= maxGap else { return nil }
        return CGVector(dx: (b.point.x - a.point.x) / dt, dy: (b.point.y - a.point.y) / dt)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: same command as Step 2.
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/Services/Badminton/Model/ShuttleObservation.swift Sources/Services/Badminton/Analysis/ShuttleTrajectory.swift Tests/BadmintonTrajectoryTests.swift
git commit -m "feat(badminton): shuttle observation + trajectory trail/velocity"
```

---

### Task 2: ShotDetector

**Files:**
- Create: `Sources/Services/Badminton/Analysis/ShotDetector.swift`
- Test: `Tests/BadmintonShotDetectorTests.swift`

**Interfaces:**
- Consumes: `TrajectorySample` (Task 1).
- Produces:
  - `struct ShotEvent: Equatable { let time: TimeInterval; let point: CGPoint }`
  - `final class ShotDetector { init(minPixelSpeed: Double = 300, refractory: TimeInterval = 0.2); private(set) var shotCount: Int; func ingest(_ sample: TrajectorySample) -> ShotEvent? }`
  - A "shot" = the horizontal velocity sign flips (left↔right) while |horizontal speed| on both sides ≥ `minPixelSpeed`, outside the `refractory` window since the last shot. Side-on play reverses horizontal direction on every hit.

- [ ] **Step 1: Write the failing test**

```swift
// Tests/BadmintonShotDetectorTests.swift
import XCTest
@testable import AndySwissKnife

final class BadmintonShotDetectorTests: XCTestCase {
    private func feed(_ det: ShotDetector, _ pts: [(Double, Double, TimeInterval)]) -> [ShotEvent] {
        var events: [ShotEvent] = []
        for (x, y, t) in pts {
            if let e = det.ingest(TrajectorySample(point: CGPoint(x: x, y: y), time: t)) { events.append(e) }
        }
        return events
    }

    func testDetectsHorizontalReversal() {
        let det = ShotDetector(minPixelSpeed: 300, refractory: 0.2)
        // moving right (+x) fast, then reversing to left (-x) fast at t=0.3
        let events = feed(det, [
            (0, 100, 0.0), (100, 100, 0.1), (200, 100, 0.2), // rightward ~1000 px/s
            (120, 100, 0.3), (40, 100, 0.4)                   // leftward ~800 px/s
        ])
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(det.shotCount, 1)
    }

    func testNoShotBelowSpeed() {
        let det = ShotDetector(minPixelSpeed: 300, refractory: 0.2)
        // slow drift reversal -> not a shot
        let events = feed(det, [
            (0, 100, 0.0), (10, 100, 0.1), (20, 100, 0.2),
            (15, 100, 0.3), (10, 100, 0.4)
        ])
        XCTAssertEqual(events.count, 0)
    }

    func testRefractorySuppressesDoubleCount() {
        let det = ShotDetector(minPixelSpeed: 300, refractory: 0.5)
        let events = feed(det, [
            (0, 100, 0.0), (100, 100, 0.1), (200, 100, 0.2),
            (120, 100, 0.3),                 // reversal #1 -> shot at 0.3
            (220, 100, 0.4), (300, 100, 0.5) // reversal #2 within 0.5s refractory -> suppressed
        ])
        XCTAssertEqual(events.count, 1)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test ... -only-testing:AndySwissKnifeTests/BadmintonShotDetectorTests`
Expected: FAIL — `cannot find 'ShotDetector' in scope`.

- [ ] **Step 3: Write the implementation**

```swift
// Sources/Services/Badminton/Analysis/ShotDetector.swift
import CoreGraphics
import Foundation

struct ShotEvent: Equatable {
    let time: TimeInterval
    let point: CGPoint
}

/// Detects shuttle hits as sharp horizontal-velocity reversals (side-on view).
final class ShotDetector {
    let minPixelSpeed: Double
    let refractory: TimeInterval
    private(set) var shotCount = 0

    private var prev: TrajectorySample?
    private var prevVX: Double?       // last horizontal velocity (px/s)
    private var lastShotTime: TimeInterval = -.greatestFiniteMagnitude

    init(minPixelSpeed: Double = 300, refractory: TimeInterval = 0.2) {
        self.minPixelSpeed = minPixelSpeed
        self.refractory = refractory
    }

    func ingest(_ sample: TrajectorySample) -> ShotEvent? {
        defer { prev = sample }
        guard let p = prev else { return nil }
        let dt = sample.time - p.time
        guard dt > 0 else { return nil }
        let vx = (sample.point.x - p.point.x) / dt
        defer { prevVX = vx }
        guard let pvx = prevVX else { return nil }

        let reversed = (pvx > 0 && vx < 0) || (pvx < 0 && vx > 0)
        let fastEnough = abs(pvx) >= minPixelSpeed && abs(vx) >= minPixelSpeed
        let outsideRefractory = (sample.time - lastShotTime) >= refractory

        if reversed && fastEnough && outsideRefractory {
            lastShotTime = sample.time
            shotCount += 1
            return ShotEvent(time: sample.time, point: sample.point)
        }
        return nil
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: same as Step 2. Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/Services/Badminton/Analysis/ShotDetector.swift Tests/BadmintonShotDetectorTests.swift
git commit -m "feat(badminton): shot detection via horizontal-velocity reversal"
```

---

### Task 3: FPSCounter

**Files:**
- Create: `Sources/Services/Badminton/Analysis/FPSCounter.swift`
- Test: `Tests/BadmintonFPSCounterTests.swift`

**Interfaces:**
- Produces: `final class FPSCounter { init(window: TimeInterval = 1.0); func tick(at time: TimeInterval); var fps: Double }`
- `fps` = number of ticks within the last `window` seconds, divided by the span between the oldest and newest retained tick (≥ 2 ticks), else `0`.

- [ ] **Step 1: Write the failing test**

```swift
// Tests/BadmintonFPSCounterTests.swift
import XCTest
@testable import AndySwissKnife

final class BadmintonFPSCounterTests: XCTestCase {
    func testThirtyFps() {
        let c = FPSCounter(window: 1.0)
        for i in 0..<31 { c.tick(at: Double(i) / 30.0) }   // ticks every 1/30s over ~1s
        XCTAssertEqual(c.fps, 30, accuracy: 1.0)
    }

    func testZeroWithOneTick() {
        let c = FPSCounter()
        c.tick(at: 5.0)
        XCTAssertEqual(c.fps, 0)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test ... -only-testing:AndySwissKnifeTests/BadmintonFPSCounterTests`
Expected: FAIL — `cannot find 'FPSCounter' in scope`.

- [ ] **Step 3: Write the implementation**

```swift
// Sources/Services/Badminton/Analysis/FPSCounter.swift
import Foundation

final class FPSCounter {
    let window: TimeInterval
    private var times: [TimeInterval] = []

    init(window: TimeInterval = 1.0) { self.window = window }

    func tick(at time: TimeInterval) {
        times.append(time)
        let cutoff = time - window
        times.removeAll { $0 < cutoff }
    }

    var fps: Double {
        guard times.count >= 2, let first = times.first, let last = times.last, last > first else { return 0 }
        return Double(times.count - 1) / (last - first)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: same as Step 2. Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/Services/Badminton/Analysis/FPSCounter.swift Tests/BadmintonFPSCounterTests.swift
git commit -m "feat(badminton): rolling FPS counter"
```

---

### Task 4: MotionBlobFinder (pure classical-detection core)

**Files:**
- Create: `Sources/Services/Badminton/Detect/MotionBlobFinder.swift`
- Test: `Tests/BadmintonBlobFinderTests.swift`

**Interfaces:**
- Produces:
  - `struct Blob: Equatable { let point: CGPoint; let area: Int; let peak: UInt8 }`
  - `enum MotionBlobFinder { static func brightestBlob(diff: [UInt8], width: Int, height: Int, threshold: UInt8, minArea: Int, maxArea: Int, near: CGPoint?, searchRadius: Double) -> Blob? }`
  - Finds the brightest diff pixel ≥ `threshold` (preferring pixels within `searchRadius` of `near` when `near != nil`), computes the intensity-weighted centroid over a local window, returns it if its bright-pixel `area` is within `[minArea, maxArea]`. Pure; deterministic.

- [ ] **Step 1: Write the failing test**

```swift
// Tests/BadmintonBlobFinderTests.swift
import XCTest
@testable import AndySwissKnife

final class BadmintonBlobFinderTests: XCTestCase {
    // Build a WxH diff image with a bright square centered at (cx,cy).
    private func image(_ w: Int, _ h: Int, square cx: Int, _ cy: Int, half: Int, value: UInt8) -> [UInt8] {
        var px = [UInt8](repeating: 0, count: w * h)
        for y in (cy - half)...(cy + half) {
            for x in (cx - half)...(cx + half) where x >= 0 && x < w && y >= 0 && y < h {
                px[y * w + x] = value
            }
        }
        return px
    }

    func testFindsBrightSquareCentroid() {
        let w = 64, h = 48
        let img = image(w, h, square: 40, 20, half: 1, value: 255)   // 3x3 bright = area 9
        let blob = MotionBlobFinder.brightestBlob(
            diff: img, width: w, height: h, threshold: 64,
            minArea: 1, maxArea: 200, near: nil, searchRadius: 9999)
        XCTAssertNotNil(blob)
        XCTAssertEqual(blob!.point.x, 40, accuracy: 1.0)
        XCTAssertEqual(blob!.point.y, 20, accuracy: 1.0)
        XCTAssertEqual(blob!.peak, 255)
    }

    func testRejectsTooLargeBlob() {
        let w = 64, h = 48
        let img = image(w, h, square: 32, 24, half: 10, value: 255)  // 21x21 = area 441
        let blob = MotionBlobFinder.brightestBlob(
            diff: img, width: w, height: h, threshold: 64,
            minArea: 1, maxArea: 100, near: nil, searchRadius: 9999)
        XCTAssertNil(blob)
    }

    func testNilWhenBelowThreshold() {
        let w = 32, h = 32
        let img = image(w, h, square: 16, 16, half: 1, value: 40)
        let blob = MotionBlobFinder.brightestBlob(
            diff: img, width: w, height: h, threshold: 64,
            minArea: 1, maxArea: 100, near: nil, searchRadius: 9999)
        XCTAssertNil(blob)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test ... -only-testing:AndySwissKnifeTests/BadmintonBlobFinderTests`
Expected: FAIL — `cannot find 'MotionBlobFinder' in scope`.

- [ ] **Step 3: Write the implementation**

```swift
// Sources/Services/Badminton/Detect/MotionBlobFinder.swift
import CoreGraphics
import Foundation

struct Blob: Equatable {
    let point: CGPoint
    let area: Int
    let peak: UInt8
}

enum MotionBlobFinder {
    static func brightestBlob(
        diff: [UInt8], width: Int, height: Int,
        threshold: UInt8, minArea: Int, maxArea: Int,
        near: CGPoint?, searchRadius: Double
    ) -> Blob? {
        guard diff.count == width * height, width > 0, height > 0 else { return nil }

        // 1) Find the brightest qualifying pixel (optionally near a prior point).
        var peakVal: UInt8 = 0
        var peakX = -1, peakY = -1
        for y in 0..<height {
            let row = y * width
            for x in 0..<width {
                let v = diff[row + x]
                if v < threshold { continue }
                if let n = near {
                    let dx = Double(x) - n.x, dy = Double(y) - n.y
                    if (dx * dx + dy * dy) > searchRadius * searchRadius { continue }
                }
                if v > peakVal { peakVal = v; peakX = x; peakY = y }
            }
        }
        guard peakX >= 0 else { return nil }

        // 2) Flood-fill the connected bright region containing the peak (4-neighbour),
        //    accumulating an intensity-weighted centroid + true pixel area. Measuring the
        //    whole connected component (not a fixed window) is what lets `maxArea` reject
        //    large moving objects like a player's body while keeping the small shuttle.
        var visited = [Bool](repeating: false, count: width * height)
        var stack: [(Int, Int)] = [(peakX, peakY)]
        visited[peakY * width + peakX] = true
        var sumW = 0.0, sumX = 0.0, sumY = 0.0, area = 0
        while let (x, y) = stack.popLast() {
            let v = diff[y * width + x]
            let w = Double(v)
            sumW += w; sumX += w * Double(x); sumY += w * Double(y); area += 1
            if area > maxArea { return nil }   // region already too big -> reject early
            let neighbours = [(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)]
            for (nx, ny) in neighbours where nx >= 0 && nx < width && ny >= 0 && ny < height {
                let idx = ny * width + nx
                if visited[idx] || diff[idx] < threshold { continue }
                visited[idx] = true
                stack.append((nx, ny))
            }
        }
        guard sumW > 0, area >= minArea, area <= maxArea else { return nil }
        return Blob(point: CGPoint(x: sumX / sumW, y: sumY / sumW), area: area, peak: peakVal)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: same as Step 2. Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/Services/Badminton/Detect/MotionBlobFinder.swift Tests/BadmintonBlobFinderTests.swift
git commit -m "feat(badminton): pure motion blob finder over diff buffer"
```

---

### Task 5: Grayscale helper + ShuttleDetector protocol + MotionShuttleDetector

**Files:**
- Create: `Sources/Services/Badminton/Capture/PixelBufferGray.swift`
- Create: `Sources/Services/Badminton/Detect/ShuttleDetector.swift`
- Create: `Sources/Services/Badminton/Detect/MotionShuttleDetector.swift`

**Interfaces:**
- Consumes: `MotionBlobFinder`, `Blob` (Task 4); `ShuttleObservation` (Task 1).
- Produces:
  - `enum PixelBufferGray { static func luma(from pixelBuffer: CVPixelBuffer, downscale: Int) -> (pixels: [UInt8], width: Int, height: Int)? }` — reads the Y plane of a `420f`/`420v` (bi-planar) buffer, optionally subsampling by `downscale`.
  - `protocol ShuttleDetector: AnyObject { func detect(pixelBuffer: CVPixelBuffer, time: TimeInterval) -> ShuttleObservation? }`
  - `final class MotionShuttleDetector: ShuttleDetector { init(downscale: Int = 2, threshold: UInt8 = 28, minArea: Int = 2, maxArea: Int = 120) }` — holds the previous grayscale frame, abs-diffs against the current, runs `MotionBlobFinder`, maps the blob (in downscaled coords) back to full-resolution image pixels, and remembers the last point to bias the next search (`near`).

> This task has **no unit test** — it depends on `CVPixelBuffer` (a device/Core Video type awkward to synthesize in a unit test) and its core logic (`MotionBlobFinder`) is already tested. Verify by a clean build (Step 2).

- [ ] **Step 1: Write the implementation**

```swift
// Sources/Services/Badminton/Capture/PixelBufferGray.swift
import CoreVideo
import Foundation

enum PixelBufferGray {
    /// Reads the luma (Y) plane of a bi-planar YUV buffer, subsampled by `downscale`.
    static func luma(from pixelBuffer: CVPixelBuffer, downscale: Int) -> (pixels: [UInt8], width: Int, height: Int)? {
        let step = max(1, downscale)
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        guard CVPixelBufferGetPlaneCount(pixelBuffer) >= 1,
              let base = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0) else { return nil }
        let srcW = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0)
        let srcH = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0)
        let rowBytes = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)
        let src = base.assumingMemoryBound(to: UInt8.self)

        let dstW = srcW / step, dstH = srcH / step
        guard dstW > 0, dstH > 0 else { return nil }
        var out = [UInt8](repeating: 0, count: dstW * dstH)
        for y in 0..<dstH {
            let srcRow = (y * step) * rowBytes
            let dstRow = y * dstW
            for x in 0..<dstW {
                out[dstRow + x] = src[srcRow + x * step]
            }
        }
        return (out, dstW, dstH)
    }
}
```

```swift
// Sources/Services/Badminton/Detect/ShuttleDetector.swift
import CoreVideo
import Foundation

protocol ShuttleDetector: AnyObject {
    /// Returns a shuttle observation in FULL-resolution image pixels, or nil.
    func detect(pixelBuffer: CVPixelBuffer, time: TimeInterval) -> ShuttleObservation?
}
```

```swift
// Sources/Services/Badminton/Detect/MotionShuttleDetector.swift
import CoreVideo
import CoreGraphics
import Foundation

/// Classical frame-difference shuttle detector. Works for a single fast object
/// against a calm-ish background; replaced by a TrackNetV3 Core ML detector later.
final class MotionShuttleDetector: ShuttleDetector {
    private let downscale: Int
    private let threshold: UInt8
    private let minArea: Int
    private let maxArea: Int

    private var prev: [UInt8]?
    private var prevW = 0
    private var prevH = 0
    private var lastPointDown: CGPoint?

    init(downscale: Int = 2, threshold: UInt8 = 28, minArea: Int = 2, maxArea: Int = 120) {
        self.downscale = downscale
        self.threshold = threshold
        self.minArea = minArea
        self.maxArea = maxArea
    }

    func detect(pixelBuffer: CVPixelBuffer, time: TimeInterval) -> ShuttleObservation? {
        guard let gray = PixelBufferGray.luma(from: pixelBuffer, downscale: downscale) else { return nil }
        defer { prev = gray.pixels; prevW = gray.width; prevH = gray.height }
        guard let p = prev, gray.width == prevW, gray.height == prevH else { return nil }

        var diff = [UInt8](repeating: 0, count: gray.pixels.count)
        for i in 0..<gray.pixels.count {
            let d = Int(gray.pixels[i]) - Int(p[i])
            diff[i] = UInt8(min(255, abs(d)))
        }

        let near = lastPointDown
        let searchRadius = near == nil ? .greatestFiniteMagnitude : Double(max(gray.width, gray.height)) * 0.4
        guard let blob = MotionBlobFinder.brightestBlob(
            diff: diff, width: gray.width, height: gray.height,
            threshold: threshold, minArea: minArea, maxArea: maxArea,
            near: near, searchRadius: searchRadius) else {
            lastPointDown = nil
            return nil
        }
        lastPointDown = blob.point

        // Map downscaled coords back to full-resolution image pixels.
        let full = CGPoint(x: blob.point.x * Double(downscale), y: blob.point.y * Double(downscale))
        let confidence = min(1.0, Double(blob.peak) / 255.0)
        return ShuttleObservation(point: full, confidence: confidence, time: time)
    }
}
```

- [ ] **Step 2: Verify a clean build**

Run: `xcodegen generate && xcodebuild build -project AndySwissKnife.xcodeproj -scheme AndySwissKnife -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add Sources/Services/Badminton/Capture/PixelBufferGray.swift Sources/Services/Badminton/Detect/ShuttleDetector.swift Sources/Services/Badminton/Detect/MotionShuttleDetector.swift
git commit -m "feat(badminton): grayscale luma reader + motion shuttle detector"
```

---

### Task 6: CameraSession

**Files:**
- Create: `Sources/Services/Badminton/Capture/CameraSession.swift`

**Interfaces:**
- Produces:
  - `final class CameraSession: NSObject { var onFrame: ((CVPixelBuffer, TimeInterval) -> Void)?; let session: AVCaptureSession; func configure(fps: Int) async -> Bool; func start(); func stop() }`
  - `configure(fps:)` requests camera authorization, sets up a 1080p `AVCaptureVideoDataOutput` at the requested frame rate, returns `false` if denied/unavailable. Frames are delivered on a background queue via `onFrame` with the buffer presentation time in seconds.

> No unit test (AVFoundation needs a device). Verify by clean build, then on-device after Task 8's OTA publish.

- [ ] **Step 1: Write the implementation**

```swift
// Sources/Services/Badminton/Capture/CameraSession.swift
import AVFoundation
import CoreVideo
import Foundation

// @unchecked Sendable: mutable AV state is confined to the private serial queue;
// onFrame is set once before start(). Required so the @MainActor engine can call
// configure/start/stop without a cross-isolation "sending non-Sendable" error.
final class CameraSession: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    let session = AVCaptureSession()
    var onFrame: ((CVPixelBuffer, TimeInterval) -> Void)?

    private let queue = DispatchQueue(label: "badminton.camera.frames")
    private let output = AVCaptureVideoDataOutput()

    /// Requests access + configures a 1080p video-data output at `fps`. Returns success.
    func configure(fps: Int) async -> Bool {
        let granted = await Self.requestAccess()
        guard granted else { return false }
        return await withCheckedContinuation { cont in
            queue.async {
                cont.resume(returning: self.configureLocked(fps: fps))
            }
        }
    }

    private static func requestAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .video)
        default: return false
        }
    }

    private func configureLocked(fps: Int) -> Bool {
        session.beginConfiguration()
        session.sessionPreset = .hd1920x1080
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration(); return false
        }
        session.addInput(input)

        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: queue)
        guard session.canAddOutput(output) else { session.commitConfiguration(); return false }
        session.addOutput(output)
        session.commitConfiguration()

        // Best-effort frame-rate lock.
        if let format = bestFormat(for: device, fps: fps), (try? device.lockForConfiguration()) != nil {
            device.activeFormat = format
            let duration = CMTime(value: 1, timescale: CMTimeScale(fps))
            device.activeVideoMinFrameDuration = duration
            device.activeVideoMaxFrameDuration = duration
            device.unlockForConfiguration()
        }
        return true
    }

    private func bestFormat(for device: AVCaptureDevice, fps: Int) -> AVCaptureDevice.Format? {
        device.formats.first { f in
            let d = CMVideoFormatDescriptionGetDimensions(f.formatDescription)
            let supportsFps = f.videoSupportedFrameRateRanges.contains { $0.maxFrameRate >= Double(fps) }
            return d.width == 1920 && d.height == 1080 && supportsFps
        }
    }

    func start() { queue.async { if !self.session.isRunning { self.session.startRunning() } } }
    func stop() { queue.async { if self.session.isRunning { self.session.stopRunning() } } }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let t = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
        onFrame?(buffer, t)
    }
}
```

- [ ] **Step 2: Verify a clean build**

Run: `xcodegen generate && xcodebuild build -project AndySwissKnife.xcodeproj -scheme AndySwissKnife -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add Sources/Services/Badminton/Capture/CameraSession.swift
git commit -m "feat(badminton): AVFoundation camera session (1080p, fps lock)"
```

---

### Task 7: BadmintonEngine (conductor)

**Files:**
- Create: `Sources/Services/Badminton/BadmintonEngine.swift`

**Interfaces:**
- Consumes: `CameraSession` (Task 6), `MotionShuttleDetector`/`ShuttleDetector` (Task 5), `ShuttleTrajectory` (Task 1), `ShotDetector` (Task 2), `FPSCounter` (Task 3).
- Produces:
  - `@Observable @MainActor final class BadmintonEngine` with published state: `var trail: [CGPoint]`, `var latestPoint: CGPoint?`, `var fps: Double`, `var shotCount: Int`, `var isRunning: Bool`, `var frameSize: CGSize` (full-res image dimensions for overlay coordinate mapping), and a callback hook `var onShot: ((ShotEvent, ShuttleTrajectory) -> Void)?` used in P2.
  - Methods: `func start() async`, `func stop()`. `start()` configures + starts the camera; each frame runs the detector on a background actor, then hops to main to update state.

> No unit test (it orchestrates the camera). Its building blocks are all unit-tested. Verify by clean build + on-device.

- [ ] **Step 1: Write the implementation**

```swift
// Sources/Services/Badminton/BadmintonEngine.swift
import Observation
import CoreGraphics
import CoreVideo
import Foundation

@Observable
@MainActor
final class BadmintonEngine {
    // Published UI state
    var trail: [CGPoint] = []
    var latestPoint: CGPoint?
    var fps: Double = 0
    var shotCount: Int = 0
    var isRunning = false
    var frameSize: CGSize = .zero
    var cameraDenied = false

    /// Fired on each detected shot (P2 uses this to measure speed).
    var onShot: ((ShotEvent, ShuttleTrajectory) -> Void)?

    let captureFPS: Int
    let camera = CameraSession()
    private let detector: ShuttleDetector
    private let trajectory = ShuttleTrajectory(trailWindow: 1.0, maxGap: 0.3)
    private let shots = ShotDetector()
    private let fpsCounter = FPSCounter()
    private let processQueue = DispatchQueue(label: "badminton.process")

    init(detector: ShuttleDetector = MotionShuttleDetector(), captureFPS: Int = 60) {
        self.detector = detector
        self.captureFPS = captureFPS
        camera.onFrame = { [weak self] buffer, time in
            self?.handleFrame(buffer, time: time)
        }
    }

    func start() async {
        guard !isRunning else { return }
        let ok = await camera.configure(fps: captureFPS)
        guard ok else { cameraDenied = true; return }
        camera.start()
        isRunning = true
    }

    func stop() {
        camera.stop()
        isRunning = false
    }

    // Runs on the camera's delivery queue.
    private nonisolated func handleFrame(_ buffer: CVPixelBuffer, time: TimeInterval) {
        let w = CVPixelBufferGetWidth(buffer)
        let h = CVPixelBufferGetHeight(buffer)
        let obs = detector.detect(pixelBuffer: buffer, time: time)
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.frameSize = CGSize(width: w, height: h)
            self.fpsCounter.tick(at: time)
            self.fps = self.fpsCounter.fps
            guard let obs else { self.latestPoint = nil; return }
            self.trajectory.add(obs)
            self.trail = self.trajectory.trail
            self.latestPoint = obs.point
            let sample = TrajectorySample(point: obs.point, time: obs.time)
            if let shot = self.shots.ingest(sample) {
                self.shotCount = self.shots.shotCount
                self.onShot?(shot, self.trajectory)
            }
        }
    }
}
```

- [ ] **Step 2: Verify a clean build**

Run: `xcodegen generate && xcodebuild build -project AndySwissKnife.xcodeproj -scheme AndySwissKnife -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add Sources/Services/Badminton/BadmintonEngine.swift
git commit -m "feat(badminton): engine wiring camera -> detector -> trajectory/shots"
```

---

### Task 8: Camera preview + overlay + Live view + dashboard wiring + permission

**Files:**
- Create: `Sources/Views/Badminton/CameraPreview.swift`
- Create: `Sources/Views/Badminton/OverlayRenderer.swift`
- Create: `Sources/Views/Badminton/BadmintonView.swift`
- Modify: `Sources/Services/DashboardLayout.swift`
- Modify: `Sources/Views/Dashboard/TodayDashboardView.swift` (`rawCardContent(for:)` and `destination(for:)`)
- Modify: `Sources/Views/SwissKnifeApp.swift` (`Services`)
- Modify: `project.yml` (app target `info.properties`)

**Interfaces:**
- Consumes: `BadmintonEngine` (Task 7), `AppColors`/`AppType`/`ThemedBackground` (`Style.swift`), `Services` (existing).
- Produces: `struct BadmintonView: View { init(services: Services) }`; `services.badminton: BadmintonEngine`.

This task is the first **installable, on-device-testable** deliverable: point at a moving object → live trail + fps. No unit test; verified by clean build + OTA install.

- [ ] **Step 1: Add the camera-usage string to `project.yml`**

In `project.yml`, under `targets: → AndySwissKnife: → info: → properties:`, add this key (alongside the existing `NSCalendarsFullAccessUsageDescription`):

```yaml
        NSCameraUsageDescription: "Swiss Knife uses the camera to track the shuttlecock and measure your shot speed."
```

- [ ] **Step 2: Add the dashboard card case**

In `Sources/Services/DashboardLayout.swift`, add to the `DashboardCard` enum and both switches:

```swift
    case badminton = "badminton"
```
```swift
        case .badminton: return "Badminton"
```
```swift
        case .badminton: return "figure.badminton"
```

- [ ] **Step 3: Wire the card content + destination**

In `Sources/Views/Dashboard/TodayDashboardView.swift`, add a case to `rawCardContent(for:)`:

```swift
        case .badminton:
            GlanceCard(label: "Badminton", primary: "Track", secondary: "Shuttle + speed")
```

and a case to `destination(for:)`:

```swift
        case .badminton: BadmintonView(services: services)
```

- [ ] **Step 4: Add the engine to `Services`**

In `Sources/Views/SwissKnifeApp.swift`, add the property and initialise it (the constructor is cheap and does NOT touch the camera — the view starts/stops it):

```swift
    let badminton: BadmintonEngine
```
```swift
        self.badminton = BadmintonEngine()
```
(Place the assignment anywhere in `Services.init(context:)`, e.g. after `self.weather = ...`.)

- [ ] **Step 5: Write the camera preview**

```swift
// Sources/Views/Badminton/CameraPreview.swift
import SwiftUI
import AVFoundation

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let v = PreviewView()
        v.videoPreviewLayer.session = session
        v.videoPreviewLayer.videoGravity = .resizeAspect
        return v
    }
    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}
```

- [ ] **Step 6: Write the overlay renderer**

`OverlayRenderer` maps full-resolution image points into the preview's displayed rect (aspect-fit) and draws the trail + marker. `imageSize` is `engine.frameSize`; `displaySize` is the SwiftUI canvas size.

```swift
// Sources/Views/Badminton/OverlayRenderer.swift
import SwiftUI

struct OverlayRenderer: View {
    let trail: [CGPoint]
    let latest: CGPoint?
    let imageSize: CGSize
    let accent: Color

    var body: some View {
        Canvas { ctx, size in
            guard imageSize.width > 0, imageSize.height > 0 else { return }
            let scale = min(size.width / imageSize.width, size.height / imageSize.height)
            let offX = (size.width - imageSize.width * scale) / 2
            let offY = (size.height - imageSize.height * scale) / 2
            func map(_ p: CGPoint) -> CGPoint {
                CGPoint(x: offX + p.x * scale, y: offY + p.y * scale)
            }
            if trail.count >= 2 {
                var path = Path()
                path.move(to: map(trail[0]))
                for p in trail.dropFirst() { path.addLine(to: map(p)) }
                ctx.stroke(path, with: .color(accent), lineWidth: 3)
            }
            if let latest {
                let c = map(latest)
                let r: CGFloat = 7
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)),
                         with: .color(accent))
            }
        }
        .allowsHitTesting(false)
    }
}
```

- [ ] **Step 7: Write the Badminton view (Live state)**

```swift
// Sources/Views/Badminton/BadmintonView.swift
import SwiftUI

struct BadmintonView: View {
    let engine: BadmintonEngine

    init(services: Services) { self.engine = services.badminton }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if engine.isRunning {
                CameraPreview(session: engine.camera.session).ignoresSafeArea()
                OverlayRenderer(
                    trail: engine.trail, latest: engine.latestPoint,
                    imageSize: engine.frameSize, accent: AppColors.accent
                ).ignoresSafeArea()
            }

            VStack {
                HStack {
                    Text(String(format: "%.0f FPS", engine.fps))
                    Spacer()
                    Text("SHOTS \(engine.shotCount)")
                }
                .font(AppType.mono)
                .foregroundStyle(.white)
                .padding(8)
                .background(Color.black.opacity(0.55))
                Spacer()
                if engine.cameraDenied {
                    Text("CAMERA ACCESS DENIED — enable it in Settings")
                        .font(AppType.mono).foregroundStyle(.white)
                        .padding(10).background(Color.black.opacity(0.7))
                }
            }
            .padding()
        }
        .navigationTitle("Badminton")
        .navigationBarTitleDisplayMode(.inline)
        .task { await engine.start() }
        .onDisappear { engine.stop() }
    }
}
```

- [ ] **Step 8: Verify a clean build**

Run: `xcodegen generate && xcodebuild build -project AndySwissKnife.xcodeproj -scheme AndySwissKnife -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO`
Expected: BUILD SUCCEEDED.

- [ ] **Step 9: Commit**

```bash
git add Sources/Views/Badminton/ Sources/Services/DashboardLayout.swift Sources/Views/Dashboard/TodayDashboardView.swift Sources/Views/SwissKnifeApp.swift project.yml
git commit -m "feat(badminton): live camera preview + shuttle trail overlay + dashboard section"
```

- [ ] **Step 10: On-device smoke test (after an OTA publish)**

Add the Badminton card from the dashboard editor, open it, grant camera access, and wave a bright object across a calm background. Expected: a trail follows the object; FPS reads ~30–60. (Tune `MotionShuttleDetector` thresholds in later iterations from debug clips.)

---

## P2 — Reference-scale calibration + speed

### Task 9: ReferenceScale

**Files:**
- Create: `Sources/Services/Badminton/Geometry/ReferenceScale.swift`
- Test: `Tests/BadmintonReferenceScaleTests.swift`

**Interfaces:**
- Produces:
  - `struct ReferenceScale: Equatable, Codable { let metersPerPixel: Double }`
  - `init?(p1: CGPoint, p2: CGPoint, realMeters: Double)` — `nil` if the points coincide or `realMeters <= 0`.
  - `func meters(pixels: Double) -> Double`
  - `func meters(from a: CGPoint, to b: CGPoint) -> Double`

- [ ] **Step 1: Write the failing test**

```swift
// Tests/BadmintonReferenceScaleTests.swift
import XCTest
@testable import AndySwissKnife

final class BadmintonReferenceScaleTests: XCTestCase {
    func testScaleFromNetHeight() {
        // 200px segment represents 1.55m -> 0.00775 m/px
        let s = ReferenceScale(p1: CGPoint(x: 100, y: 400), p2: CGPoint(x: 100, y: 200), realMeters: 1.55)
        XCTAssertNotNil(s)
        XCTAssertEqual(s!.metersPerPixel, 1.55 / 200, accuracy: 1e-9)
        XCTAssertEqual(s!.meters(pixels: 400), 1.55 / 200 * 400, accuracy: 1e-9)
    }

    func testMetersBetweenPoints() {
        let s = ReferenceScale(p1: CGPoint(x: 0, y: 0), p2: CGPoint(x: 100, y: 0), realMeters: 1.0)!
        XCTAssertEqual(s.meters(from: CGPoint(x: 0, y: 0), to: CGPoint(x: 0, y: 50)), 0.5, accuracy: 1e-9)
    }

    func testNilOnDegenerate() {
        XCTAssertNil(ReferenceScale(p1: CGPoint(x: 5, y: 5), p2: CGPoint(x: 5, y: 5), realMeters: 1.55))
        XCTAssertNil(ReferenceScale(p1: CGPoint(x: 0, y: 0), p2: CGPoint(x: 10, y: 0), realMeters: 0))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test ... -only-testing:AndySwissKnifeTests/BadmintonReferenceScaleTests`
Expected: FAIL — `cannot find 'ReferenceScale' in scope`.

- [ ] **Step 3: Write the implementation**

```swift
// Sources/Services/Badminton/Geometry/ReferenceScale.swift
import CoreGraphics
import Foundation

struct ReferenceScale: Equatable, Codable {
    let metersPerPixel: Double

    init?(p1: CGPoint, p2: CGPoint, realMeters: Double) {
        guard realMeters > 0 else { return nil }
        let dx = p2.x - p1.x, dy = p2.y - p1.y
        let pixels = (dx * dx + dy * dy).squareRoot()
        guard pixels > 0 else { return nil }
        self.metersPerPixel = realMeters / pixels
    }

    func meters(pixels: Double) -> Double { pixels * metersPerPixel }

    func meters(from a: CGPoint, to b: CGPoint) -> Double {
        let dx = b.x - a.x, dy = b.y - a.y
        return (dx * dx + dy * dy).squareRoot() * metersPerPixel
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: same as Step 2. Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/Services/Badminton/Geometry/ReferenceScale.swift Tests/BadmintonReferenceScaleTests.swift
git commit -m "feat(badminton): one-segment reference scale (pixels<->metres)"
```

---

### Task 10: SpeedEstimator

**Files:**
- Create: `Sources/Services/Badminton/Geometry/SpeedEstimator.swift`
- Test: `Tests/BadmintonSpeedEstimatorTests.swift`

**Interfaces:**
- Consumes: `ReferenceScale` (Task 9), `TrajectorySample` (Task 1).
- Produces:
  - `struct ShotSpeed: Equatable { let metersPerSecond: Double; var kmh: Double { metersPerSecond * 3.6 }; var mph: Double { metersPerSecond * 2.2369362921 } }`
  - `enum SpeedEstimator { static func peakSpeed(samples: [TrajectorySample], from start: TimeInterval, window: TimeInterval, scale: ReferenceScale) -> ShotSpeed? }`
  - Considers samples with `start <= time <= start + window`; for each consecutive pair computes `scale.meters(from:to:) / dt`; returns the peak, or `nil` if fewer than two qualifying samples.

- [ ] **Step 1: Write the failing test**

```swift
// Tests/BadmintonSpeedEstimatorTests.swift
import XCTest
@testable import AndySwissKnife

final class BadmintonSpeedEstimatorTests: XCTestCase {
    func testPeakSpeedConstantVelocity() {
        // 0.01 m/px. 500 px between frames, dt=1/120s -> 5 m * 120 = 600 m/s? scale it down:
        // Use 100 px/frame at 0.01 m/px = 1 m/frame, dt = 1/120 -> 120 m/s.
        let scale = ReferenceScale(p1: CGPoint(x: 0, y: 0), p2: CGPoint(x: 100, y: 0), realMeters: 1.0)! // 0.01 m/px
        let dt = 1.0 / 120.0
        let samples = (0..<6).map { i in
            TrajectorySample(point: CGPoint(x: Double(i) * 100, y: 0), time: Double(i) * dt)
        }
        let speed = SpeedEstimator.peakSpeed(samples: samples, from: 0, window: 0.08, scale: scale)
        XCTAssertNotNil(speed)
        XCTAssertEqual(speed!.metersPerSecond, 120, accuracy: 1.0)
        XCTAssertEqual(speed!.kmh, 432, accuracy: 4.0)
    }

    func testNilWhenTooFewSamples() {
        let scale = ReferenceScale(p1: .zero, p2: CGPoint(x: 100, y: 0), realMeters: 1.0)!
        let samples = [TrajectorySample(point: .zero, time: 0)]
        XCTAssertNil(SpeedEstimator.peakSpeed(samples: samples, from: 0, window: 0.08, scale: scale))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test ... -only-testing:AndySwissKnifeTests/BadmintonSpeedEstimatorTests`
Expected: FAIL — `cannot find 'SpeedEstimator' in scope`.

- [ ] **Step 3: Write the implementation**

```swift
// Sources/Services/Badminton/Geometry/SpeedEstimator.swift
import CoreGraphics
import Foundation

struct ShotSpeed: Equatable {
    let metersPerSecond: Double
    var kmh: Double { metersPerSecond * 3.6 }
    var mph: Double { metersPerSecond * 2.2369362921 }
}

enum SpeedEstimator {
    /// Peak instantaneous speed over samples within [start, start+window].
    static func peakSpeed(samples: [TrajectorySample], from start: TimeInterval,
                          window: TimeInterval, scale: ReferenceScale) -> ShotSpeed? {
        let win = samples.filter { $0.time >= start && $0.time <= start + window }
        guard win.count >= 2 else { return nil }
        var peak = 0.0
        for i in 1..<win.count {
            let dt = win[i].time - win[i - 1].time
            guard dt > 0 else { continue }
            let speed = scale.meters(from: win[i - 1].point, to: win[i].point) / dt
            peak = max(peak, speed)
        }
        guard peak > 0 else { return nil }
        return ShotSpeed(metersPerSecond: peak)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: same as Step 2. Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/Services/Badminton/Geometry/SpeedEstimator.swift Tests/BadmintonSpeedEstimatorTests.swift
git commit -m "feat(badminton): peak post-hit speed estimator"
```

---

### Task 11: BadmintonSettings (persisted scale + units)

**Files:**
- Create: `Sources/Services/Badminton/BadmintonSettings.swift`
- Test: `Tests/BadmintonSettingsTests.swift`

**Interfaces:**
- Consumes: `ReferenceScale` (Task 9).
- Produces:
  - `enum SpeedUnit: String, Codable, CaseIterable { case kmh, mph; var label: String }`
  - `@Observable @MainActor final class BadmintonSettings { static let shared: BadmintonSettings; var scale: ReferenceScale?; var unit: SpeedUnit; func display(_ speed: ShotSpeed) -> String }`
  - Persists `scale` (JSON) + `unit` to `UserDefaults.standard` under `badminton.scale.v1` / `badminton.unit.v1`. `init(defaults:)` for testing.

- [ ] **Step 1: Write the failing test**

```swift
// Tests/BadmintonSettingsTests.swift
import XCTest
@testable import AndySwissKnife

@MainActor
final class BadmintonSettingsTests: XCTestCase {
    private func freshDefaults() -> UserDefaults {
        let d = UserDefaults(suiteName: "badminton.tests")!
        d.removePersistentDomain(forName: "badminton.tests")
        return d
    }

    func testPersistsScaleAndUnit() {
        let d = freshDefaults()
        let s1 = BadmintonSettings(defaults: d)
        s1.scale = ReferenceScale(p1: .zero, p2: CGPoint(x: 100, y: 0), realMeters: 1.55)
        s1.unit = .mph

        let s2 = BadmintonSettings(defaults: d)   // reload
        XCTAssertEqual(s2.scale, s1.scale)
        XCTAssertEqual(s2.unit, .mph)
    }

    func testDisplayFormatsByUnit() {
        let d = freshDefaults()
        let s = BadmintonSettings(defaults: d)
        s.unit = .kmh
        XCTAssertEqual(s.display(ShotSpeed(metersPerSecond: 100)), "360 km/h")
        s.unit = .mph
        XCTAssertEqual(s.display(ShotSpeed(metersPerSecond: 100)), "224 mph")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test ... -only-testing:AndySwissKnifeTests/BadmintonSettingsTests`
Expected: FAIL — `cannot find 'BadmintonSettings' in scope`.

- [ ] **Step 3: Write the implementation**

```swift
// Sources/Services/Badminton/BadmintonSettings.swift
import Observation
import Foundation

enum SpeedUnit: String, Codable, CaseIterable {
    case kmh, mph
    var label: String { self == .kmh ? "km/h" : "mph" }
}

@Observable
@MainActor
final class BadmintonSettings {
    static let shared = BadmintonSettings(defaults: .standard)

    private let defaults: UserDefaults
    private static let scaleKey = "badminton.scale.v1"
    private static let unitKey = "badminton.unit.v1"

    var scale: ReferenceScale? { didSet { persistScale() } }
    var unit: SpeedUnit { didSet { defaults.set(unit.rawValue, forKey: Self.unitKey) } }

    init(defaults: UserDefaults) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.scaleKey) {
            self.scale = try? JSONDecoder().decode(ReferenceScale.self, from: data)
        } else {
            self.scale = nil
        }
        self.unit = SpeedUnit(rawValue: defaults.string(forKey: Self.unitKey) ?? "") ?? .kmh
    }

    private func persistScale() {
        if let scale, let data = try? JSONEncoder().encode(scale) {
            defaults.set(data, forKey: Self.scaleKey)
        } else {
            defaults.removeObject(forKey: Self.scaleKey)
        }
    }

    func display(_ speed: ShotSpeed) -> String {
        let value = unit == .kmh ? speed.kmh : speed.mph
        return "\(Int(value.rounded())) \(unit.label)"
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: same as Step 2. Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/Services/Badminton/BadmintonSettings.swift Tests/BadmintonSettingsTests.swift
git commit -m "feat(badminton): persisted reference scale + speed-unit settings"
```

---

### Task 12: Calibration UI + speed readout + engine speed wiring

**Files:**
- Create: `Sources/Views/Badminton/CalibrationView.swift`
- Create: `Sources/Views/Badminton/SpeedReadout.swift`
- Modify: `Sources/Services/Badminton/BadmintonEngine.swift` (publish `lastSpeed`/`maxSpeed`, consume settings)
- Modify: `Sources/Views/Badminton/BadmintonView.swift` (Calibrate state + readout)

**Interfaces:**
- Consumes: `BadmintonSettings` (Task 11), `SpeedEstimator`/`ShotSpeed` (Task 10), `ReferenceScale` (Task 9), `BadmintonEngine.onShot` (Task 7).
- Produces: `BadmintonEngine.lastSpeed: ShotSpeed?`, `BadmintonEngine.maxSpeed: ShotSpeed?`; `struct CalibrationView` (tap two points → `ReferenceScale`); `struct SpeedReadout`.

No unit test (UI + orchestration); the speed math is already tested. Verify by clean build + on-device.

- [ ] **Step 1: Extend the engine to compute speed on each shot**

Add to `BadmintonEngine` published state and wire `onShot` in `init` (replace the existing `init`'s `onShot` default of nil). Add:

```swift
    var lastSpeed: ShotSpeed?
    var maxSpeed: ShotSpeed?
    var settings: BadmintonSettings = .shared
```

and at the end of `init(detector:captureFPS:)`, add:

```swift
        onShot = { [weak self] shot, trajectory in
            guard let self, let scale = self.settings.scale else { return }
            guard let speed = SpeedEstimator.peakSpeed(
                samples: trajectory.samples, from: shot.time, window: 0.08, scale: scale) else { return }
            self.lastSpeed = speed
            if speed.metersPerSecond > (self.maxSpeed?.metersPerSecond ?? 0) { self.maxSpeed = speed }
        }
```

(Note: `onShot` is already invoked from `handleFrame` on the main actor in Task 7.)

- [ ] **Step 2: Write the calibration view**

```swift
// Sources/Views/Badminton/CalibrationView.swift
import SwiftUI

struct CalibrationView: View {
    let session: AVCaptureSession
    let imageSize: CGSize
    let realMeters: Double            // default 1.55 (net height)
    let onDone: (ReferenceScale) -> Void
    let onCancel: () -> Void

    @State private var points: [CGPoint] = []   // in display coords

    var body: some View {
        GeometryReader { geo in
            ZStack {
                CameraPreview(session: session).ignoresSafeArea()
                Canvas { ctx, _ in
                    for p in points {
                        ctx.fill(Path(ellipseIn: CGRect(x: p.x - 6, y: p.y - 6, width: 12, height: 12)),
                                 with: .color(AppColors.accent))
                    }
                    if points.count == 2 {
                        var path = Path(); path.move(to: points[0]); path.addLine(to: points[1])
                        ctx.stroke(path, with: .color(AppColors.accent), lineWidth: 3)
                    }
                }
                .ignoresSafeArea()
                VStack {
                    Text("TAP THE TOP OF EACH NET POST (1.55 m)")
                        .font(AppType.mono).foregroundStyle(.white)
                        .padding(8).background(Color.black.opacity(0.6))
                    Spacer()
                    HStack {
                        Button("CANCEL") { onCancel() }
                        Spacer()
                        Button("RESET") { points.removeAll() }
                        Spacer()
                        Button("CONFIRM") { confirm(displaySize: geo.size) }
                            .disabled(points.count != 2)
                    }
                    .font(AppType.mono).foregroundStyle(.white)
                    .padding().background(Color.black.opacity(0.6))
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { loc in
                if points.count >= 2 { points.removeAll() }
                points.append(loc)
            }
        }
    }

    /// Convert the two display-space taps to image pixels (inverse of the aspect-fit map).
    private func confirm(displaySize: CGSize) {
        guard points.count == 2, imageSize.width > 0 else { return }
        let scaleF = min(displaySize.width / imageSize.width, displaySize.height / imageSize.height)
        let offX = (displaySize.width - imageSize.width * scaleF) / 2
        let offY = (displaySize.height - imageSize.height * scaleF) / 2
        func toImage(_ p: CGPoint) -> CGPoint {
            CGPoint(x: (p.x - offX) / scaleF, y: (p.y - offY) / scaleF)
        }
        guard let s = ReferenceScale(p1: toImage(points[0]), p2: toImage(points[1]), realMeters: realMeters) else { return }
        onDone(s)
    }
}

import AVFoundation
```

- [ ] **Step 3: Write the speed readout**

```swift
// Sources/Views/Badminton/SpeedReadout.swift
import SwiftUI

struct SpeedReadout: View {
    let last: ShotSpeed?
    let max: ShotSpeed?
    let settings: BadmintonSettings

    var body: some View {
        HStack(spacing: 16) {
            field("LAST", last)
            field("MAX", max)
        }
        .padding(10)
        .background(Color.black.opacity(0.6))
    }

    @ViewBuilder private func field(_ label: String, _ speed: ShotSpeed?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(AppType.tiny).foregroundStyle(.white.opacity(0.7))
            Text(speed.map { settings.display($0) } ?? "—")
                .font(AppType.mono).foregroundStyle(AppColors.accent)
        }
    }
}
```

- [ ] **Step 4: Add the Calibrate state + readout to `BadmintonView`**

Replace the body of `BadmintonView` with a state machine that adds a Calibrate sheet and the readout. Full replacement:

```swift
// Sources/Views/Badminton/BadmintonView.swift
import SwiftUI

struct BadmintonView: View {
    let engine: BadmintonEngine
    @State private var calibrating = false

    init(services: Services) { self.engine = services.badminton }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if engine.isRunning {
                CameraPreview(session: engine.camera.session).ignoresSafeArea()
                OverlayRenderer(
                    trail: engine.trail, latest: engine.latestPoint,
                    imageSize: engine.frameSize, accent: AppColors.accent
                ).ignoresSafeArea()
            }

            VStack {
                HStack {
                    Text(String(format: "%.0f FPS", engine.fps))
                    Spacer()
                    Text("SHOTS \(engine.shotCount)")
                }
                .font(AppType.mono).foregroundStyle(.white)
                .padding(8).background(Color.black.opacity(0.55))

                Spacer()

                if engine.settings.scale == nil {
                    Text("CALIBRATE TO SHOW SPEED")
                        .font(AppType.mono).foregroundStyle(.white)
                        .padding(8).background(Color.black.opacity(0.6))
                } else {
                    SpeedReadout(last: engine.lastSpeed, max: engine.maxSpeed, settings: engine.settings)
                }

                HStack {
                    Button("CALIBRATE") { calibrating = true }
                    Spacer()
                    Button(engine.settings.unit.label.uppercased()) { toggleUnit() }
                }
                .font(AppType.mono).foregroundStyle(.white)
                .padding().background(Color.black.opacity(0.55))
            }
            .padding()

            if engine.cameraDenied {
                Text("CAMERA ACCESS DENIED — enable it in Settings")
                    .font(AppType.mono).foregroundStyle(.white)
                    .padding(10).background(Color.black.opacity(0.7))
            }
        }
        .navigationTitle("Badminton")
        .navigationBarTitleDisplayMode(.inline)
        .task { await engine.start() }
        .onDisappear { engine.stop() }
        .fullScreenCover(isPresented: $calibrating) {
            CalibrationView(
                session: engine.camera.session,
                imageSize: engine.frameSize,
                realMeters: 1.55,
                onDone: { scale in engine.settings.scale = scale; calibrating = false },
                onCancel: { calibrating = false }
            )
        }
    }

    private func toggleUnit() {
        engine.settings.unit = engine.settings.unit == .kmh ? .mph : .kmh
    }
}
```

- [ ] **Step 5: Verify a clean build**

Run: `xcodegen generate && xcodebuild build -project AndySwissKnife.xcodeproj -scheme AndySwissKnife -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO`
Expected: BUILD SUCCEEDED.

- [ ] **Step 6: Commit**

```bash
git add Sources/Views/Badminton/CalibrationView.swift Sources/Views/Badminton/SpeedReadout.swift Sources/Views/Badminton/BadmintonView.swift Sources/Services/Badminton/BadmintonEngine.swift
git commit -m "feat(badminton): net-height calibration + per-shot speed readout"
```

- [ ] **Step 7: On-device smoke test (after an OTA publish)**

Calibrate by tapping the two net-post tops, then hit a shuttle. Expected: `LAST`/`MAX` show plausible km/h on each detected shot; the unit button toggles km/h ⁄ mph.

---

## Task 13: CI unit-test step

**Files:**
- Create: `.github/workflows/ios-tests.yml`

`publish-ios.yml` is **main-only** and does the OTA build, so adding tests there
would not run on feature branches. Instead, add a **standalone** test workflow
triggered on every push + PR (any branch) — this is the maintainer's primary
verification channel and gives branch feedback without triggering an OTA publish.

**Interfaces:** none (CI only).

- [ ] **Step 1: Create the test workflow**

Create `.github/workflows/ios-tests.yml`:

```yaml
name: iOS Unit Tests

on:
  push:
  pull_request:

concurrency:
  group: ios-tests-${{ github.ref }}
  cancel-in-progress: true

jobs:
  test:
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v4
      - name: Select latest Xcode (Swift 6 / project format 77 needs Xcode 16+)
        run: sudo xcode-select -s "$(ls -d /Applications/Xcode_*.app | sort -V | tail -1)"
      - name: Install xcodegen
        run: brew install xcodegen
      - name: Prepare sources (Secrets stub — gitignored but a declared build input)
        run: cp Config/Secrets.swift.example Config/Secrets.swift
      - name: Generate Xcode project
        run: xcodegen generate
      - name: Run unit tests
        run: |
          set -euo pipefail
          SIM="$(xcrun simctl list devices available | grep -oE 'iPhone [0-9]+( Pro)?' | sort -V | tail -1)"
          xcodebuild test \
            -project AndySwissKnife.xcodeproj -scheme AndySwissKnife \
            -destination "platform=iOS Simulator,name=${SIM:-iPhone 16}" \
            -only-testing:AndySwissKnifeTests \
            CODE_SIGNING_ALLOWED=NO
```

> `macos-15` ships Xcode 16 with iOS 18 simulators (incl. iPhone 16). Building
> the test target compiles the app target too, so this also catches app-target
> compile errors on every branch push.

- [ ] **Step 2: Commit**

```bash
git add .github/workflows/publish-ios.yml
git commit -m "ci: run AndySwissKnife unit tests on every push"
```

- [ ] **Step 3: Verify in CI**

Push the branch (or merge to `main`) and confirm the "Run unit tests" step passes with all `Badminton*Tests` green.

---

## Self-review against the spec

- **Spec coverage:** Camera (`CameraSession`, Task 6) · classical `MotionShuttleDetector` + protocol (Tasks 4–5) · `ShuttleTrajectory` (Task 1) · `ShotDetector` + shot count (Task 2) · fps HUD (Task 3, surfaced Task 8) · live trail overlay (Task 8) · reference-scale calibration, net-height default 1.55 m (Tasks 9, 12) · `SpeedEstimator` peak post-hit speed (Task 10) · km/h⁄mph units, estimate framing (Tasks 11–12) · dashboard section + permission, app-target-only, OTA-safe (Task 8) · pure-logic unit tests + CI test job (all test tasks + Task 13). **Deferred by design (not in this plan):** YOLO pose, TrackNetV3 Core ML (the P0 plan), court homography, in/out, scoring, doubles, debug-record (moved to the P0/scoring plans — see note below).
- **Placeholder scan:** every code step contains complete code; no TBD/stubs.
- **Type consistency:** `ShuttleObservation`/`TrajectorySample` (Task 1) flow into Tasks 2, 5, 7, 10; `ReferenceScale` (Task 9) used by Tasks 10–12; `ShotSpeed` (Task 10) used by Tasks 11–12; `BadmintonEngine.onShot: (ShotEvent, ShuttleTrajectory) -> Void` defined Task 7, consumed Task 12; `engine.camera.session` exposed via the `CameraSession.session` property used by Tasks 8 and 12.

> **Scope note:** the spec's P1 also lists a **debug-record** toggle. It was deliberately deferred out of this plan to keep P1 shippable sooner; it belongs with the TrackNet-tuning work (it exists to capture clips for detector iteration). Add it at the start of the P0/TrackNet plan, before detector-threshold tuning. Flagging it here so it is not silently dropped.

---

## Next plans (not this document)

1. **P0 — Model conversion** (Python/coremltools): YOLO11-pose + TrackNetV3 → validated `.mlpackage`s; add `TrackNetShuttleDetector` behind the `ShuttleDetector` protocol; add the debug-record toggle for tuning.
2. **P3+ — Court phase** (Swift): homography calibration, TOP VIEW minimap, in/out landing (120 fps buffer), rally state machine, `BadmintonScorekeeper`, assisted scoreboard, match history.
