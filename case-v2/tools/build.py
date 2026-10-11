#!/usr/bin/env python3
"""Build one version of the v2 case from xgm-v2.scad and check it.

  1. every part, laid out for printing          -> build/<bed>/stl
  2. every part in place                        -> build/<bed>/assembled, and xgm-v2-<bed>-assembled.3mf
  3. printed parts against the hardware         (the model's collision test: must be empty)
  4. printed parts against each other           (no two may share volume)
  5. what would print in mid-air                (downward faces that are not on the bed)
  6. sizes and volumes                          -> build/<bed>/parts.json

usage: tools/build.py 350|256 [--fast]        --fast: no vents, checks only (steps 3 and 4)"""
import sys
sys.dont_write_bytecode = True
import glob, itertools, json, math, os, re, subprocess, tempfile, zipfile
from concurrent.futures import ThreadPoolExecutor
from xml.sax.saxutils import escape

HERE = os.path.dirname(os.path.abspath(__file__))
V2 = os.path.dirname(HERE)
SCAD = os.path.join(V2, 'xgm-v2.scad')
bed = sys.argv[1] if len(sys.argv) > 1 else '350'
fast = '--fast' in sys.argv
assert bed in ('350', '256'), 'bed is 350 or 256'
BUILD = os.path.join(V2, 'build', bed)
STL, ASM = os.path.join(BUILD, 'stl'), os.path.join(BUILD, 'assembled')
BEDS = {'350': (300, 300, 320), '256': (256, 256, 256)}

plates = ['frame', 'floor', 'lid'] if bed == '350' else ['frame_a', 'frame_b', 'floor_a', 'floor_b', 'lid_a', 'lid_b']
panels = ['panel_rear', 'panel_far', 'panel_left_r', 'panel_left_f', 'panel_right_r', 'panel_right_f']
PRINT = plates + ['post_corner', 'post_mid'] + panels + ['handle', 'foot_corner', 'foot_mid', 'bracket_holder', 'bracket_washer', 'cradle', 'psu_spacer', 'coupon']
QTY = {'post_corner': 4, 'post_mid': 2, 'foot_corner': 4, 'foot_mid': 2, 'bracket_washer': 2}
posts = [f'post_corner_{i}' for i in range(4)] + ['post_mid_0', 'post_mid_1']
ASSEMBLED = plates + posts + panels + ['handle', 'feet', 'cradle', 'bracket_holder', 'psu_spacer', 'rods', 'screws', 'board', 'card', 'psu', 'zones']
# assembled name -> the module that draws it in place, for the pairwise check
MODULES = {'frame': 'frame_full()', 'floor': 'floor_full()', 'lid': 'lid_full()'}
MODULES.update({n: n + '()' for n in ['frame_a', 'frame_b', 'floor_a', 'floor_b', 'lid_a', 'lid_b'] + panels + ['handle', 'feet', 'cradle', 'bracket_holder', 'psu_spacer']})
MODULES.update({f'post_corner_{i}': f'at_corner({i}) corner_post_local()' for i in range(4)})
MODULES.update({f'post_mid_{i}': f'at_mid({i}) mid_post_local()' for i in range(2)})
COLOURS = {'frame': '3A4A63FF', 'floor': '4A6FA5FF', 'lid': '7FA3D1FF', 'post': '2F4F7FFF', 'panel': '9DBBE0FF', 'handle': 'E9A23BFF',
           'feet': 'E9A23BFF', 'cradle': '2E4A7AFF', 'bracket_holder': '2E4A7AFF', 'psu_spacer': '2E4A7AFF', 'rods': 'B8B8B8FF', 'screws': 'D8402CFF',
           'board': '2E8B57FF', 'card': '8A8A8AFF', 'psu': '303030FF', 'zones': 'FFA50080'}


def scad(out, part, extra=()):
    args = ['openscad', '-o', out, '-D', f'part="{part}"', '-D', f'bed="{bed}"'] + (['-D', 'vents=false'] if fast else []) + list(extra) + [SCAD]
    return subprocess.run(args, capture_output=True, text=True)

def load(path):
    v = [tuple(float(a) for a in m) for m in re.findall(r'vertex\s+(\S+)\s+(\S+)\s+(\S+)', open(path).read())]
    return [v[i:i + 3] for i in range(0, len(v), 3)]

def bbox(tris):
    p = [q for t in tris for q in t]
    return [min(q[i] for q in p) for i in range(3)], [max(q[i] for q in p) for i in range(3)]

def volume(tris):
    return abs(sum(a[0]*(b[1]*c[2]-b[2]*c[1]) - a[1]*(b[0]*c[2]-b[2]*c[0]) + a[2]*(b[0]*c[1]-b[1]*c[0]) for a, b, c in tris)) / 6

