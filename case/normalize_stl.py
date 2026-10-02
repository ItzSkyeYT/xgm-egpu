#!/usr/bin/env python3
"""Shift ASCII STLs so their bounding box starts at (0, 0, 0): slicers then place them on the plate cleanly.
usage: normalize_stl.py file.stl [...]"""
import sys
for path in sys.argv[1:]:
    lines = open(path).read().splitlines()
    vs = [(i, [float(t) for t in l.split()[1:4]]) for i, l in enumerate(lines) if l.strip().startswith('vertex')]
    if not vs: continue
    mn = [min(v[k] for _, v in vs) for k in range(3)]
    if all(abs(m) < 1e-6 for m in mn): continue
    for i, v in vs:
        lines[i] = '      vertex %.4f %.4f %.4f' % (v[0]-mn[0], v[1]-mn[1], v[2]-mn[2])
    open(path, 'w').write('\n'.join(lines) + '\n')
    print(f"{path}: shifted by ({-mn[0]:.1f}, {-mn[1]:.1f}, {-mn[2]:.1f})")
