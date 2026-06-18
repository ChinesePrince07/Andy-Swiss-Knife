"""
Offline study of TrackNetV3 shuttle detection noise, to find why the Swift
live integration is noisy. Runs the real PyTorch model on real badminton footage
under controlled configs that isolate each suspected cause.

Configs (all decode with the SAME decoder = Swift's: peak + 0.5 threshold +
3-window weighted centroid):
  C  Swift-actual : EMA background (alpha=0.02) + decode channel 7 (newest frame)
  B  median bg    : median background          + decode channel 7
  E  median+mid   : median background          + decode channel 4 (middle frame)

C vs B isolates the BACKGROUND. B vs E isolates the EDGE-FRAME choice.
"""
import sys, cv2, numpy as np, torch
from PIL import Image
from model import TrackNet

W, H, SEQ = 512, 288, 8
ALPHA = 0.02
THRESH = 0.5

VIDEO = sys.argv[1] if len(sys.argv) > 1 else \
    "/home/andy/.claude/uploads/65d7204f-9b85-494c-8775-d448ffccc68f/aa5c725f-ssstwitter.com_1781725936737.mp4"
START = int(sys.argv[2]) if len(sys.argv) > 2 else 240
N = int(sys.argv[3]) if len(sys.argv) > 3 else 150

def load_model():
    ck = torch.load("ckpts/TrackNet_best.pt", map_location="cpu", weights_only=False)
    m = TrackNet(in_dim=27, out_dim=8); m.load_state_dict(ck["model"]); m.eval()
    print("param_dict:", ck.get("param_dict"))
    return m

def read_frames(path, start, n):
    cap = cv2.VideoCapture(path)
    cap.set(cv2.CAP_PROP_POS_FRAMES, start)
    out = []
    for _ in range(n):
        ok, f = cap.read()
        if not ok: break
        out.append(f[..., ::-1].copy())   # BGR->RGB
    cap.release()
    return out  # list of HxWx3 RGB uint8 (native res)

def resized_chw(rgb_uint8):
    """RGB uint8 HxWx3 native -> (3,H,W) float 0..1 at model res (PIL like reference)."""
    img = np.array(Image.fromarray(rgb_uint8).resize((W, H)))
    return np.moveaxis(img, -1, 0).astype(np.float32) / 255.0

