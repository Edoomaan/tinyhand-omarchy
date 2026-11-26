#!/usr/bin/env python3
"""Build the plugin's assets from a TinyHand checkout (MIT, nilbuild/tinyhand).

usage: tools/prepare-assets.py <path-to-tinyhand-checkout>

Writes assets/hands/<id>.webp (1024 px tall, lossless), assets/thumbs/<id>.webp,
assets/sounds/tap_<id>.wav and Hands.js (per-image metrics). The metrics port
HandAsset.measure (Sources/TinyHand/PointerStyle.swift:252-323) so the plugin
doesn't scan pixels at runtime.
"""
import json
import pathlib
import shutil
import subprocess
import sys

# id, title, ink (PointerStyle.swift:23-60). Ink.purple/Ink.red come from Ink.swift.
PURPLE, RED = "#8754F2", "#FF291F"
BUILT_IN = [
    ("lavender", "Lavender toy", PURPLE), ("glove", "Cursor glove", PURPLE),
    ("coral", "Coral vinyl", RED), ("plush", "Plush", "#2F86F0"),
    ("robot", "Robot", "#16A87A"), ("pink", "Bubblegum", "#EE4F98"),
    ("blue", "Sky", "#2F86F0"), ("mint", "Mint", "#16A87A"),
    ("lemon", "Lemon", "#F2B705"), ("black", "Midnight", "#1D1D21"),
    ("chrome", "Chrome", "#6B7380"), ("holo", "Holo", PURPLE),
    ("fuzzy", "Fuzzy", PURPLE), ("wood", "Wood", "#9A5E2C"),
    ("marble", "Marble", "#6B7380"), ("terrazzo", "Terrazzo", "#F0561D"),
    ("glass", "Glass", "#1597E5"), ("jelly", "Jelly", "#A33FE6"),
    ("pastel", "Pastel", "#EE4F98"), ("pixel", "Pixel", "#1D1D21"),
    ("lowpoly", "Low poly", PURPLE), ("knit", "Knit", PURPLE),
    ("skeleton", "Skeleton", "#9A5E2C"), ("astro", "Astronaut", "#2F86F0"),
    ("space", "Space", RED), ("monster", "Monster", "#3E9E2E"),
    ("water", "Water", "#1597E5"), ("lava", "Lava", "#F0561D"),
    ("grass", "Grass", "#3E9E2E"), ("cactus", "Cactus", "#3E9E2E"),
    ("choco", "Chocolate", "#9A5E2C"), ("cloud", "Cloud", "#2F86F0"),
    ("mech", "Mech", "#F0561D"), ("neon", "Neon", "#E0309A"),
    ("leaf", "Leaf", "#3E9E2E"), ("cookie", "Gingerbread", "#9A5E2C"),
]
SOUNDS = ["thock", "click", "tock", "clack", "typewriter", "snap", "wood", "pop",
          "boop", "blip", "coin", "pew", "squeak", "quack", "chirp"]

OPAQUE = bytes(1 if b > 128 else 0 for b in range(256))


def alpha_rows(png):
    out = subprocess.run(["magick", str(png), "-alpha", "extract", "-depth", "8", "gray:-"],
                         check=True, capture_output=True).stdout
    w, h = map(int, subprocess.run(["magick", "identify", "-format", "%w %h", str(png)],
                                   check=True, capture_output=True, text=True).stdout.split())
    return w, h, [out[y * w:(y + 1) * w].translate(OPAQUE) for y in range(h)]


def measure(png):
    w, h, rows = alpha_rows(png)
    counts = [r.count(1) for r in rows]

    def center(y):
        r = rows[y]
        lo, hi = r.find(1), r.rfind(1)
        return 0.5 if lo < 0 else (lo + hi) / 2 / w

    top = next(y for y, c in enumerate(counts) if c > 0)
    max_w = max(counts[top:min(h, top + int(0.45 * h))])
    fist = next(y for y in range(top, h) if counts[y] > 0.6 * max_w)
    wrist = next(y for y in range(fist, h) if counts[y] < 0.35 * max_w)
    rod_w = counts[min(h - 1, wrist + h // 50)]
    last_row = max(y for y, c in enumerate(counts) if c > 0)
    start = min(h - 1, wrist + h // 33)
    rod_end = next((y for y in range(start, h) if counts[y] > 1.8 * rod_w), last_row)
    xs = [x for y in range(top, wrist) for x in (rows[y].find(1), rows[y].rfind(1)) if x >= 0]
    return {
        "aspect": w / h,
        "handTop": max(0, top - 0.004 * h) / h,
        "tip": top / h,
        "wrist": wrist / h,
        "rodEnd": rod_end / h,
        "tipX": center(min(h - 1, top + h // 200)),
        "rodX": center((wrist + rod_end) // 2),
        "handMinX": min(xs) / w,
        "handMaxX": max(xs) / w,
    }


def thumbnail(src, dst, m):
    # Square crop around the hand, 1.06 margin, 128 px (PointerStyle.swift:213-236).
    w, h = map(int, subprocess.run(["magick", "identify", "-format", "%w %h", str(src)],
                                   check=True, capture_output=True, text=True).stdout.split())
    side = max((m["handMaxX"] - m["handMinX"]) * w, (m["wrist"] - m["handTop"]) * h) * 1.06
    cx = (m["handMinX"] + m["handMaxX"]) / 2 * w
    cy = (m["handTop"] + m["wrist"]) / 2 * h
    x0, y0 = max(0, int(cx - side / 2)), max(0, int(cy - side / 2))
    s = int(side)
    subprocess.run(["magick", str(src), "-crop", f"{s}x{s}+{x0}+{y0}", "+repage",
                    "-resize", "128x128", "-define", "webp:lossless=true", str(dst)], check=True)


def main():
    src = pathlib.Path(sys.argv[1]) / "assets"
    root = pathlib.Path(__file__).resolve().parent.parent
    hands_dir, thumbs_dir, sounds_dir = (root / "assets" / d for d in ("hands", "thumbs", "sounds"))
    for d in (hands_dir, thumbs_dir, sounds_dir):
        d.mkdir(parents=True, exist_ok=True)
    styles = []
    for sid, title, ink in BUILT_IN:
        png = src / f"hand_{sid}.png"
        m = measure(png)
        subprocess.run(["magick", str(png), "-resize", "x1024", "-define", "webp:lossless=true",
                        str(hands_dir / f"{sid}.webp")], check=True)
        thumbnail(png, thumbs_dir / f"{sid}.webp", m)
        styles.append({"id": sid, "title": title, "ink": ink, **{k: round(v, 5) for k, v in m.items()}})
        print(sid, file=sys.stderr)
    for s in SOUNDS:
        shutil.copy(src / "sounds" / f"tap_{s}.wav", sounds_dir / f"tap_{s}.wav")
    (root / "Hands.js").write_text(
        "// Generated by tools/prepare-assets.py from TinyHand's PNGs. Do not edit.\n"
        "\n"
        f"var hands = {json.dumps(styles, indent=1)}\n\n"
        f"var sounds = {json.dumps(SOUNDS)}\n\n"
        "if (typeof module !== \"undefined\") module.exports = { hands, sounds }\n")


if __name__ == "__main__":
    main()
