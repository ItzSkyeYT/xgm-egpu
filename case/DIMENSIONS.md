# Dimensions

All numbers in mm, read from the rendered STLs in `stl/` (as laid out for printing) and `stl/assembled/`
(in place). Defaults: Inno3D RTX 3060 Twin X2 OC, 160 mm ATX PSU, XG Mobile Station Lite board.

## Box

| | X (length) | Y (width) | Z (height) |
|---|---|---|---|
| outside, over the posts | 270.7 | 248.0 | 179.6 |
| inside the panels | 260.7 | 238.0 | 173.6 |
| cable channel (between PSU and board) | 260.7 | 65.0 | 173.6 |
| cable bay (behind the PSU) | 89.7 | 86.0 | 173.6 |

## Printed parts, as exported for printing (bed footprint X × Y, height Z)

| Part | Qty | X | Y | Z | What it is |
|---|---|---|---|---|---|
| `floor_rl` | 1 | 150.5 | 123.5 | 25.0 | floor quarter, rear / PSU side: cable saddles, PSU side stops |
| `floor_rr` | 1 | 150.5 | 131.0 | 25.0 | floor quarter, rear / board side: 5 board pegs, 3 clips, holder sockets, foot relief |
| `floor_fl` | 1 | 126.7 | 123.5 | 25.0 | floor quarter, far / PSU side: PSU end stop, cable-tie slots |
| `floor_fr` | 1 | 126.7 | 131.0 | 25.0 | floor quarter, far / board side: cradle sockets, clip |
| `lid_l` | 1 | 150.5 | 248.0 | 75.3 | lid, rear half: lip, 4 pegs, card ribs, bracket guides |
| `lid_r` | 1 | 126.7 | 248.0 | 7.0 | lid, far half: lip, 4 pegs |
| `lid_rl` | 1 | 150.5 | 123.5 | 7.0 | lid quarter (small-bed alternative) |
| `lid_rr` | 1 | 150.5 | 131.0 | 75.3 | lid quarter (small-bed alternative) |
| `lid_fl` | 1 | 126.7 | 123.5 | 7.0 | lid quarter (small-bed alternative) |
| `lid_fr` | 1 | 126.7 | 131.0 | 7.0 | lid quarter (small-bed alternative) |
| `post_corner` | 4 | 15.0 | 15.0 | 176.0 | corner post: two panel slots at 90°, peg below, socket on top |
| `post_mid` | 4 | 15.0 | 14.0 | 176.0 | mid post: two panel slots in line, peg below, socket on top |
| `panel_rear_l` | 1 | 173.1 | 116.4 | 3.0 | rear wall, PSU side: PSU opening |
| `panel_rear_r` | 1 | 173.1 | 110.4 | 3.0 | rear wall, board side: USB-C, port window, cable exit, vents |
| `panel_far_l` | 1 | 173.1 | 116.4 | 3.0 | far wall, PSU side: vents |
| `panel_far_r` | 1 | 173.1 | 110.4 | 3.0 | far wall, board side: GPU exhaust vents |
| `panel_left_r` | 1 | 143.4 | 173.1 | 3.0 | -Y wall, rear part: PSU intake grille |
| `panel_left_f` | 1 | 106.1 | 173.1 | 3.0 | -Y wall, far part: PSU intake grille |
| `panel_right_r` | 1 | 143.4 | 173.1 | 3.0 | +Y wall, rear part: GPU intake grille |
| `panel_right_f` | 1 | 106.1 | 173.1 | 3.0 | +Y wall, far part: GPU intake grille |
| `cradle` | 1 | 40.2 | 49.0 | 18.0 | support under the card's far end |
| `bracket_holder` | 1 | 115.6 | 51.0 | 5.5 | stands in the board's 3 holes, arm under the bracket tab |
| `shim_05` | as needed | 5.5 | 24.0 | 0.5 | 0.5 mm shim for the holder arm |
| `shim_10` | as needed | 5.5 | 24.0 | 1.0 | 1.0 mm shim |
| `shim_15` | as needed | 5.5 | 24.0 | 1.5 | 1.5 mm shim |
| `coupon` | 1 | 60.0 | 36.5 | 9.0 | fit test |

## Where each part sits (assembled; world frame: X along the board from its rear edge, Y across from the 24-pin edge, Z up from the floor's top surface)

