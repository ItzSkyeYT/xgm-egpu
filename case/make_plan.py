#!/usr/bin/env python3
"""Floor plan at 1:1: plan/floor-plan-A3.pdf and plan/floor-plan-A4-2pages.pdf.
Outlines come from the model (part="plan_shapes"), dimensions from part="plan_meta"; labels, numbered
markers, legend and page layout are drawn here as real text. The A4 pair joins at a cut line between the
PSU and the board: sheet 1 is cut along it and laid on sheet 2, which repeats a band above the line. Its
pages are portrait with the drawing turned a quarter, so that it fits an inkjet's printable area."""
import os, re, json, subprocess, tempfile, html

HERE = os.path.dirname(os.path.abspath(__file__))
SCAD = os.path.join(HERE, 'xgm-lite-frame.scad')
OUT = os.path.join(HERE, 'plan')
FONT = "Liberation Sans, DejaVu Sans, Arial, sans-serif"
INK, ACCENT, MUTED = '#1f2328', '#c2410c', '#57606a'

tmp = tempfile.mkdtemp()
def scad(part, out):
    subprocess.run(['openscad', '-o', out, '-D', f'part="{part}"', SCAD], check=True, capture_output=True)
scad('plan_shapes', f'{tmp}/shapes.svg'); scad('plan_meta', f'{tmp}/meta.echo')
paths = re.findall(r'<path d="([^"]+)"', open(f'{tmp}/shapes.svg').read(), re.S)
P = dict(json.loads(re.search(r'PLAN = (\[.*\])', open(f'{tmp}/meta.echo').read()).group(1)))
mir = P['mirror'] == 1
def S(x, y): return (x, y if mir else -y)          # model coordinates -> SVG millimetres (y down)

x0, x1 = P['xp0'], P['xp1']
y0, y1 = sorted([S(0, P['yp0'])[1], S(0, P['yp1'])[1]])
W, H = x1 - x0, y1 - y0
num = lambda v: f"{v:g}"

# ---------- labels written straight onto the drawing (big areas only) ----------
cy_card = (P['card_y0'] + P['card_y1']) / 2
psu_cy = (P['psu_y0'] + P['psu_y1']) / 2
inline = [
    (P['xb'] + 30, cy_card - 1.5, f"graphics card  {num(P['gpu_len'])} × {num(P['gpu_w'])}", 3.4, 'bold'),
    (P['xb'] + 30, cy_card + 3.5, "its fans face the wall below", 2.6, 'normal'),
    (92, 9.5, "board 220 × 65 · " + ("five M3 screws in heat-set inserts" if P['use_inserts'] else "five pegs and clips"), 2.5, 'normal'),
    (P['psu_x0'] + 12, psu_cy - 3, f"PSU, lying on its side  {num(P['psu_l'])} × {num(P['psu_w'])} × {num(P['psu_h'])}", 3.4, 'bold'),
    (P['psu_x0'] + 12, psu_cy + 2, "its fan faces the wall above", 2.6, 'normal'),
    (P['psu_x0'] + 3, psu_cy + 14, "← modular face (cables)", 2.6, 'normal'),
    (P['bay_x0'] + 5, P['psu_y0'] + 12, "cable bay", 3.4, 'bold'),
    (P['bay_x0'] + 5, P['psu_y0'] + 17, "spare 24-pin and 8-pin length", 2.5, 'normal'),
]
if P['iec_far']:
    inline.append((P['psu_x1'] - 3, psu_cy + 14, "IEC inlet at the far wall →", 2.6, 'end'))

# ---------- numbered markers, explained in the legend ----------
callouts = [
    (P['xo0'], (P['usbc_y0'] + P['usbc_y1']) / 2, "USB-C opening in the rear wall"),
    (P['xo0'], (P['bracket_y0'] + P['bracket_y1']) / 2, "window in the rear wall for the card's display ports"),
    (P['xo0'], (P['exit_y0'] + P['exit_y1']) / 2, "notch for the laptop cable, open at the bottom of the rear wall"),
    (P['xo0'], psu_cy, "rear wall: vents over the cable bay" if P['iec_far'] else "rear wall: PSU opening"),
    (P['xo1'], psu_cy, "far wall: opening for the PSU's power inlet and switch" if P['iec_far'] else "far wall: vents"),
    (P['xo1'], cy_card, "far wall: exhaust grille for the card"),
    ((P['psu_x0'] + P['psu_x1']) / 2, P['yo0'], "wall above the PSU: PSU intake grille"),
    ((P['xb'] + P['card_x1']) / 2, P['yo1'], "wall below the card: intake grille for the card's fans"),
    ((P['hdr_x0'] + P['hdr_x1']) / 2, -P['bend'] / 2, "24-pin plug and its sleeved bend: keep this area clear"),
    ((P['hx0'] + P['hx1']) / 2, 40, "bracket holder, standing in the board's three small holes"),
    (P['foot_slot_x'], 58, "bracket line: the bracket's foot drops into the board's slot"),
    (P['card_x1'] - 9, cy_card, "cradle under the card's far end"),
    (P['grommet_x'], P['grommet_y'], "clip for the laptop cable's rubber grommet"),
    ((P['grommet_x'] + 20 + P['conn_x1']) / 2, P['board_w'] + 5.75, "the laptop cable's taped harness runs along this edge"),
]

