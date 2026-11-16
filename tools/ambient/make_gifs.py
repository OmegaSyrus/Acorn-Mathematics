"""Turns tools/stills/ambient_stills frames into small looping GIFs.

    python3 tools/ambient/make_gifs.py /tmp/shots /tmp/gifs [--width=640]
"""
import os
import sys

from PIL import Image

src, dst = sys.argv[1], sys.argv[2]
width = 640
for a in sys.argv[3:]:
    if a.startswith("--width="):
        width = int(a[8:])
os.makedirs(dst, exist_ok=True)
for name in sorted(os.listdir(src)):
    d = os.path.join(src, name)
    if not os.path.isdir(d):
        continue
    frames = []
    for f in sorted(os.listdir(d)):
        im = Image.open(os.path.join(d, f)).convert("RGB")
        im = im.resize((width, width * im.height // im.width), Image.LANCZOS)
        frames.append(im.quantize(colors=128, method=Image.Quantize.MEDIANCUT))
    if frames:
        out = os.path.join(dst, name + ".gif")
        frames[0].save(out, save_all=True, append_images=frames[1:], duration=50, loop=0, optimize=True)
        print(out, len(frames), os.path.getsize(out) // 1024, "KB")