def render(names, folder, prefix, shift):
    os.makedirs(folder, exist_ok=True)
    def one(n):
        out = os.path.join(folder, n + '.stl')
        r = scad(out, prefix + n)
        if not os.path.exists(out) or 'facet' not in open(out).read(400):
            return n, 'FAILED: ' + (r.stderr.strip().splitlines() or ['?'])[-1]
        subprocess.run([sys.executable, os.path.join(HERE, 'normalize_stl.py')] + (['--shift'] if shift else []) + [out], check=True)
        return n, None
    with ThreadPoolExecutor(8) as pool:
        bad = [(n, e) for n, e in pool.map(one, names) if e]
    for n, e in bad: print(f'  {n}: {e}')
    return not bad

def collision():
    """(nothing touches, what was found). A film where two faces coincide has no volume and is not a collision."""
    with tempfile.TemporaryDirectory() as tmp:
        out = os.path.join(tmp, 'c.stl')
        r = subprocess.run(['openscad', '-o', out, '-D', 'part="collision"', '-D', f'bed="{bed}"', '-D', 'vents=false', SCAD], capture_output=True, text=True)
        if 'Current top level object is empty' in r.stderr:
            return True, ''
        if not os.path.exists(out):
            return False, 'the test did not run: ' + (r.stderr.strip().splitlines() or ['?'])[-1]
        tris = load(out)
    vol = volume(tris)
    if vol < 0.05:
        return True, ''
    lo, hi = bbox(tris)
    return False, '%.1f mm3 inside x %.1f..%.1f  y %.1f..%.1f  z %.1f..%.1f (as exported: Y mirrored)' % (vol, lo[0], hi[0], lo[1], hi[1], lo[2], hi[2])

def overlaps():
    names = [n for n in MODULES if n in ASSEMBLED]
    boxes = {} if fast else {n: bbox(load(os.path.join(ASM, n + '.stl'))) for n in names}      # --fast: no meshes to go by, so every pair
    near = lambda a, b: all(a[0][i] <= b[1][i] + 0.01 and b[0][i] <= a[1][i] + 0.01 for i in range(3))
    pairs = [p for p in itertools.combinations(names, 2) if fast or near(boxes[p[0]], boxes[p[1]])]
    def one(pair, tmp):
        a, b = pair
        f, off = os.path.join(tmp, f'{a}--{b}.scad'), os.path.join(tmp, f'{a}--{b}.off')
        open(f, 'w').write(f'include <{SCAD}>\nintersection() {{ {MODULES[a]}; {MODULES[b]}; }}\n')
        r = subprocess.run(['openscad', '-o', off, '-D', 'part="none"', '-D', f'bed="{bed}"', '-D', 'vents=false', f], capture_output=True, text=True)
        if 'Current top level object is empty' in r.stderr or not os.path.exists(off):
            return pair, ('ERROR: ' + r.stderr.strip().splitlines()[-1]) if r.returncode and 'empty' not in r.stderr else None
        lines = open(off).read().split('\n')
        head = lines[0].split()
        if head == ['OFF']:
            lines = lines[1:]; head = ['OFF'] + lines[0].split()
        nv, nf = int(head[1]), int(head[2])
        pts = [tuple(map(float, l.split())) for l in lines[1:1 + nv]]
        vol = 0.0
        for l in lines[1 + nv:1 + nv + nf]:
            fc = list(map(int, l.split()))[1:]
            for i in range(1, len(fc) - 1):
                (ax, ay, az), (bx, by, bz), (cx, cy, cz) = pts[fc[0]], pts[fc[i]], pts[fc[i + 1]]
                vol += ax * (by * cz - bz * cy) - ay * (bx * cz - bz * cx) + az * (bx * cy - by * cx)
        vol = abs(vol) / 6
        if vol <= 0.05:
            return pair, None
        lo = [min(p[i] for p in pts) for i in range(3)]; hi = [max(p[i] for p in pts) for i in range(3)]
        return pair, '%.1f mm3 inside x %.2f..%.2f  y %.2f..%.2f  z %.2f..%.2f' % (vol, lo[0], hi[0], lo[1], hi[1], lo[2], hi[2])
    bad = []
    with tempfile.TemporaryDirectory() as tmp, ThreadPoolExecutor(8) as pool:
        for pair, found in pool.map(lambda p: one(p, tmp), pairs):
            if found: bad.append((pair, found))
    return len(pairs), bad

def midair(tris):
    """Area of faces that look down (steeper than 45 degrees from vertical) and are not on the bed, and the widest such face."""
    area, widest = 0.0, 0.0
    for a, b, c in tris:
        u = [b[i] - a[i] for i in range(3)]; v = [c[i] - a[i] for i in range(3)]
        n = (u[1]*v[2] - u[2]*v[1], u[2]*v[0] - u[0]*v[2], u[0]*v[1] - u[1]*v[0])
        size = math.sqrt(sum(x * x for x in n))
        if size < 1e-9 or n[2] / size > -0.72 or min(a[2], b[2], c[2]) < 0.05:
            continue
        area += size / 2
        widest = max(widest, min(max(p[0] for p in (a, b, c)) - min(p[0] for p in (a, b, c)), max(p[1] for p in (a, b, c)) - min(p[1] for p in (a, b, c))))
    return area, widest

