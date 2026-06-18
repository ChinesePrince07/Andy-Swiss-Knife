"""Validate the SHIPPED detector config (EMA bg + 3-window ensemble @ 0.25) on a
NEW clip: detection density/cleanliness (generalization) + shot detection + the
RELATIVE peak speed per shot (a smash should spike higher than a clear — verifiable
without absolute ground truth)."""
import sys, math, numpy as np
from study import load_model, read_frames, ema_provider, run, decode, W, H, SEQ

VIDEO, START, N = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
FULLW = FULLH = None

def ensemble_track(hm, frames):
    maxw = len(hm) - 1
    out = {}
    for f in range(len(frames)):
        acc, n = None, 0
        for p in (3, 4, 5):
            w = f - p
            if 0 <= w <= maxw:
                acc = hm[w][p].astype(np.float32) if acc is None else acc + hm[w][p]; n += 1
        if n:
            d = decode(acc/n, thresh=0.25)
            if d: out[f] = (d[0]*FULLW/W, d[1]*FULLH/H)
    return out

model = load_model()
frames = read_frames(VIDEO, START, N)
FULLW, FULLH = frames[0].shape[1], frames[0].shape[0]
print(f"{VIDEO.split('/')[-1]}: {len(frames)} frames @ {FULLW}x{FULLH}")
hm = run(model, frames, ema_provider(frames))
track = ensemble_track(hm, frames)

# Detection metrics (generalization).
fs = sorted(track)
jumps = [math.hypot(track[b][0]-track[a][0], track[b][1]-track[a][1]) for a,b in zip(fs,fs[1:]) if b-a==1]
j = np.array(jumps) if jumps else np.array([0.0])
print(f"detections: {len(fs)}/{len(frames)}  p90jump={np.percentile(j,90):.1f}px  "
      f"teleport={ (j>0.12*FULLW).mean()*100:.1f}%")

# Full pipeline (pixel space): gate -> ShotDetector -> per-shot peak px/s.
FPS = 25.0
samples = [{"t": f/FPS, "x": track[f][0], "y": track[f][1]} for f in fs]
last=None; misses=0; prev=None; runDir=0; runLen=0; lastStroke=0; lastShotT=-9e9; win=[]; shots=[]
def peak_pxps(ts, window=0.12):
    w=[s for s in win if ts<=s['t']<=ts+window]; pk=0
    for i in range(1,len(w)):
        dt=w[i]['t']-w[i-1]['t']
        if dt<=0: continue
        v=math.hypot(w[i]['x']-w[i-1]['x'],w[i]['y']-w[i-1]['y'])/dt
        if v <= max(FULLW,FULLH)*0.3*30*1.2:   # generous gate-equiv cap
            pk=max(pk,v)
    return pk
for s in samples:
    p=(s['x'],s['y']); t=s['t']
    if last is None: last=(p,t); acc=True
    else:
        dt=max(t-last[1],1/120); dist=math.hypot(p[0]-last[0][0],p[1]-last[0][1])
        if dist>max(FULLW,FULLH)*0.3*(dt*30) and misses<5: misses+=1; acc=False
        else: last=(p,t); misses=0; acc=True
    if not acc: continue
    win.append(s); shot=None
    if prev:
        dt=t-prev['t']
        if dt>0:
            vx=(s['x']-prev['x'])/dt; dr=1 if vx>=200 else (-1 if vx<=-200 else 0)  # 200px/s @640w
            if dr!=0:
                if dr==runDir: runLen+=1
                else: runDir=dr; runLen=1
                if runLen==3 and dr!=lastStroke and t-lastShotT>=0.12:
                    lastStroke=dr; lastShotT=t; shot=t
    prev=s
    if shot is not None:
        shots.append((round(t,2), round(peak_pxps(t))))
print(f"shots: {len(shots)}  ->  (time, peak px/s):")
for tt, v in shots: print(f"    t={tt:5.2f}s   {v:5d} px/s")
if shots:
    vmax=max(v for _,v in shots); vmed=int(np.median([v for _,v in shots]))
    print(f"peak px/s: max={vmax}  median={vmed}  ratio max/median={vmax/max(vmed,1):.1f}x  "
          f"(a real smash should stand well above the median shot)")
