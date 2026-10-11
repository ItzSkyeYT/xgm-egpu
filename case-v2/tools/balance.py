#!/usr/bin/env python3
"""Where the loaded case balances, and what it weighs. The handle has to be over this point, or the case hangs crooked.

Printed parts: their place from the assembled meshes, their weight from the slicer (build/<bed>/sliced.json) or, without it,
from their volume. Hardware: the masses in hardware.scad, each at the middle of its own shape. Cables and steel: estimates.
Coordinates are the model's (design frame): X along the board, Y across it with the PSU on -Y, Z up from the floor.

usage: tools/balance.py 350|256"""
import sys
sys.dont_write_bytecode = True
import json, os, re

HERE = os.path.dirname(os.path.abspath(__file__))
V2 = os.path.dirname(HERE)
bed = sys.argv[1] if len(sys.argv) > 1 else '350'
ASM = os.path.join(V2, 'build', bed, 'assembled')

def mesh(name):
    """(volume in cm3, centroid) of an assembled mesh, in the design frame (the files are mirrored in Y)."""
    v = [tuple(float(a) for a in m) for m in re.findall(r'vertex\s+(\S+)\s+(\S+)\s+(\S+)', open(os.path.join(ASM, name + '.stl')).read())]
    vol, cx, cy, cz = 0.0, 0.0, 0.0, 0.0
    for i in range(0, len(v), 3):
        a, b, c = v[i], v[i + 1], v[i + 2]
        d = a[0]*(b[1]*c[2]-b[2]*c[1]) - a[1]*(b[0]*c[2]-b[2]*c[0]) + a[2]*(b[0]*c[1]-b[1]*c[0])
        vol += d; cx += d * (a[0]+b[0]+c[0]); cy += d * (a[1]+b[1]+c[1]); cz += d * (a[2]+b[2]+c[2])
    return abs(vol) / 6000, (cx / vol / 4, -cy / vol / 4, cz / vol / 4)

sliced = {}
if os.path.exists(os.path.join(V2, 'build', bed, 'sliced.json')):
    sliced = json.load(open(os.path.join(V2, 'build', bed, 'sliced.json')))['parts']
plates = ['frame', 'floor', 'lid'] if bed == '350' else ['frame_a', 'frame_b', 'floor_a', 'floor_b', 'lid_a', 'lid_b']
printed = plates + [f'post_corner_{i}' for i in range(4)] + ['post_mid_0', 'post_mid_1', 'panel_rear', 'panel_far', 'panel_left_r', 'panel_left_f',
                                                           'panel_right_r', 'panel_right_f', 'handle', 'feet', 'cradle', 'bracket_holder']
def grams(name, cm3):
    key = re.sub(r'_\d$', '', name)
    if name == 'feet' and 'foot_corner' in sliced:
        return 4 * sliced['foot_corner']['g'] + 2 * sliced['foot_mid']['g']
    return sliced[key]['g'] if key in sliced else cm3 * 1.27 * 0.6       # no slice: 60 % of solid, about what 4 walls and 20 % infill give

items = []                                  # (what, kg, centroid)
for n in printed:
    cm3, c = mesh(n)
    items.append((n, grams(n, cm3) / 1000, c))
case_kg = sum(i[1] for i in items)
for n, kg in [('psu', 1.65), ('card', 1.05), ('board', 0.25)]:
    items.append((n, kg, mesh(n)[1]))
items.append(('cables (estimate, lying in the bay)', 0.35, (50, -95, 30)))
items.append(('six rods with nuts and springs', 0.15, mesh('rods')[1]))
items.append(('screws and nuts', 0.16, mesh('screws')[1]))
total = sum(i[1] for i in items)
cg = [sum(i[1] * i[2][k] for i in items) / total for k in range(3)]
print(f'  printed parts {case_kg:.2f} kg' + ('' if sliced else '  (ESTIMATE from volume: run tools/slice.py for real weights)'))
print(f'  loaded case   {total:.2f} kg')
print(f'  balance point x {cg[0]:.1f}  y {cg[1]:.1f}  z {cg[2]:.1f}   (design frame)')
src = open(os.path.join(V2, 'xgm-v2.scad')).read()
x_mid = float(re.search(r'^x_mid = ([\d.]+);', src, re.M).group(1))
g = [float(a) for a in re.search(r'^handle_grip = \[(-?[\d.]+), (-?[\d.]+)\];', src, re.M).groups()]
print(f'  handle        x {x_mid:.1f}  y {(g[0] + g[1]) / 2:.1f}  (grip {g[0]:.0f}..{g[1]:.0f})   ->  off by {cg[0] - x_mid:+.1f} in x, {cg[1] - (g[0] + g[1]) / 2:+.1f} in y')
json.dump({'case_kg': round(case_kg, 2), 'loaded_kg': round(total, 2), 'cg': [round(c, 1) for c in cg], 'sliced': bool(sliced)},
          open(os.path.join(V2, 'build', bed, 'balance.json'), 'w'))
