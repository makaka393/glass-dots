#!/usr/bin/env python3
# Перекрашивает папки Papirus в акцентный цвет темы (primary из matugen).
# Создаёт свою тему иконок ~/.local/share/icons/Papirus-Matugen, системные файлы не трогает.
import json, os, re, sys

home = os.path.expanduser("~")
mode = sys.argv[1] if len(sys.argv) > 1 else "dark"
src = os.environ.get("PAPIRUS_SRC", "/usr/share/icons/Papirus")
if not os.path.isdir(src):
    sys.exit(0)

c = json.load(open(f"{home}/.cache/matugen/colors.json"))
def h2r(h): h = h.lstrip("#"); return [int(h[i:i + 2], 16) for i in (0, 2, 4)]
def r2h(r): return "#%02x%02x%02x" % tuple(max(0, min(255, round(v))) for v in r)
def mix(a, b, t): return [a[i] + (b[i] - a[i]) * t for i in range(3)]

p = h2r(c["primary"])
main  = r2h(p)                       # лицевая сторона папки
back  = r2h(mix(p, [0, 0, 0], 0.20)) # задняя стенка — чуть темнее
glyph = r2h(mix(p, [0, 0, 0], 0.70)) # значок на папке (документы, музыка…)

dst = f"{home}/.local/share/icons/Papirus-Matugen"
os.makedirs(dst, exist_ok=True)
idx = open(f"{src}/index.theme").read()
idx = re.sub(r"^Name=.*$", "Name=Papirus-Matugen", idx, flags=re.M)
inherits = "Papirus-Light,Papirus,breeze,hicolor" if mode == "light" else "Papirus-Dark,Papirus,breeze-dark,hicolor"
idx = re.sub(r"^Inherits=.*$", "Inherits=" + inherits, idx, flags=re.M)
open(f"{dst}/index.theme", "w").write(idx)

count = 0
for size in os.listdir(src):
    pdir = f"{src}/{size}/places"
    if not os.path.isdir(pdir):
        continue
    out = f"{dst}/{size}/places"
    os.makedirs(out, exist_ok=True)
    for name in os.listdir(pdir):
        real = os.path.realpath(f"{pdir}/{name}")
        if not os.path.basename(real).startswith("folder-blue") or not real.endswith(".svg"):
            continue
        svg = open(real).read()
        svg = svg.replace("#5294e2", main).replace("#4877b1", back).replace("#1d344f", glyph)
        open(f"{out}/{name}", "w").write(svg)
        count += 1
print(f"папки перекрашены: {count} иконок → {main}")
