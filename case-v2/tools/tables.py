#!/usr/bin/env python3
"""The parts table of README.md, from build/<bed>/parts.json (sizes) and sliced.json (weights and times).
usage: tools/tables.py 350|256"""
import sys
sys.dont_write_bytecode = True
import json, os

V2 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
bed = sys.argv[1] if len(sys.argv) > 1 else '350'
parts = json.load(open(os.path.join(V2, 'build', bed, 'parts.json')))
sliced = json.load(open(os.path.join(V2, 'build', bed, 'sliced.json')))
HOW = {'frame': 'sole down, rails up', 'floor': 'underside down', 'lid': 'top face down', 'post': 'standing, with a brim', 'panel': 'outer face down',
       'handle': 'on its side', 'foot': 'as it stands', 'bracket_holder': 'on its back, as in v1', 'bracket_washer': 'flat', 'cradle': 'on its side, as in v1',
       'psu_spacer': 'flat', 'coupon': 'as its three pieces lie'}
print('| Part | Pieces | Size on the bed (mm) | Printed | Each | Time each |')
print('|---|---|---|---|---|---|')
for name, p in parts.items():
    s = sliced['parts'].get(name)
    how = next(v for k, v in HOW.items() if name.startswith(k))
    size = ' × '.join(f'{v:.0f}' if v >= 10 else f'{v:.1f}' for v in p['size'])
    print(f"| `{name}` | {p['qty']} | {size} | {how} | {s['g']:.0f} g | {s['min'] // 60} h {s['min'] % 60:02d} |" if s else f"| `{name}` | {p['qty']} | {size} | {how} | does not slice | |")
t = sliced['total_min']
print(f"\n{sliced['total_g']} g and {t // 60} h {t % 60:02d} in all, without the test piece ({sliced['printer']}, {sliced['walls']} walls, {sliced['infill']} infill, 0.2 mm layers).")
