"""Extract the clean shuttle trajectory from the match clip using the SHIPPED
Swift config (EMA background + decode middle channel 4), and dump it as a test
fixture so a Swift CI test can replay it through the real downstream pipeline."""
import sys, json
from study import load_model, read_frames, ema_provider, run, decode, W, H

VIDEO = "/home/andy/.claude/uploads/65d7204f-9b85-494c-8775-d448ffccc68f/aa5c725f-ssstwitter.com_1781725936737.mp4"
START, N, FPS, CH = 240, 300, 60.0, 4     # CH=4 = TrackNetShuttleDetector.decodeChannel
FULLW, FULLH = 1280, 720
OUT = sys.argv[1]

model = load_model()
frames = read_frames(VIDEO, START, N)
print(f"got {len(frames)} frames; running EMA-bg pass ...")
hm = run(model, frames, ema_provider(frames))

samples = []
for w in range(len(hm)):
    d = decode(hm[w][CH])
    if not d:
        continue
    x, y, peak = d
    f = w + CH                                  # channel CH -> frame index (w+CH)
    samples.append({"frame": f, "t": round(f / FPS, 5),
                    "x": round(x * FULLW / W, 2), "y": round(y * FULLH / H, 2),
                    "peak": round(float(peak), 3)})
samples.sort(key=lambda r: r["frame"])
json.dump({"video": "twitter_demo", "fps": FPS, "width": FULLW, "height": FULLH,
           "config": "EMA_bg_ch4_shipped", "samples": samples},
          open(OUT, "w"), indent=0)
print(f"wrote {len(samples)} samples to {OUT}")
