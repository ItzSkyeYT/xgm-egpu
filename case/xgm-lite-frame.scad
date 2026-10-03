// xgm-lite-frame.scad
// Print-only enclosure for an XG Mobile Station Lite (osy) board + a desktop GPU + an ATX PSU.
// No screws, inserts, glue or adapters: pegs, slots, friction fits and gravity.
//
// World frame:  X along the board (0 = the board's rear edge, where the USB-C is; +X toward the card's far end)
//               Y across the board (0 = the edge with the 24-pin ATX header; the GPU cooler is on +Y)
//               Z up (0 = top surface of the floor plate)
//
// Render one part:   openscad -o out.stl -D 'part="floor_rr"' xgm-lite-frame.scad
// Collision test:    openscad -o collision.stl -D 'part="collision"' -D vents=false xgm-lite-frame.scad   (must be empty)
// See README.md in this folder for the part list, print settings and assembly order.

part = "assembly";
vents = true;          // false speeds up test renders
MIRROR = true;         // KiCad's Y points down on screen; the design frame below keeps that, so every export is mirrored in Y to match the real board

/* ---------- Parts you own (measure where marked; everything else comes from the KiCad file / spec sheets) ---------- */
board_l = 220;  board_w = 65;  board_t = 1.6;             // XG Mobile Station Lite PCB
holes = [[28,14],[28,51],[117,32.5],[206,14],[206,51]];   // O3.2 mounting holes
hole_d = 3.2;
pcie_a1_x = 61.15;  pcie_y = 20.7;                         // centre of contact A1/B1; slot centreline = card PCB plane
pcie_x0 = 58.15;    pcie_x1 = 147.15;                      // slot body
foot_slot_x = 13.7;                                        // 3 mm slot in the board (x 12.2..15.2, y 17..65): the GPU bracket's foot drops in here
holder_holes_y = [18.65, 38.95, 59.3];                     // three 3 x 4 mm holes at x 7.2: for the bracket holder
holder_hole_x = 7.2;
usbc_y = [5.5, 14.4];                                      // USB-C receptacle on the rear edge
atx_hdr_x = [30.5, 85.2];                                  // right-angle 24-pin header (overhangs the Y=0 edge by 9.7)
xg_conn_x = [77.5, 136.2];                                 // the two micro-coax connectors of the laptop cable, Y 42..49

gpu_len = 240;  gpu_h = 120;  gpu_w = 42.2;                // Inno3D RTX 3060 Twin X2 OC: length, height (Inno3D), thickness measured at the bracket end
gpu_backplate = 2.5;                                       // backplate + gap on the solder side of the PCB
bracket_to_a1 = pcie_a1_x - foot_slot_x;                   // 47.45: bracket plane = the board's foot slot (CEM Fig 9-1 gives 47.8)
bracket_w = 18.42;  bracket_t = 0.86;
bracket_margin = 5.3;                                      // card PCB plane -> solder-side edge of the bracket
card_seat = 4.1;                                           // finger bottom above the board surface: measured tab height 109.0 minus CEM 104.86
card_bottom_clear = 18.9;                                  // MEASURED: board surface -> lowest point of the card near its far end
tab_above_board = 109.0;                                   // MEASURED: board surface -> underside of the bracket's top tab
foot_below_board = 9.7;                                    // MEASURED: the bracket's foot reaches this far below the board's top surface
plug8_clear = 42;                                          // room above the card for a straight 8-pin plug and a stiff sleeved cable

psu_l = 160;  psu_w = 150;  psu_h = 86;                    // ATX PSU: length (rear -> modular face), width (fan face), height
atx_plug_clear = 48;                                       // from the board's Y=0 edge: 24-pin plug body + the start of its bend; the rest of the bend is in the cable bay
atx_bend_reach = 92;                                       // MEASURED 86.8 + margin: how far from the board edge the sleeved bundle's bend reaches
psu_iec_at_far = true;                                     // PSU turned end-for-end: IEC inlet in the far wall, modular face toward the rear, bay beside the 24-pin
psu_wall_gap = 11;                                         // PSU fan face -> wall (keeps the corner and mid posts clear of the PSU)

/* ---------- Frame ---------- */
wall = 3;  floor_t = 3;  lid_t = 3;
lip = 2;              // posts stand this much proud of the panels
core = 10;            // posts reach this far into the interior
slot_d = 7;           // panel-end depth in corner posts (5 in mid posts)
slot_fit = 0.4;       // panel thickness clearance in the post slots
peg_fit = 0.4;        // square pegs (posts, lid, cradle)
pin_fit = 0.3;        // board pegs vs the O3.2 holes (on diameter)
tab_fit = 0.2;        // jigsaw tabs between floor / lid pieces (per side)
standoff = 7;         // board underside above the floor (the bracket foot reaches 9.7 below the board top: it ends inside the floor's slot)
boss_d = 7;
use_inserts = true;   // M3x5x4.5 heat-set inserts + M3 socket-head screws: 5 for the board, 4 for the lid. false = print-only pegs and clips
insert_hole = 4.0;    // hole for the M3x5x4.5 inserts (4.5 across): confirm with coupon_inserts (3.8 / 4.0 / 4.2)
insert_depth = 5.6;   // insert length 5 + 0.6
boss_d_ins = 8.5;     // board boss with an insert
gap_y = 24;           // board +Y (fan-side) edge -> wall: the laptop-cable harness and its boot run along this edge
x_mid = 145;  y_mid = -40;      // mid posts (panels split here)
x_seam = 135; y_seam = -50;     // floor and lid pieces split here (jigsaw tabs)
lid_split_y = false;            // true: lid in 4 pieces for small beds
xg_exit_y = [board_w-5, board_w+15];   // laptop cable leaves through the rear wall here, beside the board's fan-side edge
// the laptop cable's rubber grommet clicks into a thin wall on the floor: a pull on the cable lands on the case, not the micro-coax connectors
grommet_x = 41.5 + 2.5;        // MEASURED 41.5: board's rear edge -> the grommet's gap, harness gently straight; +2.5 of slack
grommet_y = board_w + 12;      // MEASURED 12.7: board's long edge -> grommet centre, lying relaxed
grommet_d = 14.8;              // MEASURED: the round disc (the square plate is 14.7 across flats)
grommet_gap = 1.4;             // MEASURED: the gap between disc and plate
grommet_slot = 11.5;           // the rubber neck in the gap, about 11-13: confirm with coupon_grommet (10.5 / 11.5 / 12.5)
grommet_zc = 8;                // grommet axis above the floor (the disc clears the floor by 0.6)
clip_t = 1.2;                  // clip wall, inside the 1.4 gap
clip_hw = 9;                   // clip half-width
cable_d = 9;                   // the thick cable, generous
vent_w = 3;  vent_pitch = 6;  vent_h = 20;  vent_row = 24;
$fn = 40;  eps = 0.01;

