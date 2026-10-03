#!/usr/bin/env python3
"""Build print-pack/: one folder per stage, a README.md with settings, pictures and pass checklists.
usage: make_print_pack.py [destination]   (default: ./print-pack next to this script)"""
import json, os, shutil, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
STL = os.path.join(HERE, 'stl')
DEST = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else os.path.join(HERE, 'print-pack')
WEIGHTS = {}                                                  # real slices from slice_weights.py, when it has been run
if os.path.exists(os.path.join(HERE, 'weights.json')):
    WEIGHTS = json.load(open(os.path.join(HERE, 'weights.json')))

# (file, quantity shown, copies printed)
STAGES = [
    ('1-tests', 'Tests', [('coupon', '1 file, 2 pieces', 1), ('coupon_rear', '1', 1), ('coupon_grommet', '1 file, 3 pieces', 1), ('coupon_inserts', '1', 1)]),
    ('2-board-and-card', 'Board and card', [('floor_rr', '1', 1), ('floor_fr', '1', 1), ('bracket_holder', '1', 1),
                                            ('cradle', '1', 1), ('shim_05', '1', 1), ('shim_10', '1', 1), ('shim_15', '1', 1)]),
    ('3-structure-sample', 'Structure sample', [('post_corner', '1', 1), ('post_mid', '1', 1), ('panel_rear_r', '1', 1)]),
    ('4-final', 'The rest', [('floor_rl', '1', 1), ('floor_fl', '1', 1), ('post_corner', '3 more', 3), ('post_mid', '3 more', 3),
                             ('panel_rear_l', '1', 1), ('panel_far_l', '1', 1), ('panel_far_r', '1', 1), ('panel_left_r', '1', 1),
                             ('panel_left_f', '1', 1), ('panel_right_r', '1', 1), ('panel_right_f', '1', 1),
                             ('lid_l', '1', 1), ('lid_r', '1', 1)]),
]
LID_QUARTERS = ['lid_rl', 'lid_rr', 'lid_fl', 'lid_fr']
SUBDIR_LIDQ = 'lid-quarters-if-bed-under-250mm'

def stl_info(name):
    xs, ys, zs, tri, vol = [], [], [], [], 0.0
    for line in open(os.path.join(STL, name + '.stl')):
        t = line.split()
        if t and t[0] == 'vertex':
            v = (float(t[1]), float(t[2]), float(t[3])); tri.append(v)
            xs.append(v[0]); ys.append(v[1]); zs.append(v[2])
            if len(tri) == 3:
                (ax, ay, az), (bx, by, bz), (cx, cy, cz) = tri
                vol += (ax*(by*cz-bz*cy) + bx*(cy*az-cz*ay) + cx*(ay*bz-az*by)) / 6.0
                tri = []
    size = (max(xs)-min(xs), max(ys)-min(ys), max(zs)-min(zs))
    sliced = WEIGHTS.get('parts', {}).get(name)
    fill = 0.6 if name.startswith('post') else 0.9          # fallback estimate from the volume; it runs about a quarter high
    return size, sliced['g'] if sliced else abs(vol) / 1000.0 * 1.27 * fill

def read_stl(name):
    verts, index, tris, cur = [], {}, [], []
    for line in open(os.path.join(STL, name + '.stl')):
        t = line.split()
        if t and t[0] == 'vertex':
            v = (float(t[1]), float(t[2]), float(t[3])); i = index.get(v)
            if i is None: i = len(verts); index[v] = i; verts.append(v)
            cur.append(i)
            if len(cur) == 3: tris.append(tuple(cur)); cur = []
    return verts, tris

