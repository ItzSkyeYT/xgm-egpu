// hardware.scad
// The real parts that go into the case, and the room their plugs and cables need. Included by xgm-v2.scad.
// Every number here is carried over from case/xgm-lite-frame.scad (v1), where each one was measured on the real hardware or settled at a
// test fit. tools/check_hardware.sh proves the two files draw the same volumes. Change a number here only after measuring.
//
// World frame:  X along the board (0 = the board's rear edge, where the USB-C is; +X toward the card's far end)
//               Y across the board (0 = the edge with the 24-pin ATX header; the GPU cooler is on +Y)
//               Z up (0 = top surface of the floor plate)
// KiCad's Y points down on screen and this frame keeps that, so every export is mirrored in Y (MIRROR in xgm-v2.scad).

/* ---------- the board: osy XG Mobile Station Lite ---------- */
board_l = 220;  board_w = 65;  board_t = 1.6;
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
standoff = 7;                                              // board underside above the floor (the bracket's foot reaches 9.7 below the board top)

/* ---------- the card: Inno3D RTX 3060 Twin X2 OC ---------- */
gpu_len = 240;  gpu_h = 120;  gpu_w = 42.2;                // length, height (Inno3D), thickness MEASURED at the bracket end
gpu_backplate = 6.6;                                       // PCB's solder side -> the backplate's outer face. FOUND at v1's test fit
gpu_mass = 1.05;                                           // kg, a shop's figure, possibly with its box: the worst case
bracket_to_a1 = pcie_a1_x - foot_slot_x;                   // 47.45: bracket plane = the board's foot slot
bracket_w = 41.5;  bracket_t = 0.86;                       // a two-slot bracket; its top tab MEASURED 39.4 long
bracket_port_w = 18.42;                                    // the display ports are all in the first slot's row
tab_reach = 11.4;                                          // top tab, bracket's outer face -> free edge: MEASURED 10.6 to the bend
bracket_margin = 5.3;                                      // card PCB plane -> solder-side edge of the bracket
card_seat = 4.1;                                           // finger bottom above the board surface
card_bottom_clear = 18.9;                                  // MEASURED: board surface -> lowest point of the card near its far end
tab_above_board = 109.0;                                   // MEASURED: board surface -> underside of the bracket's top tab
foot_below_board = 9.7;                                    // MEASURED: the bracket's foot reaches this far below the board's top surface
plug8_clear = 42;                                          // room above the card for a straight 8-pin plug and a stiff sleeved cable

/* ---------- the power supply: Corsair RM850 (2021) ---------- */
psu_l = 160;  psu_w = 150;  psu_h = 86;                    // length (rear face -> modular face), width (fan face), height
psu_mass = 1.65;                                           // kg
atx_plug_clear = 48;                                       // from the board's Y=0 edge: 24-pin plug body + the start of its bend
atx_bend_reach = 92;                                       // MEASURED 86.8 + margin: how far from the board edge the sleeved bundle's bend reaches
psu_wall_gap = 11;                                         // PSU fan face -> the wall with its intake grille

/* ---------- the laptop cable and its grommet ---------- */
gap_y = 24;                                                // board's fan-side edge -> wall: the harness and its boot run along this edge
xg_exit_y = [board_w-5, board_w+15];                       // the cable leaves through the rear wall here
grommet_x = 41.5 + 2.5;        // MEASURED 41.5: board's rear edge -> the grommet's gap, harness gently straight; +2.5 of slack
grommet_y = board_w + 12;      // MEASURED 12.7: board's long edge -> grommet centre, lying relaxed
grommet_d = 14.8;              // MEASURED: the round disc (the square plate is 14.7 across flats)
grommet_gap = 1.4;             // MEASURED: the gap between disc and plate
grommet_slot = 10.5;           // the rubber neck in the gap. TESTED on the real printer: 10.5 holds it closely
grommet_zc = 8;                // grommet axis above the floor
clip_t = 1.2;  clip_hw = 9;    // the clip's wall, inside the 1.4 gap, and its half-width
cable_d = 9;                   // the thick cable, generous

