# Badminton shuttle-detection research harness

Offline tooling to study and improve TrackNetV3 shuttle detection **without a
device** — the iOS app can't be run locally (Linux dev box, no Mac), so we
validate detector changes by running the real PyTorch model on real footage and
measuring tracking noise, then port the winning config to Swift.

## Why this exists

The Swift live detector (`Sources/Services/Badminton/Detect/TrackNetShuttleDetector.swift`)
was very noisy ("red lines bouncing around"). `study.py` reproduced and root-caused
it offline.

## Key finding (2026-06-19)

TrackNetV3 outputs one heatmap **per frame** of its 8-frame input window. The Swift
detector decoded **channel 7 — the newest frame, at the edge of the window with no
future context** — which the model predicts least reliably (the reference temporal
ensemble weights edge frames `1/20` vs `4/20` for the middle).

Measured on the 1280×720 match clip (frame-to-frame jump = noise):

| background | decode channel | p90 jump | teleport% | detections |
|---|---|---|---|---|
| EMA (old Swift) | **ch7 (old)** | **203 px** | 19% | 69/150 |
| EMA | **ch4 (fix)** | **22 px** | 9% | 53/150 |
| sigma-delta | ch7 | 228 px | 21% | 79/150 |
| median | ch3 | 5 px | 6% | 38/150 |

→ **The decode channel dominates.** ch7→ch4 (same background) cut p90 jitter ~10×.
Background type is secondary (median helps further but trades detections + needs
frame buffering). Fix shipped: decode the middle channel (4) and timestamp the
observation with that frame's time (~50 ms latency at 60 fps) to keep velocities
correct.

## Environment

The model, checkpoint, and reference code live in `/tmp/tnv3` (ephemeral — set up
during the TrackNetV3 → Core ML conversion):

- Reference repo: **qaz812345/TrackNetV3** (`model.py`, `dataset.py`, `predict.py`,
  `utils/`) — checkpoint `ckpts/TrackNet_best.pt` (seq_len=8, bg_mode=concat).
- venv: `/tmp/tnv3/.venv` (torch 2.7 CPU, opencv, pillow, matplotlib).

If `/tmp/tnv3` is gone, re-clone TrackNetV3, fetch its pretrained TrackNet
checkpoint, and `pip install torch torchvision opencv-python pillow matplotlib`.

## Run

```bash
cd /tmp/tnv3   # needs model.py + ckpts/ alongside
.venv/bin/python study.py <video.mp4> <start_frame> <num_frames>
# default footage: the @mountain_mal Twitter badminton clip (1280x720@60)
```

Outputs: a noise-metrics table (bg × channel matrix), `study_xt.png` (shuttle x
over time per config), and `study_overlay.mp4` (side-by-side Swift-vs-fix overlay).

`sweep.py` runs the threshold × ensemble density sweep; `extract_track.py` dumps a
fixture for the Swift e2e test; `validate_clip.py` runs the full pipeline on any
clip. Get fresh footage with `uv pip install yt-dlp` then
`python -m yt_dlp -f "mp4[height<=720]" --download-sections "*0-25" "ytsearch1:<query>"`.

## Findings log

- **Shipped:** middle-frame decode (vs edge) → ~10× less jitter; 3-window ensemble
  (ch3/4/5) @ threshold 0.25 → 2–4× detections, still clean; physical speed cap.
- **Generalization (verified):** on a *different* match clip (Prannoy vs Weng,
  640×360@25, never tuned on) the shipped config detected **200/220 = 91% with 0%
  teleport** — the fix is not over-fit to the Twitter clip.
- **Frame rate (tested, rejected):** subsampling the 60 fps clip to 30/20 fps barely
  raised detection (63→68→77%) but **doubled/quadrupled teleport** (4.8→10.5→23%).
  Keep processing every frame at 60 fps.
- **Orientation:** `ShotDetector` keys on *horizontal* velocity reversals (correct
  for the app's side-on setup). On an *end-on* broadcast clip (shuttle moves
  vertically) it under-detects shots — fine for the intended setup, fragile otherwise.

## Open frontier (needs data we don't have offline)

- **Absolute velocity accuracy** can't be validated without a known scale
  (in-app net-height calibration) + ground-truth speed (a broadcast speed-gun clip,
  or the user's calibrated footage). On available clips speeds are *plausible* and
  physically bounded, but not validated against a reference.
- Levers if such data arrives: median-quality background, wider/smarter speed
  window for the post-smash blur gap, gap-tolerant / 2-axis shot detection.
