#!/usr/bin/env python3
"""Build print-pack/: one folder per stage with its batch plates (the OrcaSlicer projects from make_plates.py)
and its loose STLs, and a README.md with the print order, settings, pictures and pass checklists.
usage: make_print_pack.py [destination]   (default: ./print-pack next to this script)"""
import json, os, shutil, subprocess, sys
from stages import STAGES, NOTES, LID_QUARTERS, SUBDIR_LIDQ

HERE = os.path.dirname(os.path.abspath(__file__))
STL = os.path.join(HERE, 'stl')
PLATES = os.path.join(HERE, 'plates')
DEST = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else os.path.join(HERE, 'print-pack')
WEIGHTS = {}                                                  # real slices from make_plates.py, when it has been run
if os.path.exists(os.path.join(HERE, 'weights.json')):
    WEIGHTS = json.load(open(os.path.join(HERE, 'weights.json')))

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

def grams(g):
    return f"≈ {max(1, round(g))} g" if g < 10 else f"≈ {int(5 * round(g / 5))} g"

def hm(minutes):
    return f"{minutes // 60} h {minutes % 60:02d}"

def batch_grams(batch, rows):
    known = WEIGHTS.get('batches', {}).get(batch)
    return known['g'] if known else sum(stl_info(n)[1] * c for n, c in rows)

def batch_time(batch):
    known = WEIGHTS.get('batches', {}).get(batch)
    return hm(known['min']) if known else '?'

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

def batch_table(stage, batches):
    lines = ['| Order | Open this file | Pieces | Time | Plastic |', '|:-:|---|---|--:|--:|']
    for i, (batch, _, _, rows) in enumerate(batches, start=1):
        pieces = ', '.join(f'`{n}`' if c == 1 else f'{c} × `{n}`' for n, c in rows)
        lines.append(f"| {i} | [`{batch}.3mf`]({stage}/{batch}.3mf) | {pieces} | {batch_time(batch)} | {grams(batch_grams(batch, rows))} |")
    return '\n'.join(lines)

def tree():
    """The whole print order as a tree: stages, their batches top first, and the pieces on each plate."""
    out = []
    for key, title, batches in STAGES:
        known = all(b in WEIGHTS.get('batches', {}) for b, *_ in batches)
        spent = hm(sum(WEIGHTS['batches'][b]['min'] for b, *_ in batches)) + ' · ' if known else ''
        head = f'{key[0]} · {title}'
        out.append(f"{head:42}{spent}{grams(sum(batch_grams(b, rows) for b, _, _, rows in batches))[2:]}")
        for bi, (batch, _, _, rows) in enumerate(batches):
            last = bi == len(batches) - 1
            line = ('└── ' if last else '├── ') + batch + '.3mf'
            out.append(f"{line:42}{batch_time(batch)} · {grams(batch_grams(batch, rows))[2:]}")
            groups = []                                   # consecutive pieces that share a note go on one line
            for n, c in rows:
                label = n if c == 1 else f'{c} × {n}'
                if groups and groups[-1][1] == NOTES[n]:
                    groups[-1][0].append(label)
                else:
                    groups.append(([label], NOTES[n]))
            for gi, (labels, note) in enumerate(groups):
                branch = ('    ' if last else '│   ') + ('└── ' if gi == len(groups) - 1 else '├── ')
                out.append(f"{branch}{', '.join(labels):28}{note}")
        out.append('')
    return '\n'.join(out).rstrip()

# ---------------------------------------------------------------- build the folders
if os.path.isdir(DEST):
    shutil.rmtree(DEST)
os.makedirs(os.path.join(DEST, 'img'))
totals, missing = {}, []
for key, title, batches in STAGES:
    os.makedirs(os.path.join(DEST, key, 'stl'))
    names = []
    for batch, _, _, rows in batches:
        plate = os.path.join(PLATES, key, batch + '.3mf')
        if os.path.exists(plate):
            shutil.copy(plate, os.path.join(DEST, key))
        else:
            missing.append(batch)
        for n, _ in rows:
            if n not in names:
                names.append(n)
                shutil.copy(os.path.join(STL, n + '.stl'), os.path.join(DEST, key, 'stl'))
    totals[key] = sum(batch_grams(b, rows) for b, _, _, rows in batches)
    render_stage(names, os.path.join(DEST, 'img', f'stage-{key[0]}.png'))
if missing:
    sys.exit('no plate for ' + ', '.join(missing) + ': run make_plates.py first')
os.makedirs(os.path.join(DEST, '4-final', SUBDIR_LIDQ))
for n in LID_QUARTERS:
    shutil.copy(os.path.join(STL, n + '.stl'), os.path.join(DEST, '4-final', SUBDIR_LIDQ))
