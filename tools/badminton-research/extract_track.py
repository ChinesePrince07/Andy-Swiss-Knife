"""Extract the clean shuttle trajectory from the match clip using the SHIPPED
Swift config (EMA background + 3-window middle-channel ensemble @ threshold 0.25),
and dump it as a test fixture so a Swift CI test can replay it through the real
downstream pipeline."""
import sys, json, numpy as np
from study import load_model, read_frames, ema_provider, run, decode, W, H, SEQ

VIDEO = "/home/andy/.claude/uploads/65d7204f-9b85-494c-8775-d448ffccc68f/aa5c725f-ssstwitter.com_1781725936737.mp4"
START, N, FPS, THRESH = 240, 300, 60.0, 0.25
FULLW, FULLH = 1280, 720
OUT = sys.argv[1]

model = load_model()
frames = read_frames(VIDEO, START, N)
print(f"got {len(frames)} frames; running EMA-bg pass ...")
hm = run(model, frames, ema_provider(frames))
maxw = len(hm) - 1

samples = []
for f in range(len(frames)):
    # Ensemble the SAME frame from 3 overlapping windows: ch3 of window f-3,
    # ch4 of f-4, ch5 of f-5 (matches TrackNetShuttleDetector).
    acc, n = None, 0
    for p in (3, 4, 5):
        w = f - p
        if 0 <= w <= maxw:
            acc = hm[w][p].astype(np.float32) if acc is None else acc + hm[w][p]
            n += 1
    if not n:
        continue
    d = decode(acc / n, thresh=THRESH)
    if not d:
        continue
    x, y, peak = d
    samples.append({"frame": f, "t": round(f / FPS, 5),
                    "x": round(x * FULLW / W, 2), "y": round(y * FULLH / H, 2),
                    "peak": round(float(peak), 3)})
samples.sort(key=lambda r: r["frame"])
json.dump({"video": "twitter_demo", "fps": FPS, "width": FULLW, "height": FULLH,
           "config": "EMA_bg_midEnsemble345_th0.25_shipped", "samples": samples},
          open(OUT, "w"), indent=0)
print(f"wrote {len(samples)} samples to {OUT}")