/* ---------- Derived ---------- */
zb       = standoff + board_t;               // board top surface
xb       = pcie_a1_x - bracket_to_a1;        // bracket outer face (card front)
card_x1  = xb + gpu_len;
card_y0  = pcie_y - board_t/2 - gpu_backplate;
card_y1  = card_y0 + gpu_w;
card_z0  = zb + card_seat;                   // finger bottom (Datum W)
card_top = card_z0 + 3.2 + gpu_h;            // generous: height taken from the PCB's main bottom edge
card_bot = zb + card_bottom_clear;           // lowest point of the card away from the connector (measured)
bracket_y0 = pcie_y - bracket_margin;  bracket_y1 = bracket_y0 + bracket_w;
tab_z    = zb + tab_above_board;
psu_y1   = -atx_plug_clear;  psu_y0 = psu_y1 - psu_h;
xi0 = -4;  xi1 = card_x1 + 3;
yi0 = psu_y0 - psu_wall_gap;  yi1 = board_w + gap_y;
zi1 = card_top + plug8_clear;                // interior height = lid underside
psu_x0 = psu_iec_at_far ? xi1 - core - 1 - psu_l : xi0 + core + 1;  psu_x1 = psu_x0 + psu_l;
bay_x0 = psu_iec_at_far ? xi0 + 4 : psu_x1 + 4;  bay_x1 = psu_iec_at_far ? psu_x0 - 4 : xi1 - 4;   // cable bay, along X
xo0 = xi0 - wall;  xo1 = xi1 + wall;  yo0 = yi0 - wall;  yo1 = yi1 + wall;     // panel exterior
xp0 = xo0 - lip;   xp1 = xo1 + lip;   yp0 = yo0 - lip;   yp1 = yo1 + lip;      // post / floor / lid outline
slot_w = wall + slot_fit;
panel_h = zi1 - 0.5;
peg = 6;

echo(str("interior ", xi1-xi0, " x ", yi1-yi0, " x ", zi1, " mm; outside ", xp1-xp0, " x ", yp1-yp0, " x ", zi1+floor_t+lid_t, " mm"));
echo(str("card: x ", xb, "..", card_x1, "  y ", card_y0, "..", card_y1, "  z ", card_z0, "..", card_top, "  bracket->A1 ", bracket_to_a1));
echo(str("PSU: x ", psu_x0, "..", psu_x1, "  y ", psu_y0, "..", psu_y1, "  z 0..", psu_w, "  bay x ", bay_x0, "..", bay_x1, "  foot bottom z ", zb - foot_below_board));

module box(x0,x1,y0,y1,z0,z1) { translate([x0,y0,z0]) cube([x1-x0, y1-y0, z1-z0]); }

/* ================= ghosts (the real parts, for the assembly view and the collision test) ================= */
module ghost_board() {
  color("green", 0.6) difference() {
    box(0, board_l, 0, board_w, standoff, zb);
    for (h = holes) translate([h[0], h[1], standoff-1]) cylinder(d = hole_d, h = board_t+2);
    box(foot_slot_x-1.5, foot_slot_x+1.5, 17, board_w+1, standoff-1, zb+1);                          // bracket foot slot
    for (y = holder_holes_y) box(holder_hole_x-1.5, holder_hole_x+1.5, y-2, y+2, standoff-1, zb+1);  // holder holes
  }
  color("darkgreen", 0.6) {
    box(atx_hdr_x[0], atx_hdr_x[1], -9.7, 12.8, zb, zb+12.6);   // 24-pin right-angle header
    box(84, 96, 0, 12, zb, zb+13);                                // 8-pin Mini-Fit Jr input (J14)
    box(130, 141, 0, 10, zb, zb+15);                              // Mini-Fit Sr inputs (J18, J19)
    box(143, 154, 0, 10, zb, zb+15);
    box(158, 176, 3, 30, zb, zb+10);                              // pin headers + JST near the far end
    box(150, 159, 50, 61, zb, zb+10);                             // pin header near the +Y edge
    box(xg_conn_x[0], xg_conn_x[1], 42, 49.5, zb, zb+3);          // micro-coax connectors
    box(0, 8, usbc_y[0], usbc_y[1], zb, zb+3.3);                  // USB-C
    box(pcie_x0, pcie_x1, 17, 25.8, zb, zb+11.3);                 // PCIe x16 slot
  }
}
module ghost_card() {
  color("gray", 0.5) box(xb, card_x1, card_y0, card_y1, card_bot, card_top);
  color("gray", 0.5) box(pcie_x0-1, pcie_x1+1, pcie_y-0.8, pcie_y+0.8, card_z0, card_bot+eps);   // finger tab
  color("silver", 0.7) box(xb, xb+bracket_t, bracket_y0, bracket_y1, card_z0-7.9, tab_z);
  color("silver", 0.7) box(xb-10.2, xb, bracket_y0, bracket_y1, tab_z, tab_z+0.9);
}
module ghost_card_detail() {   // the Inno3D Twin X2 OC as it actually looks; the plain box above stays the collision envelope
  pcb_x0 = xb + 1.9;  pcb_x1 = xb + 190;
  pcb_z0 = zb + card_seat + 3.2;  pcb_z1 = pcb_z0 + 111;
  sh_x0 = xb + 6;  sh_z0 = card_bot;  sh_z1 = card_top - 3;
  fan_z = (sh_z0 + sh_z1) / 2 + 2;
  color("darkgreen") box(pcb_x0, pcb_x1, pcie_y-0.8, pcie_y+0.8, pcb_z0, pcb_z1);                       // PCB
  color("goldenrod") box(pcie_x0+1, pcie_x1-1, pcie_y-0.8, pcie_y+0.8, card_z0, pcb_z0+eps);           // gold fingers
  color("black") box(pcb_x0+3, pcb_x1-2, card_y0, pcie_y-0.8, pcb_z0+3, pcb_z1-3);                     // backplate
  color("dimgray") difference() {                                                                       // shroud + heatsink
    box(sh_x0, card_x1, pcie_y+0.8, card_y1, sh_z0, sh_z1);
    for (fx = [xb+70, xb+170]) translate([fx, card_y1+0.01, fan_z]) rotate([90,0,0]) cylinder(d = 88, h = 7);
  }
  color("black") for (fx = [xb+70, xb+170]) translate([fx, card_y1-6.9, fan_z]) rotate([-90,0,0]) {   // fan hubs and blades
    cylinder(d = 36, h = 5);
    for (a = [0:40:359]) rotate([0,0,a]) translate([14,-3,0]) cube([30, 6, 1.2]);
  }
  color("silver") difference() {                                                                        // bracket with its ports
    box(xb, xb+bracket_t, bracket_y0, bracket_y1, zb-foot_below_board, tab_z+0.9);
    for (i = [0:2]) box(xb-1, xb+2, bracket_y0+1.2, bracket_y0+17.2, tab_z-9-6.5-i*16, tab_z-9-i*16);  // 3x DisplayPort
    box(xb-1, xb+2, bracket_y0+2, bracket_y0+16.5, tab_z-9-6.5-3*16-4, tab_z-9-3*16-4);              // HDMI
    for (zz = [zb+12 : 7 : tab_z-62]) for (yy = [bracket_y0+3 : 5 : bracket_y1-5]) box(xb-1, xb+2, yy, yy+3, zz, zz+4);   // vent mesh, roughly
  }
  color("silver") difference() {                                                                        // top tab with its screw hole
    box(xb-10.2, xb+bracket_t, bracket_y0+1.5, bracket_y0+14, tab_z, tab_z+0.9);
    translate([xb-5.5, bracket_y0+7.5, tab_z-1]) cylinder(d = 4.3, h = 3);
  }
  color("black") box(xb+150, xb+168, pcie_y-0.8, pcie_y+8.5, pcb_z1-2, pcb_z1+7);                     // 8-pin socket
}
module ghost_psu() { color("black", 0.35) box(psu_x0, psu_x1, psu_y0, psu_y1, 0.05, psu_w); }
module ghost_zones() {   // volumes that must stay free for plugs and cables
  color("orange", 0.25) {
    box(atx_hdr_x[0]-2, atx_hdr_x[1]+2, -atx_bend_reach, 0, zb-1, zb+28);
    if (use_inserts) for (h = holes) translate([h[0], h[1], zb]) cylinder(d = 6, h = 3.2, $fn = 24);   // board screw heads              // 24-pin plug + the whole bend (reaches into the bay)
    box(card_x1-110, card_x1, card_y0, card_y1, card_top, card_top+plug8_clear-0.1);    // 8-pin plug + cable bend
    // laptop cable: harness along the fan-side edge, grommet in its clip, thick cable out through the rear notch
    box(grommet_x+20, xg_conn_x[1]+2, board_w+0.5, board_w+11, 1, 15);                               // harness along the edge
    box(grommet_x+2.8, grommet_x+20, grommet_y-5.5, grommet_y+5.5, 1, 15);                            // harness entering the grommet
    box(grommet_x+0.7, grommet_x+2.8, grommet_y-7.6, grommet_y+7.6, grommet_zc-7.6, grommet_zc+7.6);  // square plate
    box(grommet_x-2.8, grommet_x-0.7, grommet_y-7.6, grommet_y+7.6, grommet_zc-7.6, grommet_zc+7.6);  // round disc
    box(grommet_x-15, grommet_x-2.8, grommet_y-5.5, grommet_y+5.5, grommet_zc-5.5, grommet_zc+5.5);   // cone and sleeve
    box(12, grommet_x-15, grommet_y-5.5, grommet_y+4.5, grommet_zc-cable_d/2, grommet_zc+cable_d/2);  // thick cable, easing toward the notch
    box(xo0-10, 12, 69, 78, grommet_zc-cable_d/2, grommet_zc+cable_d/2);                               // ... and out, clear of the corner post
    if (psu_iec_at_far) box(bay_x0, psu_x0+1, -atx_bend_reach-10, psu_y1-8, 7, 34);     // bundles running from the bend to the modular face (above the 6 mm PSU stop)
    else                box(atx_hdr_x[0], psu_x1+10, psu_y1+5, psu_y1+33, 3.5, 34);
    box(xi0, xb-1, bracket_y0+0.5, bracket_y1-0.5, zb+6.5, tab_z-5.5);                  // DP/HDMI plugs reaching the bracket (top port ~9 mm under the tab)
    box(xo0-6, 10, usbc_y[0]-2.5, usbc_y[1]+2, zb-2.5, zb+8.5);                         // USB-C plug
    if (psu_iec_at_far) { box(psu_x0-30, psu_x0, psu_y0, psu_y1, 10, psu_w-5); box(psu_x1, xo1+25, psu_y0+3, psu_y1-3, 6, psu_w-6); }
    else                { box(psu_x1, psu_x1+30, psu_y0, psu_y1, 10, psu_w-5); box(xo0-25, psu_x0, psu_y0+3, psu_y1-3, 6, psu_w-6); }
  }
}
module ghosts()      { ghost_board(); ghost_card_detail(); ghost_psu(); ghost_zones(); }
module ghosts_hard() { ghost_board(); ghost_card(); ghost_psu(); ghost_zones(); }

