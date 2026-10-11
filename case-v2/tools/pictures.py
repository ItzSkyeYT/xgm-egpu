#!/usr/bin/env python3
"""Pictures of the assembled case, made from the STLs that tools/build.py left in build/<bed>/assembled.
(OpenSCAD cannot preview the model itself: too many cuts. Imported meshes it shows at once.)

usage: tools/pictures.py 350|256 [view ...]      -> docs/img/<bed>-<view>.png"""
import sys
sys.dont_write_bytecode = True
import os, subprocess, tempfile
from concurrent.futures import ThreadPoolExecutor

HERE = os.path.dirname(os.path.abspath(__file__))
V2 = os.path.dirname(HERE)
bed = sys.argv[1] if len(sys.argv) > 1 else '350'
ASM = os.path.join(V2, 'build', bed, 'assembled')
OUT = os.path.join(V2, 'docs', 'img')
plates = {'350': {'frame': ['frame'], 'floor': ['floor'], 'lid': ['lid']},
          '256': {'frame': ['frame_a', 'frame_b'], 'floor': ['floor_a', 'floor_b'], 'lid': ['lid_a', 'lid_b']}}[bed]
posts = [f'post_corner_{i}' for i in range(4)] + ['post_mid_0', 'post_mid_1']
panels = ['panel_rear', 'panel_far', 'panel_left_r', 'panel_left_f', 'panel_right_r', 'panel_right_f']
COLOUR = {'frame': '#33415c', 'floor': '#4a6fa5', 'lid': '#7fa3d1', 'post': '#22365c', 'panel': '#9dbbe0', 'handle': '#e9a23b', 'feet': '#e9a23b',
          'cradle': '#c05a2e', 'bracket_holder': '#c05a2e', 'psu_spacer': '#c05a2e', 'rods': '#c9c9c9', 'screws': '#d8402c', 'board': '#2e8b57', 'card': '#6f6f6f', 'psu': '#2b2b2b'}
# In the pictures the real-world Y is used (the STLs are already mirrored): the PSU is at +Y, the card's fans face -Y.
ALL = plates['frame'] + plates['floor'] + plates['lid'] + posts + panels + ['handle', 'feet', 'cradle', 'bracket_holder', 'psu_spacer', 'rods', 'screws']
HARD = ['board', 'card', 'psu']
def without(names, *drop): return [n for n in names if not any(n.startswith(d) for d in drop)]
# view: (parts, {part prefix: [dx, dy, dz]}, camera eye, camera centre)
C = (126, 28, 80)
BIG = 2000
VIEWS = {
  'closed':     (ALL, {}, (760, -640, 520), C),
  'closed-psu': (ALL, {}, (-520, 720, 470), C),
  'open':       (without(ALL, 'lid', 'handle', 'panel_right', 'panel_far') + HARD, {}, (700, -700, 560), C),
  'open-psu':   (without(ALL, 'lid', 'handle', 'panel_left', 'panel_rear') + HARD, {}, (-520, 740, 540), C),
  'skeleton':   (without(ALL, 'panel', 'lid', 'screws'), {}, (760, -640, 480), C),
  'below':      (without(ALL, 'screws'), {}, (640, -560, -560), (126, 28, 60)),
  'exploded':   (ALL, {'feet': [0, 0, -80], 'frame': [0, 0, -40], 'lid': [0, 0, 70], 'handle': [0, 0, 120],
                       'panel_rear': [-80, 0, 0], 'panel_far': [80, 0, 0], 'panel_left': [0, 80, 0], 'panel_right': [0, -80, 0]},
                 (1040, -880, 700), (126, 28, 80)),
  # cut through the handle's two rods, seen from the rear: handle, lid, posts, rods, base and feet in one slice
  'section':    (ALL + HARD, {}, (-560, 60, 240), (145, 28, 75), (145, -BIG, -BIG, BIG, BIG, BIG)),
  # cut along the rear wall through its two corner rods: each rod from its foot to the nut on the lid
  'section-rear': (without(ALL, 'handle') + HARD, {}, (-620, 40, 200), (-7.5, 28, 75), (-7.5, -BIG, -BIG, BIG, BIG, BIG)),
  # cut level through a corner post at one of its screws: flange, panel, core, nut
  'section-post': (['post_corner_0', 'panel_rear', 'panel_left_r', 'screws', 'rods'], {}, (-28, 185, 215), (4, 138, 89), (-BIG, -BIG, -BIG, BIG, BIG, 89)),
}
# CGAL refuses to read the posts' meshes back in for a real cut (an old bug of its STL import), so in cut views they are drawn from the model
MODEL = {**{f'post_corner_{i}': f'at_corner({i}) corner_post_local();' for i in range(4)}, **{f'post_mid_{i}': f'at_mid({i}) mid_post_local();' for i in range(2)}}
def scad(parts, moves, cut=None):
    lines = [f'include <{os.path.join(V2, "xgm-v2.scad")}>'] if cut else []
    for n in parts:
        key = next((k for k in COLOUR if n.startswith(k)), None)
        move = next((v for k, v in moves.items() if n.startswith(k)), [0, 0, 0])
        one = f'translate({move}) import("{os.path.join(ASM, n + ".stl")}", convexity = 8);'
        if cut:
            x0, y0, z0, x1, y1, z1 = cut
            if n in MODEL:
                one = f'translate({move}) mirror([0, 1, 0]) {MODEL[n]}'
            one = f'render() intersection() {{ {one} translate([{x0}, {y0}, {z0}]) cube([{x1 - x0}, {y1 - y0}, {z1 - z0}]); }}'     # a real cut, so that the cut faces are closed and keep their colour
        lines.append(f'color("{COLOUR.get(key, "#888888")}") {one}')
    return '\n'.join(lines) + '\n'
def render(view):
    parts, moves, eye, centre, *cut = VIEWS[view]
    out = os.path.join(OUT, f'{bed}-{view}.png')
    with tempfile.TemporaryDirectory() as tmp:
        f = os.path.join(tmp, 'v.scad'); open(f, 'w').write(scad(parts, moves, cut[0] if cut else None))
        cam = ','.join(str(v) for v in eye + centre)
        r = subprocess.run(['xvfb-run', '-a', 'openscad', '-o', out, '--imgsize=1800,1350', f'--camera={cam}', '--projection=p',
                            '--colorscheme=Tomorrow', '-D', 'part="none"', '-D', f'bed="{bed}"', f], capture_output=True, text=True)
    ok = os.path.exists(out) and os.path.getsize(out) > 0
    return view, ok, '' if ok else r.stderr.strip().splitlines()[-1:]
os.makedirs(OUT, exist_ok=True)
todo = sys.argv[2:] or list(VIEWS)
with ThreadPoolExecutor(3) as pool:
    for view, ok, err in pool.map(render, todo):
        print(f'  {bed}-{view}.png' if ok else f'  {view}: FAILED {err}')
