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

/* ---------- Parts you own (measure where marked; everything else comes from the KiCad file / spec sheets) ---------- */
board_l = 220;  board_w = 65;  board_t = 1.6;             // XG Mobile Station Lite PCB
holes = [[28,14],[28,51],[117,32.5],[206,14],[206,51]];   // O3.2 mounting holes
hole_d = 3.2;
pcie_a1_x = 61.15;  pcie_y = 20.7;                         // centre of contact A1/B1; slot centreline = card PCB plane
pcie_x0 = 58.15;    pcie_x1 = 147.15;                      // slot body
usbc_y = [5.5, 14.4];                                      // USB-C receptacle on the rear edge
atx_hdr_x = [30.5, 85.2];                                  // right-angle 24-pin header (overhangs the Y=0 edge by 9.7)
xg_conn_x = [77.5, 136.2];                                 // the two micro-coax connectors of the laptop cable, Y 42..49

gpu_len = 240;  gpu_h = 120;  gpu_w = 42;                  // Inno3D RTX 3060 Twin X2 OC: length, height, 2-slot width
gpu_backplate = 2.5;                                       // backplate + gap on the solder side of the PCB
bracket_to_a1 = 15.0;                                      // MEASURE: bracket outer face -> centre of the first gold finger
bracket_w = 18.42;  bracket_t = 0.86;
bracket_margin = 5.3;                                      // card PCB plane -> solder-side edge of the bracket
card_seat = 3.5;                                           // finger bottom above the board surface when seated (upper bound)
card_bottom_clear = 6.5;                                   // MEASURE: board surface -> lowest point of the card near its far end
tab_above_board = 108.4;                                   // underside of the bracket's top tab above the board surface
plug8_clear = 38;                                          // room above the card for the 8-pin plug and its cable bend

psu_l = 160;  psu_w = 150;  psu_h = 86;                    // ATX PSU: length (rear -> modular face), width (fan face), height
atx_plug_clear = 45;                                       // from the board's Y=0 edge: 24-pin plug body + cable bend
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
standoff = 5;         // board underside above the floor (through-hole pins need ~3)
boss_d = 7;
gap_y = 11;           // board +Y edge -> wall (room for the edge clips and the corner post)
x_mid = 145;  y_mid = -40;      // mid posts (panels split here)
x_seam = 135; y_seam = -50;     // floor and lid pieces split here (jigsaw tabs)
lid_split_y = false;            // true: lid in 4 pieces for small beds
xg_exit = "both";               // "side" (through the +Y wall beside the connectors), "rear", or "both"
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
xi0 = -1;  xi1 = card_x1 + 3;
yi0 = psu_y0 - psu_wall_gap;  yi1 = board_w + gap_y;
zi1 = card_top + plug8_clear;                // interior height = lid underside
psu_x0 = xi0 + core + 1;  psu_x1 = psu_x0 + psu_l;
xo0 = xi0 - wall;  xo1 = xi1 + wall;  yo0 = yi0 - wall;  yo1 = yi1 + wall;     // panel exterior
xp0 = xo0 - lip;   xp1 = xo1 + lip;   yp0 = yo0 - lip;   yp1 = yo1 + lip;      // post / floor / lid outline
slot_w = wall + slot_fit;
panel_h = zi1 - 0.5;
peg = 6;

echo(str("interior ", xi1-xi0, " x ", yi1-yi0, " x ", zi1, " mm; outside ", xp1-xp0, " x ", yp1-yp0, " x ", zi1+floor_t+lid_t, " mm"));
echo(str("card: x ", xb, "..", card_x1, "  y ", card_y0, "..", card_y1, "  z ", card_z0, "..", card_top));
echo(str("PSU: x ", psu_x0, "..", psu_x1, "  y ", psu_y0, "..", psu_y1, "  z 0..", psu_w));

module box(x0,x1,y0,y1,z0,z1) { translate([x0,y0,z0]) cube([x1-x0, y1-y0, z1-z0]); }

