#!/usr/bin/env python3
"""wall-palettes.py <картинка> <схема> <режим> [контраст]

Для пикера обоев: какие главные цвета matugen видит на обоях и какая из каждого
получится палитра. Печатает строки:  P <цвет-источник> <primary> <secondary> <tertiary> <primary_container>
Ничего не применяет (--dry-run).
"""
import json
import re
import subprocess
import sys

img, scheme, mode = sys.argv[1:4]
contrast = sys.argv[4] if len(sys.argv) > 4 else "0"


def run(args):
    try:
        return subprocess.run(args, capture_output=True, text=True, timeout=15).stdout
    except Exception:
        return ""


def palette(args):
    try:
        col = json.loads(run(args + ["-t", scheme, "-m", mode, "--contrast", contrast, "--dry-run", "-j", "hex", "-q"]))["colors"]
        return [col[k]["default"]["color"] for k in ("primary", "secondary", "tertiary", "primary_container")]
    except Exception:
        return None


srcs = []
for c in re.findall(r"#[0-9a-fA-F]{6}", run(["matugen", "image", img, "--show-source-colors"])):
    if c.lower() not in srcs:
        srcs.append(c.lower())

for c in srcs[:5]:
    p = palette(["matugen", "color", "hex", c])
    if p:
        print("\t".join(["P", c] + p), flush=True)

if not srcs:   # серые/однотонные обои — matugen берёт запасной цвет сам
    p = palette(["matugen", "image", img, "--prefer", "saturation"])
    if p:
        print("\t".join(["P", ""] + p), flush=True)