/* ================= posts ================= */
function post_centers() = [
  [xi0+core/2, yi0+core/2], [xi0+core/2, yi1-core/2], [xi1-core/2, yi0+core/2], [xi1-core/2, yi1-core/2],
  [xi0+core/2, y_mid], [xi1-core/2, y_mid], [x_mid, yi0+core/2], [x_mid, yi1-core/2] ];

module top_socket(h) { translate([-(peg+peg_fit)/2, -(peg+peg_fit)/2, h-4]) cube([peg+peg_fit, peg+peg_fit, 5]); }
module bottom_peg()  { translate([-peg/2, -peg/2, -(floor_t-0.6)]) cube([peg, peg, floor_t-0.6+eps]); }

// corner post, local frame: interior toward +X,+Y; the two panels occupy x in [-wall,0] and y in [-wall,0]
module corner_post_local(h = zi1) {
  difference() {
    translate([-wall-lip, -wall-lip, 0]) cube([wall+lip+core, wall+lip+core, h]);
    translate([-wall-slot_fit/2, core-slot_d, -1]) cube([slot_w, slot_d+2, h+2]);      // slot for the YZ panel
    translate([core-slot_d, -wall-slot_fit/2, -1]) cube([slot_d+2, slot_w, h+2]);      // slot for the XZ panel
    if (use_inserts) translate([core/2, core/2, 0]) {                  // insert for the lid screw, clearance below it
      translate([0, 0, h - insert_depth]) cylinder(d = insert_hole, h = insert_depth + 1, $fn = 40);
      translate([0, 0, h - insert_depth - 5]) cylinder(d = 3.2, h = 6, $fn = 30);
    } else translate([core/2, core/2, 0]) top_socket(h);
  }
  translate([core/2, core/2, 0]) bottom_peg();
}
// mid post for a YZ wall (thin in X), local frame: interior toward +X, centred on the wall seam in Y
module midpost_yz_local(h = zi1) {
  difference() {
    translate([-wall-lip, -7, 0]) cube([wall+lip+core, 14, h]);
    translate([-wall-slot_fit/2, -8, -1]) cube([slot_w, 6, h+2]);
    translate([-wall-slot_fit/2,  2, -1]) cube([slot_w, 6, h+2]);
    translate([core/2, 0, 0]) top_socket(h);
  }
  translate([core/2, 0, 0]) bottom_peg();
}
module midpost_xz_local(h = zi1) { rotate([0,0,-90]) mirror([1,0,0]) midpost_yz_local(h); }

module post_corner_rl() { translate([xi0, yi0, 0]) corner_post_local(); }
module post_corner_rr() { translate([xi0, yi1, 0]) mirror([0,1,0]) corner_post_local(); }
module post_corner_fl() { translate([xi1, yi0, 0]) mirror([1,0,0]) corner_post_local(); }
module post_corner_fr() { translate([xi1, yi1, 0]) mirror([1,0,0]) mirror([0,1,0]) corner_post_local(); }
module post_mid_rear()  { translate([xi0, y_mid, 0]) midpost_yz_local(); }
module post_mid_far()   { translate([xi1, y_mid, 0]) mirror([1,0,0]) midpost_yz_local(); }
module post_mid_left()  { translate([x_mid, yi0, 0]) midpost_xz_local(); }
module post_mid_right() { translate([x_mid, yi1, 0]) mirror([0,1,0]) midpost_xz_local(); }
module posts() { post_corner_rl(); post_corner_rr(); post_corner_fl(); post_corner_fr(); post_mid_rear(); post_mid_far(); post_mid_left(); post_mid_right(); }