| Part | X | Y | Z |
|---|---|---|---|
| board | 0.0 … 220.0 | -9.7 … 65.0 | 5.0 … 21.6 |
| bracket_holder | 3.0 … 8.5 | 11.0 … 62.0 | -2.4 … 113.2 |
| card | 3.5 … 253.7 | 15.4 … 59.4 | 0.5 … 131.6 |
| cradle | 235.7 … 253.7 | 13.9 … 62.9 | -2.4 … 37.8 |
| floor_fl | 135.0 … 261.7 | -167.0 … -43.5 | -3.0 … 22.0 |
| floor_fr | 135.0 … 261.7 | -50.0 … 81.0 | -3.0 … 22.0 |
| floor_rl | -9.0 … 141.5 | -167.0 … -43.5 | -3.0 … 22.0 |
| floor_rr | -9.0 … 141.5 | -50.0 … 81.0 | -3.0 … 22.0 |
| lid_l | -9.0 … 141.5 | -167.0 … 81.0 | 101.3 … 176.6 |
| lid_r | 135.0 … 261.7 | -167.0 … 81.0 | 169.6 … 176.6 |
| panel_far_l | 256.7 … 259.7 | -158.7 … -42.3 | 0.0 … 173.1 |
| panel_far_r | 256.7 … 259.7 | -37.7 … 72.7 | 0.0 … 173.1 |
| panel_left_f | 147.3 … 253.4 | -165.0 … -162.0 | 0.0 … 173.1 |
| panel_left_r | -0.7 … 142.7 | -165.0 … -162.0 | 0.0 … 173.1 |
| panel_rear_l | -7.0 … -4.0 | -158.7 … -42.3 | 0.0 … 173.1 |
| panel_rear_r | -7.0 … -4.0 | -37.7 … 72.7 | 0.0 … 173.1 |
| panel_right_f | 147.3 … 253.4 | 76.0 … 79.0 | 0.0 … 173.1 |
| panel_right_r | -0.7 … 142.7 | 76.0 … 79.0 | 0.0 … 173.1 |
| post_corner_fl | 246.7 … 261.7 | -167.0 … -152.0 | -2.4 … 173.6 |
| post_corner_fr | 246.7 … 261.7 | 66.0 … 81.0 | -2.4 … 173.6 |
| post_corner_rl | -9.0 … 6.0 | -167.0 … -152.0 | -2.4 … 173.6 |
| post_corner_rr | -9.0 … 6.0 | 66.0 … 81.0 | -2.4 … 173.6 |
| post_mid_far | 246.7 … 261.7 | -47.0 … -33.0 | -2.4 … 173.6 |
| post_mid_left | 138.0 … 152.0 | -167.0 … -152.0 | -2.4 … 173.6 |
| post_mid_rear | -9.0 … 6.0 | -47.0 … -33.0 | -2.4 … 173.6 |
| post_mid_right | 138.0 … 152.0 | 66.0 … 81.0 | -2.4 … 173.6 |
| psu | 7.0 … 167.0 | -151.0 … -65.0 | 0.1 … 150.0 |
| zones | -32.0 … 253.7 | -151.0 … 59.4 | 3.5 … 173.5 |

## Features

| Feature | Size |
|---|---|
| panels | 3.0 thick; ends sit 7.0 deep in corner posts, 5.0 deep in mid posts; slots are 3.4 wide |
| posts | 15.0 × 15.0 section (corner), 15.0 × 14.0 (mid), 173.6 tall + 2.4 peg; stand 2.0 proud of the panels |
| square pegs / sockets | 6.0 × 6.0 pegs, 6.4 × 6.4 sockets (`peg_fit` 0.4); floor sockets go through the 3.0 plate |
| lid and floor lips | 1.5 thick, 4.0 tall (lid) and 3.0 tall (floor), 1.5 inside the panels, broken at the posts |
| jigsaw tabs | 10.4 wide head, 6.0 neck, 6.5 long; slots are 0.2 larger per side (`tab_fit`) |
| board pegs | Ø2.9 × 7.6 on Ø7.0 × 4.95 bosses; board underside at 5.0, top surface at 6.6 |
| board clips | 1.2 thick beams, 16 long, lip 1.2 over the board at 6.9 … 8.1 |
| bracket holder | 5.5 thick (x 3.0 … 8.5), arm 11 … 62 wide, seat at 113.2 above the floor (`tab_above_board` 106.7 + 6.6 − 0.1); pegs 2.6 × 3.6 |
| cradle | inner width 43.2 (card 42.2 + 1), rest at 12.8 above the floor (`card_bottom_clear` 6.5 + 6.6 − 0.3), walls to 37.8 |
| card envelope | x 13.7 … 253.7, y 17.4 … 59.6, bottom 13.1, top 131.6; 42.0 of air above it |
| PSU envelope | x 7.0 … 167.0, y −151.0 … −65.0, z 0 … 150; 11.0 recess behind the rear wall for the IEC plug |
| rear-wall openings | PSU face 80 × 144; USB-C 21 × 12 at z 3.6 … 15.6; display ports 21.4 × 86.4 at z 12.6 … 99; cable exit 30 × 23.5 at z 3.5 … 27 |
| vents | 3.0 wide slots, 20 long, 6.0 pitch, rows every 24 |
| cable saddles | 30 inner width, 22 tall, 14 long, at x 110 and 190 in the channel |

