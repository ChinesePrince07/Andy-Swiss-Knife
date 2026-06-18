"""Sweep detection-density levers (confidence threshold + middle-channel ensemble)
on real footage to find a config that detects MORE of the shuttle while staying
clean. One model pass per segment; configs decoded instantly from stored heatmaps."""
import sys, numpy as np, math
from study import load_model, read_frames, ema_provider, run, decode, W, H, SEQ

def metrics(coords):
    fs = sorted(coords)
    jumps = [math.hypot(coords[b][0]-coords[a][0], coords[b][1]-coords[a][1])
             for a, b in zip(fs, fs[1:]) if b - a == 1]
    j = np.array(jumps) if jumps else np.array([0.0])
    return len(fs), float(np.percentile(j, 90)), float((j > 0.12*W).mean())

def decode_configs(hm, thresh):
    """Return dict name->{frame:(x,y,peak)} for ch4-single and mid-ensemble(3,4,5)."""
    maxw = len(hm) - 1
    single, ens = {}, {}
    for w in range(len(hm)):
        d = decode(hm[w][4], thresh=thresh)
        if d: single[w+4] = d
    for f in range(len(hm) + SEQ):
        acc, n = None, 0
        for p in (3, 4, 5):
            w = f - p
            if 0 <= w <= maxw:
                acc = hm[w][p].astype(np.float32) if acc is None else acc + hm[w][p]
                n += 1
        if n:
            d = decode(acc/n, thresh=thresh)
            if d: ens[f] = d
    return {"ch4": single, "mid-ens(3,4,5)": ens}

def sweep(model, video, start, n, label):
    frames = read_frames(video, start, n)
    hm = run(model, frames, ema_provider(frames))
    print(f"\n=== {label}: frames {start}..{start+n} ({len(frames)} read) ===")
    print(f"{'config':18s} {'thresh':>6s} {'det':>4s} {'p90jump':>8s} {'teleport':>9s}")
    for thresh in (0.25, 0.30, 0.35, 0.40, 0.50):
        for name, coords in decode_configs(hm, thresh).items():
            det, p90, tele = metrics(coords)
            print(f"{name:18s} {thresh:6.2f} {det:4d} {p90:7.1f}px {tele*100:7.1f}%")

if __name__ == "__main__":
    VIDEO = "/home/andy/.claude/uploads/65d7204f-9b85-494c-8775-d448ffccc68f/aa5c725f-ssstwitter.com_1781725936737.mp4"
    model = load_model()
    sweep(model, VIDEO, 240, 150, "segment A")
    sweep(model, VIDEO, 600, 150, "segment B (held-out)")