/* ================= lips (floor and lid), broken at the posts ================= */
module lip_ring(z0, z1, t = 1.5) {
  segs_y = [[yi0+core+0.5, y_mid-7.5], [y_mid+7.5, yi1-core-0.5]];
  segs_x = [[xi0+core+0.5, x_mid-7.5], [x_mid+7.5, xi1-core-0.5]];
  for (s = segs_y) { box(xi0, xi0+t, s[0], s[1], z0, z1); box(xi1-t, xi1, s[0], s[1], z0, z1); }
  for (s = segs_x) { box(s[0], s[1], yi0, yi0+t, z0, z1); box(s[0], s[1], yi1-t, yi1, z0, z1); }
}

/* ================= floor ================= */
module board_clip(x, side) {   // horizontal cantilever with a chamfered lip hooking over the board edge
  ye = side > 0 ? board_w : 0;
  s  = side;                       // +1: clip on the +Y edge, -1: on the Y=0 edge
  // anchor block
  box(x, x+4, min(ye+s*0.3, ye+s*3.5), max(ye+s*0.3, ye+s*3.5), 0, 8.5);
  // beam
  box(x+4, x+20, min(ye+s*0.3, ye+s*1.5), max(ye+s*0.3, ye+s*1.5), 0, 8.3);
  // lip over the board, 45 deg lead-in on top
  hull() {
    box(x+14, x+20, min(ye+s*0.3, ye-s*0.9), max(ye+s*0.3, ye-s*0.9), zb+0.3, zb+0.6);
    box(x+14, x+20, min(ye+s*0.3, ye+s*0.3+s*eps), max(ye+s*0.3, ye+s*0.3+s*eps), zb+0.3, zb+1.8);
  }
}
module board_clip_rear(y) {   // same clip, hooking over the board's rear edge (x = 0)
  box(-3.5, -0.3, y, y+4, 0, 8.5);
  box(-1.5, -0.3, y+4, y+20, 0, 8.3);
  hull() {
    box(-0.3, 0.9, y+14, y+20, zb+0.3, zb+0.6);
    box(-0.3, -0.3+eps, y+14, y+20, zb+0.3, zb+1.8);
  }
}
module cable_saddle(x) {      // U on the floor, open at the top, 30 mm wide: both power cables lie in it side by side
  for (y = [[psu_y1+1, psu_y1+4], [psu_y1+34, psu_y1+37]]) box(x, x+14, y[0], y[1], 0, 22);
  box(x, x+14, psu_y1+1, psu_y1+37, 0, 3);
}
module cradle_peg_centres() { for (y = [card_y0+7, card_y1-7]) translate([card_x1-9, y, 0]) children(); }

module floor_full() {
  difference() {
    union() {
      box(xp0, xp1, yp0, yp1, -floor_t, 0);                                   // plate
      lip_ring(0, 3);
      for (h = holes) translate([h[0], h[1], 0]) {
        if (use_inserts) cylinder(d = boss_d_ins, h = standoff - 0.05);
        else { cylinder(d = boss_d, h = standoff - 0.05); cylinder(d = hole_d - pin_fit, h = standoff + board_t + 1.0); }
      }
      if (!use_inserts) {                              // print-only: the board is held by pegs and these clips
        board_clip(150, +1); board_clip(186, +1);      // fan-side edge, beyond the harness (x < 138)
        board_clip(100, -1); board_clip(186, -1);      // 24-pin edge: the two gaps between header and power inputs
        board_clip_rear(34);                           // rear edge, between the USB-C and the corner
      }
      translate([grommet_x, grommet_y, 0]) grommet_clip();   // the laptop cable's grommet clicks in here
      // PSU stops: in front of the modular face (bottom edge only) and along the plug-zone side
      if (psu_iec_at_far) box(psu_x0-3.5, psu_x0-0.5, psu_y0+6, psu_y1-6, 0, 6);
      else                box(psu_x1+0.5, psu_x1+3.5, psu_y0+6, psu_y1-6, 0, 6);
      box(psu_x0+2, psu_x0+16, psu_y1+0.5, psu_y1+2.5, 0, 6);
      box(psu_x0+110, psu_x0+130, psu_y1+0.5, psu_y1+2.5, 0, 6);
    }
    for (p = post_centers()) translate([p[0]-(peg+peg_fit)/2, p[1]-(peg+peg_fit)/2, -floor_t-1]) cube([peg+peg_fit, peg+peg_fit, floor_t+2]);
    if (use_inserts) for (h = holes) translate([h[0], h[1], 0]) {      // insert in each board boss, screw clearance below it
      translate([0, 0, standoff - insert_depth]) cylinder(d = insert_hole, h = insert_depth + 1, $fn = 40);
      translate([0, 0, -1]) cylinder(d = 3.2, h = standoff + 1, $fn = 30);
    }
    cradle_peg_centres() translate([-(peg+peg_fit)/2, -(peg+peg_fit)/2, -floor_t-1]) cube([peg+peg_fit, peg+peg_fit, floor_t+2]);
    box(foot_slot_x-2.7, foot_slot_x+2.7, 16, board_w+1, -floor_t-1, 1);                        // relief for the bracket's foot
    box(xi0-0.2, xi0+2, xg_exit_y[0], xg_exit_y[1], -0.1, 3.2);                                  // floor lip opened under the cable notch
    for (y = holder_holes_y) box(holder_hole_x-1.5, holder_hole_x+1.5, y-2, y+2, -floor_t-1, 1); // sockets for the holder's pegs
    // cable-tie slots in the cable bay
    for (x = [bay_x0+10, (bay_x0+bay_x1)/2-5, bay_x1-20]) for (y = [psu_y0+20, psu_y0+55]) { box(x, x+1.8, y, y+6, -floor_t-1, 1); box(x+8, x+9.8, y, y+6, -floor_t-1, 1); }
  }
}

/* ================= lid ================= */
module lid_full() {
  difference() {
    box(xp0, xp1, yp0, yp1, zi1, zi1+lid_t);
    // vents over the card, but never within 3 mm of a jigsaw slot: keep clear of both seams
    if (vents) for (p = grid(xb-4, card_x1+2, card_y0-4, yi1-5, vent_w, vent_pitch, vent_h, vent_row))
      if (!(p[0]+vent_w > x_seam-4 && p[0] < x_seam+10) && !(p[1]+vent_h > y_seam-4 && p[1] < y_seam+10))
        box(p[0], p[0]+vent_w, p[1], p[1]+vent_h, zi1-1, zi1+lid_t+1);
    if (use_inserts) for (i = [0:3]) translate([post_centers()[i][0], post_centers()[i][1], zi1-1]) cylinder(d = 3.4, h = lid_t + 2, $fn = 30);   // lid screws into the corner posts
  }
  lip_ring(zi1-4, zi1);
  for (i = [(use_inserts ? 4 : 0) : 7]) translate([post_centers()[i][0]-peg/2, post_centers()[i][1]-peg/2, zi1-3.6]) cube([peg, peg, 3.6+eps]);   // pegs: mid posts (and corners when print-only)
  // ribs straddling the card's top edge (front half of the card, clear of the 8-pin plug)
  for (y = [[card_y0-3.5, card_y0-0.5], [card_y1+0.5, card_y1+3.5]]) box(xb+14, xb+64, y[0], y[1], card_top+1, zi1+eps);
  // guides beside the bracket's top end
  box(xb-4.5, xb+3,   bracket_y0-4.8, bracket_y0-0.8, tab_z-12, zi1+eps); // solder side: beside the bracket's edge (outside the plug zone)
  box(xb-4.5, xb-0.3, bracket_y1+0.8, bracket_y1+4.8, tab_z-12, zi1+eps); // component side: in front only (the shroud is behind)
}