/* ---------- the room all of that needs (validated with the real parts and cables in v1) ---------- */
zb       = standoff + board_t;               // board top surface
xb       = pcie_a1_x - bracket_to_a1;        // bracket outer face (card front)
card_x1  = xb + gpu_len;
card_y0  = pcie_y - board_t/2 - gpu_backplate;
card_y1  = card_y0 + gpu_w;
card_z0  = zb + card_seat;                   // finger bottom
card_top = card_z0 + 3.2 + gpu_h;
card_bot = zb + card_bottom_clear;           // lowest point of the card away from the connector (measured)
bracket_y0 = pcie_y - bracket_margin;  bracket_y1 = bracket_y0 + bracket_w;
ports_y1 = bracket_y0 + bracket_port_w;
tab_screw = [xb - 5.0, pcie_y + 18.4];       // the oval hole in the card's tab (see v1 for how this was found)
tab_z    = zb + tab_above_board;
psu_y1   = -atx_plug_clear;  psu_y0 = psu_y1 - psu_h;
xi0 = -4;  xi1 = card_x1 + 3;                // interior: rear wall's inner face, far wall's inner face
yi0 = psu_y0 - psu_wall_gap;  yi1 = board_w + gap_y;
zi1 = card_top + plug8_clear;                // interior height = lid underside
psu_far_gap = 0.1;                           // PSU's rear face -> the far wall's inner face. v2 screws the PSU to that wall: they touch, give or take
psu_x1 = xi1 - psu_far_gap;  psu_x0 = psu_x1 - psu_l;
bay_x0 = xi0 + 4;  bay_x1 = psu_x0 - 4;      // cable bay behind the PSU's modular face

eps = 0.01;
module box(x0,x1,y0,y1,z0,z1) { translate([x0,y0,z0]) cube([x1-x0, y1-y0, z1-z0]); }

