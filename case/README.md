# A print-only case for the Lite board

`xgm-lite-frame.scad` is a parametric OpenSCAD enclosure for an **XG Mobile Station Lite** board
(osy's open-source XG Mobile dock, "Lite" variant), a **desktop graphics card** and an **ATX power
supply**. It needs no screws, threaded inserts, glue, magnets or 90° power adapters: the board sits on
printed pegs, the panels slide into printed posts, the lid pegs into the posts, the PSU is held by its
own weight and a few stops, and the card is held by the PCIe slot plus a printed cradle under its far end.

The defaults are the parts it was drawn around:

| Part | Default | Parameter(s) |
|---|---|---|
| Board | XG Mobile Station Lite, 220 × 65 mm, five Ø3.2 holes, geometry read from osy's KiCad file | `board_*`, `holes`, `pcie_*` |
| GPU | Inno3D RTX 3060 Twin X2 OC: 240 × 120 mm, 2-slot (42 mm), one 8-pin on top | `gpu_len`, `gpu_h`, `gpu_w` |
| PSU | ATX, 160 × 150 × 86 mm (Corsair RM850x and friends) | `psu_l`, `psu_w`, `psu_h` |

Outside dimensions with the defaults: **271 × 248 × 180 mm**. The PSU lies on its side along one
long wall with its fan against a grille; the board and the card take the other side with the GPU's
fans facing the opposite wall; between them runs a 65 mm cable channel the full length of the box,
and the space behind the PSU is the cable bay. A 600 mm sleeved 24-pin cable lies in the channel and
the bay as one big loop, held by two printed saddles, instead of being folded.

Two details of the Lite board that the case relies on, both visible in osy's KiCad file: the 3 mm
slot across the board at x = 13.7 mm is the chassis slot for the GPU bracket's foot (so the bracket
plane sits there, 47.5 mm in front of the PCIe contact A1, as the PCIe CEM spec says it should), and
the three 3 × 4 mm holes at x = 7.2 mm are for a bracket holder. This case prints that holder: it
stands in the three holes, passes through them into the floor, and the bracket's top tab rests on
its arm, which is how a PC chassis carries a card's front end.

![outside: PSU intake side and lid](img/outside.png)
![rear wall: PSU grille, laptop-cable exit, USB-C, display ports](img/rear.png)
![inside, lid and GPU-intake wall removed](img/inside.png)

## Airflow

- GPU intake: the whole +Y wall in front of the card's fans is slotted.
- GPU exhaust: slots in the lid above the card and in the far end wall; the card's own bracket vents
  exhaust through the display-port opening in the rear wall, 18 mm behind the ports, as in a PC.
- PSU intake: the −Y wall in front of the PSU fan is slotted; PSU exhaust leaves through its own rear
  grille, which sits in an opening in the rear wall. The two intakes are on opposite sides of the box.
- The lid sits 42 mm above the card so a straight 8-pin plug and a stiff sleeved cable fit without
  an adapter.
- The laptop cable: its taped micro-coax harness runs along the board's 24-pin edge, and the thick
  cable with its strain-relief boot leaves through an opening low in the rear wall beside the board.

## Before you print anything: two measurements

The model was drawn from the KiCad file, datasheets and the spec. Two heights depend on how your card
seats in your connector; both are cheap to measure with the card plugged in and both only move small
parts.

