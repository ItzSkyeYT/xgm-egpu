#!/usr/bin/env python3
"""Build print-pack/: one folder per stage, a README.md with settings, pictures and pass checklists.
usage: make_print_pack.py [destination]   (default: ./print-pack next to this script)"""
import os, shutil, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
STL = os.path.join(HERE, 'stl')
DEST = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else os.path.join(HERE, 'print-pack')

# (file, quantity shown, copies printed)
STAGES = [
    ('1-tests', 'Tests', [('coupon', '1 file, 2 pieces', 1), ('coupon_rear', '1', 1)]),
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
    fill = 0.6 if name.startswith('post') else 0.9          # thick posts get real infill; 3 mm plates print nearly solid
    return size, abs(vol) / 1000.0 * 1.27 * fill              # PETG 1.27 g/cm3

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

# ---------------------------------------------------------------- README.md
md = f"""# XGM Lite frame · print pack

A print-only case for the **XG Mobile Station Lite** board, an **Inno3D RTX 3060 Twin X2 OC** and a
**Corsair RM850**. No screws, glue or adapters: everything pegs, clips and slides together.

![The finished case](img/case.png)

## Settings

| Setting | Value |
|---|---|
| Material | **PETG**. PLA softens next to a warm GPU and creeps under the PSU's weight. |
| Layer height | 0.2 mm |
| Walls | 3 to 4 |
| Infill | 25 to 40 % |
| Supports | **None.** Nothing in this pack needs them. |
| Orientation | As exported. Every file is already laid out for the bed. |
| Bed | 180 × 180 mm, except the two-piece lid, which needs 250 mm |
| Height | 182 mm, for the posts |

> **Pick a PETG filament profile in the slicer.** The default is PLA.

## The plan

| Stage | Folder | What it proves | Plastic |
|:-:|---|---|--:|
| 1 | [`1-tests`](1-tests/) | your printer's fits, and the real plugs in the real openings | {grams(totals['1-tests'])} |
| 2 | [`2-board-and-card`](2-board-and-card/) | the board on its pegs and clips, the card on its two supports | {grams(totals['2-board-and-card'])} |
| 3 | [`3-structure-sample`](3-structure-sample/) | full-height posts, and a wall in its slots | {grams(totals['3-structure-sample'])} |
| 4 | [`4-final`](4-final/) | the rest of the box | {grams(totals['4-final'])} |

Print the stages in order, and start a stage only when the previous one passed. Only the two coupons
are throwaway: everything else ends up in the finished case. About **{grams(grand)[2:]}** of PETG in total.

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

- [ ] It slides down over the laptop cable at the rubber boot without pinching it. *The real wall goes in exactly like this.*
- [ ] A USB-C plug goes through the small hole.
- [ ] An HDMI plug goes into the bottom of the big window.

**If something fails:** note which fit binds or rattles. One number changes in the model, and only
the coupon is reprinted.

---

## 2 · Board and card

![Stage 2 on the bed](img/stage-2.png)

{table(STAGES[1][2])}

- [ ] The two floor pieces press together on their jigsaw tabs and lie flat on the table.
- [ ] The bare board drops onto its five pegs and sits flat on the round bosses.
- [ ] The five clips snap over the board's edges.
- [ ] The holder's three pegs go down through the board's three small holes, into the floor.
- [ ] With the card plugged in, the bracket's foot sits in the board's slot.
- [ ] The bracket's top tab rests on the holder's arm, or floats a hair above it. Slide shims under it until it touches.
- [ ] The card's far end rests on the cradle without lifting the card out of its slot.

**If something fails:**

- *The pegs don't meet the holes:* stop and send a photo. The board isn't what its design file says.
- *The tab is more than 2 mm off the arm:* re-measure the tab height. Only the holder is reprinted.
- *The cradle lifts the card, or there's daylight under it:* re-measure the card's lowest point. Only the cradle is reprinted.

---

## 3 · Structure sample

![Stage 3 on the bed](img/stage-3.png)

{table(STAGES[2][2])}

These go on the floor from stage 2: the corner post at the board's rear corner, the mid post in the
middle of the rear edge, and the wall between them.

- [ ] The posts came out clean at full height, with no wobble or shifted layers near the top.
- [ ] Each post's peg drops into its square hole in the floor, and the post stands upright on its own.
- [ ] The wall slides down into both posts' slots, all the way to the floor.
- [ ] The wall's bottom notch drops over the laptop cable at the boot.

---

## 4 · The rest

![Stage 4 on the bed](img/stage-4.png)

{table(STAGES[3][2])}

**On a bed under 250 mm**, print the four files in [`4-final/{SUBDIR_LIDQ}`](4-final/{SUBDIR_LIDQ}/)
instead of `lid_l` and `lid_r`.

![Inside the finished case](img/inside.png)

## Folder layout

```
print-pack/
├── README.md                  this file
├── 1-tests/                   coupon, coupon_rear
├── 2-board-and-card/          floor_rr, floor_fr, bracket_holder, cradle, shim_05, shim_10, shim_15
├── 3-structure-sample/        post_corner, post_mid, panel_rear_r
├── 4-final/                   the remaining floor, posts, walls and lid
│   └── {SUBDIR_LIDQ}/   lid_rl, lid_rr, lid_fl, lid_fr
├── reference/                 assembled 3MF, 1:1 floor plans, full notes, every dimension
└── img/                       the pictures in this file
```

## Reference

- [`xgm-lite-frame-assembled.3mf`](reference/xgm-lite-frame-assembled.3mf): the whole case assembled,
  every part a separate object. Open it in a slicer and hide parts to look inside. **Not for printing.**
- [`floor-plan-A3.pdf`](reference/floor-plan-A3.pdf) and [`floor-plan-A4-2pages.pdf`](reference/floor-plan-A4-2pages.pdf):
  the floor plan at 1:1. Print at 100 % and lay the real parts on it.
- [`README.md`](reference/README.md): the full notes, including the assembly order.
- [`DIMENSIONS.md`](reference/DIMENSIONS.md): every part's size and position.
"""
open(os.path.join(DEST, 'README.md'), 'w').write(md)
n_files = sum(len(f) for _, _, f in os.walk(DEST))
print(f"print pack: {DEST}  ({n_files} files, {grams(grand)} of PETG)")