def median_bg(path, sample=300):
    cap = cv2.VideoCapture(path)
    total = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    step = max(1, total // sample)
    frames = []
    for i in range(0, total, step):
        cap.set(cv2.CAP_PROP_POS_FRAMES, i)
        ok, f = cap.read()
        if not ok: break
        frames.append(f[..., ::-1])
    cap.release()
    med = np.median(np.array(frames), axis=0).astype(np.uint8)   # HxWx3 RGB
    return resized_chw(med)   # (3,H,W) 0..1

def decode(hm, thresh=THRESH, win=3):
    """hm: (H,W) 0..1 -> (x,y,peak) or None. Swift's decoder."""
    peak = float(hm.max())
    if peak < thresh: return None
    py, px = np.unravel_index(int(hm.argmax()), hm.shape)
    cut = thresh * 0.5
    y0, y1 = max(0, py-win), min(H, py+win+1)
    x0, x1 = max(0, px-win), min(W, px+win+1)
    patch = hm[y0:y1, x0:x1].copy()
    patch[patch < cut] = 0
    s = patch.sum()
    if s <= 0: return (float(px), float(py), peak)
    ys, xs = np.mgrid[y0:y1, x0:x1]
    return (float((patch*xs).sum()/s), float((patch*ys).sum()/s), peak)

def run(model, frames, bg_provider):
    """Run model over sliding windows. bg_provider(i)-> (3,H,W) bg for window ending at frame i.
       Returns per-window heatmaps list aligned to window start index."""
    chw = [resized_chw(f) for f in frames]      # precompute resized frames
    heatmaps = []   # heatmaps[w] = (8,H,W) for window frames w..w+7
    for w in range(len(frames) - SEQ + 1):
        seq = np.stack(chw[w:w+SEQ], 0).reshape(SEQ*3, H, W)   # (24,H,W)
        bg = bg_provider(w + SEQ - 1)                          # bg as of newest frame in window
        x = np.concatenate([bg, seq], 0)[None]                 # (1,27,H,W)
        with torch.no_grad():
            y = model(torch.from_numpy(x).float()).numpy()[0]  # (8,H,W)
        heatmaps.append(y.astype(np.float32))
    return heatmaps

def ema_provider(frames):
    chw = [resized_chw(f) for f in frames]
    bg = chw[0].copy()
    series = [bg.copy()]
    for i in range(1, len(chw)):
        bg = bg*(1-ALPHA) + chw[i]*ALPHA
        series.append(bg.copy())
    return lambda i: series[i]

def sigma_delta_provider(frames, step=0.01):
    """Per-pixel running-median estimator: bg += clip(frame-bg, -step, step).
       O(1) memory, robust to transient movers (shuttle/players) unlike EMA."""
    chw = [resized_chw(f) for f in frames]
    bg = chw[0].copy()
    series = [bg.copy()]
    for i in range(1, len(chw)):
        bg = bg + np.clip(chw[i] - bg, -step, step)
        series.append(bg.copy())
    return lambda i: series[i]

def metrics(name, coords):
    """coords: dict frame->(x,y,peak). Print detection rate + jump stats."""
    fs = sorted(coords)
    det = len(fs)
    jumps = []
    for a, b in zip(fs, fs[1:]):
        if b - a == 1:
            (x0,y0,_), (x1,y1,_) = coords[a], coords[b]
            jumps.append(np.hypot(x1-x0, y1-y0))
    jumps = np.array(jumps) if jumps else np.array([0.0])
    teleport = float((jumps > 0.12*W).mean())   # >12% of width in one frame
    peaks = np.array([c[2] for c in coords.values()])
    print(f"{name:22s} det={det:3d}/{N}  medJump={np.median(jumps):6.1f}px "
          f"p90Jump={np.percentile(jumps,90):6.1f}px  teleport={teleport*100:4.1f}%  "
          f"medPeak={np.median(peaks):.2f}")
    return dict(det=det, medJump=float(np.median(jumps)), p90=float(np.percentile(jumps,90)),
                teleport=teleport, frames=fs)

def main():
    model = load_model()
    print(f"Reading {N} frames from frame {START} of {VIDEO.split('/')[-1]} ...")
    frames = read_frames(VIDEO, START, N)
    print(f"Got {len(frames)} frames. Building median background ...")
    med = median_bg(VIDEO)
    med_provider = lambda i: med

    print("Running median-bg pass ...")
    hm_med = run(model, frames, med_provider)
    print("Running EMA-bg pass ...")
    hm_ema = run(model, frames, ema_provider(frames))
    print("Running sigma-delta-bg pass ...")
    hm_sd = run(model, frames, sigma_delta_provider(frames))

    weight = np.array([1,2,3,4,4,3,2,1], np.float32); weight /= weight.sum()

    # Derive per-frame coords for each config.
    C, B, E, E3, A = {}, {}, {}, {}, {}   # frame -> (x,y,peak)
    maxw = len(hm_med) - 1
    for w in range(len(hm_med)):
        d7e = decode(hm_ema[w][7])
        if d7e: C[w+7] = d7e
        d7m = decode(hm_med[w][7])
        if d7m: B[w+7] = d7m
        d4m = decode(hm_med[w][4])
        if d4m: E[w+4] = d4m
        d3m = decode(hm_med[w][3])
        if d3m: E3[w+3] = d3m
    # A: full reference temporal ensemble (median bg) -- gold upper bound (7-frame latency).
    for f in range(len(frames)):
        acc, tot = None, 0.0
        for w in range(max(0, f-7), min(maxw, f) + 1):
            p = f - w
            if 0 <= p < SEQ:
                acc = hm_med[w][p]*weight[p] if acc is None else acc + hm_med[w][p]*weight[p]
                tot += weight[p]
        if acc is not None:
            d = decode(acc/tot)
            if d: A[f] = d

    # bg x channel matrix: isolate whether channel-fix alone suffices, and if
    # cheap sigma-delta bg matches the median.
    EMA3, EMA4, SD7, SD3, SD4 = {}, {}, {}, {}, {}
    for w in range(len(hm_med)):
        d = decode(hm_ema[w][3]);  d and EMA3.__setitem__(w+3, d)
        d = decode(hm_ema[w][4]);  d and EMA4.__setitem__(w+4, d)
        d = decode(hm_sd[w][7]);   d and SD7.__setitem__(w+7, d)
        d = decode(hm_sd[w][3]);   d and SD3.__setitem__(w+3, d)
        d = decode(hm_sd[w][4]);   d and SD4.__setitem__(w+4, d)

    print("\n=== NOISE METRICS (lower jump/teleport = cleaner track) ===")
    print("-- channel sweep (EMA bg = current Swift bg) --")
    metrics("C  EMA,ch7 (Swift)", C)
    metrics("   EMA,ch4", EMA4)
    metrics("   EMA,ch3", EMA3)
    print("-- bg sweep at ch3 (the channel fix) --")
    metrics("   EMA,ch3", EMA3)
    metrics("   sigmaDelta,ch3", SD3)
    metrics("   median,ch3", E3)
    print("-- reference points --")
    metrics("   sigmaDelta,ch7", SD7)
    metrics("   median,ch4", E)
    metrics("   median,ensemble", A)

    # x(t) plot for visual.
    try:
        import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
        series = [("C Swift (EMA, ch7)", C, "red"), ("E median, ch4 (mid)", E, "green"),
                  ("A median, full ensemble", A, "blue")]
        fig, ax = plt.subplots(len(series), 1, figsize=(11, 8), sharex=True)
        for a, (nm, r, col) in zip(ax, series):
            fs = sorted(r); a.plot(fs, [r[f][0] for f in fs], ".-", color=col, ms=3, lw=0.7)
            a.set_ylabel("shuttle x (px)"); a.set_title(nm); a.set_ylim(0, W); a.grid(alpha=0.3)
        ax[-1].set_xlabel("frame")
        plt.tight_layout(); plt.savefig("study_xt.png", dpi=90)
        print("Saved plot: /tmp/tnv3/study_xt.png")
    except Exception as e:
        print("plot skipped:", e)

    # Side-by-side overlay video: C (Swift) | E (fix). Draw a short trail.
    try:
        sx, sy = frames[0].shape[1]/W, frames[0].shape[0]/H
        def draw(img, coords, f, col):
            out = img.copy()
            for k in range(max(0, f-6), f+1):
                if k in coords:
                    x, y, _ = coords[k]; p = int(x*sx), int(y*sy)
                    cv2.circle(out, p, 6 if k == f else 3, col, -1 if k == f else 1)
            return out
        h, wpx = frames[0].shape[:2]
        vw = cv2.VideoWriter("study_overlay.mp4", cv2.VideoWriter_fourcc(*"mp4v"), 20, (wpx*2, h))
        for f in range(len(frames)):
            left = draw(frames[f][..., ::-1], C, f, (0,0,255))    # RGB->BGR, red
            right = draw(frames[f][..., ::-1], E, f, (0,255,0))   # green
            cv2.putText(left, "SWIFT (EMA, ch7)", (20,40), cv2.FONT_HERSHEY_SIMPLEX, 1.0, (0,0,255), 2)
            cv2.putText(right, "FIX (median, ch4)", (20,40), cv2.FONT_HERSHEY_SIMPLEX, 1.0, (0,255,0), 2)
            vw.write(np.concatenate([left, right], 1))
        vw.release()
        print("Saved overlay: /tmp/tnv3/study_overlay.mp4")
    except Exception as e:
        print("overlay skipped:", e)

if __name__ == "__main__":
    main()