| Measure (card plugged in) | Parameter | Default | What it sets |
|---|---|---|---|
| Board surface → underside of the bracket's top tab | `tab_above_board` | 106.7 | the height of the holder's arm. It is printed 0.1 mm low on purpose; `shim_05/10/15` go on the arm if the tab floats |
| Board surface → lowest point of the card near its far end | `card_bottom_clear` | 6.5 | the cradle height (too high: the card won't seat; too low: it does nothing) |

The bracket's foot should be in the board's slot at x 12.2..15.2 mm. If it is not, the card is not
in the slot the board was designed for.

Then print `coupon` first (5 g, twenty minutes). It has a jigsaw tab and slot, a 6 mm peg and
socket, and a 3 mm panel slot. Everything should push together by hand and hold. If not, adjust
`tab_fit`, `peg_fit`, `slot_fit` (all in mm) and print it again. Fits vary between printers; this is
the cheap place to find out.

## Check the fit on paper first

`plan/floor-plan-A3.pdf` (one A3 page) and `plan/floor-plan-A4-2pages.pdf` (two A4 landscape pages,
tape them together along the alignment crosses) are the floor plan at 1:1: the frame, the posts, the
board with its holes, the card's footprint and bracket plane, the PSU, the cable channel with its two
saddles, the cradle, the holder, and the openings in the rear wall. Print at **actual size / 100 %**,
then check the 100 mm bar with a ruler. Lay the board, the card and the PSU on it, plug the 24-pin in
and see where the bundle wants to go. This costs nothing and catches the mistakes a render can't:
a cable that is stiffer than I think, a plug that sticks out further, a PSU that isn't the one on the
label. Re-export after changing parameters: `openscad -o plan/plan_a3.svg -D 'part="plan_a3"'
xgm-lite-frame.scad`, then `rsvg-convert -f pdf`.

## Viewing the model in 3D

- OpenSCAD itself (installed): `openscad xgm-lite-frame.scad`, press F5. Drag to orbit, scroll to
  zoom. In *Window → Customizer* set `part` to `assembly` (everything plus the real parts' volumes:
  board green, card grey, PSU black, plug and cable zones orange), `inside` (lid and intake wall
  removed), or any single part. Turn `vents` off for a faster preview.
- **`xgm-lite-frame-assembled.3mf`**: every part in its assembled position as a separate, named,
  coloured object (28 of them: the 4 floor quarters, 2 lid halves, 8 posts, 8 panels, cradle, holder,
  plus the board, card, PSU and cable zones). Open it in 3dviewer.net, Bambu Studio, PrusaSlicer or
  OrcaSlicer and hide a wall or the lid in the object list to look inside. 3dviewer.net works on a
  phone. The same parts as individual in-place STLs are in `stl/assembled/`.
- `stl/_assembly_structure.stl` and `stl/_assembly_ghosts.stl`: the same thing as just two meshes
  (printed parts, and the real parts' volumes), for viewers that only take STL.
- For printing, use `stl/<part>.stl`: one file per part, each already laid flat for the bed.

## Parts

Rendered STLs are in `stl/`. Re-render after changing parameters with `./render.sh` (all parts) or
`./render.sh floor_rr cradle` (some parts); `./render-assembled.sh` rebuilds the in-place set and the 3MF.

| Part | Qty | Size (mm) | Prints | Notes |
|---|---|---|---|---|
| `floor_rl`, `floor_rr`, `floor_fl`, `floor_fr` | 1 each | ≤ 151 × 131 × 25 | flat, as exported | the four floor quarters; jigsaw tabs join them. `floor_rr` carries the board pegs, the clips, the foot relief and the holder sockets; `floor_rl` the two cable saddles |
| `lid_l`, `lid_r` | 1 each | ≤ 151 × 248 × 75 | upside down, as exported | two-piece lid (needs a 250 mm bed). For smaller beds print `lid_rl`, `lid_rr`, `lid_fl`, `lid_fr` instead (≤ 151 × 131) |
| `post_corner` | 4 | 15 × 15 × 176 | upright, as exported (socket on the bed, peg up) | identical; mirrors are the same part |
| `post_mid` | 4 | 15 × 14 × 176 | upright | one per wall, where the panels split |
| `panel_rear_l`, `panel_rear_r`, `panel_far_l`, `panel_far_r` | 1 each | ≤ 173 × 117 × 3 | flat | the rear wall carries the PSU opening, the USB-C hole, the display-port opening and the laptop-cable exit |
| `panel_left_r`, `panel_left_f`, `panel_right_r`, `panel_right_f` | 1 each | ≤ 144 × 173 × 3 | flat | left = PSU intake grille; right = GPU intake grille |
| `bracket_holder` | 1 | 116 × 51 × 6 | on its side, as exported | stands in the board's three holes; the bracket tab rests on its arm |
| `shim_05`, `shim_10`, `shim_15` | as needed | 24 × 6 | flat | 0.5 / 1.0 / 1.5 mm shims for the holder's arm |
| `cradle` | 1 | 40 × 49 × 18 | on its side, as exported | supports the card's far end; height from `card_bottom_clear` |
| `coupon` | 1 | 60 × 37 × 9 | flat | fit test |
| `_assembly_structure`, `_assembly_ghosts` | — | — | not for printing | the whole thing, for viewers |

Total about 1050 cm³ of geometry, roughly 1.1 to 1.3 kg of PETG depending on infill. Every part fits
a 180 × 180 mm bed except the two-piece lid; the posts need 178 mm of Z.

Print settings: PETG (PLA softens next to a hot GPU and creeps under the PSU), 0.2 mm layers, 3 to 4
perimeters, 25 to 40 % infill, no supports anywhere. Panels print flat with their outer face down.

## Order of work

1. `coupon`, tune fits.
2. `floor_rr`. Drop the bare board onto its five pegs. It should sit flat on the bosses with the edge
   clips over its edges and the pegs standing about 1 mm proud. If a peg misses, the board isn't the
   board this was drawn for; stop here.
3. `bracket_holder`. Its three pegs go down through the board's three small holes into the floor.
   Plug the card in: the bracket's foot drops into the board's slot and the tab should land on the
   holder's arm, or float just above it (shim). If the tab lands well off the arm, re-measure
   `tab_above_board`.
4. `cradle`, `floor_fr`. Set both floor pieces together and check that the card's far end rests on the
   cradle without lifting the card out of the slot. Re-measure `card_bottom_clear` if it doesn't.
5. Everything else.

## Assembly

1. Join the four floor quarters (press the jigsaw tabs down into their slots).
2. Push the eight posts into the square holes in the floor. Corner posts have two slots at 90°, mid
   posts two slots in line.
3. Board on its pegs; press down until the four edge clips snap over the edges. Bracket holder into
   its three holes.
4. PSU on its side, fan toward the −Y wall, IEC inlet toward the rear wall, slid back against the stops.
5. Card into the slot: foot in the board's slot, tab on the holder's arm, far end on the cradle. Then
   the 24-pin (its bundle goes forward 40 mm, turns, and lies in the channel and the bay as one loop,
   through the two saddles), the 8-pin over the top of the card into the same loop, and the laptop
   cable's boot out through the opening low in the rear wall.
6. Slide the eight panels down into the post slots. Rear panels: the one with the big opening goes on
   the PSU side.
7. Lid: the pegs drop into the posts, the two ribs straddle the card's top edge and the two guides
   straddle the top of the bracket.

Tie points: there are pairs of slots in the floor of the cable bay for zip ties, if you have them. The
box is lifted by its floor, not by the lid.

## What this case does not do

- The holder carries the card's front by its tab, but with gravity only: there is no thumbscrew. The
  lid guides straddle the top of the bracket so it cannot sway; lifting the whole box upside down is
  still a bad idea.
- The display ports sit 18 mm inside the rear wall; the opening in the panel is sized for plugs.
- It is not sealed against dust; it's a ventilated frame.

## Changing it

All geometry derives from the parameters at the top of the .scad. A longer card lengthens the box; a
thicker card widens the cradle and moves the GPU intake grille; a 140 mm PSU shortens the PSU bay
and lengthens the cable bay. `psu_wall_gap`, `atx_plug_clear` and `plug8_clear` are the three
clearances that set the outside size; `atx_plug_clear` is 65 because sleeved Corsair bundles need a
40 mm bend. Flat ribbon cables would allow 50.

`openscad -o x.stl -D 'part="collision"' -D vents=false xgm-lite-frame.scad` renders the intersection
of the printed geometry with the volumes of the board (connectors included), the card, the PSU and the
plug/cable zones. It must come out empty; it does with the defaults. Run it after any change.