def text(x, y, s, size, weight='normal', anchor='start', fill=INK, halo=True):
    style = f"font-family:{FONT};font-size:{size}px;font-weight:{weight};fill:{fill}"
    if halo: style += ";paint-order:stroke;stroke:#ffffff;stroke-width:0.9;stroke-linejoin:round"
    return f'<text x="{x:.2f}" y="{y:.2f}" text-anchor="{anchor}" style="{style}">{html.escape(s)}</text>'

def marker(x, y, n):
    return (f'<circle cx="{x:.2f}" cy="{y:.2f}" r="2.9" fill="#ffffff" stroke="{ACCENT}" stroke-width="0.5"/>'
            + text(x, y + 1.15, str(n), 3.2, 'bold', 'middle', ACCENT, halo=False))

def plan_group(tx, ty, clip=None):
    """The drawing, its labels and markers, translated so model point (x0, y0) lands at (tx, ty) on the page."""
    cid = f"c{abs(hash((tx, ty, clip))) % 10**8}"
    defs = ''
    clip_attr = ''
    if clip:
        cy0, cy1 = clip
        defs = f'<clipPath id="{cid}"><rect x="{x0 - 6}" y="{cy0}" width="{W + 12}" height="{cy1 - cy0}"/></clipPath>'
        clip_attr = f' clip-path="url(#{cid})"'
    body = [f'<path d="{d}" fill="{INK}" fill-rule="evenodd"/>' for d in paths]
    for (x, y, s, size, w) in inline:
        sx, sy = S(x, y)
        anchor = 'end' if w == 'end' else 'start'
        body.append(text(sx, sy, s, size, 'normal' if w == 'end' else w, anchor))
    for i, (x, y, _) in enumerate(callouts, start=1):
        body.append(marker(*S(x, y), i))
    return defs, f'<g transform="translate({tx - x0:.2f},{ty - y0:.2f})"{clip_attr}>' + ''.join(body) + '</g>'

def cut_marks(tx, ty):
    """The A4 cut line, dashed across the drawing at model y CUT, with two crosses on it in the empty strip between the
    24-pin bend and the far wall. Crosses in the side margins would land where an inkjet cannot print."""
    y = ty + (CUT - y0)
    out = [f'<line x1="{tx - 2:.2f}" y1="{y:.2f}" x2="{tx + W + 2:.2f}" y2="{y:.2f}" stroke="{ACCENT}" stroke-width="0.3" stroke-dasharray="3 1.5"/>']
    for mxc in (P['hdr_x1'] + 30, P['xi1'] - 30):
        cx = tx + (mxc - x0)
        out.append(f'<g stroke="{ACCENT}" stroke-width="0.35" fill="none"><circle cx="{cx:.2f}" cy="{y:.2f}" r="2.2"/>'
                   f'<line x1="{cx:.2f}" y1="{y - 3:.2f}" x2="{cx:.2f}" y2="{y + 3:.2f}"/></g>')
    return ''.join(out)

def scale_bar(x, y):
    return (f'<g stroke="{INK}" stroke-width="0.6"><line x1="{x}" y1="{y}" x2="{x + 100}" y2="{y}"/>'
            f'<line x1="{x}" y1="{y - 3}" x2="{x}" y2="{y + 3}"/><line x1="{x + 100}" y1="{y - 3}" x2="{x + 100}" y2="{y + 3}"/>'
            f'<line x1="{x + 50}" y1="{y - 1.5}" x2="{x + 50}" y2="{y + 1.5}"/></g>'
            + text(x + 104, y + 1.2, "100 mm: check this bar with a ruler before trusting the page", 3, 'normal', 'start', MUTED, False))

def legend(x, y, cols=2, colw=136, lh=5.6):
    out = [text(x, y, "Numbered markers", 3.6, 'bold', 'start', INK, False)]
    rows = -(-len(callouts) // cols)
    for i, (_, _, s) in enumerate(callouts, start=1):
        c, r = (i - 1) // rows, (i - 1) % rows
        lx, ly = x + c * colw, y + 7 + r * lh
        out.append(marker(lx + 3, ly - 1.1, i))
        out.append(text(lx + 8, ly, s, 2.9, 'normal', 'start', INK, False))
    return ''.join(out)

def title(x, y, extra):
    return (text(x, y, "XGM Lite frame · floor plan 1:1", 6, 'bold', 'start', INK, False)
            + text(x, y + 6.5, f"Box outside {W:.1f} × {H:.0f} mm, seen from above with the board's components facing up. "
                   "Print at 100 % (actual size), never \"fit to page\".", 3, 'normal', 'start', MUTED, False)
            + (text(x, y + 11.5, extra, 3, 'normal', 'start', MUTED, False) if extra else ''))

def page(w, h, *parts, turn=False):
    """turn: lay the sheet out w x h, then turn it a quarter clockwise onto an h x w page (its left edge becomes the top)."""
    defs = ''.join(p[0] for p in parts if isinstance(p, tuple))
    body = ''.join(p[1] if isinstance(p, tuple) else p for p in parts)
    if turn:
        body, w, h = f'<g transform="translate({h},0) rotate(90)">{body}</g>', h, w
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}mm" height="{h}mm" viewBox="0 0 {w} {h}">'
            f'<rect width="{w}" height="{h}" fill="#ffffff"/><defs>{defs}</defs>{body}</svg>')

