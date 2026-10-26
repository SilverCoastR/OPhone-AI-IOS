#!/usr/bin/env python3
from pathlib import Path
from PIL import Image
import json
import sys

source = Path(sys.argv[1])
root = Path(__file__).resolve().parents[1] / "OPhoneAI" / "Resources" / "Assets.xcassets"
app = root / "AppIcon.appiconset"
logo = root / "OPhoneLogo.imageset"
app.mkdir(parents=True, exist_ok=True)
logo.mkdir(parents=True, exist_ok=True)

original = Image.open(source).convert("RGBA")
background = Image.new("RGBA", original.size, (12, 12, 14, 255))
background.alpha_composite(original)
image = background.convert("RGB")

specification = [
    ("iphone", "20x20", "2x", 40), ("iphone", "20x20", "3x", 60),
    ("iphone", "29x29", "2x", 58), ("iphone", "29x29", "3x", 87),
    ("iphone", "40x40", "2x", 80), ("iphone", "40x40", "3x", 120),
    ("iphone", "60x60", "2x", 120), ("iphone", "60x60", "3x", 180),
    ("ipad", "20x20", "1x", 20), ("ipad", "20x20", "2x", 40),
    ("ipad", "29x29", "1x", 29), ("ipad", "29x29", "2x", 58),
    ("ipad", "40x40", "1x", 40), ("ipad", "40x40", "2x", 80),
    ("ipad", "76x76", "1x", 76), ("ipad", "76x76", "2x", 152),
    ("ipad", "83.5x83.5", "2x", 167), ("ios-marketing", "1024x1024", "1x", 1024),
]
entries = []
for idiom, size, scale, pixels in specification:
    filename = f"icon-{pixels}.png"
    image.resize((pixels, pixels), Image.Resampling.LANCZOS).save(app / filename, optimize=True)
    entries.append({"idiom": idiom, "size": size, "scale": scale, "filename": filename})
(app / "Contents.json").write_text(json.dumps({"images": entries, "info": {"author": "xcode", "version": 1}}, indent=2), encoding="utf-8")

logos = []
for scale, pixels in [("1x", 256), ("2x", 512), ("3x", 768)]:
    filename = f"logo-{pixels}.png"
    image.resize((pixels, pixels), Image.Resampling.LANCZOS).save(logo / filename, optimize=True)
    logos.append({"idiom": "universal", "scale": scale, "filename": filename})
(logo / "Contents.json").write_text(json.dumps({"images": logos, "info": {"author": "xcode", "version": 1}}, indent=2), encoding="utf-8")
(root / "Contents.json").write_text(json.dumps({"info": {"author": "xcode", "version": 1}}, indent=2), encoding="utf-8")
