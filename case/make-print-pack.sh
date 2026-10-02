#!/usr/bin/env bash
# Build a self-contained folder to take to a printer: one subfolder per stage, with quantities and pass checks.
# Usage: ./make-print-pack.sh [destination]   (default: ./print-pack, inside the repo)
set -eu
cd "$(dirname "$0")"
dest="${1:-}"
if [ -z "$dest" ]; then dest="$(pwd)/print-pack"; fi
rm -rf "$dest"; mkdir -p "$dest"
put() { local dir="$1"; shift; mkdir -p "$dest/$dir"; for p in "$@"; do cp "stl/$p.stl" "$dest/$dir/"; done; }

put "1-tests"              coupon coupon_rear
put "2-board-fit"          floor_rr bracket_holder shim_05 shim_10 shim_15
put "3-card-support"       floor_fr cradle
put "4-structure-sample"   post_corner post_mid panel_rear_r
put "5-final"              floor_rl floor_fl post_corner post_mid panel_rear_l panel_far_l panel_far_r panel_left_r panel_left_f panel_right_r panel_right_f lid_l lid_r
put "5-final/lid-quarters-if-bed-under-250mm" lid_rl lid_rr lid_fl lid_fr
mkdir -p "$dest/reference"
cp xgm-lite-frame-assembled.3mf plan/floor-plan-A3.pdf plan/floor-plan-A4-2pages.pdf DIMENSIONS.md README.md "$dest/reference/"
cp img/outside.png img/inside.png img/rear.png "$dest/reference/"

cat > "$dest/READ-ME-FIRST.txt" <<'TXT'
XGM LITE FRAME - print pack
===========================
Material: PETG (PLA sags next to a warm GPU and creeps under the PSU).
Settings: 0.2 mm layers, 3-4 walls, 25-40 % infill, NO supports anywhere.
Orientation: every STL is already laid out for the bed. Panels print flat, lid pieces upside down
(as exported), posts upright (socket on the bed, peg up), cradle and holder on their side (as exported).
Bed needed: 180 x 180 mm for everything except the two-piece lid (250 mm); Z needed: 182 mm (posts).
If the bed is under 250 mm, print the four lid quarters instead of lid_l / lid_r.

Print the folders in order. Each stage proves something before the next; only the two coupons are
throwaway, everything else goes into the finished box.

1-tests  (one plate, ~25 g, < 1 h)
  coupon.stl        jigsaw tab -> slot, 6 mm peg -> socket, snap the thin bar off and push it into the
                    panel slot. All by hand, all staying put.
  coupon_rear.stl   slice of the real rear wall: laptop-cable boot through the big opening, USB-C plug
                    through the small one, an HDMI plug through the bottom of the port window.
  FAIL -> note which one binds or rattles; one tolerance number changes, reprint the coupon only.

2-board-fit  (~95 g)
  floor_rr.stl, bracket_holder.stl, shim_05/10/15.stl
  Bare board onto the five pegs: flat on the bosses, the four clips snapped over its edges.
  Holder's three pegs down through the board's small holes. Card in: foot in the board's slot, tab on
  the holder's arm or a hair above it (that is what the shims are for).
  FAIL on the pegs -> stop. FAIL on the tab by > 2 mm -> re-measure the tab height; holder reprints.

3-card-support  (~80 g)
  floor_fr.stl, cradle.stl
  Join the two quarters on their jigsaw tabs. Card in, far end on the cradle: must rest on it without
  lifting the card out of the slot.  FAIL -> cradle height; only the cradle reprints.

4-structure-sample  (~115 g)
  post_corner.stl x1, post_mid.stl x1, panel_rear_r.stl
  Posts into the floor sockets, the panel slides down into both slots. Checks your Z against 180 mm.

5-final  (the rest, ~800 g)
  floor_rl, floor_fl              x1 each
  post_corner                     x3 MORE (4 total)
  post_mid                        x3 MORE (4 total)
  panel_rear_l, panel_far_l, panel_far_r, panel_left_r, panel_left_f, panel_right_r, panel_right_f   x1 each
  lid_l + lid_r (250 mm bed)  OR  lid-quarters-if-bed-under-250mm/ (all four)

reference/
  xgm-lite-frame-assembled.3mf   the whole case assembled, every part a separate object (open in Orca,
                                 hide parts to look inside). NOT for printing.
  floor-plan-A3.pdf / -A4-2pages.pdf   1:1 paper plan, print at 100 %, lay the real parts on it.
  README.md, DIMENSIONS.md       full notes and every size.  outside/inside/rear.png: renders.
TXT
find "$dest" -type f | wc -l | sed "s|^|files: |"; echo "pack at $dest"
