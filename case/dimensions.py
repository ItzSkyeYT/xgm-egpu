#!/usr/bin/env python3
"""Regenerate DIMENSIONS.md from the rendered STLs and the model's echo output. Run after ./render.sh and ./render-assembled.sh."""
import glob, os, re, subprocess
def bbox(f):
    xs=[];ys=[];zs=[]
    for line in open(f):
        if 'vertex' in line:
            a=line.split(); xs.append(float(a[1])); ys.append(float(a[2])); zs.append(float(a[3]))
    return (min(xs),max(xs),min(ys),max(ys),min(zs),max(zs))
echo=subprocess.run(['openscad','-o','out/_dims.stl','-D','part="none"','xgm-lite-frame.scad'],capture_output=True,text=True).stderr
nums=lambda key: re.search(key+r'[^"]*',echo).group(0)
inside=re.search(r'interior ([\d.]+) x ([\d.]+) x ([\d.]+) mm; outside ([\d.]+) x ([\d.]+) x ([\d.]+)',echo).groups()
qty={'post_corner':4,'post_mid':4,'bridge_strap':4,'bracket_washer':2,'shim_05':'print-only','shim_10':'print-only','shim_15':'print-only'}
desc={
 'floor_rl':'floor quarter, rear / PSU side: cable bay floor with tie slots','floor_rr':'floor quarter, rear / board side: 3 board bosses (inserts), holder sockets, foot relief, grommet clip',
 'floor_fl':'floor quarter, far / PSU side: PSU stops','floor_fr':'floor quarter, far / board side: 2 board bosses (inserts), cradle sockets',
 'lid_l':'lid, rear half: lip, strap bosses, two tabs for the mid posts','lid_r':'lid, far half: lip, strap bosses',
 'lid_rl':'lid quarter (small-bed alternative)','lid_rr':'lid quarter (small-bed alternative)','lid_fl':'lid quarter (small-bed alternative)','lid_fr':'lid quarter (small-bed alternative)',
 'post_corner':'corner post: two panel slots at 90°, peg below, insert holes in the top end and the sides','post_mid':'mid post: two panel slots in line, peg below, insert holes in the top end and the side bosses',
 'panel_rear_l':'rear wall, bay side: vents','panel_rear_r':'rear wall, board side: USB-C, port window, cable exit, vents, boss for the screw into the bracket holder',
 'panel_far_l':'far wall, PSU side: PSU opening (IEC, switch, grille)','panel_far_r':'far wall, board side: GPU exhaust vents',
 'panel_left_r':'-Y wall, rear part: bay vents / PSU intake','panel_left_f':'-Y wall, far part: PSU intake grille',
 'panel_right_r':'+Y wall, rear part: GPU intake grille','panel_right_f':'+Y wall, far part: GPU intake grille',
 'cradle':"support under the card's far end",'bracket_holder':"stands in the board's 3 holes; the bracket tab is screwed to its top edge, its back to the rear wall",
 'bracket_washer':"under the head of the bracket's screw",'bridge_centre':'plate over the point where the four floor pieces meet','bridge_strap':'strap across a seam: two on the floor, two under the lid',
 'shim_05':'0.5 mm shim for the holder (print-only variant)','shim_10':'1.0 mm shim','shim_15':'1.5 mm shim','coupon':'fit test'}
order=['floor_rl','floor_rr','floor_fl','floor_fr','lid_l','lid_r','lid_rl','lid_rr','lid_fl','lid_fr','post_corner','post_mid',
       'panel_rear_l','panel_rear_r','panel_far_l','panel_far_r','panel_left_r','panel_left_f','panel_right_r','panel_right_f','cradle','bracket_holder','bracket_washer','bridge_centre','bridge_strap','shim_05','shim_10','shim_15','coupon']