def write_stage_3mf(rows, out):
    """Every file of the stage, copies included, laid flat in a grid: one File > Open Project loads the whole stage."""
    import zipfile
    objs, x, y, row_h = [], 0.0, 0.0, 0.0
    for n, _, copies in rows:
        verts, tris = read_stl(n); (sx, sy, sz), _ = stl_info(n)
        for c in range(copies):
            if x > 0 and x + sx > 250: x, y, row_h = 0.0, y + row_h + 10, 0.0
            objs.append((n + (f' ({c+1})' if copies > 1 else ''), [(vx + x, vy - y - sy, vz) for vx, vy, vz in verts], tris))
            x += sx + 10; row_h = max(row_h, sy)
    xml = ['<?xml version="1.0" encoding="UTF-8"?>',
           '<model unit="millimeter" xml:lang="en-US" xmlns="http://schemas.microsoft.com/3dmanufacturing/core/2015/02">', ' <resources>']
    for i, (n, verts, tris) in enumerate(objs, start=1):
        xml.append(f'  <object id="{i}" name="{n}" type="model"><mesh><vertices>')
        xml += [f'<vertex x="{a:.4f}" y="{b:.4f}" z="{c:.4f}"/>' for a, b, c in verts]
        xml.append('</vertices><triangles>')
        xml += [f'<triangle v1="{a}" v2="{b}" v3="{c}"/>' for a, b, c in tris]
        xml.append('</triangles></mesh></object>')
    xml += [' </resources>', ' <build>'] + [f'  <item objectid="{i}"/>' for i in range(1, len(objs) + 1)] + [' </build>', '</model>']
    def put(z, name, data):           # fixed timestamp: an unchanged stage rebuilds byte for byte, so git only sees real changes
        zi = zipfile.ZipInfo(name, (1980, 1, 1, 0, 0, 0)); zi.external_attr = 0o644 << 16
        z.writestr(zi, data, zipfile.ZIP_DEFLATED)
    with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED) as z:
        put(z, '[Content_Types].xml', '<?xml version="1.0" encoding="UTF-8"?>\n<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="model" ContentType="application/vnd.ms-package.3dmanufacturing-3dmodel+xml"/></Types>\n')
        put(z, '_rels/.rels', '<?xml version="1.0" encoding="UTF-8"?>\n<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Target="/3D/3dmodel.model" Id="rel0" Type="http://schemas.microsoft.com/3dmanufacturing/2013/01/3dmodel"/></Relationships>\n')
        put(z, '3D/3dmodel.model', '\n'.join(xml) + '\n')

def grams(g):
    return f"≈ {max(1, round(g))} g" if g < 10 else f"≈ {int(5 * round(g / 5))} g"

def render_stage(names, png):
    """Lay the stage's files out on a virtual bed, as they print, and render a picture."""
    scad = os.path.join(DEST, '.stage.scad')
    x = y = row_h = 0.0
    out, palette = [], ['#3f7cc0', '#5a9bd8', '#2f6aa8', '#78b0e0']
    for i, n in enumerate(names):
        (sx, sy, sz), _ = stl_info(n)
        if x > 0 and x + sx > 560:
            x, y, row_h = 0.0, y + row_h + 25, 0.0
        out.append(f'color("{palette[i % len(palette)]}") translate([{x:.1f}, {-y - sy:.1f}, 0]) import("{os.path.join(STL, n + ".stl")}");')
        x += sx + 25; row_h = max(row_h, sy)
    open(scad, 'w').write('\n'.join(out) + '\n')
    subprocess.run(['openscad', '-o', png, '--imgsize=2400,1400', '--autocenter', '--viewall',
                    '--camera=0,0,0,48,0,22,0', '--colorscheme=Tomorrow', scad],
                   check=True, capture_output=True)
    os.remove(scad)
    from PIL import Image, ImageChops                         # crop to the parts, keep a margin, same width for every stage
    im = Image.open(png).convert('RGB')
    bg = Image.new('RGB', im.size, im.getpixel((2, 2)))
    l, t, r, b = ImageChops.difference(im, bg).point(lambda v: 255 if v > 12 else 0).getbbox()
    pad = 40
    im = im.crop((max(0, l - pad), max(0, t - pad), min(im.width, r + pad), min(im.height, b + pad)))
    w = 1400
    im.resize((w, round(im.height * w / im.width)), Image.LANCZOS).save(png, optimize=True)

