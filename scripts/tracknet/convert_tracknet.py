#!/usr/bin/env python3
"""
Convert the official TrackNetV3 tracking module to Core ML for on-device shuttle
detection in the Andy-Swiss-Knife "Badminton" feature.

Source repo : https://github.com/qaz812345/TrackNetV3   (MIT license)
Checkpoint  : ckpts/TrackNet_best.pt  ->  seq_len=8, bg_mode='concat'

  input  "frames"   : [1, 27, 288, 512]  = [ median_bg(3ch), 8 RGB frames(24ch) ]
                      each channel resized to 512x288 (WxH), channels-first, /255
  output "heatmaps" : [1,  8, 288, 512]  sigmoid, one heatmap per input frame
                      (live: take the newest frame's heatmap -> peak -> shuttle xy)

Reproduce (Linux or macOS, Python 3.11):
  uv venv --python 3.11 .venv
  uv pip install --python .venv/bin/python torch --index-url https://download.pytorch.org/whl/cpu
  uv pip install --python .venv/bin/python coremltools gdown numpy
  git clone --depth 1 https://github.com/qaz812345/TrackNetV3 tnv3 && cd tnv3
  gdown 1CfzE87a0f6LhBp0kniSl1-89zaLCZ8cA -O ckpts.zip && unzip -o ckpts.zip
  cp /path/to/convert_tracknet.py . && .venv/bin/python convert_tracknet.py
Then copy TrackNet.mlpackage to Sources/Services/Badminton/ML/.

Note: coremltools converts on Linux but cannot RUN .mlmodel there. Numerical
validation against PyTorch happens on a macOS CI runner (see the badminton plan).
"""
import torch
import coremltools as ct
from model import TrackNet   # from the cloned TrackNetV3 repo

IN_DIM, OUT_DIM, H, W = 27, 8, 288, 512

ckpt = torch.load("ckpts/TrackNet_best.pt", map_location="cpu", weights_only=False)
pd = ckpt["param_dict"]
assert pd["seq_len"] == 8 and pd["bg_mode"] == "concat", f"unexpected config: {pd}"

model = TrackNet(in_dim=IN_DIM, out_dim=OUT_DIM)
model.load_state_dict(ckpt["model"])
model.eval()

example = torch.rand(1, IN_DIM, H, W)
traced = torch.jit.trace(model, example)

mlmodel = ct.convert(
    traced,
    inputs=[ct.TensorType(name="frames", shape=(1, IN_DIM, H, W))],
    outputs=[ct.TensorType(name="heatmaps")],
    minimum_deployment_target=ct.target.iOS17,
    compute_precision=ct.precision.FLOAT16,
    convert_to="mlprogram",
)
mlmodel.short_description = (
    "TrackNetV3 tracking module (seq_len=8, bg_mode=concat). "
    "frames[1,27,288,512]=[median_bg(3),8 RGB frames(24)] /255 -> heatmaps[1,8,288,512] sigmoid."
)
mlmodel.save("TrackNet.mlpackage")
print("saved TrackNet.mlpackage")
