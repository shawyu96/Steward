#!/usr/bin/env python3
"""Steward app icon — pure black gear, bold, crisp on white."""

import os
import subprocess
import math
import sys
import shutil
from PIL import Image, ImageDraw

SIZE = 1024
ICONSET = "/tmp/Steward.iconset"
OUTPUT = os.path.join(os.path.dirname(__file__), "..", "Resources", "Steward.icns")

os.makedirs(ICONSET, exist_ok=True)

img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)

WHITE = (255, 255, 255, 255)
BLACK = (0, 0, 0, 255)

draw.rounded_rectangle([0, 0, SIZE, SIZE], radius=224, fill=WHITE)

# ── Bold gear — simple, crisp ──
cx, cy = SIZE // 2, SIZE // 2 - 10

# Outer circle radius
outer_r = 350
tooth_w = 80   # tooth width at base
tooth_h = 65   # how far teeth stick out
tooth_count = 6

# Build gear outline
pts = []
for i in range(tooth_count):
    angle = math.radians(i * 360 / tooth_count - 90)
    next_angle = math.radians((i + 1) * 360 / tooth_count - 90)
    mid_angle = math.radians((i + 0.5) * 360 / tooth_count - 90)

    # Start at outer circle between teeth
    x0 = cx + outer_r * math.cos(angle)
    y0 = cy + outer_r * math.sin(angle)
    
    # Tooth left edge
    tooth_angle = angle + math.radians(tooth_w / outer_r / 2)
    x1 = cx + (outer_r + tooth_h) * math.cos(tooth_angle)
    y1 = cy + (outer_r + tooth_h) * math.sin(tooth_angle)
    
    # Tooth flat top
    x2 = cx + (outer_r + tooth_h) * math.cos(mid_angle - math.radians(tooth_w / outer_r / 2))
    y2 = cy + (outer_r + tooth_h) * math.sin(mid_angle - math.radians(tooth_w / outer_r / 2))
    x3 = cx + (outer_r + tooth_h) * math.cos(mid_angle + math.radians(tooth_w / outer_r / 2))
    y3 = cy + (outer_r + tooth_h) * math.sin(mid_angle + math.radians(tooth_w / outer_r / 2))
    
    # Tooth right edge
    x4 = cx + outer_r * math.cos(next_angle - math.radians(tooth_w / outer_r / 2))
    y4 = cy + outer_r * math.sin(next_angle - math.radians(tooth_w / outer_r / 2))

    pts.extend([(x0, y0), (x1, y1), (x2, y2), (x3, y3), (x4, y4)])

# Draw gear as filled polygon
draw.polygon(pts, fill=BLACK)

# Inner circle cutout (white)
inner_r = 160
draw.ellipse(
    [cx - inner_r, cy - inner_r, cx + inner_r, cy + inner_r],
    fill=WHITE
)

# Thin accent ring around center
ring_r = inner_r - 15
draw.ellipse(
    [cx - ring_r, cy - ring_r, cx + ring_r, cy + ring_r],
    outline=BLACK, width=8
)

# Small solid center dot
dot_r = 30
draw.ellipse(
    [cx - dot_r, cy - dot_r, cx + dot_r, cy + dot_r],
    fill=BLACK
)

# Save
sizes = [
    (16, "icon_16x16.png"), (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"), (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"), (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"), (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"), (1024, "icon_512x512@2x.png"),
]

for w, name in sizes:
    img.resize((w, w), Image.LANCZOS).save(os.path.join(ICONSET, name), "PNG")

subprocess.run(["iconutil", "-c", "icns", ICONSET, "-o", OUTPUT],
               capture_output=True, text=True, check=True)
shutil.rmtree(ICONSET)
print(f"✅ {OUTPUT}")
