# A print-only case for the Lite board

`xgm-lite-frame.scad` is a parametric OpenSCAD enclosure for an **XG Mobile Station Lite** board
(osy's open-source XG Mobile dock, "Lite" variant), a **desktop graphics card** and an **ATX power
supply**. It needs no glue, magnets or 90° power adapters. Screws are optional: by default five M3
screws in heat-set inserts hold the board and four hold the lid (`use_inserts = false` gives the
print-only version, with pegs and snap clips instead). The panels slide into printed posts, the PSU is
held by its own weight and a few stops, and the card is held by the PCIe slot plus a printed cradle
under its far end.

The defaults are the parts it was drawn around:

| Part | Default | Parameter(s) |
|---|---|---|
| Board | XG Mobile Station Lite, 220 × 65 mm, five Ø3.2 holes, geometry read from osy's KiCad file | `board_*`, `holes`, `pcie_*` |
| GPU | Inno3D RTX 3060 Twin X2 OC: 240 × 120 mm, 42.2 mm thick (measured), one 8-pin on top | `gpu_len`, `gpu_h`, `gpu_w` |
| PSU | ATX, 160 × 150 × 86 mm (Corsair RM850x and friends) | `psu_l`, `psu_w`, `psu_h` |

Outside dimensions with the measured parts: **271 × 244 × 184 mm**. The PSU lies on its side along
one long wall with its fan against a grille, IEC inlet in the far wall and modular face toward the
rear; the board and the card take the other side with the GPU's fans facing the opposite wall; between
them runs a 48 mm channel for the 24-pin plug, and the space between the rear wall and the PSU's
modular face is the cable bay, right beside the 24-pin header. The sleeved 24-pin bundle leaves its
plug, makes its wide bend inside the bay (measured: it reaches 87 mm from the board edge) and arrives
at the modular face; the spare length lies in the bay as one loop.

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
- The IEC power cord comes in at the far end; the laptop cable leaves at the rear.
- The laptop cable: its taped micro-coax harness runs along the board's fan-side edge, in the 24 mm
  gap between board and intake wall. Its rubber grommet clicks into a thin printed clip on the floor,
  44 mm in from the board's rear edge, so a pull on the cable lands on the case instead of the
  micro-coax connectors. The thick cable then leaves through a notch at the bottom of the rear wall.
  The notch is open at the bottom, so the rear panel drops over the cable: the laptop plug never has
  to pass through a hole and nothing gets unplugged.

## Orientation

KiCad's screen has Y pointing down, so a model built straight from its coordinates with Z up is a
mirror image of the real board. The design frame inside the .scad keeps KiCad's numbers as they are,
and `MIRROR = true` mirrors every export in Y to match reality; the paper plan is drawn as seen from
above with the component side up. If you read the source, remember that "+Y" there is the real board's
fan side. The clue was the rear photo: 24-pin and USB-C on the left, fans on the right.

## Measured, not assumed

The defaults are now the real parts, measured with calipers (see the table in `DIMENSIONS.md`): card
thickness 42.2, bracket tab 109.0 above the board, foot 9.7 below it, card's lowest point 18.9 above
the board at its far end, the sleeved 24-pin bend reaching 86.8 from the board edge, and the cable
grommet: disc Ø14.8, plate 14.7, gap 1.4, sitting 41.5 from the board's rear edge and 12.7 out from its
long edge. For another card or PSU, those are the numbers to re-measure; each is a single parameter at the top of
the file. The holder's arm is printed 0.1 mm low on purpose; `shim_05/10/15` go on it if the tab floats.

Then print `coupon` first (about 10 g, half an hour). It has a jigsaw tab and slot, a 6 mm peg and
socket, and a 3 mm panel slot. Everything should push together by hand and hold. If not, adjust
`tab_fit`, `peg_fit`, `slot_fit` (all in mm) and print it again. Fits vary between printers; this is
the cheap place to find out.

## Check the fit on paper first

`plan/floor-plan-A3.pdf` (one A3 page) and `plan/floor-plan-A4-2pages.pdf` (two A4 pages)
are the floor plan at 1:1: the frame and its posts, the board with its holes, the card's footprint and
bracket line, the PSU and its 24-pin bend, the cradle, the holder, the grommet clip and the openings
in the walls, with numbered markers explained in a legend. Print at **actual size / 100 %**, never
"fit to page", then check the 100 mm bar with a ruler. For the A4 pair, cut sheet 1 along its dashed
line, lay it on sheet 2 with the cut edge on the dashed line there and the crosses lined up, and tape.

The A4 pages are portrait with the drawing turned sideways, on purpose: the 270.7 mm side then runs
down the paper, where an inkjet can print almost to the edge. Laid out landscape, the printer driver
turns the page itself and one wall lands in the strip it cannot print (the last 14.5 mm of the sheet
on an HP Deskjet 1510). From a terminal: `lp -o media=A4 -o print-scaling=none plan/floor-plan-A4-2pages.pdf`.

Lay the board, the card and the PSU on it, plug the 24-pin in and see where the bundle wants to go.
This costs nothing and catches the mistakes a render can't: a cable that is stiffer than I think, a
plug that sticks out further, a PSU that isn't the one on the label. Re-export after changing
parameters with `./make_plan.py`, which runs OpenSCAD for the outlines and `rsvg-convert` for the PDFs.

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

Exact sizes of every part, where each one sits, and the feature dimensions are in
[`DIMENSIONS.md`](DIMENSIONS.md). Rendered STLs are in `stl/`. Re-render after changing parameters with `./render.sh` (all parts) or
`./render.sh floor_rr cradle` (some parts); `./render-assembled.sh` rebuilds the in-place set and the 3MF.

| Part | Qty | Size (mm) | Prints | Notes |
|---|---|---|---|---|
| `floor_rl`, `floor_rr`, `floor_fl`, `floor_fr` | 1 each | ≤ 151 × 144 × 25 | flat, as exported | the four floor quarters; jigsaw tabs join them. `floor_rr` (three) and `floor_fr` (two) carry the board bosses with their inserts; `floor_rr` also the foot relief, the holder sockets and the grommet clip |
| `lid_l`, `lid_r` | 1 each | ≤ 151 × 244 × 75 | upside down, as exported | two-piece lid (needs a 250 mm bed). For smaller beds print `lid_rl`, `lid_rr`, `lid_fl`, `lid_fr` instead (≤ 151 × 144) |
| `post_corner` | 4 | 15 × 15 × 180 | upright, as exported (socket on the bed, peg up) | identical; mirrors are the same part |
| `post_mid` | 4 | 15 × 14 × 180 | upright | one per wall, where the panels split |
| `panel_rear_l`, `panel_rear_r`, `panel_far_l`, `panel_far_r` | 1 each | ≤ 178 × 111 × 3 | flat | rear wall: bay vents, USB-C hole, display-port opening, laptop-cable exit; far wall: PSU opening and GPU exhaust vents |
| `panel_left_r`, `panel_left_f`, `panel_right_r`, `panel_right_f` | 1 each | ≤ 144 × 178 × 3 | flat | left = PSU intake grille; right = GPU intake grille |
| `bracket_holder` | 1 | 116 × 51 × 6 | on its side, as exported | stands in the board's three holes; the bracket tab rests on its arm |
| `shim_05`, `shim_10`, `shim_15` | as needed | 24 × 6 | flat | 0.5 / 1.0 / 1.5 mm shims for the holder's arm |
| `cradle` | 1 | 55 × 49 × 18 | on its side, as exported | supports the card's far end; height from `card_bottom_clear` |
| `coupon` | 1 file, 2 pieces | 60 × 82 × 9 | flat | fit test: the two pieces are tested against each other |
| `coupon_rear` | 1 | 58 × 89 × 3 | flat | bottom of the rear wall: laptop-cable notch, USB-C hole, bottom of the port window |
| `coupon_grommet` | 1 file, 3 pieces | 54 × 24 × 19 | flat | three grommet clips, slots 10.5 / 11.5 / 12.5: the one that grips sets `grommet_slot` |
| `coupon_inserts` | 1 | 52 × 17 × 9 | flat | three board bosses, insert holes 3.8 / 4.0 / 4.2: the one that takes an insert cleanly sets `insert_hole` |
| `_assembly_structure`, `_assembly_ghosts` | — | — | not for printing | the whole thing, for viewers |

About 890 g of PETG, tests included, so one 1 kg spool, and about 30 hours of printing: those are real
slices of the print pack's batches for a Bambu X1 Carbon at 3 walls and 15 % infill, which
`./make_plates.py` writes to `weights.json`. A volume estimate runs about a quarter high, and 4 walls
with 40 % infill go just past a kilo.
Every part fits a 180 × 180 mm bed except the two-piece lid; the posts need 182 mm of Z.

Print settings: PETG (PLA softens next to a hot GPU and creeps under the PSU), 0.2 mm layers, 3 walls,
15 % infill, textured PEI plate, no supports anywhere. Panels print flat with their outer face down.

## Printing

Everything to take to a printer is in [`print-pack/`](print-pack/), one folder per stage, with its own
[README](print-pack/README.md): the print order, settings, a picture of each stage, what it checks, and
a pass checklist. Each stage is a few **batches**, one plate each: an OrcaSlicer project with the parts
already arranged on an X1 Carbon's bed and the settings saved in it. In short:

1. **Tests**: `coupon` (two pieces), `coupon_rear`, `coupon_grommet` and `coupon_inserts`, about 25 g.
   Your printer's fits, the real plugs in the real openings, which clip grips the cable's grommet, and
   which hole takes the heat-set inserts.
2. **Board and card**: `floor_rr`, `floor_fr`, `bracket_holder`, `cradle` and the shims. The board
   screwed down on its five bosses, the card on the holder and the cradle.
3. **Structure sample**: one `post_corner`, one `post_mid`, and both halves of the rear wall.
   Full-height posts, a wall in its slots, and the wall's notch over the laptop cable.
4. **The rest**: the floor under the PSU, the other six posts, the three remaining walls, the lid.

Only the stage 1 tests are throwaway. The plan itself, stages and batches in print order, is
`stages.py`. After any change to the model: `./render.sh`, then `./make_plates.py` (a quarter of an
hour: it arranges and slices every batch with OrcaSlicer's command line), then `./make-print-pack.sh`.

## Assembly

1. Heat-set inserts first, while the parts are loose: five into the round board bosses (three on
   `floor_rr`, two on `floor_fr`) and one into the top end of each of the four corner posts. A soldering
   iron at about 230 °C, pressed straight down until the insert sits flush.
2. Join the four floor quarters (press the jigsaw tabs down into their slots).
3. Push the eight posts into the square holes in the floor. Corner posts have two slots at 90°, mid
   posts two slots in line.
4. Board on its five bosses, screwed down with five M3×8 socket-head screws (M3×6 also works; nothing
   longer than 8, or the tips reach the floor). Bracket holder into its three holes.
5. PSU on its side, fan toward the outer wall on the PSU side, IEC inlet toward the far wall, slid
   forward against the stops.
6. Card into the slot: foot in the board's slot, tab on the holder's arm, far end on the cradle. Then
   the 24-pin (its bundle leaves the plug, bends inside the bay and reaches the modular face; the spare
   length lies in the bay as one loop), the 8-pin over the top of the card into the same bay. Press
   the laptop cable's grommet down into the clip beside the board, the clip's thin wall going into the
   gap between the grommet's round disc and square plate, and lay the thick cable toward the rear corner.
7. Slide the eight panels down into the post slots. The panel with the big opening is the far wall on
   the PSU side. The board-side rear panel goes down over the laptop cable: its bottom notch straddles
   the cable.
8. Lid: the mid-post pegs drop into their posts, the two ribs straddle the card's top edge and the two
   guides straddle the top of the bracket. Four M3×8 or M3×10 screws go through the lid's corners into
   the corner posts.

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
thicker card widens the cradle and moves the GPU intake grille; a 140 mm PSU lengthens the cable bay.
`psu_wall_gap`, `atx_plug_clear`, `gap_y` and `plug8_clear` are the clearances that set the outside
size. `psu_iec_at_far = false` turns the PSU back round (IEC at the rear, bay at the far end), which
only makes sense with flat cables that can bend inside a 65 mm channel.

`openscad -o x.stl -D 'part="collision"' -D vents=false xgm-lite-frame.scad` renders the intersection
of the printed geometry with the volumes of the board (connectors included), the card, the PSU and the
plug/cable zones. It must come out empty; it does with the defaults. Run it after any change.