def pack_3mf(out):
    mats = list(COLOURS.items()) + [('other', '888888FF')]
    index = {k: i for i, (k, _) in enumerate(mats)}
    xml = ['<?xml version="1.0" encoding="UTF-8"?>', '<model unit="millimeter" xml:lang="en-US" xmlns="http://schemas.microsoft.com/3dmanufacturing/core/2015/02">',
           ' <resources>', '  <basematerials id="1">'] + [f'   <base name="{k}" displaycolor="#{v}"/>' for k, v in mats] + ['  </basematerials>']
    items = []
    for oid, name in enumerate(ASSEMBLED, 2):
        tris = load(os.path.join(ASM, name + '.stl'))
        verts, idx, faces = [], {}, []
        for t in tris:
            f = []
            for p in t:
                if p not in idx: idx[p] = len(verts); verts.append(p)
                f.append(idx[p])
            faces.append(f)
        key = next((k for k in COLOURS if name.startswith(k)), 'other')
        xml += [f'  <object id="{oid}" name="{escape(name)}" type="model" pid="1" pindex="{index[key]}">', '   <mesh>', '    <vertices>']
        xml += [f'     <vertex x="{x:.4f}" y="{y:.4f}" z="{z:.4f}"/>' for x, y, z in verts]
        xml += ['    </vertices>', '    <triangles>'] + [f'     <triangle v1="{a}" v2="{b}" v3="{c}"/>' for a, b, c in faces] + ['    </triangles>', '   </mesh>', '  </object>']
        items.append(f'  <item objectid="{oid}"/>')
    xml += [' </resources>', ' <build>'] + items + [' </build>', '</model>']
    def put(z, name, data):
        zi = zipfile.ZipInfo(name, (1980, 1, 1, 0, 0, 0)); zi.external_attr = 0o644 << 16
        z.writestr(zi, data, zipfile.ZIP_DEFLATED)
    with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED) as z:
        put(z, '[Content_Types].xml', '<?xml version="1.0" encoding="UTF-8"?>\n<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">\n'
            ' <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>\n'
            ' <Default Extension="model" ContentType="application/vnd.ms-package.3dmanufacturing-3dmodel+xml"/>\n</Types>\n')
        put(z, '_rels/.rels', '<?xml version="1.0" encoding="UTF-8"?>\n<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\n'
            ' <Relationship Target="/3D/3dmodel.model" Id="rel0" Type="http://schemas.microsoft.com/3dmanufacturing/2013/01/3dmodel"/>\n</Relationships>\n')
        put(z, '3D/3dmodel.model', '\n'.join(xml) + '\n')

ok = True
if not fast:
    print(f'== 1/6  bed {bed}: every part, laid out for printing'); ok &= render(PRINT, STL, '', True)
    print('== 2/6  every part in place'); ok &= render(ASSEMBLED, ASM, 'asm_', False)
    if ok:
        pack_3mf(os.path.join(V2, f'xgm-v2-{bed}-assembled.3mf'))
print('== 3/6  printed parts against the hardware')
c, found = collision(); ok &= c
print('  nothing touches the hardware' if c else '  COLLISION: ' + found)
if True:
    print('== 4/6  printed parts against each other')
    n, bad = overlaps(); ok &= not bad
    for pair, found in bad: print(f'  OVERLAP  {pair[0]} / {pair[1]}:  {found}   (design frame)')
    print(f'  {n} pairs checked, ' + ('none overlap' if not bad else f'{len(bad)} overlap'))
if not fast:
    print('== 5/6  what would print in mid-air, and whether each part fits the bed')
    table = {}
    bx, by, bz = BEDS[bed]
    for n in PRINT:
        tris = load(os.path.join(STL, n + '.stl'))
        lo, hi = bbox(tris); size = [hi[i] - lo[i] for i in range(3)]
        area, widest = midair(tris)
        fits = (size[0] <= bx and size[1] <= by or size[0] <= by and size[1] <= bx) and size[2] <= bz
        table[n] = {'qty': QTY.get(n, 1), 'size': [round(s, 1) for s in size], 'cm3': round(volume(tris) / 1000, 1), 'midair_mm2': round(area), 'widest_bridge': round(widest, 1), 'fits': fits}
        flag = '' if fits else '   DOES NOT FIT THE BED'
        print(f"  {n:16} {size[0]:6.1f} x {size[1]:6.1f} x {size[2]:6.1f}   solid {volume(tris)/1000:6.1f} cm3   mid-air {area:6.0f} mm2, widest span {widest:4.1f}{flag}")
        ok &= fits
    print('== 6/6  sizes and volumes -> build/%s/parts.json' % bed)
    json.dump(table, open(os.path.join(BUILD, 'parts.json'), 'w'), indent=1)
    print('  solid plastic in all, without the test piece: %.0f cm3' % sum(t['cm3'] * t['qty'] for n, t in table.items() if n != 'coupon'))
sys.exit(0 if ok else 1)
