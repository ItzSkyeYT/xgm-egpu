#!/usr/bin/env python3
"""Check that no two printed parts occupy the same space. The collision test in the .scad only checks the
printed parts against the real hardware; this one checks them against each other.

Run after render-assembled.sh (it reads build/assembled/ to skip pairs that are nowhere near each other).
Every remaining pair is intersected by OpenSCAD with the vents off. Parts that only touch give faces with no
volume between them, which is fine; any shared volume is reported with where it is.

usage: check_overlaps.py [-j N] [-D name=value ...] [part ...]
  part ...        only the pairs involving one of these
  -D name=value   a model parameter for this run, e.g. -D use_inserts=false"""
import sys
sys.dont_write_bytecode = True        # no __pycache__ beside the scripts
import itertools, os, subprocess, tempfile
from concurrent.futures import ThreadPoolExecutor
from paths import SCAD, ASSEMBLED

# assembled STL name -> the module that draws it in place
MODULES = {n: n + '()' for n in '''floor_rl floor_rr floor_fl floor_fr lid_l lid_r post_corner_rl post_corner_rr post_corner_fl
    post_corner_fr post_mid_rear post_mid_far post_mid_left post_mid_right panel_rear_l panel_rear_r panel_far_l panel_far_r
    panel_left_r panel_left_f panel_right_r panel_right_f cradle bracket_holder bridges'''.split()}
MODULES['bracket_washer'] = 'washer_placed()'
DEFINES = []
SMALL = 0.05                                                # mm3: below this, two parts merely touch


def bbox(path):
    lo, hi = [1e9] * 3, [-1e9] * 3
    for line in open(path):
        if 'vertex' in line:
            for i, v in enumerate(map(float, line.split()[1:4])):
                lo[i] = min(lo[i], v); hi[i] = max(hi[i], v)
    return lo, hi


def near(a, b):
    return all(a[0][i] <= b[1][i] + 0.01 and b[0][i] <= a[1][i] + 0.01 for i in range(3))


def intersect(pair, tmp):
    a, b = pair
    scad, off = os.path.join(tmp, f'{a}--{b}.scad'), os.path.join(tmp, f'{a}--{b}.off')
    open(scad, 'w').write(f'include <{SCAD}>\nintersection() {{ {MODULES[a]}; {MODULES[b]}; }}\n')
    r = subprocess.run(['openscad', '-o', off, '-D', 'part="none"', '-D', 'vents=false'] + DEFINES + [scad], capture_output=True, text=True)
    if 'Current top level object is empty' in r.stderr or not os.path.exists(off):
        if r.returncode and 'empty' not in r.stderr:
            return pair, 'ERROR: ' + r.stderr.strip().splitlines()[-1]
        return pair, None
    lines = open(off).read().split('\n')
    head = lines[0].split()
    if head == ['OFF']:
        lines = lines[1:]; head = ['OFF'] + lines[0].split()
    nv, nf = int(head[1]), int(head[2])
    pts = [tuple(map(float, l.split())) for l in lines[1:1 + nv]]
    vol = 0.0
    for l in lines[1 + nv:1 + nv + nf]:
        f = list(map(int, l.split()))[1:]
        for i in range(1, len(f) - 1):
            (ax, ay, az), (bx, by, bz), (cx, cy, cz) = pts[f[0]], pts[f[i]], pts[f[i + 1]]
            vol += ax * (by * cz - bz * cy) - ay * (bx * cz - bz * cx) + az * (bx * cy - by * cx)
    vol = abs(vol) / 6
    if vol <= SMALL:
        return pair, None                                   # the two parts touch (faces with nothing between them), nothing more
    lo = [min(p[i] for p in pts) for i in range(3)]; hi = [max(p[i] for p in pts) for i in range(3)]
    return pair, '%.1f mm3 inside x %.2f..%.2f  y %.2f..%.2f  z %.2f..%.2f' % (vol, lo[0], hi[0], lo[1], hi[1], lo[2], hi[2])


def main():
    args = sys.argv[1:]
    jobs = 6
    while args[:1] in (['-j'], ['-D']):
        if args[0] == '-j': jobs = int(args[1])
        else: DEFINES.extend(['-D', args[1]])
        args = args[2:]
    boxes = {n: bbox(os.path.join(ASSEMBLED, n + '.stl')) for n in MODULES}
    pairs = [p for p in itertools.combinations(MODULES, 2) if near(boxes[p[0]], boxes[p[1]]) and (not args or p[0] in args or p[1] in args)]
    print(f'{len(pairs)} pairs close enough to check')
    bad = 0
    with tempfile.TemporaryDirectory() as tmp, ThreadPoolExecutor(jobs) as pool:
        for pair, found in pool.map(lambda p: intersect(p, tmp), pairs):
            if found:
                bad += 1
                print(f'OVERLAP  {pair[0]} / {pair[1]}:  {found}   (design frame, y not mirrored)')
    print('no two parts overlap' if not bad else f'{bad} overlapping pairs')
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