/* ================= panels ================= */
// slot grid: returns [a,b] origins of slots (a along the first axis, b along the second) fully inside the rectangle
function grid(a0, a1, b0, b1, w, pa, h, pb) =
  [ for (a = [a0 : pa : a1 - w]) for (b = [b0 : pb : b1 - h]) [a, b] ];

module panel_yz(x0, x1, y0, y1) {       // thin in X, spans y0..y1
  difference() {
    box(x0, x1, y0, y1, 0, panel_h);
    intersection() {
      box(x0-1, x1+1, y0+5, y1-5, 3.5, panel_h-4.5);          // safe area: clear of post slots, floor lip and lid lip
      union() { children(); translate([9999,9999,9999]) cube(1); }
    }
  }
}
module panel_xz(x0, x1, y0, y1) {       // thin in Y, spans x0..x1
  difference() {
    box(x0, x1, y0, y1, 0, panel_h);
    intersection() {
      box(x0+5, x1-5, y0-1, y1+1, 3.5, panel_h-4.5);
      union() { children(); translate([9999,9999,9999]) cube(1); }
    }
  }
}
module vents_yz(x0, x1, y0, y1, z0, z1) { if (vents) for (p = grid(y0, y1, z0, z1, vent_w, vent_pitch, vent_h, vent_row)) box(x0-1, x1+1, p[0], p[0]+vent_w, p[1], p[1]+vent_h); }
module vents_xz(y0, y1, x0, x1, z0, z1) { if (vents) for (p = grid(x0, x1, z0, z1, vent_w, vent_pitch, vent_h, vent_row)) box(p[0], p[0]+vent_w, y0-1, y1+1, p[1], p[1]+vent_h); }

// rear wall (x in [xo0, xi0]) — cutters are world-coordinate solids
module rear_cutters() {
  if (psu_iec_at_far) vents_yz(xo0, xi0, psu_y0+4, psu_y1-4, 8, zi1-9);                 // cable bay breathes
  else box(xo0-1, xi0+1, psu_y0+3, psu_y1-3, 3, psu_w-3);                           // PSU rear face (IEC, switch, grille)
  box(xo0-1, xi0+1, usbc_y[0]-3.5, usbc_y[1]+3.5, zb-3, zb+9);                      // USB-C
  box(xo0-1, xi0+1, bracket_y0-1.5, bracket_y1+1.5, zb+6, tab_z-4.5);               // opening for the card's display ports, up to just under the tab
  // (the laptop-cable notch is cut in panel_rear_r itself: it must reach the bottom edge, outside the safe area)
  vents_yz(xo0, xi0, 38, yi1-4, 30, zi1-9);
  vents_yz(xo0, xi0, 2, 38, tab_z-2, zi1-9);
  vents_yz(xo0, xi0, psu_y1+6, -4, 30, zi1-9);                                      // over the 24-pin plug zone
}
module far_cutters() {
  vents_yz(xi1, xo1, card_y0-8, yi1-4, 8, zi1-9);                                   // GPU exhaust
  if (psu_iec_at_far) box(xi1-1, xo1+1, psu_y0+3, psu_y1-3, 3, psu_w-3);               // PSU rear face (IEC, switch, grille)
  else vents_yz(xi1, xo1, yi0+4, psu_y1-4, 8, zi1-9);                                // cable bay breathes too
}
module left_cutters() {                                                             // -Y wall: PSU intake
  vents_xz(yo0, yi0, psu_x0+2, psu_x1-4, 4, psu_w-4);
}
module right_cutters() {                                                            // +Y wall: GPU intake + cable exit
  vents_xz(yi1, yo1, xb-4, card_x1+2, card_z0-2, card_top+2);
}

module panel_rear_l()  { panel_yz(xo0, xi0, yi0+core-slot_d+0.3, y_mid-2.3) rear_cutters(); }
module panel_rear_r()  {
  difference() {
    panel_yz(xo0, xi0, y_mid+2.3, yi1-core+slot_d-0.3) rear_cutters();
    box(xo0-1, xi0+1, xg_exit_y[0], xg_exit_y[1], -1, 27);   // laptop-cable notch, open at the bottom: the panel drops over the routed cable
  }
}
module panel_far_l()   { panel_yz(xi1, xo1, yi0+core-slot_d+0.3, y_mid-2.3) far_cutters(); }
module panel_far_r()   { panel_yz(xi1, xo1, y_mid+2.3, yi1-core+slot_d-0.3) far_cutters(); }
module panel_left_r()  { panel_xz(xi0+core-slot_d+0.3, x_mid-2.3, yo0, yi0) left_cutters(); }
module panel_left_f()  { panel_xz(x_mid+2.3, xi1-core+slot_d-0.3, yo0, yi0) left_cutters(); }
module panel_right_r() { panel_xz(xi0+core-slot_d+0.3, x_mid-2.3, yi1, yo1) right_cutters(); }
module panel_right_f() { panel_xz(x_mid+2.3, xi1-core+slot_d-0.3, yi1, yo1) right_cutters(); }
module panels() { panel_rear_l(); panel_rear_r(); panel_far_l(); panel_far_r(); panel_left_r(); panel_left_f(); panel_right_r(); panel_right_f(); }

/* ================= far-end cradle (separate part, plugs into the floor) ================= */
module cradle() {
  rest = card_bot - 0.3;
  cx0 = card_x1 - 18;  cx1 = card_x1;
  difference() {
    union() {
      box(cx0, cx1, card_y0-3.5, card_y1+3.5, 0, 3);
      box(cx0, cx1, card_y0-0.5, card_y1+0.5, 0, rest);
      for (y = [[card_y0-3.5, card_y0-0.5], [card_y1+0.5, card_y1+3.5]]) box(cx0, cx1, y[0], y[1], 0, rest+25);
    }
    // lead-in chamfers on the inner faces
    translate([cx0-1, card_y0-0.5, rest+25]) rotate([45,0,0]) cube([cx1-cx0+2, 3, 3], center=true);
    translate([cx0-1, card_y1+0.5, rest+25]) rotate([45,0,0]) cube([cx1-cx0+2, 3, 3], center=true);
  }
  cradle_peg_centres() translate([-peg/2, -peg/2, -(floor_t-0.6)]) cube([peg, peg, floor_t-0.6+eps]);
}

