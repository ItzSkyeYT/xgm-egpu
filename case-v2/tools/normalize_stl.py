#!/usr/bin/env python3
"""Rewrite ASCII STLs in one fixed form, so that the same shape always gives the same file. OpenSCAD writes
the same facets in a different order from one run to the next, which made every rebuild look like a change.
Coordinates go to 0.0001 mm, each facet starts at its lowest corner, the facets are sorted and their normals
recomputed. With --shift the part is also moved so that its bounding box starts at (0, 0, 0), which is how
a slicer wants a print file.
usage: normalize_stl.py [--shift] file.stl [...]"""
import math, sys

def number(v):
    return ('%.6f' % (round(v, 6) + 0.0)).rstrip('0').rstrip('.')                    # + 0.0: no minus zero

def tidy(path, shift):
    pts = [tuple(float(t) for t in line.split()[1:4]) for line in open(path) if line.lstrip().startswith('vertex')]
    if not pts or len(pts) % 3:
        return False
    low = [min(p[k] for p in pts) for k in range(3)] if shift else (0.0, 0.0, 0.0)
    pts = [tuple(round(p[k] - low[k], 4) + 0.0 for k in range(3)) for p in pts]       # + 0.0: no minus zero
    facets = []
    for i in range(0, len(pts), 3):
        corners = pts[i:i + 3]
        first = corners.index(min(corners))
        facets.append(tuple(corners[first:] + corners[:first]))                      # same winding, lowest corner first
    out = ['solid OpenSCAD_Model']
    for a, b, c in sorted(facets):
        u, v = [b[k] - a[k] for k in range(3)], [c[k] - a[k] for k in range(3)]
        n = (u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0])
        size = math.sqrt(sum(x * x for x in n)) or 1.0
        out.append('  facet normal ' + ' '.join(number(x / size) for x in n))
        out.append('    outer loop')
        out += ['      vertex %.4f %.4f %.4f' % p for p in (a, b, c)]
        out += ['    endloop', '  endfacet']
    out.append('endsolid OpenSCAD_Model')
    open(path, 'w').write('\n'.join(out) + '\n')
    return True

args = sys.argv[1:]
shift = args[:1] == ['--shift']
for path in args[1:] if shift else args:
    if not tidy(path, shift):
        sys.exit(f'{path}: not an ASCII STL with whole facets')
