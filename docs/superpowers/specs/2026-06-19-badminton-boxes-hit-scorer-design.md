# Badminton — player boxes + P1/P2 labels, hit effect, auto-scorer

**Date:** 2026-06-19
**Repo:** Andy-Swiss-Knife (iOS)
**Status:** Approved design, implementing
**Builds on:** `2026-06-18-badminton-scorekeeper-design.md` (this is the manual/auto
scoring layer brought forward, minus the court-gated in/out landing call).

## Summary

Three additions to the live Badminton tracker:

1. **Player boxes + P1/P2 labels** — draw each detected player's bounding box and a
   stable `P1`/`P2` tag over the camera preview.
2. **Hit effect** — an expanding ring + `HIT` pulse at the shuttle every time the
   shot detector fires, so hit detection is visually verifiable live.
3. **Auto-scorer** — an experimental, no-court scorer: when a rally ends, award the
   point to whoever hit the shuttle last. Simple two-counter tally (no game/match/
   serve logic) with first-class manual `+/−` override and reset.

All on-device, client-only. No backend, entitlement, or pipeline changes.

## Decisions (resolved during brainstorming)

| Question | Decision |
| --- | --- |
| P1/P2 identity | By image x — left = **P1**, right = **P2** (side-on camera splits L/R). Two highest-confidence boxes if extras are detected. |
| Scoring input | **Auto-detect winner** (owner's choice), paired with manual `+/−` override since auto is unreliable without a court. |
| "Who won" logic | **Last-hitter-wins** on a rally-end timeout (rides the already-detected hit signal; degrades gracefully). Not landing-side (needs court). |
| Scoring rules | **Simple tally** — two integer counters, no game/match/serve logic. |
| Hit effect | Expanding ring + `HIT` tag at the hit point, ~0.45 s, in yellow. Also the live debug view of the scorer's input signal. |

## Architecture

Pure, single-purpose, CI-testable units (no device needed) + thin view/engine glue.

**Scoring (pure, unit-tested)**
- `PlayerSide` — `enum { p1, p2 }` (`Sendable`).
- `AutoScorer` (`Sources/Services/Badminton/Scoring/AutoScorer.swift`) — state
  machine. `registerHit(side:time:)` records a hit; `tick(now:)` awards **+1 to the
  last hitter's side** when no new hit has arrived for `endTimeout` (default 1.2 s)
  and the rally had at least `minHits` (default 2) hits. `adjust(_:by:)` (clamped
  ≥ 0) and `reset()` for manual correction. Deterministic; main-actor owned.

**Analysis (pure, unit-tested)**
- `PlayerLabeler` (`Sources/Services/Badminton/Analysis/PlayerLabeler.swift`) —
  `assign(_ poses:imageWidth:) -> [LabeledPose]` picks the two highest-score poses,
  orders by `box.midX` (left = P1), labels a lone player by image half; and
  `side(ofHitAt:players:imageWidth:) -> PlayerSide` attributes a hit by the shuttle
  x vs the net midline (midpoint of the two players, else image center).
- `LabeledPose` — `{ side: PlayerSide, pose: PlayerPose }` (`Sendable`).

**Presentation**
- `AspectFit` (`Sources/Views/Badminton/AspectFit.swift`) — shared image→view
  aspect-fit mapping (used by the overlay and the hit flash; DRYs the duplicated
  scale/offset math).
- `OverlayRenderer` — now takes `players: [LabeledPose]`; draws skeleton **+ box +
  P1/P2 label** per player, colored by side (P1 green, P2 cyan).
- `ShotFlash` (`Sources/Views/Badminton/ShotFlash.swift`) — animates the hit ring,
  keyed on an incrementing shot id so each new hit re-fires.
- `Scoreboard` (`Sources/Views/Badminton/Scoreboard.swift`) — `P1 n — m P2` panel
  with `+/−` per side and `RESET`.
- `BadmintonEngine` — on each frame: label players, attribute + register any hit,
  `tick` the scorer, publish `players`, `score`, `lastShot`. Adds `adjustScore`,
  `resetScore`. Scorer mutated on the main actor only.

## Data flow

camera → `FrameProcessor` (unchanged: yields `poses` + `shot`) → `apply()` on main:
`PlayerLabeler.assign` → publish `players`; if `shot`: `PlayerLabeler.side` →
`AutoScorer.registerHit` + bump `lastShot`; `AutoScorer.tick(now:)` → publish
`score`. View draws `OverlayRenderer(players:)` + `ShotFlash(marker:)` + `Scoreboard`.

## Testing

- `AutoScorerTests` — last-hitter award after timeout; no award before timeout or
  below `minHits`; rally resets after award (no double-award); `adjust` clamps at 0;
  `reset` clears scores + rally.
- `PlayerLabelerTests` — left=P1/right=P2 regardless of input order; picks two
  highest-score; lone player by half; hit-side by player midline and by image-center
  fallback.
- Verified via `ios-tests.yml` on push (no local Mac); then OTA build for the
  on-court visual check of boxes/labels, the hit ring, and auto-scoring.

## Non-goals

- No court homography / in-out landing / official rules / games / serve tracking
  (still deferred to the court phase). Auto-scoring is explicitly experimental.