/* ================= bracket holder: stands in the board's three 3 x 4 holes, the bracket's tab rests on its arm ================= */
hx0 = holder_hole_x - 4.2;  hx1 = holder_hole_x + 1.3;      // column 5.5 mm thick, in front of the bracket plane
arm_x1 = xb - 1.7;                                          // the arm reaches to 1.7 mm from the bracket's outer face
arm_h  = 4.5;                                               // thin: the top display port starts only ~9 mm under the tab
module bracket_holder() {
  z0 = zb + 0.3;
  box(hx0, hx1, 17.2, 61.5, z0, z0+4.5);                              // base beam over the three pegs, below the lowest port
  box(hx0, hx1, 40, 61.5, z0, tab_z-0.1);                             // column beside the ports
  box(hx0, hx1, 37, 61.5, tab_z-30, tab_z-0.1);                       // wider head
  box(hx0, arm_x1, bracket_y0-0.4, 61.5, tab_z-0.1-arm_h, tab_z-0.1);  // arm: its top face is the seat for the bracket's tab (shim up to touch)
  for (y = holder_holes_y) box(holder_hole_x-1.3, holder_hole_x+1.3, y-1.8, y+1.8, -(floor_t-0.6), z0+eps);   // pegs through the board into the floor
}
module shim(t = 1.0) { difference() { box(0, 5.5, 0, 24, 0, t); } }   // lies on the holder's arm if the tab floats

/* ================= splitting plates into bed-sized pieces (jigsaw tabs) ================= */
module tab2d() { polygon([[-3,-eps],[3,-eps],[3,1.0],[5.2,2.2],[5.2,6.5],[-5.2,6.5],[-5.2,2.2],[-3,1.0]]); }
function seam_positions(a0, a1) = let(n = max(1, floor((a1-a0)/60))) [ for (i = [1:n]) a0 + (a1-a0)*i/(n+1) ];

module split_piece(X0, X1, Y0, Y1, z0, z1, male_east, male_north, female_west, female_south) {
  difference() {
    union() {
      intersection() { children(); box(X0, X1, Y0, Y1, z0-200, z1+200); }   // features may hang below (lid) or stand above (floor) the plate
      if (male_east)  for (yy = seam_positions(Y0, Y1)) translate([X1, yy, z0]) rotate([0,0,-90]) linear_extrude(z1-z0) tab2d();
      if (male_north) for (xx = seam_positions(X0, X1)) translate([xx, Y1, z0]) linear_extrude(z1-z0) tab2d();
    }
    if (female_west)  for (yy = seam_positions(Y0, Y1)) translate([X0, yy, z0-1]) rotate([0,0,-90]) linear_extrude(z1-z0+2) offset(delta=tab_fit) tab2d();
    if (female_south) for (xx = seam_positions(X0, X1)) translate([xx, Y0, z0-1]) linear_extrude(z1-z0+2) offset(delta=tab_fit) tab2d();
  }
}
module floor_rl() { split_piece(xp0, x_seam, yp0, y_seam, -floor_t, 0, true,  true,  false, false) floor_full(); }
module floor_rr() { split_piece(xp0, x_seam, y_seam, yp1, -floor_t, 0, true,  false, false, true ) floor_full(); }
module floor_fl() { split_piece(x_seam, xp1, yp0, y_seam, -floor_t, 0, false, true,  true,  false) floor_full(); }
module floor_fr() { split_piece(x_seam, xp1, y_seam, yp1, -floor_t, 0, false, false, true,  true ) floor_full(); }
module lid_l()    { split_piece(xp0, x_seam, yp0, yp1, zi1, zi1+lid_t, true,  false, false, false) lid_full(); }
module lid_r()    { split_piece(x_seam, xp1, yp0, yp1, zi1, zi1+lid_t, false, false, true,  false) lid_full(); }
module lid_rl()   { split_piece(xp0, x_seam, yp0, y_seam, zi1, zi1+lid_t, true,  true,  false, false) lid_full(); }
module lid_rr()   { split_piece(xp0, x_seam, y_seam, yp1, zi1, zi1+lid_t, true,  false, false, true ) lid_full(); }
module lid_fl()   { split_piece(x_seam, xp1, yp0, y_seam, zi1, zi1+lid_t, false, true,  true,  false) lid_full(); }
module lid_fr()   { split_piece(x_seam, xp1, y_seam, yp1, zi1, zi1+lid_t, false, false, true,  true ) lid_full(); }

/* ================= fit coupon: print this first and tune *_fit ================= */
module coupon() {
  difference() {
    union() {
      box(0, 60, 0, 30, 0, 3);
      translate([30, 30, 0]) linear_extrude(3) tab2d();                   // male jigsaw tab
      translate([50, 15, 3]) translate([-peg/2, -peg/2, 0]) cube([peg, peg, 6]);   // 6 mm peg
    }
    translate([15, 0, -1]) linear_extrude(5) offset(delta=tab_fit) tab2d();          // female jigsaw slot
    translate([35-(peg+peg_fit)/2, 15-(peg+peg_fit)/2, -1]) cube([peg+peg_fit, peg+peg_fit, 5]);   // socket
    box(5, 25, 20, 20+slot_w, -1, 4);                                                  // panel slot (try a 3 mm strip)
  }
}

/* ================= laptop-cable grommet clip, and its test piece ================= */
module grommet_clip(slot = grommet_slot) {   // a thin wall that sits in the grommet's gap; U-slot open at the top, small snap lips
  h = grommet_zc + slot/2 + 2.5;
  difference() {
    union() {
      translate([-clip_t/2, -clip_hw, 0]) cube([clip_t, 2*clip_hw, h]);
      for (s = [-1, 1]) hull() {                                   // gussets at both ends, outside the disc and the plate
        translate([-5, s > 0 ? clip_hw-1.1 : -clip_hw, 0]) cube([10, 1.1, 0.01]);
        translate([-clip_t/2, s > 0 ? clip_hw-1.1 : -clip_hw, 0]) cube([clip_t, 1.1, h*0.7]);
      }
    }
    translate([0, 0, grommet_zc]) rotate([0, 90, 0]) cylinder(d = slot, h = 20, center = true, $fn = 60);
    translate([-10, -slot/2, grommet_zc]) cube([20, slot, h]);
  }
  for (s = [-1, 1]) translate([-clip_t/2, s > 0 ? slot/2 - 0.6 : -slot/2, h - 2.5]) cube([clip_t, 0.6, 2.5]);   // snap lips
}
module coupon_inserts() {   // three bosses like the board's, holes 3.8 / 4.0 / 4.2: the one that takes an insert cleanly sets insert_hole
  labels = ["3.8", "4.0", "4.2"];
  difference() {
    union() {
      translate([-8, -8.5, 0]) cube([52, 17, 2]);
      for (i = [0:2]) translate([i*18, 0, 2]) cylinder(d = boss_d_ins, h = standoff, $fn = 48);
    }
    for (i = [0:2]) translate([i*18, 0, 2 + standoff - insert_depth]) cylinder(d = 3.8 + 0.2*i, h = insert_depth + 1, $fn = 40);
    for (i = [0:2]) translate([i*18, 0, 1]) cylinder(d = 3.2, h = standoff + 2, $fn = 30);
  }
  for (i = [0:2]) translate([i*18, -6.6, 2]) linear_extrude(0.6) text(labels[i], size = 2.6, font = "Liberation Sans:style=Bold", halign = "center", valign = "center");
}
module coupon_grommet() {   // three clips, slots 10.5 / 11.5 / 12.5: the one that grips the neck sets grommet_slot
  for (i = [0:2]) translate([i*20, 0, 0]) {
    sl = 10.5 + i;
    translate([-7, -12, 0]) cube([14, 24, 2]);
    translate([0, 0, 2]) grommet_clip(sl);
    translate([5, 0, 2]) linear_extrude(0.6) rotate(90) text(str(sl), size = 3, font = "Liberation Sans:style=Bold", halign = "center", valign = "center");
  }
}