os.makedirs(OUT, exist_ok=True)
mx = (297 - W) / 2                                         # centre the plan horizontally on a 297 mm wide sheet

# ---------- A3 portrait: everything on one sheet ----------
a3 = page(297, 420,
          title(mx, 16, "Lay the real board, card and PSU on their outlines to check the fit before printing anything."),
          plan_group(mx, 36),
          scale_bar(mx, 36 + H + 12),
          legend(mx, 36 + H + 26))
open(f'{tmp}/a3.svg', 'w').write(a3)

# ---------- two A4 sheets: sheet 1 is cut along a line and laid on sheet 2 ----------
# Each sheet is laid out 297 x 210 and turned onto a portrait page, so no printer driver turns it, and the 270.7 mm
# side runs down the paper, where an HP Deskjet 1510 prints from 1.5 mm below the top to 14.5 mm above the bottom
# (A4 ImageableArea in its HPLIP PPD). Left landscape, the driver turns it +90° and a wall lands in the 14.5 mm.
PRINT_X = (1.52, 297 - 14.48)                              # printable band along the 297 mm side, top to bottom
ax = (PRINT_X[0] + PRINT_X[1] - W) / 2                     # the drawing centred in that band
assert PRINT_X[0] + 1 < ax - 3.2 and ax + W + 3.2 < PRINT_X[1] - 1, "the wall markers no longer fit the printable band"
CUT = min(S(0, 0)[1], S(0, P['board_w'])[1]) - 4           # model y of the cut: 4 mm above the board, below the PSU
OVER = 15                                                  # sheet 2 repeats this much above the cut, for the tape
for (x, y, s, *_) in callouts + inline:
    assert abs(S(x, y)[1] - CUT) > 5, f"'{s}' sits on the A4 cut line"
top1 = 30                                                  # page y of the drawing's top edge on sheet 1
cut1 = top1 + (CUT - y0)                                   # page y of the cut line on sheet 1
p1 = page(297, 210,
          title(ax, 13, "Sheet 1 of 2. Cut along the dashed line, lay this sheet on sheet 2 with the cut edge on its dashed line "
                        "and the crosses lined up, then tape."),
          plan_group(ax, top1, clip=(y0 - 10, CUT)),
          cut_marks(ax, top1),
          text(ax, cut1 + 5.5, "cut along the dashed line: the strip below it is not needed once the scale is checked",
               2.8, 'normal', 'start', MUTED, False),
          scale_bar(ax, cut1 + 16), turn=True)
ty2 = 14 - (CUT - OVER - y0)                               # sheet 2's drawing starts OVER mm above the cut, at page y 14
bot2 = ty2 + (y1 - y0)                                     # page y of the drawing's bottom edge on sheet 2
p2 = page(297, 210,
          text(ax, 9, "XGM Lite frame · floor plan 1:1 · sheet 2 of 2", 3.4, 'bold', 'start', INK, False),
          text(ax + W, 9, "sheet 1 goes on top: its cut edge on the dashed line, crosses on crosses", 2.8, 'normal', 'end', MUTED, False),
          plan_group(ax, ty2, clip=(CUT - OVER, y1 + 6)),
          cut_marks(ax, ty2),
          scale_bar(ax, bot2 + 10),
          legend(ax, bot2 + 22), turn=True)
open(f'{tmp}/a4-1.svg', 'w').write(p1); open(f'{tmp}/a4-2.svg', 'w').write(p2)

# cairo stamps the PDFs with SOURCE_DATE_EPOCH when it is set: the model's last commit, so an unchanged plan rebuilds byte for byte
epoch = subprocess.run(['git', 'log', '-1', '--format=%ct', '--', SCAD], capture_output=True, text=True, cwd=HERE).stdout.strip()
env = dict(os.environ, SOURCE_DATE_EPOCH=epoch or '0')
subprocess.run(['rsvg-convert', '-f', 'pdf', '-o', f'{OUT}/floor-plan-A3.pdf', f'{tmp}/a3.svg'], check=True, env=env)
subprocess.run(['rsvg-convert', '-f', 'pdf', '-o', f'{OUT}/floor-plan-A4-2pages.pdf', f'{tmp}/a4-1.svg', f'{tmp}/a4-2.svg'], check=True, env=env)
print("written:", f'{OUT}/floor-plan-A3.pdf', f'{OUT}/floor-plan-A4-2pages.pdf',
      f"(plan {W:.1f} x {H:.1f} mm; A4 cut line at page y {cut1:.0f} on sheet 1, sheet 2's drawing ends at page y {bot2:.0f})")