def table(rows):
    lines = ['| File | Qty | Size (mm) | Plastic |', '|---|:-:|---|--:|']
    for n, q, copies in rows:
        (sx, sy, sz), g = stl_info(n)
        d = lambda v: f"{v:.1f}" if v < 10 and abs(v - round(v)) > 0.05 else f"{v:.0f}"
        lines.append(f"| `{n}.stl` | {q} | {d(sx)} × {d(sy)} × {d(sz)} | {grams(g * copies)} |")
    return '\n'.join(lines)

# ---------------------------------------------------------------- build the folders
if os.path.isdir(DEST):
    shutil.rmtree(DEST)
os.makedirs(os.path.join(DEST, 'img'))
totals = {}
for key, title, rows in STAGES:
    os.makedirs(os.path.join(DEST, key))
    for n, _, _ in rows:
        shutil.copy(os.path.join(STL, n + '.stl'), os.path.join(DEST, key))
    totals[key] = sum(stl_info(n)[1] * c for n, _, c in rows)
    write_stage_3mf(rows, os.path.join(DEST, key, f"stage-{key[0]}.3mf"))
    render_stage([n for n, _, _ in rows], os.path.join(DEST, "img", f"stage-{key[0]}.png"))
os.makedirs(os.path.join(DEST, '4-final', SUBDIR_LIDQ))
for n in LID_QUARTERS:
    shutil.copy(os.path.join(STL, n + '.stl'), os.path.join(DEST, '4-final', SUBDIR_LIDQ))
ref = os.path.join(DEST, 'reference'); os.makedirs(ref)
for f in ['xgm-lite-frame-assembled.3mf', 'plan/floor-plan-A3.pdf', 'plan/floor-plan-A4-2pages.pdf', 'DIMENSIONS.md', 'README.md']:
    shutil.copy(os.path.join(HERE, f), ref)
shutil.copy(os.path.join(HERE, 'img', 'outside.png'), os.path.join(DEST, 'img', 'case.png'))
shutil.copy(os.path.join(HERE, 'img', 'inside.png'), os.path.join(DEST, 'img', 'inside.png'))
grand = sum(totals.values())
walls, infill = (str(WEIGHTS['walls']), WEIGHTS['infill'].replace('%', ' %')) if WEIGHTS else ('3', '15 %')
if WEIGHTS:
    basis = (f"The weights are real slices, not estimates: {WEIGHTS['slicer']}, {WEIGHTS['printer'].replace(' 0.4 nozzle', '')}, "
             f"{WEIGHTS['filament'].split(' @')[0]}, {walls} walls, {infill} infill. ")
    basis += (f"At these settings **one 1 kg spool covers the whole pack**, tests included, with about {int(5 * round((1000 - grand) / 5))} g "
              "to spare; 4 walls and 40 % infill push it just past a kilo. " if grand < 1000 else
              "At these settings the pack needs more than one 1 kg spool. ")
    basis += ("Allow about 33 hours of printing in all on that machine, as the slicer arranges the plates: roughly 1 h for stage 1, "
              "3 h over two plates for stage 2, 5 h for stage 3 and 24 h over six plates for stage 4. The posts are what takes long: "
              "the plate that carries them runs for more than 7 h.")
else:
    basis = "The weights are estimates from each part's volume; run `slice_weights.py` for real ones."