/* ================= 1:1 paper plan (2D, for SVG/PDF export) ================= */
module ln(x0, y0, x1, y1, w = 0.4) { hull() { translate([x0, y0]) circle(d = w, $fn = 8); translate([x1, y1]) circle(d = w, $fn = 8); } }
module rect_o(x0, x1, y0, y1, w = 0.4) { ln(x0,y0,x1,y0,w); ln(x1,y0,x1,y1,w); ln(x1,y1,x0,y1,w); ln(x0,y1,x0,y0,w); }
module ring(x, y, d, w = 0.4) { translate([x, y]) difference() { circle(d = d + w, $fn = 48); circle(d = d - w, $fn = 48); } }
module cross(x, y, r = 6) { ln(x-r, y, x+r, y, 0.3); ln(x, y-r, x, y+r, 0.3); ring(x, y, r, 0.3); }
function my(y) = MIRROR ? -y : y;                    // design-frame Y -> paper Y
// a label anchored at a design-frame point; the glyphs are never mirrored
module lbl(x, y, t, sz = 3.2, rot = 0) {
  if (rot == 0)        translate([x, my(y) - (MIRROR ? sz : 0)]) text(t, size = sz, font = "Liberation Sans");
  else if (MIRROR)     translate([x + sz, my(y)]) rotate(-90) text(t, size = sz, font = "Liberation Sans");
  else                 translate([x, y]) rotate(90) text(t, size = sz, font = "Liberation Sans");
}
module plan_shapes() {
  rect_o(xp0, xp1, yp0, yp1, 0.6);
  rect_o(xi0, xi1, yi0, yi1, 0.25);
  for (p = post_centers()) rect_o(p[0]-7, p[0]+7, p[1]-7, p[1]+7, 0.3);
  difference() { offset(r = 10) offset(delta = -10) square([board_l, board_w]); offset(delta = -0.5) offset(r = 10) offset(delta = -10) square([board_l, board_w]); }
  for (h = holes) ring(h[0], h[1], hole_d);
  rect_o(foot_slot_x-1.5, foot_slot_x+1.5, 17, board_w, 0.3);
  for (y = holder_holes_y) rect_o(holder_hole_x-1.5, holder_hole_x+1.5, y-2, y+2, 0.3);
  rect_o(0, 8, usbc_y[0], usbc_y[1], 0.3);
  rect_o(atx_hdr_x[0], atx_hdr_x[1], -9.7, 12.8, 0.3);
  rect_o(pcie_x0, pcie_x1, 17, 25.8, 0.3);
  rect_o(xg_conn_x[0], 106.2, 42.1, 49.3, 0.3); rect_o(107.5, xg_conn_x[1], 42.1, 49.3, 0.3);
  rect_o(xb, card_x1, card_y0, card_y1, 0.5);
  ln(xb, bracket_y0, xb, bracket_y1, 1.2);
  rect_o(card_x1-18, card_x1, card_y0-3.5, card_y1+3.5, 0.3);
  rect_o(hx0, hx1, 11, 61.5, 0.3);
  rect_o(psu_x0, psu_x1, psu_y0, psu_y1, 0.5);
  rect_o(atx_hdr_x[0]-2, atx_hdr_x[1]+2, -atx_bend_reach, 0, 0.25);
  rect_o(grommet_x+20, xg_conn_x[1]+2, board_w+0.5, board_w+11, 0.25);
  rect_o(grommet_x-2.8, grommet_x+2.8, grommet_y-7.4, grommet_y+7.4, 0.3);
  rect_o(grommet_x-clip_t/2, grommet_x+clip_t/2, grommet_y-clip_hw, grommet_y+clip_hw, 0.7);
  ln(xo0, usbc_y[0]-3.5, xo0, usbc_y[1]+3.5, 1.5);
  ln(xo0, bracket_y0-1.5, xo0, bracket_y1+1.5, 1.5);
  ln(xo0, xg_exit_y[0], xo0, xg_exit_y[1], 1.5);
  if (psu_iec_at_far) ln(xo1, psu_y0+3, xo1, psu_y1-3, 1.5); else ln(xo0, psu_y0+3, xo0, psu_y1-3, 1.5);
}
module plan_labels() {
  lbl(xb+30, card_y0+14, "GPU footprint, fans face this edge", 3.2);
  lbl(xb+30, card_y0+5, str("bracket at x = ", xb, "   card ", gpu_len, " x ", gpu_w), 2.8);
  lbl(60, 36, "board 220 x 65, five pegs", 3);
  lbl(xg_conn_x[0], board_w+13, "laptop-cable harness along this edge", 2.6);
  lbl(grommet_x+4, grommet_y+11, "grommet clip", 2.6);
  lbl(psu_x0+10, psu_y0+40, str("PSU on its side  ", psu_l, " x ", psu_w, " x ", psu_h, "  (fan -> outer wall)"), 3.2);
  lbl(psu_x0+10, psu_y0+30, psu_iec_at_far ? "<- modular face      IEC inlet at the far wall ->" : "modular face ->", 3);
  lbl((bay_x0+bay_x1)/2-6, psu_y0+70, "cable bay", 3.2, 90);
  lbl(atx_hdr_x[0]+2, -22, "24-pin plug + bend", 2.6);
  lbl(atx_hdr_x[0]+2, -75, "sleeved bundle reaches 87 from the edge", 2.6);
  lbl(card_x1-16, card_y1+6, "cradle", 2.6);
  lbl(hx1+2, 50, "holder", 2.6, 90);
  lbl(xo0+2, -60, psu_iec_at_far ? "rear wall: vents over the bay" : "rear wall: PSU opening", 2.6, 90);
  lbl(xo0+2, 14, "ports", 2.6, 90);
  lbl(xo0-9, 2, "USB-C", 2.6, 90);
  lbl(xo0+2, board_w-4, "cable exit", 2.6, 90);
  lbl(xi1-6, 10, "far wall: GPU exhaust grille", 2.6, 90);
  lbl(xi0+20, yi1-7, "wall on the fan side: GPU intake grille", 3);
  lbl(xi0+20, yi0+2.5, "wall on the PSU side: PSU intake grille", 3);
}
PY0 = MIRROR ? -yp1 : yp0;  PY1 = MIRROR ? -yp0 : yp1;   // the plan's Y extent on paper
module plan2d() {
  mirror([0, MIRROR ? 1 : 0]) plan_shapes();
  plan_labels();
  translate([xp0, PY1+6]) text(str("xgm-lite-frame  floor plan 1:1   outside ", xp1-xp0, " x ", yp1-yp0, " mm   (as seen from above, component side up)"), size = 3.6, font = "Liberation Sans");
  ln(xp0, PY0-8, xp0+100, PY0-8, 0.8); ln(xp0, PY0-11, xp0, PY0-5, 0.6); ln(xp0+100, PY0-11, xp0+100, PY0-5, 0.6);
  translate([xp0+38, PY0-16]) text("100 mm", size = 3.2, font = "Liberation Sans");
}
// pages: A3 portrait (297 x 420) with the whole plan, or two A4 landscape tiles (297 x 210) with an overlap band and crosses
cross_y = (PY0 + PY1) / 2;
module page(x0, y0, w, h) {
  intersection() { plan2d(); translate([x0, y0]) square([w, h]); }
  rect_o(x0, x0+w, y0, y0+h, 0.3);
  for (x = [40, 140, 240]) if (y0 < cross_y && y0+h > cross_y) cross(x, cross_y);
}
// frames are 2 mm smaller than the paper: the SVG exporter pads the page by 1 mm, and "actual size" must stay 1:1
a4x = xp0 - (295 - (xp1-xp0))/2;
module plan_a3()  { translate([-a4x, -(PY0-26)]) page(a4x, PY0-26, 295, 418); }
module plan_a4a() { translate([-a4x, -(PY0-9)])  page(a4x, PY0-9, 295, 208); }
module plan_a4b() { translate([-a4x, -(PY1+9-208)]) page(a4x, PY1+9-208, 295, 208); }

