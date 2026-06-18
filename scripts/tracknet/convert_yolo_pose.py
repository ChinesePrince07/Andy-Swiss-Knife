#!/usr/bin/env python3
"""
Convert YOLO11-pose (Ultralytics, AGPL-3.0) to Core ML for on-device player pose
tracking in the Andy-Swiss-Knife "Badminton" feature.

  input  "image"     : 640x640 RGB (Core ML imageType; /255 scale baked in)
  output [1,56,8400] : per-anchor [cx,cy,w,h, conf, 17*(kx,ky,kv)] in 640 px,
                       decoded + NMS'd on-device (see YOLOPoseDecoder.swift).
  keypoints (COCO-17): nose, eyes, ears, shoulders, elbows, wrists, hips, knees, ankles.

Reproduce (Python 3.11). NOTE: a matched torch/torchvision pair is required, and
coremltools 8.x (9.0 hits a torch-frontend cast bug converting this model):
  uv venv --python 3.11 .venv
  uv pip install --python .venv/bin/python torch==2.7.0 torchvision==0.22.0 --index-url https://download.pytorch.org/whl/cpu
  uv pip install --python .venv/bin/python ultralytics "coremltools==8.2"
  .venv/bin/python convert_yolo_pose.py
Then copy yolo11n-pose.mlpackage to Sources/Services/Badminton/ML/YOLO11Pose.mlpackage.
"""
from ultralytics import YOLO

YOLO("yolo11n-pose.pt").export(format="coreml", imgsz=640, nms=False, half=True)
print("saved yolo11n-pose.mlpackage")