# ---------------------------------------------------------------- README.md
md = f"""# XGM Lite frame · print pack

A print-only case for the **XG Mobile Station Lite** board, an **Inno3D RTX 3060 Twin X2 OC** and a
**Corsair RM850**. No glue: the parts peg, slot and slide together, and the board and the lid are held
by M3 screws in heat-set inserts.

![The finished case](img/case.png)

## Settings

| Setting | Value |
|---|---|
| Material | **PETG**. PLA softens next to a warm GPU and creeps under the PSU's weight. |
| Layer height | 0.2 mm |
| Walls | {walls} |
| Infill | {infill} |
| Plate | Textured PEI. Bambu's PETG profile refuses the smooth Cool Plate. Let the plate cool before removing parts. |
| Supports | **None.** Nothing in this pack needs them. |
| Orientation | As exported. Every file is already laid out for the bed. |
| Bed | 180 × 180 mm, except the two-piece lid, which needs 250 mm. On a Bambu X1 Carbon (256 mm) every part fits whole. |
| Height | 182 mm, for the posts |

> **Pick a PETG filament profile in the slicer.** The default is PLA.

## The plan

| Stage | Folder | What it proves | Plastic |
|:-:|---|---|--:|
| 1 | [`1-tests`](1-tests/) | your printer's fits, the real plugs in the real openings, the grommet clip, the insert holes | {grams(totals['1-tests'])} |
| 2 | [`2-board-and-card`](2-board-and-card/) | the board screwed down on its five inserts, the card on its two supports | {grams(totals['2-board-and-card'])} |
| 3 | [`3-structure-sample`](3-structure-sample/) | full-height posts, and a wall in its slots | {grams(totals['3-structure-sample'])} |
| 4 | [`4-final`](4-final/) | the rest of the box | {grams(totals['4-final'])} |

**Opening a stage in OrcaSlicer:** each folder has a `stage-N.3mf` holding all of that stage's parts,
copies included. File → Open Project loads the whole stage at once; then press **A** to arrange it on
the plate. If it doesn't all fit, put the leftover parts on a second plate. Single STL files come in with
File → Import (Ctrl+I), or by dragging them onto the Orca window.

Print the stages in order, and start a stage only when the previous one passed. Only the stage 1 tests
are throwaway: everything else ends up in the finished case. About **{grams(grand)[2:]}** of PETG in total.

{basis}

---

## 1 · Tests

![Stage 1 on the bed](img/stage-1.png)

{table(STAGES[0][2])}

**coupon** holds two identical pieces that you test against each other. Each fit should go together
by hand and stay put: neither forced nor loose.

- [ ] One piece's jigsaw tab presses down into the other's notch. *This is how the floor and lid pieces join.*
- [ ] Laid on the other, one piece's square peg goes through the other's square hole. *This is how the posts and the lid seat.*
- [ ] One piece's tab pushes edge-first into the other's long thin slot. *This is how the walls sit in the posts.*

**coupon_rear** is the bottom of the real rear wall, board side.

- [ ] It slides down over the thick laptop cable without pinching it. *The real wall goes in exactly like this.*
- [ ] A USB-C plug goes through the small hole.
- [ ] An HDMI plug goes into the bottom of the big window.

**coupon_grommet** has three small clips with slots of 10.5, 11.5 and 12.5 mm, the number printed
beside each. The clip's thin wall goes into the gap between the grommet's round disc and square plate,
and the rubber neck clicks down into the slot.

- [ ] One of the three holds the grommet firmly: pushing it in takes a little force, it doesn't fall out, and the rubber isn't badly squashed. *Tell me which number.*

**coupon_inserts** has three bosses like the ones that hold the board, with holes of 3.8, 4.0 and
4.2 mm. Melt one M3×5×4.5 insert into each with a soldering iron at about 230 °C, pressing straight
down until it sits flush, then let it cool.

- [ ] One of the three takes its insert straight and flush, and an M3 screw tightens into it firmly without the insert turning. *Tell me which number.*

**If something fails:** note which fit binds or rattles, or which clip held the grommet best. One
number changes in the model, and only the coupon is reprinted.

---

## 2 · Board and card

![Stage 2 on the bed](img/stage-2.png)

{table(STAGES[1][2])}

- [ ] The two floor pieces press together on their jigsaw tabs and lie flat on the table.
- [ ] The five inserts are melted into the round bosses, straight and flush: three on `floor_rr`, two on `floor_fr`.
- [ ] The bare board sits flat on the five bosses, and five M3×8 screws pull it down without rocking. M3×6 also works; nothing longer than 8.
- [ ] The holder's three pegs go down through the board's three small holes, into the floor.
- [ ] With the card plugged in, the bracket's foot sits in the board's slot.
- [ ] The bracket's top tab rests on the holder's arm, or floats a hair above it. Slide shims under it until it touches.
- [ ] The card's far end rests on the cradle without lifting the card out of its slot.

**If something fails:**

- *The bosses don't meet the board's holes:* stop and send a photo. The board isn't what its design file says.
- *The tab is more than 2 mm off the arm:* re-measure the tab height. Only the holder is reprinted.
- *The cradle lifts the card, or there's daylight under it:* re-measure the card's lowest point. Only the cradle is reprinted.

---

## 3 · Structure sample

![Stage 3 on the bed](img/stage-3.png)

{table(STAGES[2][2])}

These go on the floor from stage 2: the corner post at the board's rear corner, the mid post in the
middle of the rear edge, and the wall between them.

- [ ] The posts came out clean at full height, with no wobble or shifted layers near the top.
- [ ] The corner post takes an insert in its top end, straight and flush.
- [ ] Each post's peg drops into its square hole in the floor, and the post stands upright on its own.
- [ ] The wall slides down into both posts' slots, all the way to the floor.
- [ ] The wall's bottom notch drops over the thick laptop cable.

---

## 4 · The rest

![Stage 4 on the bed](img/stage-4.png)

{table(STAGES[3][2])}

**Screws:** melt an insert into the top end of each of the other three corner posts. The lid is held by
four M3×8 or M3×10 screws through its corners.

**On a bed under 250 mm**, print the four files in [`4-final/{SUBDIR_LIDQ}`](4-final/{SUBDIR_LIDQ}/)
instead of `lid_l` and `lid_r`.

![Inside the finished case](img/inside.png)

## Folder layout

```
print-pack/
├── README.md                  this file
├── 1-tests/                   stage-1.3mf (everything below in one project), coupon, coupon_rear
├── 2-board-and-card/          stage-2.3mf, floor_rr, floor_fr, bracket_holder, cradle, shim_05, shim_10, shim_15
├── 3-structure-sample/        stage-3.3mf, post_corner, post_mid, panel_rear_r
├── 4-final/                   stage-4.3mf, the remaining floor, posts, walls and lid
│   └── {SUBDIR_LIDQ}/   lid_rl, lid_rr, lid_fl, lid_fr
├── reference/                 assembled 3MF, 1:1 floor plans, full notes, every dimension
└── img/                       the pictures in this file
```

## Reference

- [`xgm-lite-frame-assembled.3mf`](reference/xgm-lite-frame-assembled.3mf): the whole case assembled,
  every part a separate object. File → Open Project in Orca, then hide parts in the object list to look
  inside. **Not for printing.**
- [`floor-plan-A3.pdf`](reference/floor-plan-A3.pdf) and [`floor-plan-A4-2pages.pdf`](reference/floor-plan-A4-2pages.pdf):
  the floor plan at 1:1. Print at 100 % and lay the real parts on it. The A4 pair is drawn sideways so it
  fits an inkjet's printable area: cut sheet 1 along its dashed line and lay it on sheet 2, cut edge on the
  dashed line there, crosses on crosses.
- [`README.md`](reference/README.md): the full notes, including the assembly order.
- [`DIMENSIONS.md`](reference/DIMENSIONS.md): every part's size and position.
"""
open(os.path.join(DEST, 'README.md'), 'w').write(md)
n_files = sum(len(f) for _, _, f in os.walk(DEST))
print(f"print pack: {DEST}  ({n_files} files, {grams(grand)} of PETG)")