/* ================= ghosts: the real parts, for the assembly view and the collision test ================= */
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
module ghost_card() {      // the plain envelope: this is what the collision test uses
  color("gray", 0.5) box(xb, card_x1, card_y0, card_y1, card_bot, card_top);
  color("gray", 0.5) box(pcie_x0-1, pcie_x1+1, pcie_y-0.8, pcie_y+0.8, card_z0, card_bot+eps);   // finger tab
  color("silver", 0.7) box(xb, xb+bracket_t, bracket_y0, bracket_y1, card_z0-7.9, tab_z);
  color("silver", 0.7) box(xb-tab_reach, xb, bracket_y0, bracket_y1, tab_z, tab_z+0.9);
}
module ghost_card_detail() {   // the Inno3D Twin X2 OC as it actually looks, for pictures
  pcb_x0 = xb + 1.9;  pcb_x1 = xb + 190;
  pcb_z0 = zb + card_seat + 3.2;  pcb_z1 = pcb_z0 + 111;
  sh_x0 = xb + 6;  sh_z0 = card_bot;  sh_z1 = card_top - 3;
  fan_z = (sh_z0 + sh_z1) / 2 + 2;
  color("darkgreen") box(pcb_x0, pcb_x1, pcie_y-0.8, pcie_y+0.8, pcb_z0, pcb_z1);                       // PCB
  color("goldenrod") box(pcie_x0+1, pcie_x1-1, pcie_y-0.8, pcie_y+0.8, card_z0, pcb_z0+eps);           // gold fingers
  color("black") box(pcb_x0+3, pcb_x1-2, card_y0, pcie_y-0.8, pcb_z0+3, pcb_z1-3);                     // backplate
  color("black") box(pcb_x1-2-eps, card_x1-2, card_y0, pcie_y-0.8, card_bot, pcb_z1-3);                // which runs on past the PCB
  color("dimgray") difference() {                                                                       // shroud + heatsink
    box(sh_x0, card_x1, pcie_y+0.8, card_y1, sh_z0, sh_z1);
    for (fx = [xb+70, xb+170]) translate([fx, card_y1+0.01, fan_z]) rotate([90,0,0]) cylinder(d = 88, h = 7);
  }
  color("black") for (fx = [xb+70, xb+170]) translate([fx, card_y1-6.9, fan_z]) rotate([-90,0,0]) {   // fan hubs and blades
    cylinder(d = 36, h = 5);
    for (a = [0:40:359]) rotate([0,0,a]) translate([14,-3,0]) cube([30, 6, 1.2]);
  }
  ghost_bracket();
  color("black") box(xb+150, xb+168, pcie_y-0.8, pcie_y+8.5, pcb_z1-2, pcb_z1+7);                     // 8-pin socket
}
module ghost_bracket() {
  color("silver") difference() {                                                                        // bracket with its ports
    box(xb, xb+bracket_t, bracket_y0, bracket_y1, zb-foot_below_board, tab_z+0.9);
    for (i = [0:2]) box(xb-1, xb+2, bracket_y0+1.2, bracket_y0+17.2, tab_z-9-6.5-i*16, tab_z-9-i*16);  // 3x DisplayPort
    box(xb-1, xb+2, bracket_y0+2, bracket_y0+16.5, tab_z-9-6.5-3*16-4, tab_z-9-3*16-4);              // HDMI
    for (zz = [zb+12 : 7 : tab_z-62]) for (yy = [bracket_y0+3 : 5 : ports_y1-5]) box(xb-1, xb+2, yy, yy+3, zz, zz+4);
    for (zz = [zb+12 : 7 : tab_z-12]) for (yy = [ports_y1+4 : 5 : bracket_y1-6]) box(xb-1, xb+2, yy, yy+3, zz, zz+4);
  }
  ghost_tab();
}
module ghost_tab() {   // the top tab as measured and photographed: 39.4 long, a finger at the backplate end, two notches, one oval screw hole
  t0 = tab_screw[1] - 23.1;  t1 = t0 + 39.4;  xf = xb - tab_reach + 0.4;
  color("silver") difference() {
    box(xf, xb+bracket_t, t0, t1, tab_z, tab_z+0.9);
    box(xf+3.9, xb+bracket_t+1, t0-1, t0+5.4, tab_z-1, tab_z+2);
    for (y = [t0+9.2, t0+9.2+20.32]) box(xf-1, xf+4.2, y-1.5, y+1.5, tab_z-1, tab_z+2);
    hull() for (dy = [-1.15, 1.15]) translate([tab_screw[0], tab_screw[1]+dy, tab_z-1]) cylinder(d = 4.5, h = 3, $fn = 30);
  }
}
module ghost_psu() { color("black", 0.35) box(psu_x0, psu_x1, psu_y0, psu_y1, 0.05, psu_w); }
// Volumes that must stay free for plugs and cables. wall_out = the rear wall's outer face (x), far_out = the far wall's outer face.
module ghost_zones(wall_out, far_out, board_screws = true, psu_access = true) {
  color("orange", 0.25) {
    box(atx_hdr_x[0]-2, atx_hdr_x[1]+2, -atx_bend_reach, 0, zb-1, zb+28);                              // 24-pin plug + the whole bend (reaches into the bay)
    if (board_screws) for (h = holes) translate([h[0], h[1], zb]) cylinder(d = 6, h = 3.2, $fn = 24);   // board screw heads
    box(card_x1-110, card_x1, card_y0, card_y1, card_top, card_top+plug8_clear-0.1);                   // 8-pin plug + cable bend
    // laptop cable: harness along the fan-side edge, grommet in its clip, thick cable out through the rear notch
    box(grommet_x+20, xg_conn_x[1]+2, board_w+0.5, board_w+11, 1, 15);                               // harness along the edge
    box(grommet_x+2.8, grommet_x+20, grommet_y-5.5, grommet_y+5.5, 1, 15);                            // harness entering the grommet
    box(grommet_x+0.7, grommet_x+2.8, grommet_y-7.6, grommet_y+7.6, grommet_zc-7.6, grommet_zc+7.6);  // square plate
    box(grommet_x-2.8, grommet_x-0.7, grommet_y-7.6, grommet_y+7.6, grommet_zc-7.6, grommet_zc+7.6);  // round disc
    box(grommet_x-15, grommet_x-2.8, grommet_y-5.5, grommet_y+5.5, grommet_zc-5.5, grommet_zc+5.5);   // cone and sleeve
    box(12, grommet_x-15, grommet_y-5.5, grommet_y+4.5, grommet_zc-cable_d/2, grommet_zc+cable_d/2);  // thick cable, easing toward the notch
    box(wall_out-10, 12, 69, 78, grommet_zc-cable_d/2, grommet_zc+cable_d/2);                          // ... and out through the rear wall
    box(bay_x0, psu_x0+1, -atx_bend_reach-10, psu_y1-8, 7, 34);                                        // bundles running from the bend to the modular face
    box(xi0, xb-1, bracket_y0+0.5, ports_y1-0.5, zb+6.5, tab_z-5.5);                                   // DP/HDMI plugs reaching the bracket
    box(wall_out-6, 10, usbc_y[0]-2.5, usbc_y[1]+2, zb-2.5, zb+8.5);                                   // USB-C plug
    box(psu_x0-30, psu_x0, psu_y0, psu_y1, 10, psu_w-5);                                               // modular plugs and their cables
    if (psu_access) box(psu_x1, far_out+25, psu_y0+3, psu_y1-3, 6, psu_w-6);                           // mains plug, switch, exhaust
  }
}
