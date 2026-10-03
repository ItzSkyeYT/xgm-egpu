# Dimensions

All numbers in mm, read from the rendered STLs in `stl/` (as laid out for printing) and `stl/assembled/` (in place). Regenerate with `./dimensions.py`.

## Box

| | X (length) | Y (width) | Z (height) |
|---|---|---|---|
| outside, over the posts | 270.7 | 244 | 183.9 |
| inside the panels | 260.7 | 234 | 177.9 |

## Printed parts, as exported for printing (bed footprint X × Y, height Z)

| Part | Qty | X | Y | Z | What it is |
|---|---|---|---|---|---|
| `floor_rl` | 1 | 150.5 | 126.5 | 24.0 | floor quarter, rear / PSU side: cable bay floor with tie slots |
| `floor_rr` | 1 | 150.5 | 124.0 | 24.0 | floor quarter, rear / board side: 3 board bosses (inserts), holder sockets, foot relief, grommet clip |
| `floor_fl` | 1 | 126.7 | 126.5 | 24.0 | floor quarter, far / PSU side: PSU stops |
| `floor_fr` | 1 | 126.7 | 124.0 | 24.0 | floor quarter, far / board side: 2 board bosses (inserts), cradle sockets |
| `lid_l` | 1 | 150.5 | 244.0 | 75.3 | lid, rear half: lip, 4 pegs, card ribs, bracket guides |
| `lid_r` | 1 | 126.7 | 244.0 | 7.0 | lid, far half: lip, 4 pegs |
| `lid_rl` | 1 | 150.5 | 126.5 | 16.0 | lid quarter (small-bed alternative) |
| `lid_rr` | 1 | 150.5 | 124.0 | 75.3 | lid quarter (small-bed alternative) |
| `lid_fl` | 1 | 126.7 | 126.5 | 7.0 | lid quarter (small-bed alternative) |
| `lid_fr` | 1 | 126.7 | 124.0 | 7.0 | lid quarter (small-bed alternative) |
| `post_corner` | 4 | 15.0 | 15.0 | 180.3 | corner post: two panel slots at 90°, peg below, socket on top |
| `post_mid` | 4 | 15.0 | 20.0 | 180.3 | mid post: two panel slots in line, peg below, socket on top |
| `panel_rear_l` | 1 | 177.4 | 99.4 | 3.0 | rear wall, bay side: vents |
| `panel_rear_r` | 1 | 177.4 | 123.4 | 3.0 | rear wall, board side: USB-C, port window, cable exit, vents |
| `panel_far_l` | 1 | 177.4 | 99.4 | 3.0 | far wall, PSU side: PSU opening (IEC, switch, grille) |
| `panel_far_r` | 1 | 177.4 | 123.4 | 3.0 | far wall, board side: GPU exhaust vents |
| `panel_left_r` | 1 | 143.4 | 177.4 | 3.0 | -Y wall, rear part: bay vents / PSU intake |
| `panel_left_f` | 1 | 106.1 | 177.4 | 3.0 | -Y wall, far part: PSU intake grille |
| `panel_right_r` | 1 | 143.4 | 177.4 | 3.0 | +Y wall, rear part: GPU intake grille |
| `panel_right_f` | 1 | 106.1 | 177.4 | 3.0 | +Y wall, far part: GPU intake grille |
| `cradle` | 1 | 54.6 | 49.2 | 18.0 | support under the card's far end |
| `bracket_holder` | 1 | 119.9 | 46.5 | 9.0 | stands in the board's 3 holes, arm under the bracket tab |
| `shim_05` | as needed | 5.5 | 24.0 | 0.5 | 0.5 mm shim for the holder arm |
| `shim_10` | as needed | 5.5 | 24.0 | 1.0 | 1.0 mm shim |
| `shim_15` | as needed | 5.5 | 24.0 | 1.5 | 1.5 mm shim |
| `coupon` | 1 | 60.0 | 81.5 | 9.0 | fit test |

## Where each part sits (assembled; X along the board from its rear edge, Y across from the 24-pin edge, Z up from the floor's top surface)