/* ================= ghosts (the real parts, for the assembly view and the collision test) ================= */
module ghost_board() {
  color("green", 0.6) difference() {
    box(0, board_l, 0, board_w, standoff, zb);
    for (h = holes) translate([h[0], h[1], standoff-1]) cylinder(d = hole_d, h = board_t+2);
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
module ghost_psu() { color("black", 0.35) box(psu_x0, psu_x1, psu_y0, psu_y1, 0.05, psu_w); }
module ghost_zones() {   // volumes that must stay free for plugs and cables
  color("orange", 0.25) {
    box(atx_hdr_x[0]-2, atx_hdr_x[1]+2, -atx_plug_clear, 0, zb-1, zb+26);              // 24-pin plug + cable bend
    box(card_x1-110, card_x1, card_y0, card_y1, card_top, card_top+plug8_clear-0.1);    // 8-pin plug + cable bend
    box(xg_conn_x[0], xg_conn_x[1], 40, yo1+1, zb, zb+8);                               // micro-coax ribbons out through the +Y wall
    box(xi0, xb-1, bracket_y0+0.5, bracket_y1-0.5, zb+6.5, tab_z-14);                   // DP/HDMI plugs reaching the bracket
    box(xo0-6, 10, usbc_y[0]-2.5, usbc_y[1]+2.5, zb-2.5, zb+8.5);                       // USB-C plug
    box(psu_x1, psu_x1+30, psu_y0, psu_y1, 10, psu_w-5);                                // modular plugs on the PSU
    box(xo0-25, psu_x0, psu_y0+3, psu_y1-3, 6, psu_w-6);                                // IEC plug / switch
  }
}
module ghosts()      { ghost_board(); ghost_card(); ghost_psu(); ghost_zones(); }
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
    translate([core/2, core/2, 0]) top_socket(h);
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

module posts() {
  translate([xi0, yi0, 0]) corner_post_local();
  translate([xi0, yi1, 0]) mirror([0,1,0]) corner_post_local();
  translate([xi1, yi0, 0]) mirror([1,0,0]) corner_post_local();
  translate([xi1, yi1, 0]) mirror([1,0,0]) mirror([0,1,0]) corner_post_local();
  translate([xi0, y_mid, 0]) midpost_yz_local();
  translate([xi1, y_mid, 0]) mirror([1,0,0]) midpost_yz_local();
  translate([x_mid, yi0, 0]) midpost_xz_local();
  translate([x_mid, yi1, 0]) mirror([0,1,0]) midpost_xz_local();
}

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
module cradle_peg_centres() { for (y = [card_y0+7, card_y1-7]) translate([card_x1-9, y, 0]) children(); }

module floor_full() {
  difference() {
    union() {
      box(xp0, xp1, yp0, yp1, -floor_t, 0);                                   // plate
      lip_ring(0, 3);
      for (h = holes) translate([h[0], h[1], 0]) {
        cylinder(d = boss_d, h = standoff - 0.05);
        cylinder(d = hole_d - pin_fit, h = standoff + board_t + 1.0);
      }
      board_clip(52, +1);  board_clip(186, +1);      // +Y edge: clear of the laptop-cable ribbons (x 77..136)
      board_clip(100, -1); board_clip(186, -1);      // Y=0 edge: between the power inputs
      // PSU stops: behind the modular face (bottom edge only) and along the plug-zone side
      box(psu_x1+0.5, psu_x1+3.5, psu_y0+6, psu_y1-6, 0, 6);
      box(psu_x0+2, psu_x0+16, psu_y1+0.5, psu_y1+2.5, 0, 6);
      box(psu_x0+110, psu_x0+130, psu_y1+0.5, psu_y1+2.5, 0, 6);
    }
    for (p = post_centers()) translate([p[0]-(peg+peg_fit)/2, p[1]-(peg+peg_fit)/2, -floor_t-1]) cube([peg+peg_fit, peg+peg_fit, floor_t+2]);
    cradle_peg_centres() translate([-(peg+peg_fit)/2, -(peg+peg_fit)/2, -floor_t-1]) cube([peg+peg_fit, peg+peg_fit, floor_t+2]);
    // cable-tie slots in the cable bay and under the 8-pin route
    for (x = [psu_x1+25, psu_x1+65, psu_x1+105]) for (y = [psu_y0+20, psu_y0+50]) { box(x, x+1.8, y, y+6, -floor_t-1, 1); box(x+8, x+9.8, y, y+6, -floor_t-1, 1); }
  }
}

/* ================= lid ================= */
module lid_full() {
  difference() {
    box(xp0, xp1, yp0, yp1, zi1, zi1+lid_t);
    if (vents) for (p = grid(xb-4, card_x1+2, card_y0-4, yi1-3, vent_w, vent_pitch, vent_h, vent_row))
      box(p[0], p[0]+vent_w, p[1], p[1]+vent_h, zi1-1, zi1+lid_t+1);
  }
  lip_ring(zi1-4, zi1);
  for (p = post_centers()) translate([p[0]-peg/2, p[1]-peg/2, zi1-3.6]) cube([peg, peg, 3.6+eps]);
  // ribs straddling the card's top edge (front half of the card, clear of the 8-pin plug)
  for (y = [[card_y0-3.5, card_y0-0.5], [card_y1+0.5, card_y1+3.5]]) box(xb+14, xb+64, y[0], y[1], card_top+1, zi1+eps);
  // guides beside the bracket's top end
  box(xb-6, xb+3,   bracket_y0-4.8, bracket_y0-0.8, tab_z-12, zi1+eps);   // solder side: beside the bracket's edge
  box(xb-6, xb-0.3, bracket_y1+0.8, bracket_y1+4.8, tab_z-12, zi1+eps);   // component side: in front only (the shroud is behind)
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
  box(xo0-1, xi0+1, psu_y0+3, psu_y1-3, 3, psu_w-3);                               // PSU rear face (IEC, switch, grille)
  box(xo0-1, xi0+1, usbc_y[0]-3.5, usbc_y[1]+3.5, zb-3, zb+9);                      // USB-C
  box(xo0-1, xi0+1, bracket_y0-1.5, bracket_y1+1.5, zb+6, tab_z-13);                // tunnel to the card's display ports
  if (xg_exit == "rear" || xg_exit == "both") box(xo0-1, xi0+1, 38, 62, zb-1, zb+9); // laptop cable, rear exit
  vents_yz(xo0, xi0, 38, yi1-4, 14, zi1-9);
  vents_yz(xo0, xi0, 2, 38, tab_z-2, zi1-9);
  vents_yz(xo0, xi0, psu_y1+6, -4, 30, zi1-9);                                      // over the 24-pin plug zone
}
module far_cutters() {
  vents_yz(xi1, xo1, card_y0-8, yi1-4, 8, zi1-9);                                   // GPU exhaust
  vents_yz(xi1, xo1, yi0+4, psu_y1-4, 8, zi1-9);                                    // cable bay breathes too
}
module left_cutters() {                                                             // -Y wall: PSU intake
  vents_xz(yo0, yi0, psu_x0+2, psu_x1-4, 4, psu_w-4);
}
module right_cutters() {                                                            // +Y wall: GPU intake + cable exit
  vents_xz(yi1, yo1, xb-4, card_x1+2, card_z0-2, card_top+2);
  if (xg_exit == "side" || xg_exit == "both") box(xg_conn_x[0]-6, xg_conn_x[1]+6, yi1-1, yo1+1, 3.5, zb+9);
}

module panel_rear_l()  { panel_yz(xo0, xi0, yi0+core-slot_d+0.3, y_mid-2.3) rear_cutters(); }
module panel_rear_r()  { panel_yz(xo0, xi0, y_mid+2.3, yi1-core+slot_d-0.3) rear_cutters(); }
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

/* ================= views ================= */
module structure() { floor_full(); posts(); panels(); lid_full(); cradle(); }
module assembly()  { structure(); ghosts(); }
module inside()    { floor_full(); posts(); panel_rear_l(); panel_rear_r(); panel_far_l(); panel_far_r(); panel_left_r(); panel_left_f(); cradle(); ghosts(); }   // lid and +Y wall removed
module collision() { intersection() { structure(); ghosts_hard(); } }

/* ================= part selector (parts are laid out for printing) ================= */
module flat_yz(x0) { rotate([0, 90, 0]) translate([-x0 - wall, 0, 0]) children(); }   // YZ panel -> lying flat, exterior face down
module flat_xz(y0) { rotate([-90, 0, 0]) translate([0, -y0 - wall, 0]) children(); }

if (part == "assembly")   assembly();
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
else if (part == "coupon") coupon();
else echo(str("unknown part: ", part));