ref = os.path.join(DEST, 'reference'); os.makedirs(ref)
for f in ['xgm-lite-frame-assembled.3mf', 'plan/floor-plan-A3.pdf', 'plan/floor-plan-A4-2pages.pdf', 'DIMENSIONS.md', 'README.md']:
    shutil.copy(os.path.join(HERE, f), ref)
shutil.copy(os.path.join(HERE, 'img', 'outside.png'), os.path.join(DEST, 'img', 'case.png'))
shutil.copy(os.path.join(HERE, 'img', 'inside.png'), os.path.join(DEST, 'img', 'inside.png'))
for f in ['screws-floor.png', 'screws-lid.png', 'screws-closeups.png']:
    shutil.copy(os.path.join(HERE, 'img', f), os.path.join(DEST, 'img', f))
grand = sum(totals.values())
walls, infill = (str(WEIGHTS['walls']), WEIGHTS['infill'].replace('%', ' %')) if WEIGHTS else ('3', '15 %')
sliced = WEIGHTS.get('batches', {})
stage_time = {key: hm(sum(sliced[b]['min'] for b, *_ in batches)) if all(b in sliced for b, *_ in batches) else '?' for key, _, batches in STAGES}
if sliced:
    longest = max(sliced, key=lambda b: sliced[b]['min'])
    basis = (f"The times and weights are real slices of these very files, not estimates: {WEIGHTS['slicer']}, "
             f"{WEIGHTS['printer'].replace(' 0.4 nozzle', '')}, {WEIGHTS['filament'].split(' @')[0]}, {walls} walls, {infill} infill. ")
    basis += (f"At these settings **one 1 kg spool covers the whole pack**, tests included, with about {int(5 * round((1000 - grand) / 5))} g "
              "to spare; 4 walls and 40 % infill push it just past a kilo. " if grand < 1000 else
              "At these settings the pack needs more than one 1 kg spool. ")
    basis += (f"Allow about {round(sum(b['min'] for b in sliced.values()) / 60)} hours of printing in all. The longest single batch is "
              f"`{longest}`, at {hm(sliced[longest]['min'])}: tall, thin posts print slowly, one small layer at a time.")
else:
    basis = "The weights are estimates from each part's volume; run `make_plates.py` for real ones."

