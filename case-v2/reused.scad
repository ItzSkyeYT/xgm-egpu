// reused.scad
// The two parts of v1 that fitted the real card at the test fit and that v2 keeps exactly as they were printed: the bracket holder
// and the cradle. tools/check_reused.sh proves that these modules still produce v1's files, so a holder and a cradle printed for v1
// drop into a v2 case. Included by xgm-v2.scad, after hardware.scad.

insert_hole = 4.2;    // hole for the M3x5x4.5 heat-set inserts. TESTED on the real printer in PETG
insert_depth = 5.6;   // insert length 5 + 0.6
peg = 6;  peg_fit = 0.4;       // square pegs and their sockets. TESTED

/* ---------- bracket holder: stands in the board's three 3 x 4 holes, carries the bracket's tab ---------- */
hx0 = holder_hole_x - 1.4;                                  // back face (toward the rear wall)
hx1 = xb - 1.7;                                             // front face: 1.7 mm from the bracket's outer face
peg_w = 2.6;                                                // pegs 2.6 x 3.6 in the board's 3 x 4 holes
arm_h = 4.5;                                                // thin: the top display port starts only ~9 mm under the tab
holder_gap = 0.8;                                           // base beam above the board: the holder hangs from the tab once its screw is in
holder_y1  = 66;                                            // the head reaches past the tab's far end, where the screw from the rear wall gets at it
holder_peg_z0 = -1.9;                                       // the pegs' tips, as printed: this far below the floor's top face
wall_tie = [holder_y1 - 4.5, tab_z - 17.6];                 // y, z of the screw from the rear wall into the holder's back
module bracket_holder() {
  z0 = zb + holder_gap;  top = tab_z - 0.1;
  difference() {
    union() {
      box(hx0, hx1, 17.2, 61.5, z0, z0+4.5);                              // base beam over the three pegs, below the lowest port
      box(hx0, hx1, 40, 61.5, z0, top);                                   // column beside the ports
      box(hx0, hx1, 37, holder_y1, tab_z-30, top);                        // wider head
      box(hx0, hx1, bracket_y0-0.4, holder_y1, top-arm_h, top);           // arm: its top face is the seat for the bracket's tab
      box(hx0, hx1, tab_screw[1]-3.6, 40, top-11, top);                   // body for the tab screw's insert
      for (y = holder_holes_y) box(hx0, hx0+peg_w, y-1.8, y+1.8, holder_peg_z0, z0+eps);   // pegs through the board into the floor
    }
    translate([tab_screw[0], tab_screw[1], top-insert_depth]) cylinder(d = insert_hole, h = insert_depth+1, $fn = 40);   // insert under the tab's oval hole
    translate([tab_screw[0], tab_screw[1], top-9]) cylinder(d = 3.3, h = 9, $fn = 24);                                    // and room below it for the tip of an M3x8
    translate([hx0-1, wall_tie[0], wall_tie[1]]) rotate([0, 90, 0]) cylinder(d = insert_hole, h = insert_depth+1, $fn = 40);   // insert in the back face
  }
}
module bracket_washer() { difference() { cylinder(d = 8, h = 1.6, $fn = 48); translate([0, 0, -1]) cylinder(d = 3.4, h = 4, $fn = 30); } }

/* ---------- far-end cradle: plugs into two square sockets in the floor ---------- */
// Its pegs are 4.1 off-centre under it: v1's floor was printed before the card's real position was known. v2 keeps the sockets there.
cradle_socket_y = [pcie_y - board_t/2 - 2.5 + 7, pcie_y - board_t/2 - 2.5 + gpu_w - 7];
cradle_peg_len = 2.4;                                       // as printed
module cradle_peg_centres() { for (y = cradle_socket_y) translate([card_x1-9, y, 0]) children(); }
module cradle() {
  rest = card_bot - 0.3;
  cx0 = card_x1 - 18;  cx1 = card_x1;
  difference() {
    union() {
      box(cx0, cx1, card_y0-3.5, card_y1+3.5, 0, 3);
      box(cx0, cx1, card_y0-0.5, card_y1+0.5, 0, rest);
      for (y = [[card_y0-3.5, card_y0-0.5], [card_y1+0.5, card_y1+3.5]]) box(cx0, cx1, y[0], y[1], 0, rest+25);
    }
    for (y = [card_y0-0.5, card_y1+0.5]) translate([(cx0+cx1)/2, y, rest+25]) rotate([45,0,0]) cube([cx1-cx0+2, 3, 3], center=true);   // lead-in chamfers
  }
  cradle_peg_centres() translate([-peg/2, -peg/2, -cradle_peg_len]) cube([peg, peg, cradle_peg_len+eps]);
}

/* ---------- the laptop cable's grommet clip: a thin wall in the grommet's gap, U-slot open at the top ---------- */
module grommet_clip(slot = grommet_slot) {
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