| Part | X | Y | Z |
|---|---|---|---|
| board | 0.0 … 220.0 | -65.0 … 9.7 | 7.0 … 23.6 |
| bracket_holder | 3.0 … 12.0 | -61.5 … -15.0 | -2.4 … 117.5 |
| card | 3.5 … 253.7 | -59.6 … -15.4 | -1.1 … 133.9 |
| cradle | 235.7 … 253.7 | -63.1 … -13.9 | -2.4 … 52.2 |
| floor_fl | 135.0 … 261.7 | 23.5 … 150.0 | -3.0 … 21.0 |
| floor_fr | 135.0 … 261.7 | -94.0 … 30.0 | -3.0 … 21.0 |
| floor_rl | -9.0 … 141.5 | 23.5 … 150.0 | -3.0 … 21.0 |
| floor_rr | -9.0 … 141.5 | -94.0 … 30.0 | -3.0 … 21.0 |
| inserts | -1.2 … 253.9 | -86.2 … 142.2 | 2.0 … 177.9 |
| lid_l | -9.0 … 141.5 | -94.0 … 150.0 | 105.6 … 180.9 |
| lid_r | 135.0 … 261.7 | -94.0 … 150.0 | 173.9 … 180.9 |
| panel_far_l | 256.7 … 259.7 | 42.3 … 141.7 | 0.0 … 177.4 |
| panel_far_r | 256.7 … 259.7 | -85.7 … 37.7 | 0.0 … 177.4 |
| panel_left_f | 147.3 … 253.4 | 145.0 … 148.0 | 0.0 … 177.4 |
| panel_left_r | -0.7 … 142.7 | 145.0 … 148.0 | 0.0 … 177.4 |
| panel_rear_l | -7.0 … -4.0 | 42.3 … 141.7 | 0.0 … 177.4 |
| panel_rear_r | -7.0 … -4.0 | -85.7 … 37.7 | 0.0 … 177.4 |
| panel_right_f | 147.3 … 253.4 | -92.0 … -89.0 | 0.0 … 177.4 |
| panel_right_r | -0.7 … 142.7 | -92.0 … -89.0 | 0.0 … 177.4 |
| post_corner_fl | 246.7 … 261.7 | 135.0 … 150.0 | -2.4 … 177.9 |
| post_corner_fr | 246.7 … 261.7 | -94.0 … -79.0 | -2.4 … 177.9 |
| post_corner_rl | -9.0 … 6.0 | 135.0 … 150.0 | -2.4 … 177.9 |
| post_corner_rr | -9.0 … 6.0 | -94.0 … -79.0 | -2.4 … 177.9 |
| post_mid_far | 246.7 … 261.7 | 30.0 … 50.0 | -2.4 … 177.9 |
| post_mid_left | 135.0 … 155.0 | 135.0 … 150.0 | -2.4 … 177.9 |
| post_mid_rear | -9.0 … 6.0 | 30.0 … 50.0 | -2.4 … 177.9 |
| post_mid_right | 135.0 … 155.0 | -94.0 … -79.0 | -2.4 … 177.9 |
| psu | 85.7 … 245.7 | 48.0 … 134.0 | 0.1 … 150.0 |
| screws | -1.8 … 254.4 | -86.8 … 142.8 | 0.6 … 183.9 |
| zones | -17.0 … 284.7 | -84.6 … 134.0 | 0.4 … 177.8 |

## Measured inputs (from the real parts)

| What | Value | Parameter |
|---|---|---|
| card thickness at the bracket end | 42.2 | `gpu_w` |
| board top → underside of the bracket tab | 109.0 | `tab_above_board` |
| bracket foot below the board top | 9.7 | `foot_below_board` |
| board top → lowest point of the card near its far end | 18.9 | `card_bottom_clear` |
| board edge → outside of the sleeved 24-pin bend | 86.8 | `atx_bend_reach` (92 with margin) |
| 24-pin sleeved bundle diameter | 15.4 | — |
| cable grommet: round disc / square plate / gap | Ø14.8 / 14.7 / 1.4 | `grommet_d`, `grommet_gap`, `clip_t` |
| board's rear edge → grommet gap, harness straight | 41.5 | `grommet_x` (44 with 2.5 slack) |
| board's long edge → grommet centre, relaxed | 12.7 | `grommet_y` (12) |

## Features

| Feature | Size |
|---|---|
| panels | 3.0 thick; ends sit 7.0 deep in corner posts, 5.0 deep in mid posts; slots are 3.4 wide |
| posts | 15.0 × 15.0 section (corner), 15.0 × 14.0 (mid); stand 2.0 proud of the panels |
| square pegs / sockets | 6.0 × 6.0 pegs, 6.4 × 6.4 sockets (`peg_fit` 0.4); floor sockets go through the 3.0 plate |
| lid and floor lips | 1.5 thick, 4.0 tall (lid) and 3.0 tall (floor), inside the panels, broken at the posts |
| jigsaw tabs | 10.4 wide head, 6.0 neck, 6.5 long; slots are 0.2 larger per side (`tab_fit`) |
| board bosses | Ø8.5, each with a Ø4.0 × 5.6 hole for an M3×5×4.5 heat-set insert (`insert_hole`); board underside at 7.0, top surface at 8.6 |
| bracket holder | 5.5 thick (x 3.0 … 8.5), arm 11 … 62 wide, seat 108.9 above the board top; pegs 2.6 × 3.6 |
| cradle | inner width 43.2 (card 42.2 + 1), rest 18.6 above the board top |
| vents | 3.0 wide slots, 20 long, 6.0 pitch, rows every 24 |