# ---------------------------------------------------------------- README.md
md = f"""# XGM Lite frame · print pack

A print-only case for the **XG Mobile Station Lite** board, an **Inno3D RTX 3060 Twin X2 OC** and a
**Corsair RM850**. No glue: the parts peg, slot and slide together, and 39 M3×8 screws in heat-set
inserts hold the board, the posts, the lid and the seams between the floor's and the lid's pieces.

![The finished case](img/case.png)

## Settings

| Setting | Value |
|---|---|
| Material | **PETG**. PLA softens next to a warm GPU and creeps under the PSU's weight. |
| Layer height | 0.2 mm |
| Walls | {walls} |
| Infill | {infill} |
| Plate | Textured PEI. Bambu's PETG profile refuses the smooth Cool Plate. Let the plate cool before removing parts. |
| Brim | None, so that the jigsaw edges come off the plate clean. The posts alone get 5 mm: they are 180 mm tall on a 15 mm foot. |
| Avoid crossing walls | On. PETG strings, and this keeps travel moves inside the part instead of across the vents. |
| Supports | **None.** Nothing in this pack needs them. |
| Orientation | As exported. Every file is already laid out for the bed. |
| Bed | 180 × 180 mm, except the two-piece lid, which needs 250 mm. On a Bambu X1 Carbon (256 mm) every part fits whole. |
| Height | 182 mm, for the posts |

> **The batch files already carry all of this**, on top of Bambu's stock profile for the X1 Carbon and PETG Basic. The table
> is there to check against, and for another slicer or printer. The tests use exactly the same settings as the case, so
> what fits in stage 1 fits in stage 4.

## The plan

| Stage | Folder | What it proves | Batches | Time | Plastic |
|:-:|---|---|:-:|--:|--:|
| 1 | [`1-tests`](1-tests/) | your printer's fits, the real plugs in the real openings, the grommet clip, the insert holes | {len(STAGES[0][2])} | {stage_time['1-tests']} | {grams(totals['1-tests'])} |
| 2 | [`2-board-and-card`](2-board-and-card/) | the board screwed down on its five inserts, the card on its two supports | {len(STAGES[1][2])} | {stage_time['2-board-and-card']} | {grams(totals['2-board-and-card'])} |
| 3 | [`3-structure-sample`](3-structure-sample/) | full-height posts, and a wall in its slots | {len(STAGES[2][2])} | {stage_time['3-structure-sample']} | {grams(totals['3-structure-sample'])} |
| 4 | [`4-final`](4-final/) | the rest of the box | {len(STAGES[3][2])} | {stage_time['4-final']} | {grams(totals['4-final'])} |

### Print order

A batch is one plate on the printer. Print them from the top down: each one is the next thing worth knowing, and
nothing below it is worth the plastic until it has passed.

```
{tree()}
```

### Printing a batch

1. In OrcaSlicer, **File → Open Project** and pick the batch's `.3mf`. The parts come in already arranged, with the
   printer (Bambu Lab X1 Carbon, 0.4 nozzle), the filament (Bambu PETG Basic), the textured plate and the settings above.
2. Check that the filament slot matches where your spool sits in the AMS, then **Slice plate**.
3. **Print plate**, or export the sliced file to the printer's card.

The parts are placed clear of the front 14 mm of the bed, where the X1 Carbon draws its purge and flow-calibration lines
before every print: leave them where they are. Bambu Studio may offer to load only the geometry of a file made by
OrcaSlicer; if it does, set the values from the table by hand. For any other slicer, the loose STLs are in each stage's
`stl/` folder.

Print the stages in order, and start a stage only when the previous one passed. Only the stage 1 tests
are throwaway: everything else ends up in the finished case. About **{grams(grand)[2:]}** of PETG in total.

{basis}

---

## 1 · Tests

![Stage 1 on the bed](img/stage-1.png)

{batch_table(STAGES[0][0], STAGES[0][2])}

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

{batch_table(STAGES[1][0], STAGES[1][2])}

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

{batch_table(STAGES[2][0], STAGES[2][2])}

These go on the floor from stage 2: the corner post at the rear corner on the card side, the mid post
in the middle of the card-side wall, and `panel_right_r` between them. The other half of that wall,
`panel_right_f`, waits for its corner post in stage 4.

Inserts for these two posts: one in each top end; one in the corner post's higher side hole; one in
each of the mid post's two foot bosses.

- [ ] The posts came out clean at full height, with no wobble or shifted layers near the top.
- [ ] Every insert went in straight and flush, the ones in the side holes included.
- [ ] Each post's peg drops into its square hole in the floor, and the post stands upright on its own.
- [ ] An M3×8 through each floor tab pulls its post up against the tab without tilting it: one screw
      for the corner post, two for the mid post.
- [ ] With the mid post's two screws tight, the seam between the two floor pieces beside it is closed.
- [ ] `panel_right_r` slides down into both posts' slots, all the way to the floor.

---

## 4 · The rest

![Stage 4 on the bed](img/stage-4.png)

{batch_table(STAGES[3][0], STAGES[3][2])}

Print the floor first, then the posts: every wall needs a post on each side before it can go in, and the
lid goes on last.

**Inserts for the six posts of this stage**, 15 in all: one in every top end; one in each corner
post's higher side hole, and one in the lower side hole of the two that go to the corners with two
tabs (rear wall on the PSU side, far wall on the card side); for the mid posts, one in a foot boss
of the rear-wall and far-wall ones, and one in each foot boss of the PSU-side one. The two mid posts
beside the lid's seam, PSU side and card side, also take one in a top boss, facing the rear.

**Inserts for the seam bridges**, 12: one in each of the eight low bosses beside the floor's seams, two
per floor piece, and one in each of the four bosses under the lid.

**Screws**, all M3×8: every post to the floor tab or tabs beside it; the centre plate over the point
where the four floor pieces meet, and a strap across the long seam on each side of it; then the lid.
Join its two halves upside down and screw the other two straps across the seam, so that it is one
piece; lower it, and put eight screws down into the posts and two sideways through the tabs under its
rear half.

**On a bed under 250 mm**, print the four files in [`4-final/{SUBDIR_LIDQ}`](4-final/{SUBDIR_LIDQ}/)
instead of the two lid batches.

![Inside the finished case](img/inside.png)

## Where every insert and screw goes

39 inserts and 39 M3×8 socket-head screws. The horizontal ones must be M3×8: a longer screw bottoms out
in the post before it clamps.

![The 25 screws at floor level](img/screws-floor.png)

![The 14 screws of the lid](img/screws-lid.png)

![The kinds of joint](img/screws-closeups.png)

## Folder layout

```
print-pack/
├── README.md                  this file
├── 1-tests/                   1A-tests.3mf
│   └── stl/                   the same pieces as loose STLs
├── 2-board-and-card/          2A and 2B
│   └── stl/
├── 3-structure-sample/        3A and 3B
│   └── stl/
├── 4-final/                   4A to 4G
│   ├── stl/
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
