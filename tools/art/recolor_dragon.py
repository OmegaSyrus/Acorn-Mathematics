# Recolours the robot dragon for the store (Terrence 2026-11-06): steel body ->
# body hue, teal lights and green wings -> glow hue.
#   python3 -I tools/art/recolor_dragon.py art/lava/robodragon.png art/heroes
import sys, colorsys
from PIL import Image
src, outdir = sys.argv[1], sys.argv[2]
# name: (body hue deg, body sat, body value scale, glow hue deg, glow sat scale)
LOOKS = {
    "red":    (358, 0.85, 1.08, 45,  1.0),   # red plates, gold glow
    "black":  (240, 0.12, 0.48, 0,   1.0),   # charcoal plates, red glow
    "green":  (125, 0.62, 1.02, 55,  1.0),   # green plates, yellow glow
    "purple": (272, 0.62, 1.05, 185, 1.0),   # purple plates, teal glow
    "pink":   (325, 0.60, 1.18, 290, 0.8),   # pink plates, violet glow
}
im = Image.open(src).convert("RGBA")
for name, (bh, bs, bv, gh, gs) in LOOKS.items():
    out = im.copy(); px = out.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a == 0: continue
            h, s, v = colorsys.rgb_to_hsv(r/255, g/255, b/255)
            hd = h * 360
            if v < 0.12:  # outline stays dark
                continue
            if 130 <= hd <= 200 and s > 0.35:      # teal lights and green wings
                h2, s2, v2 = gh/360, min(1, s*gs), v
            else:                                  # steel plates
                h2, s2, v2 = bh/360, min(1, bs*(0.5 + s*1.5)), min(1, v*bv)
            rr, gg, bb = colorsys.hsv_to_rgb(h2, s2, v2)
            px[x, y] = (round(rr*255), round(gg*255), round(bb*255), a)
    out.save(f"{outdir}/robodragon-{name}.png")
print("ok")