out=[]
out.append("# Dimensions\n\nAll numbers in mm, read from the rendered STLs in `stl/` (as laid out for printing) and `stl/assembled/` (in place). Regenerate with `./dimensions.py`.\n")
out.append("## Box\n\n| | X (length) | Y (width) | Z (height) |\n|---|---|---|---|")
out.append(f"| outside, over the posts | {inside[3]} | {inside[4]} | {inside[5]} |\n| inside the panels | {inside[0]} | {inside[1]} | {inside[2]} |\n")
out.append("## Printed parts, as exported for printing (bed footprint X × Y, height Z)\n\n| Part | Qty | X | Y | Z | What it is |\n|---|---|---|---|---|---|")
for n in order:
    f=f'stl/{n}.stl'
    if os.path.exists(f):
        x0,x1,y0,y1,z0,z1=bbox(f); out.append(f"| `{n}` | {qty.get(n,1)} | {x1-x0:.1f} | {y1-y0:.1f} | {z1-z0:.1f} | {desc.get(n,'')} |")
out.append("\n## Where each part sits (assembled; X along the board from its rear edge, Y across from the 24-pin edge, Z up from the floor's top surface)\n\n| Part | X | Y | Z |\n|---|---|---|---|")
for f in sorted(glob.glob('stl/assembled/*.stl')):
    n=os.path.basename(f)[:-4]; x0,x1,y0,y1,z0,z1=bbox(f); out.append(f"| {n} | {x0:.1f} … {x1:.1f} | {y0:.1f} … {y1:.1f} | {z0:.1f} … {z1:.1f} |")
out.append("\n## Measured inputs (from the real parts)\n\n| What | Value | Parameter |\n|---|---|---|")
out.append("| card thickness at the bracket end | 42.2 | `gpu_w` |\n| board top → underside of the bracket tab | 109.0 | `tab_above_board` |\n| bracket foot below the board top | 9.7 | `foot_below_board` |")
out.append("| bracket's top tab, end to end | 39.4 | `bracket_w` (41.5: the envelope of a two-slot bracket and its tab) |\n| top tab, free edge → the bend | 10.6 | `tab_reach` (11.4 to the bracket's outer face) |")
out.append("| board top → lowest point of the card near its far end | 18.9 | `card_bottom_clear` |\n| board edge → outside of the sleeved 24-pin bend | 86.8 | `atx_bend_reach` (92 with margin) |")
out.append("| 24-pin sleeved bundle diameter | 15.4 | — |\n| cable grommet: round disc / square plate / gap | Ø14.8 / 14.7 / 1.4 | `grommet_d`, `grommet_gap`, `clip_t` |")
out.append("| board's rear edge → grommet gap, harness straight | 41.5 | `grommet_x` (44 with 2.5 slack) |\n| board's long edge → grommet centre, relaxed | 12.7 | `grommet_y` (12) |\n")
out.append("## Features\n\n| Feature | Size |\n|---|---|")
out.append("| panels | 3.0 thick; ends sit 7.0 deep in corner posts, 5.0 deep in mid posts; slots are 3.4 wide |\n| posts | 15.0 × 15.0 section (corner), 15.0 × 14.0 (mid); stand 2.0 proud of the panels |")
out.append("| square pegs / sockets | 6.0 × 6.0 pegs, 6.4 × 6.4 sockets (`peg_fit` 0.4); floor sockets go through the 3.0 plate |\n| lid and floor lips | 1.5 thick, 4.0 tall (lid) and 3.0 tall (floor), inside the panels, broken at the posts |")
out.append("| jigsaw tabs | 10.4 wide head, 6.0 neck, 6.5 long; slots are 0.2 larger per side (`tab_fit`) |\n| board bosses | Ø8.5, each with a Ø4.0 × 5.6 hole for an M3×5×4.5 heat-set insert (`insert_hole`); board underside at 7.0, top surface at 8.6 |")
out.append("| bracket holder | one plate 6.2 thick (x 5.8 … 12.0), top edge y 15 … 66, 108.9 above the board top; pegs 2.6 × 3.6; M3 inserts in the top edge (under the tab's oval hole, x 8.7, y 39.1) and in the back (y 61.5, 100 above the floor) |\n| cradle | inner width 43.2 (card 42.2 + 1), rest 18.6 above the board top |")
out.append("| vents | 3.0 wide slots, 20 long, 6.0 pitch, rows every 24 |")
open('DIMENSIONS.md','w').write("\n".join(out)+"\n"); print("DIMENSIONS.md written")