// a slice of the real rear wall: the laptop-cable exit, the USB-C hole and the bottom of the port window (HDMI)
module coupon_rear() { intersection() { panel_rear_r(); box(xo0-1, xi0+1, -3, board_w+22, 0, 58); } }

/* ================= views ================= */
module structure() { floor_full(); posts(); panels(); lid_full(); cradle(); bracket_holder(); }
module assembly()  { structure(); ghosts(); }
module inside()    { floor_full(); posts(); panel_rear_l(); panel_rear_r(); panel_far_l(); panel_far_r(); panel_left_r(); panel_left_f(); cradle(); bracket_holder(); ghosts(); }   // lid and +Y wall removed
module collision() { intersection() { structure(); ghosts_hard(); } }

/* ================= part selector (parts are laid out for printing) ================= */
module flat_yz(x0) { rotate([0, 90, 0]) translate([-x0 - wall, 0, 0]) children(); }   // YZ panel -> lying flat, exterior face down
module flat_xz(y0) { rotate([-90, 0, 0]) translate([0, -y0 - wall, 0]) children(); }
module M() { mirror([0, MIRROR ? 1 : 0, 0]) children(); }                              // design frame -> real world

if (part == "plan_a3")        plan_a3();
else if (part == "plan_a4a")  plan_a4a();
else if (part == "plan_a4b")  plan_a4b();
else M() selected();

module selected() {
if (part == "assembly")   assembly();
else if (part == "structure") structure();          // every printed part in place, one mesh, for 3D viewers
else if (part == "ghosts")    ghosts_hard();         // board, card, PSU and cable zones, for 3D viewers
// ---- every part in its assembled position, one per file, for viewers (render-assembled.sh) ----
else if (part == "asm_floor_rl") floor_rl();
else if (part == "asm_floor_rr") floor_rr();
else if (part == "asm_floor_fl") floor_fl();
else if (part == "asm_floor_fr") floor_fr();
else if (part == "asm_lid_l") lid_l();
else if (part == "asm_lid_r") lid_r();
else if (part == "asm_post_corner_rl") post_corner_rl();
else if (part == "asm_post_corner_rr") post_corner_rr();
else if (part == "asm_post_corner_fl") post_corner_fl();
else if (part == "asm_post_corner_fr") post_corner_fr();
else if (part == "asm_post_mid_rear") post_mid_rear();
else if (part == "asm_post_mid_far") post_mid_far();
else if (part == "asm_post_mid_left") post_mid_left();
else if (part == "asm_post_mid_right") post_mid_right();
else if (part == "asm_panel_rear_l") panel_rear_l();
else if (part == "asm_panel_rear_r") panel_rear_r();
else if (part == "asm_panel_far_l") panel_far_l();
else if (part == "asm_panel_far_r") panel_far_r();
else if (part == "asm_panel_left_r") panel_left_r();
else if (part == "asm_panel_left_f") panel_left_f();
else if (part == "asm_panel_right_r") panel_right_r();
else if (part == "asm_panel_right_f") panel_right_f();
else if (part == "asm_cradle") cradle();
else if (part == "asm_bracket_holder") bracket_holder();
else if (part == "asm_board") ghost_board();
else if (part == "asm_card") ghost_card_detail();
else if (part == "asm_psu") ghost_psu();
else if (part == "asm_zones") ghost_zones();
else if (part == "inside") inside();
else if (part == "collision") collision();
else if (part == "floor_rl") translate([0,0,floor_t]) floor_rl();
else if (part == "floor_rr") translate([0,0,floor_t]) floor_rr();
else if (part == "floor_fl") translate([0,0,floor_t]) floor_fl();
else if (part == "floor_fr") translate([0,0,floor_t]) floor_fr();
else if (part == "lid_l")  rotate([180,0,0]) translate([0,0,-(zi1+lid_t)]) lid_l();
else if (part == "lid_r")  rotate([180,0,0]) translate([0,0,-(zi1+lid_t)]) lid_r();
else if (part == "lid_rl") rotate([180,0,0]) translate([0,0,-(zi1+lid_t)]) lid_rl();
else if (part == "lid_rr") rotate([180,0,0]) translate([0,0,-(zi1+lid_t)]) lid_rr();
else if (part == "lid_fl") rotate([180,0,0]) translate([0,0,-(zi1+lid_t)]) lid_fl();
else if (part == "lid_fr") rotate([180,0,0]) translate([0,0,-(zi1+lid_t)]) lid_fr();
else if (part == "post_corner") rotate([180,0,0]) translate([0,0,-zi1]) corner_post_local();   // upside down: socket on the bed, peg up
else if (part == "post_mid")    rotate([180,0,0]) translate([0,0,-zi1]) midpost_yz_local();
else if (part == "panel_rear_l")  flat_yz(xo0) panel_rear_l();
else if (part == "panel_rear_r")  flat_yz(xo0) panel_rear_r();
else if (part == "panel_far_l")   flat_yz(xi1) panel_far_l();
else if (part == "panel_far_r")   flat_yz(xi1) panel_far_r();
else if (part == "panel_left_r")  flat_xz(yo0) panel_left_r();
else if (part == "panel_left_f")  flat_xz(yo0) panel_left_f();
else if (part == "panel_right_r") flat_xz(yi1) panel_right_r();
else if (part == "panel_right_f") flat_xz(yi1) panel_right_f();
else if (part == "cradle") rotate([0,90,0]) translate([-card_x1, 0, 0]) cradle();   // on its side: the pegs become short horizontal stubs
else if (part == "coupon") { coupon(); translate([0, 45, 0]) coupon(); }   // two: tab, peg and slot are tested against the other piece
else if (part == "coupon_rear") flat_yz(xo0) coupon_rear();
else if (part == "coupon_grommet") mirror([0, 1, 0]) coupon_grommet();   // pre-mirrored so M() leaves the labels readable
else if (part == "coupon_inserts") mirror([0, 1, 0]) coupon_inserts();
else if (part == "bracket_holder") rotate([0,90,0]) translate([-hx1, 0, 0]) bracket_holder();   // on its side, pegs horizontal
else if (part == "shim_05") shim(0.5);
else if (part == "shim_10") shim(1.0);
else if (part == "shim_15") shim(1.5);
else echo(str("unknown part: ", part));
}
