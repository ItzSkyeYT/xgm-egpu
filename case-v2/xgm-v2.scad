// xgm-v2.scad
// A second, rigidity-first enclosure for the same hardware as case/xgm-lite-frame.scad: an XG Mobile Station Lite board, a desktop
// graphics card and an ATX power supply. A design study: v1 in ../case is the one being printed.
//
// How it carries load (see README.md for the reasoning and the numbers):
//   - Six M4 threaded rods run from a foot under the case to a nut on top of the lid. They carry every pull; the printed parts between
//     the two nuts are only ever squeezed.
//   - The base is a closed sandwich 24 mm deep: a sole, a grid of rails standing on it, and the floor plate bolted on top with a steel
//     nut in every joint. The feet are part of it: each one holds the nut a rod ends in.
//   - Every edge of every wall is bolted: its two ends to the posts, its bottom edge to the floor's rim, its top edge to the lid's.
//     Walls, floor and lid are one closed box, which is what resists twisting.
//   - The vents are lattices of diagonal bars, not slots: a slotted wall carries almost no shear, a lattice does.
//   - The handle is a beam on the lid whose two ends are held down by two of the rods: a lift goes hand, beam, steel, base.
//
// Two versions, chosen with `bed`:
//   "350"  every plate in one piece. For beds of 300 x 300 mm or more (Bambu H2D).
//   "256"  base, floor and lid in two pieces each, for 256 x 256 mm beds. The three seams are at three different places, so each
//          one lies under or over an unbroken plate of the next layer, bolted to it on both sides of the seam.
// Everything else (posts, walls, handle, feet) is the same in both.
//
// Render one part:   openscad -o out.stl -D 'part="floor"' -D 'bed="350"' xgm-v2.scad
// Everything:        tools/build.py 350        (renders, then checks collisions, overlaps and what would print in mid-air)

include <hardware.scad>
include <reused.scad>

part = "assembly";
bed = "350";           // "350" or "256"
vents = true;          // false speeds up test renders
MIRROR = true;         // the design frame keeps KiCad's Y, so every export is mirrored in Y to match the real board
$fn = 40;

/* ---------- structure ---------- */
wall = 5;              // wall panels: as thick as the heat-set inserts in their edges are long
floor_t = 4;  lid_t = 4;
edge = 4;              // floor, lid, base and posts stand this far beyond the panels' outer faces. It is the thickness of the two rims
core = 10;             // posts reach this far into the interior. Kept from v1: every clearance inside was validated against it
slot_fit = 0.4;        // a panel's thickness in a post's slot, and in the floor's and the lid's grooves. TESTED in v1
slot_d = 8;            // how far a panel's end reaches into a post
skirt_h = 14;          // the floor's rim stands this far up the outside of the panels, the lid's hangs this far down. Both are screwed to them
skirt_z = 7;           // height of those screws above the floor, and below the lid
lip_h = 3;             // the low lip on the inside of each groove
sole = 2;              // the closed underside of the base
base_h = 20;           // depth of the base under the floor plate: the sole, and rails 18 mm high
rim_w = 18;            // width of its perimeter rails
rail_w = 12;           // width of its inner rails
rod_hole = 4.6;        // for M4 threaded rod
foot_h = 12;
x_mid = 145;           // the long walls' mid posts, and the handle's line: the loaded case balances on it
mid_hw = 11;           // half-width of a mid post along its wall
mid_web = 6;           // ... and the web between its two slots
bar_w = 2.4;  bar_p = 10;      // lattice vents: bars this wide, this far apart, at 45 degrees both ways

x_floor_seam = 175;    // bed "256": the floor's seam. Both pieces then fit a P1S or an X1C with room to spare (188 and 91 mm long)
x_frame_seam = 75;     // ... the base's, 100 mm from the floor's
x_lid_seam = 135;      // ... and the lid's, between the two

/* ---------- derived ---------- */
xo0 = xi0 - wall;  xo1 = xi1 + wall;  yo0 = yi0 - wall;  yo1 = yi1 + wall;     // the panels' outer faces
xp0 = xo0 - edge;  xp1 = xo1 + edge;  yp0 = yo0 - edge;  yp1 = yo1 + edge;     // outline of floor, lid, base and posts
zf = -floor_t;                 // floor plate's underside = the base's top
zr = zf - base_h;              // the base's underside
zt = zi1 + lid_t;              // lid's top face
panel_h = zi1 - 0.2;           // the posts are the spacers between floor and lid; the panels stay 0.2 short of them
slot_w = wall + slot_fit;
rc = 1 - (wall + edge)/2;      // a corner rod, in its post's local frame: in the solid block outside the two panels' ends
screw_za = [30, 89, 148];      // heights of the screws that fix a panel to a post
screw_zb = [40, 99, 158];      // ... and of the second panel at a corner post, so that the two sets cross without meeting
screw_e = 3.5;                 // their distance from the panel's end
screw_y = core - slot_d + 0.3 + screw_e;       // ... which puts them here in a corner post's local frame
mid_sy = mid_web/2 + 0.3 + screw_e;            // ... and here in a mid post's
nut_x = 5;                     // a post screw's nut sits this deep in the post's core

echo(str("v2 bed ", bed, ": outside ", xp1-xp0, " x ", yp1-yp0, " x ", zt-zr+foot_h, " mm (interior ", xi1-xi0, " x ", yi1-yi0, " x ", zi1, ")"));

/* ---------- where the posts stand ---------- */
// A corner post's local frame has the interior toward +X and +Y, its origin on the corner of the two walls' inner faces.
// A mid post's has the wall along Y and the interior toward +X, its origin on the wall's inner face.
corner_at = [[xi0, yi0, 0], [xi0, yi1, -90], [xi1, yi0, 90], [xi1, yi1, 180]];    // rear/PSU side, rear/fan side, far/PSU side, far/fan side
mid_at = [[x_mid, yi0, 90], [x_mid, yi1, -90]];                                    // PSU-side wall, fan-side wall
function rot(p, a) = [p[0]*cos(a) - p[1]*sin(a), p[0]*sin(a) + p[1]*cos(a)];
function corner_pt(i, p) = let(r = rot(p, corner_at[i][2])) [corner_at[i][0] + r[0], corner_at[i][1] + r[1]];
function mid_pt(i, p) = let(r = rot(p, mid_at[i][2])) [mid_at[i][0] + r[0], mid_at[i][1] + r[1]];
module at_corner(i) { translate([corner_at[i][0], corner_at[i][1], 0]) rotate([0, 0, corner_at[i][2]]) children(); }
module at_mid(i) { translate([mid_at[i][0], mid_at[i][1], 0]) rotate([0, 0, mid_at[i][2]]) children(); }
function rods() = concat([for (i = [0:3]) corner_pt(i, [rc, rc])], [for (i = [0:1]) mid_pt(i, [core/2, 0])]);   // four corner rods, then the handle's two
foot_screw_c = [5, 13];                             // the screw that holds a corner foot to the base, in the corner post's local frame
foot_screw_m = [[core/2, -15], [core/2, 15]];       // ... and a mid foot's two
// [where, the direction its nut slides in from] for each of them: always out of the rail into the open cell beside it
function foot_screws() = concat([for (i = [0:3]) [corner_pt(i, foot_screw_c), rot([1, 0], corner_at[i][2])]],
                                [for (i = [0:1]) for (p = foot_screw_m) [mid_pt(i, p), rot([1, 0], mid_at[i][2])]]);

/* ================= posts ================= */
// Printed standing: between floor and lid they are only ever squeezed by the rod that runs through them.
// A panel's end stands in a slot between the post's outer flange and its core. Three M3x16 countersunk screws go in from outside
// through flange and panel, each into a steel nut that was slid into a slot in the core.
module post_screws(what, zs, y, open = 1) {      // one panel end's screws, in along +X at heights zs. open: the side its nut slots open to
  for (z = zs) translate([-wall-edge, y, z]) rotate([0, 90, 0]) {       // in here +Z runs inward and +Y is still the post's +Y
    if (what == "through") translate([0, 0, -1]) cylinder(d = 3.4, h = 1 + wall + edge + nut_x + 3.5, $fn = 24);   // flange, panel, and on past the nut
    if (what == "sink") translate([0, 0, -eps]) cylinder(d1 = 6.6, d2 = 3.4, h = 1.7, $fn = 32);                    // the head, flush with the post's face
    if (what == "nut") translate([-2.85, open > 0 ? -2.9 : -core, wall + edge + nut_x - 1.35]) cube([5.7, core + 2.9, 2.7]);
    if (what == "screw") { color("#d8402c") { cylinder(d1 = 6, d2 = 3, h = 1.6, $fn = 24); cylinder(d = 3, h = 16, $fn = 16); }
                           color("#d9a520") translate([0, 0, wall + edge + nut_x - 1.2]) cylinder(d = 6.2, h = 2.4, $fn = 6); }
  }
}
module corner_screws(what) {
  post_screws(what, screw_za, screw_y);                                            // the panel in the YZ plane
  mirror([1, -1, 0]) post_screws(what, screw_zb, screw_y);                         // the panel in the XZ plane (x and y swapped)
}
module mid_screws(what) { for (s = [-1, 1]) post_screws(what, screw_za, s*mid_sy, s); }
module corner_post_local(h = zi1) {
  difference() {
    translate([-wall-edge, -wall-edge, 0]) cube([wall+edge+core, wall+edge+core, h]);
    translate([-wall-slot_fit/2, core-slot_d, -1]) cube([slot_w, slot_d+2, h+2]);      // slot for the panel in the YZ plane
    translate([core-slot_d, -wall-slot_fit/2, -1]) cube([slot_d+2, slot_w, h+2]);      // slot for the panel in the XZ plane
    translate([rc, rc, -1]) cylinder(d = rod_hole, h = h+2, $fn = 32);                 // the rod
    translate([rc, rc, -eps]) cylinder(d1 = rod_hole+2.4, d2 = rod_hole, h = 1.2, $fn = 32);   // lead-in: the post is slid down over it
    for (w = ["through", "sink", "nut"]) corner_screws(w);
  }
}
module mid_post_local(h = zi1) {
  difference() {
    translate([-wall-edge, -mid_hw, 0]) cube([wall+edge+core, 2*mid_hw, h]);
    for (s = [0, 1]) mirror([0, s, 0]) translate([-wall-slot_fit/2, mid_web/2, -1]) cube([slot_w, mid_hw, h+2]);
    translate([core/2, 0, -1]) cylinder(d = rod_hole, h = h+2, $fn = 32);
    translate([core/2, 0, -eps]) cylinder(d1 = rod_hole+2.4, d2 = rod_hole, h = 1.2, $fn = 32);
    for (w = ["through", "sink", "nut"]) mid_screws(w);
  }
}
module posts() { for (i = [0:3]) at_corner(i) corner_post_local(); for (i = [0:1]) at_mid(i) mid_post_local(); }
module post_footprints(grow = 0) {     // in plan: where rims and ribs must stop
  for (i = [0:3]) at_corner(i) translate([-wall-edge-grow, -wall-edge-grow]) square([wall+edge+core+2*grow, wall+edge+core+2*grow]);
  for (i = [0:1]) at_mid(i) translate([-wall-edge-grow, -mid_hw-grow]) square([wall+edge+core+2*grow, 2*mid_hw+2*grow]);
}
module all_post_screws(what) { for (i = [0:3]) at_corner(i) corner_screws(what); for (i = [0:1]) at_mid(i) mid_screws(what); }

/* ================= the rims' screws ================= */
// Every wall's bottom edge is screwed to the floor's rim and its top edge to the lid's: an M3x10 countersunk from outside, into a
// heat-set insert that was pressed into the panel from its INNER face. Set that way an insert can be left proud, as they come out in
// practice, without holding the panel off the rim, and the screw pulls it deeper instead of out.
// Positions along each wall, [bottom edge, top edge], clear of the posts, of every opening and of the PSU's rear face.
sk_rear = [[-120, -75, -30, 40], [-120, -75, -30, 20, 62]];        // y
sk_far  = [[-25, 20, 62],        [-120, -75, -30, 20, 62]];        // y
sk_long = [[22, 72, 122, 166, 232], [22, 72, 122, 166, 232]];      // x, on both long walls
module rim_screw(what) {              // in here +Z runs inward from the rim's outer face
  if (what == "through") translate([0, 0, -1]) cylinder(d = 3.4, h = edge + 1.2, $fn = 24);
  if (what == "sink") translate([0, 0, -eps]) cylinder(d1 = 6.6, d2 = 3.4, h = 1.7, $fn = 32);
  if (what == "insert") translate([0, 0, edge - 0.1]) cylinder(d = insert_hole, h = wall + 0.2, $fn = 32);     // right through the panel
  if (what == "tip") translate([0, 0, edge + wall]) cylinder(d = 5, h = 1.2, $fn = 24);                        // an insert left proud, and the screw's end
  if (what == "screw") color("#d8402c") { cylinder(d1 = 6, d2 = 3, h = 1.6, $fn = 24); cylinder(d = 3, h = 10, $fn = 16); }
}
module rim_screws(what) {
  for (e = [0, 1]) let(z = e == 0 ? skirt_z : zi1 - skirt_z) {
    for (y = sk_rear[e]) translate([xp0, y, z]) rotate([0, 90, 0]) rim_screw(what);
    for (y = sk_far[e])  translate([xp1, y, z]) rotate([0, -90, 0]) rim_screw(what);
    for (x = sk_long[e]) { translate([x, yp0, z]) rotate([-90, 0, 0]) rim_screw(what);  translate([x, yp1, z]) rotate([90, 0, 0]) rim_screw(what); }
  }
}

/* ================= wall panels ================= */
// Six panels: the rear and the far wall in one piece each, the two long walls in two pieces that meet inside a mid post.
// They print flat, outer face down, so the inserts go in from the top of the print.
//
// A vent is a window with a lattice of bars left standing in it, at 45 degrees both ways. Slots would be simpler, but a field of slots
// carries almost no shear (the strips between them just bend): v1's pattern keeps about 4 % of the solid wall's stiffness. Diagonal
// bars carry shear as struts and ties and keep about a third of it, with more open area (57 % against 42 %).
//
// A panel is drawn flat, in its own plane (along the wall, and up): everything that goes right through it is cut in 2D and the result
// is extruded once. That renders in seconds, where cutting a lattice out of a solid takes minutes.
module from_yz() { rotate([90, 0, 90]) children(); }                    // a drawing in (y, z) stood up, its thickness along +X
module to_yz()   { rotate([-90, 0, 0]) rotate([0, 0, -90]) children(); }
module from_xz() { rotate([90, 0, 0]) children(); }                     // a drawing in (x, z) stood up, its thickness along -Y
module to_xz()   { rotate([-90, 0, 0]) children(); }
module lattice_2d(a0, a1, b0, b1) {      // what a vent removes from the rectangle a0..a1 x b0..b1
  ca = (a0+a1)/2;  cb = (b0+b1)/2;  r = (a1-a0 + b1-b0)/2 + bar_p;
  if (vents) offset(r = 1, $fn = 16) offset(delta = -1) difference() {  // no slivers, and the holes' corners rounded
    translate([a0, b0]) square([a1-a0, b1-b0]);
    translate([ca, cb]) for (t = [45, -45]) rotate(t) for (u = [-r : bar_p : r]) translate([-r, u - bar_w/2]) square([2*r, bar_w]);
  }
}
ya = yi0 + core - slot_d + 0.3;  yb = yi1 - core + slot_d - 0.3;       // a short wall's two ends, inside the corner posts
xa = xi0 + core - slot_d + 0.3;  xb2 = xi1 - core + slot_d - 0.3;      // a long wall's
vz0 = skirt_h + 2;  vz1 = panel_h - skirt_h - 2;                       // vents stay between the two rims
module wall_holes() { all_post_screws("through");  rim_screws("insert"); }       // what the fasteners need through a panel
// Children, all 2D: (0) the vents, which are kept 11 mm from the panel's ends and between the rims; (1) its other openings;
// (2) what stays solid inside a vent.
module panel_yz(x0, x1, y0, y1) {       // thin in X, drawn in (y, z)
  translate([x0, 0, 0]) from_yz() linear_extrude(x1 - x0) difference() {
    translate([y0, 0]) square([y1 - y0, panel_h]);
    difference() { intersection() { translate([y0+11, vz0]) square([y1-y0-22, vz1-vz0]); children(0); }  if ($children > 2) children(2); }
    if ($children > 1) children(1);
    projection() to_yz() intersection() { box(x0-0.5, x1+0.5, y0, y1, 0, panel_h); wall_holes(); }
  }
}
module panel_xz(x0, x1, y0, y1) {       // thin in Y, drawn in (x, z)
  translate([0, y1, 0]) from_xz() linear_extrude(y1 - y0) difference() {
    translate([x0, 0]) square([x1 - x0, panel_h]);
    difference() { intersection() { translate([x0+11, vz0]) square([x1-x0-22, vz1-vz0]); children(0); }  if ($children > 2) children(2); }
    if ($children > 1) children(1);
    projection() to_xz() intersection() { box(x0, x1, y0-0.5, y1+0.5, 0, panel_h); wall_holes(); }
  }
}
// rear wall: USB-C, the card's display ports, the laptop cable's notch, vents, and the boss that is screwed to the bracket holder
tie_tip = hx0 - 0.5;                                        // the boss stops 0.5 short of the holder's back face
tie_travel = 2;                                             // the holder hangs from the card's tab: its screw gets this much up and down
module tie_2d(d, below = 0) { hull() for (dz = [-tie_travel - below, tie_travel]) translate([wall_tie[0], wall_tie[1]+dz]) circle(d = d, $fn = 40); }
module rear_vents() {
  lattice_2d(psu_y0+4, psu_y1-4, vz0, vz1);                                         // the cable bay breathes
  lattice_2d(psu_y1+6, -6, 32, vz1);                                                // over the 24-pin plug
  lattice_2d(2, 36, tab_z+4, vz1);                                                  // above the bracket's tab
  lattice_2d(44, 74, 36, vz1);                                                      // beside the ports, above the cable
}
module rear_openings() {
  translate([usbc_y[0]-3.5, zb-3]) square([usbc_y[1]-usbc_y[0]+7, 12]);             // USB-C
  translate([bracket_y0-1.5, zb+6]) square([ports_y1-bracket_y0+3, tab_z-4.5-zb-6]);   // the card's display ports, up to just under the tab
  translate([xg_exit_y[0], -1]) square([xg_exit_y[1]-xg_exit_y[0], 28]);            // laptop-cable notch, open at the bottom: the panel drops over the routed cable
}
module panel_rear() {
  difference() {
    union() {
      panel_yz(xo0, xi0, ya, yb) { rear_vents();  rear_openings();  tie_2d(20); }    // a solid island in the lattice around ...
      translate([xo0, 0, 0]) from_yz() linear_extrude(tie_tip - xo0) tie_2d(9.4);    // ... the boss that reaches in to the bracket holder
    }
    translate([xo0-1, 0, 0]) from_yz() linear_extrude(tie_tip - 4.3 - xo0 + 1) tie_2d(6.2);    // well for the head of an M3x10
    translate([xo0, 0, 0]) from_yz() linear_extrude(tie_tip - xo0 + 1) tie_2d(3.6);            // its slot
    translate([tie_tip-1.3, 0, 0]) from_yz() linear_extrude(3) tie_2d(5.8, 14);      // relief for the insert in the holder's back, which may stand 1 mm proud.
  }                                                                                  // Open downward: the panel is slid down past that insert
}
// far wall: the PSU is screwed to it, like in a PC case. Its rear face shows through an opening that leaves an ear around each screw.
// Screw pattern of an ATX (PS/2) supply, u along its 150 mm width and v along its 86 mm height, plus the same pattern turned half a
// turn, so that it fits whichever way up the supply turns out to be. CHECK IT AGAINST THE REAL SUPPLY BEFORE PRINTING THIS PANEL.
psu_holes = [[6, 16], [6, 80], [120, 80], [144, 6], [144, 70], [30, 6]];
function psu_hole_yz(h) = [psu_y0 + h[1], h[0]];             // the supply stands on its side: fan face (v = 0) toward the outer wall, width up
module psu_ears_2d() { for (h = psu_holes) let(p = psu_hole_yz(h)) translate([p[0]-7, p[1]-7]) square(14); }
module psu_face_2d() { difference() { translate([psu_y0+3, 6]) square([psu_h-6, psu_w-12]); psu_ears_2d(); } }      // inlet, switch, exhaust grille: all but the ears
module far_vents() {
  lattice_2d(6, 74, vz0, vz1);                                                      // GPU exhaust
  lattice_2d(psu_y1+8, -6, vz0, vz1);                                               // and the gap between card and supply
}
module far_openings() { psu_face_2d();  for (h = psu_holes) translate(psu_hole_yz(h)) circle(d = 4.0, $fn = 24); }   // 6-32 screws
module panel_far() {
  difference() {
    panel_yz(xi1, xo1, ya, yb) { far_vents();  far_openings(); }
    for (h = psu_holes) let(p = psu_hole_yz(h)) {
      translate([xi1+1.5, p[0], p[1]]) rotate([0, 90, 0]) cylinder(d = 10, h = wall, $fn = 40);     // heads sunk: a PSU screw is only 6 mm long
      translate([xi1+1.3, p[0]-2, p[1]-5]) cube([0.2+eps, 4, 10]);                                   // the pocket's roof prints as two bridges, then two more
      translate([xi1+1.1, p[0]-2, p[1]-2]) cube([0.2+eps, 4, 4]);                                    // across them: no support needed (outer face on the bed)
    }
  }
}
module psu_access_zone() { translate([psu_x1, 0, 0]) from_yz() linear_extrude(xo1 + 25 - psu_x1) offset(delta = -0.05) psu_face_2d(); }   // a hair inside the opening, so that the two never share a face
xm0 = x_mid - mid_web/2 - 0.3;  xm1 = x_mid + mid_web/2 + 0.3;                       // the two ends that meet inside a mid post
module left_vents()  { lattice_2d(12, xm0-11, vz0, psu_w-4);  lattice_2d(xm1+11, 244, vz0, psu_w-4); }        // cable bay and PSU intake
module right_vents() { lattice_2d(12, xm0-11, vz0, card_top+14);  lattice_2d(xm1+11, 244, vz0, card_top+14); }  // GPU intake
module panel_left_r()  { panel_xz(xa, xm0, yo0, yi0) left_vents(); }
module panel_left_f()  { panel_xz(xm1, xb2, yo0, yi0) left_vents(); }
module panel_right_r() { panel_xz(xa, xm0, yi1, yo1) right_vents(); }
module panel_right_f() { panel_xz(xm1, xb2, yi1, yo1) right_vents(); }
module panels() { panel_rear(); panel_far(); panel_left_r(); panel_left_f(); panel_right_r(); panel_right_f(); }

/* ================= the rims: what the panels stand between, on the floor and under the lid ================= */
// Outside, a rim as tall as skirt_h that the panel is screwed to. Inside, a low lip that only guides it. Both stop at the posts.
// g: how far the rim is cut back from the groove, for the lead-in at its free edge.
module rim_outer_2d(g = 0) {
  difference() {
    translate([xp0, yp0]) square([xp1-xp0, yp1-yp0]);
    translate([xo0-slot_fit/2-g, yo0-slot_fit/2-g]) square([xo1-xo0+slot_fit+2*g, yo1-yo0+slot_fit+2*g]);
    post_footprints(0.3);
  }
}
module rim_inner_2d(g = 0) {
  difference() {
    translate([xi0+slot_fit/2+g, yi0+slot_fit/2+g]) square([xi1-xi0-slot_fit-2*g, yi1-yi0-slot_fit-2*g]);
    translate([xi0+slot_fit/2+1.6, yi0+slot_fit/2+1.6]) square([xi1-xi0-slot_fit-3.2, yi1-yi0-slot_fit-3.2]);
    post_footprints(0.3);
  }
}
// A rim as a solid, standing on z = 0 and h tall. Its last 1.2 mm widen the groove in three steps: six panels have to find it at once.
// The child is the rim's plan, drawn with $g as its cut-back.
module rim_solid(h) {
  linear_extrude(h - 1.2) let($g = 0) children();
  for (i = [1:3]) translate([0, 0, h - (4-i)*0.4 - eps]) linear_extrude(0.4 + eps) let($g = i*0.4) children();
}

/* ================= base ================= */
// A closed sandwich: a 2 mm sole, a grid of rails standing on it, and the floor plate bolted down on top. With both skins working it
// is 24 mm deep everywhere. Printed sole down, rails up: no bridges except the 5.7 mm roofs of the nut slots.
cross_x = [28, 117, x_mid, 206];                      // rails across the box: under the board's three rows of screws, and under the handle
seam_w = 18;                                          // ... and a wider one under the floor's seam (x_floor_seam), for a row of screws on each side of it
long_y = [-44];                                       // a rail along it, under the PSU's inner edge. (The two long rims are the others.)
nut_z = zf - 4.5;                                     // an M3 nut's centre below the plate: a 12 mm countersunk screw ends just under it
foot_nut_z = zr + 5.5;                                // ... and above the base's underside, for the screw that comes up through a foot
// Every joint between plate and base: [x, y, the direction its nut slides in from]. A countersunk M3x12 from above, a nut in a slot.
// No joint sits where two rails cross (its nut could not be slid in), in the base's splice, or under anything that stands on the floor.
function plate_screws() = concat(
  [for (x = [40, 95, 195, 240]) [x, yp0+14, [0, 1]]],                                               // along the PSU-side rim
  [for (x = [54, 95, 195, 240]) [x, yp1-14, [0, -1]]],                                              // along the fan-side rim (54: clear of the grommet clip)
  [for (y = [-110, -75, -20, 48]) [xp0+14, y, [1, 0]]],                                             // along the rear rim
  [for (y = [-110, -75, -20, 44]) [xp1-14, y, [-1, 0]]],                                            // along the far rim
  [for (y = [-110, -20]) each [[28, y, [1, 0]], [117, y, [1, 0]], [206, y, [-1, 0]]]],
  [for (y = [-110, -75, -20, 20, 60]) [x_mid, y, [-1, 0]]],                                         // the keel under the handle
  bed == "256" ? [for (y = [-110, -75, -20, 20, 60]) each [[x_floor_seam-5, y, [-1, 0]], [x_floor_seam+5, y, [1, 0]]]]   // a row for each piece of the floor
               : [for (y = [-110, -75, -20, 20, 60]) [x_floor_seam, y, [1, 0]]],
  [for (x = [94, 160]) [x, long_y[0], [0, 1]]]);
board_nut_dir = [[1, 0], [1, 0], [1, 0], [-1, 0], [-1, 0]];      // which way each of the board's five nuts slides in
module nut_slot(dir, z = nut_z) {      // an M3 hex nut, 5.5 across flats and 2.4 thick, pushed in sideways until it sits on the screw's axis
  a = atan2(dir[1], dir[0]);
  rotate([0, 0, a]) translate([-2.9, -2.85, z-1.35]) cube([2.9 + 30, 5.7, 2.7]);
}
module frame_plan() {
  difference() { translate([xp0, yp0]) square([xp1-xp0, yp1-yp0]);
                 translate([xp0+rim_w, yp0+rim_w]) square([xp1-xp0-2*rim_w, yp1-yp0-2*rim_w]); }
  for (x = cross_x) translate([x-rail_w/2, yp0+1]) square([rail_w, yp1-yp0-2]);
  translate([x_floor_seam-seam_w/2, yp0+1]) square([seam_w, yp1-yp0-2]);
  for (y = long_y) translate([xp0+1, y-rail_w/2]) square([xp1-xp0-2, rail_w]);
}
module frame_full() {
  difference() {
    union() {
      translate([0, 0, zr]) linear_extrude(base_h) frame_plan();
      box(xp0, xp1, yp0, yp1, zr, zr + sole);                                          // the sole closes every cell from below
    }
    for (s = plate_screws()) translate([s[0], s[1], 0]) {                              // plate joints
      translate([0, 0, zf-13]) cylinder(d = 3.4, h = 14, $fn = 24);
      intersection() { nut_slot(s[2]); translate([-16, -16, zr]) cube([32, 32, base_h]); }
    }
    for (i = [0:4]) translate([holes[i][0], holes[i][1], 0]) {                         // the board's five bolts end in the base too
      translate([0, 0, zf-13]) cylinder(d = 3.4, h = 14, $fn = 24);
      intersection() { nut_slot(board_nut_dir[i]); translate([-16, -16, zr]) cube([32, 32, base_h]); }
    }
    for (r = rods()) translate([r[0], r[1], zr-1]) { cylinder(d = rod_hole, h = base_h+2, $fn = 32); cylinder(d = 9.6, h = 1 + 0.9, $fn = 40); }   // a rod, and a recess for the washer over its nut
    for (f = foot_screws()) translate([f[0][0], f[0][1], 0]) {                         // the screws that hold the feet, from below
      translate([0, 0, zr-1]) cylinder(d = 3.4, h = 1 + 9.5, $fn = 24);
      intersection() { nut_slot(f[1], foot_nut_z); translate([-16, -16, zr]) cube([32, 32, base_h]); }
    }
    if (bed == "256") frame_splice("bolts");
  }
}
// bed "256": the base in two pieces. Where the seam crosses a rail that runs along the box, each piece keeps half the rail's width
// for 30 mm, and two bolts go through both halves. The floor plate above lies unbroken over all of it.
frame_lines = concat([[yp0+rim_w/2, rim_w], [yp1-rim_w/2, rim_w]], [for (y = long_y) [y, rail_w]]);   // [centre, width] of each rail the seam crosses
module frame_region_a() {      // in plan: what belongs to the rear piece
  translate([xp0-1, yp0-1]) square([x_frame_seam-15-xp0+1, yp1-yp0+2]);
  for (l = frame_lines) translate([x_frame_seam-15-eps, l[0]-l[1]/2-1]) square([30, l[1]/2+1-0.1]);
}
module frame_splice(what) {
  for (l = frame_lines) for (x = [x_frame_seam-7, x_frame_seam+7]) translate([x, l[0], zr+sole+(base_h-sole)/2]) rotate([-90, 0, 0]) {
    if (what == "bolts") { cylinder(d = 3.4, h = l[1]+2, center = true, $fn = 24);
                           translate([0, 0, l[1]/2-3]) cylinder(d = 6.2, h = 4, $fn = 30);          // head and nut sink 3 mm into the two faces
                           translate([0, 0, -l[1]/2-1]) cylinder(d = 6.6, h = 4, $fn = 6); }
  }
}
module frame_a() { intersection() { frame_full(); translate([0, 0, zr-1]) linear_extrude(base_h+2) frame_region_a(); } }
module frame_b() { difference() { frame_full(); translate([0, 0, zr-1]) linear_extrude(base_h+2) offset(delta = 0.15) frame_region_a(); } }

/* ================= floor plate ================= */
// The PSU is set down 6 mm short of the far wall and pushed home, so that its switch and inlet enter the wall's opening sideways.
// It ends up screwed to that wall, between two side guides; a spacer dropped in behind it then fills the gap to a bar on the floor.
psu_slack = 6;
psu_bar = [psu_x0 - psu_slack - 3.5, psu_x0 - psu_slack - 0.5];
module psu_guides() {
  for (x = [psu_x0+2, psu_x0+110]) box(x, x+16, psu_y1+0.3, psu_y1+2.3, 0, 6);
  box(psu_bar[0], psu_bar[1], psu_y0+6, psu_y1-6, 0, 6);
}
module psu_spacer() {      // a separate part. Two hooks go round the ends of the bar. 6 high like the bar: the cables pass over it
  y0 = psu_y0 + 6;  y1 = psu_y1 - 6;  x0 = psu_bar[1] + 0.2;  x1 = psu_x0 - 0.2;
  box(x0, x1, y0-2.3, y1+2.3, 0, 6);
  for (e = [[y0-2.3, y0-0.3, y0+3], [y1+0.3, y1+2.3, y1-3]]) {
    box(psu_bar[0]-2.3, x0+eps, e[0], e[1], 0, 6);                                       // round the end of the bar
    box(psu_bar[0]-2.3, psu_bar[0]-0.3, min(e[0], e[2]), max(e[1], e[2]), 0, 6);         // and 3 mm along its back
  }
}
module tie_arch() { box(0, 1.8, 0, 6, 0, 4);  box(8, 9.8, 0, 6, 0, 4);  box(0, 9.8, 0, 6, 2.4, 4); }     // a cable tie passes under it; its roof is a 6 mm bridge
module floor_rims() {      // the groove the walls stand in
  difference() {
    union() { rim_solid(skirt_h) rim_outer_2d($g);  rim_solid(lip_h) rim_inner_2d($g); }
    box(xp0-1, xi0+3, xg_exit_y[0]-0.5, xg_exit_y[1]+0.5, -1, skirt_h+1);                // open where the laptop cable leaves
    box(xp0-1, xi0+1, usbc_y[0]-3.5, usbc_y[1]+3.5, zb-3, skirt_h+1);                    // and in front of the USB-C socket
    box(xi1-3, xp1+1, psu_y0-1, psu_y1+3, -1, skirt_h+1);                                // nothing stands in front of the PSU's rear face
    rim_screws("through");  rim_screws("sink");
  }
}
module floor_full() {
  difference() {
    union() {
      box(xp0, xp1, yp0, yp1, zf, 0);
      translate([0, 0, -eps]) floor_rims();
      for (h = holes) translate([h[0], h[1], 0]) cylinder(d = 9, h = standoff - 0.05);     // the board's five bosses
      translate([grommet_x, grommet_y, 0]) grommet_clip();
      psu_guides();
      for (x = [45, 66]) for (y = [psu_y0+20, psu_y0+55]) translate([x, y, 0]) tie_arch();   // four places to tie the spare cable down in the bay
    }
    for (s = plate_screws()) translate([s[0], s[1], 0]) { translate([0, 0, zf-1]) cylinder(d = 3.4, h = floor_t+2, $fn = 24); translate([0, 0, -1.7]) cylinder(d1 = 3.4, d2 = 6.6, h = 1.7+eps, $fn = 32); }
    for (h = holes) translate([h[0], h[1], zf-1]) cylinder(d = 3.4, h = floor_t + standoff + 2, $fn = 24);                // bolts right through boss and plate
    for (r = rods()) translate([r[0], r[1], zf-1]) cylinder(d = rod_hole, h = floor_t+2, $fn = 32);
    cradle_peg_centres() translate([-(peg+peg_fit)/2, -(peg+peg_fit)/2, -3]) cube([peg+peg_fit, peg+peg_fit, 4]);          // sockets for the cradle, as in v1
    box(foot_slot_x-2.7, foot_slot_x+2.7, 16, board_w+1, -2, 1);                                                        // pocket for the tip of the bracket's foot
    for (y = holder_holes_y) box(holder_hole_x-1.5, holder_hole_x+1.5, y-2, y+2, -2.6, 1);                              // sockets for the holder's pegs
  }
}
module floor_a() { intersection() { floor_full(); box(xp0-1, x_floor_seam-0.1, yp0-1, yp1+1, zf-1, 60); } }
module floor_b() { intersection() { floor_full(); box(x_floor_seam+0.1, xp1+1, yp0-1, yp1+1, zf-1, 60); } }

/* ================= lid ================= */
// Printed upside down: rims, ribs and the two PSU pads point up off the bed. The ribs keep out of the room over the card that its
// 8-pin plug needs. Built as a plate drawn in 2D with its vents, and the rest added under it.
lid_rib = 8;
hold_x = [psu_x0 + 18, psu_x1 - 30];  hold_y = (psu_y0 + psu_y1)/2;     // two pads over the PSU: with the lid on it cannot lift off the floor
hold_gap = 1.0;                                                        // ... less a 1 mm felt pad stuck on each
lid_seam_y = [-110, -62, -14, 34, 68];                                 // bed "256": the bolts through the two flanges of its seam
module lid_ribs_2d() {
  difference() {
    union() {
      for (y = [-95, -40]) translate([xi0+3, y-1.5]) square([xi1-xi0-6, 3]);
      for (x = [40, 95]) translate([x-1.5, yi0+3]) square([3, yi1-yi0-6]);
      translate([200-1.5, yi0+3]) square([3, card_y0-4-yi0-3]);                         // stops short of the card
    }
    post_footprints(1);
    for (r = rods()) translate([r[0], r[1]]) circle(d = 12);
  }
}
module lid_plate_2d() {
  difference() {
    translate([xp0, yp0]) square([xp1-xp0, yp1-yp0]);
    for (w = [[12, 37], [43, 92], [98, x_lid_seam-9], [x_mid+17, 244]]) lattice_2d(w[0], w[1], 10, 80);   // over the card: clear of the handle and of the seam, and solid under the two ribs
    for (r = rods()) translate([r[0], r[1]]) circle(d = rod_hole + 0.8, $fn = 32);      // easy holes: six rods meet them at once
  }
}
module lid_under() {       // everything that hangs under the plate
  difference() {
    translate([0, 0, zi1+eps]) mirror([0, 0, 1]) { rim_solid(skirt_h+eps) rim_outer_2d($g);  rim_solid(lip_h+eps) rim_inner_2d($g); }
    rim_screws("through");  rim_screws("sink");
  }
  translate([0, 0, zi1-lid_rib]) linear_extrude(lid_rib+eps) lid_ribs_2d();
  for (x = hold_x) translate([x, hold_y, psu_w + hold_gap]) cylinder(d1 = 14, d2 = 20, h = zi1 - psu_w - hold_gap + eps, $fn = 48);
  if (bed == "256") difference() {
    for (s = [-1, 1]) box(x_lid_seam + (s < 0 ? -4.1 : 0.1), x_lid_seam + (s < 0 ? -0.1 : 4.1), yi0+14, yi1-14, zi1-12, zi1+eps);
    for (y = lid_seam_y) translate([x_lid_seam, y, zi1-6.5]) rotate([0, 90, 0]) cylinder(d = 3.4, h = 12, center = true, $fn = 24);
  }
}
module lid_piece(x0, x1) {
  translate([0, 0, zi1]) linear_extrude(lid_t) intersection() { lid_plate_2d(); translate([x0, yp0-1]) square([x1-x0, yp1-yp0+2]); }
  intersection() { lid_under(); box(x0, x1, yp0-1, yp1+1, 0, zt); }
}
module lid_full() { lid_piece(xp0-1, xp1+1); }
module lid_a() { lid_piece(xp0-1, x_lid_seam-0.1); }
module lid_b() { lid_piece(x_lid_seam+0.1, xp1+1); }

/* ================= carrying handle ================= */
// A beam on the lid from one long wall's mid post to the other's. The two rods of those posts come up through its ends, and the nuts
// that close the case there sit on it. Printed on its side, so that the layers run along the load.
handle_w = 20;
handle_grip = [-88, 16];        // the opening for the fingers, 104 long: its middle is where the loaded box balances (tools/balance.py)
handle_base = 10;  handle_room = 30;  handle_bar = 12;
module handle_profile() {       // y across the box, z above the lid's top face
  up = handle_bar;  h = handle_base + handle_room + handle_bar;  g0 = handle_grip[0];  g1 = handle_grip[1];
  pa = yi0 + core + 4;  pb = yi1 - core - 4;
  difference() {
    offset(r = -6) offset(delta = 6) union() {
      translate([yp0, 0]) square([yp1 - yp0, handle_base]);
      hull() { translate([g0 - up, 0]) square([g1 - g0 + 2*up, handle_base]); for (y = [g0, g1]) translate([y, h - 12]) circle(r = 12, $fn = 64); }
      polygon([[pa, 0], [g0 - up, 0], [g0 - up, 24], [pa, handle_base]]);                // the beam deepens toward each upright
      polygon([[pb, 0], [g1 + up, 0], [g1 + up, 28], [pb, handle_base]]);
    }
    hull() for (y = [g0 + 8, g1 - 8]) for (z = [handle_base + 8, handle_base + handle_room - 8]) translate([y, z]) circle(r = 8, $fn = 48);
  }
}
module handle() {
  n = 5;  st = 0.4;                                            // 2 mm chamfers on both faces, in steps of two layers
  difference() {
    translate([x_mid - handle_w/2, 0, zt]) rotate([90, 0, 90]) {
      translate([0, 0, n*st]) linear_extrude(handle_w - 2*n*st) handle_profile();
      for (i = [0 : n-1]) for (s = [0, 1]) translate([0, 0, s ? handle_w - n*st + i*st - eps : (n-1-i)*st]) linear_extrude(st + eps) offset(delta = -(i+1)*st) handle_profile();
    }
    for (i = [4, 5]) translate([rods()[i][0], rods()[i][1], zt]) {
      translate([0, 0, -1]) cylinder(d = rod_hole, h = 60, $fn = 32);
      translate([0, 0, handle_base - 2]) cylinder(d = 10.8, h = 60, $fn = 40);            // a seat for the washer and the springs under the nut
    }
  }
}

/* ================= feet ================= */
// Each rod ends in a nut held in the top of a foot: the foot keeps it from turning, a washer in a recess of the base takes its pull.
// So a foot is the bottom anchor of a tie rod as well as what the case stands on. One screw from below holds each foot to the base
// (two for the mid feet). The corner feet stand 4 mm beyond the outline: bumpers.
foot_c = [-wall-edge-4, 20];                                   // a corner foot's extent on both axes, in the post's frame
module foot_body(x0, x1, y0, y1) { hull() { box(x0+2, x1-2, y0+2, y1-2, zr-foot_h, zr); box(x0, x1, y0, y1, zr-foot_h+2, zr); } }
foot_sink = 3;             // the head of the screw that holds a foot sits this far up inside it: an M3x16 then ends just past its nut
module foot_fix(p) { translate([p[0], p[1], zr-foot_h-1]) {
  cylinder(d = 3.4, h = foot_h+2, $fn = 24);  cylinder(d = 6.6, h = 1 + foot_sink, $fn = 32);  translate([0, 0, 1 + foot_sink - eps]) cylinder(d1 = 6.6, d2 = 3.4, h = 1.7, $fn = 32); } }
module foot_rod(p) { translate([p[0], p[1], 0]) {
  translate([0, 0, zr-foot_h+2]) cylinder(d = rod_hole, h = foot_h, $fn = 32);                  // the rod's end
  translate([0, 0, zr-3.5]) cylinder(d = 8.3, h = 3.5+eps, $fn = 6);                            // its M4 nut, dropped in from the top
  translate([0, 0, zr-foot_h-eps]) cylinder(d = 13, h = 0.6, $fn = 48); } }                     // a stick-on rubber pad, right under the rod
module foot_corner_local() { difference() { foot_body(foot_c[0], foot_c[1], foot_c[0], foot_c[1]); foot_rod([rc, rc]); foot_fix(foot_screw_c); } }
module foot_mid_local() { difference() { foot_body(-wall-edge, 16, -22, 22); foot_rod([core/2, 0]); for (p = foot_screw_m) foot_fix(p); } }
module feet() { for (i = [0:3]) at_corner(i) foot_corner_local(); for (i = [0:1]) at_mid(i) foot_mid_local(); }

/* ================= fasteners, for the pictures and for the collision test ================= */
module rods_drawn() {
  color("#b8b8b8") for (i = [0:5]) let(r = rods()[i], seat = i < 4 ? zt : zt + handle_base - 2) translate([r[0], r[1], 0]) {
    translate([0, 0, zr-foot_h+3]) cylinder(d = 4, h = seat + 9.5 - (zr-foot_h+3), $fn = 16);
    translate([0, 0, seat]) { cylinder(d = 9, h = 0.8, $fn = 24);                                                         // washer
                              for (k = [0:3]) translate([0, 0, 0.8 + k*0.75]) cylinder(d1 = k % 2 ? 5.4 : 10, d2 = k % 2 ? 10 : 5.4, h = 0.75, $fn = 24);   // four disc springs
                              translate([0, 0, 3.8]) cylinder(d = 8.1, h = 3.2, $fn = 6); }                               // nut
    translate([0, 0, zr+0.05]) cylinder(d = 9, h = 0.8, $fn = 24);
    translate([0, 0, zr-3.3]) cylinder(d = 8.1, h = 3.2, $fn = 6);
  }
}
module plate_screws_drawn() {
  color("#d8402c") {
    for (s = plate_screws()) translate([s[0], s[1], 0]) { translate([0, 0, -1.6]) cylinder(d1 = 3, d2 = 6, h = 1.6, $fn = 24); translate([0, 0, -12]) cylinder(d = 3, h = 12, $fn = 16); }
    for (h = holes) translate([h[0], h[1], zb]) { cylinder(d = 5.5, h = 3, $fn = 24); translate([0, 0, -20]) cylinder(d = 3, h = 20, $fn = 16); }
    for (f = foot_screws()) translate([f[0][0], f[0][1], zr-foot_h+foot_sink]) { cylinder(d1 = 6, d2 = 3, h = 1.6, $fn = 24); cylinder(d = 3, h = 16, $fn = 16); }
  }
  color("#d9a520") { for (s = plate_screws()) translate([s[0], s[1], nut_z-1.2]) cylinder(d = 6.2, h = 2.4, $fn = 6); for (h = holes) translate([h[0], h[1], nut_z-1.2]) cylinder(d = 6.2, h = 2.4, $fn = 6); }
  all_post_screws("screw");  rim_screws("screw");
}
module inside_extras() {       // what stands proud inside the box and is not part of a printed part: the board's bolt heads, and the rims' inserts and screw ends
  for (h = holes) translate([h[0], h[1], zb+0.05]) cylinder(d = 5.5, h = 3, $fn = 24);
  rim_screws("tip");
}

/* ================= a test piece ================= */
// Three slices of the real parts, to try the fits that v1 never tested before printing sixty hours of them: a nut in its slot in a
// post, a panel's end in the post's slot with its screw, an insert in a 5 mm panel, the panel in the floor's groove with its rim screw,
// an M4 rod through the post, and a patch of lattice.
module coupon() {
  translate([0, 0, -24]) intersection() { corner_post_local(); translate([-20, -20, 24]) cube([40, 40, 24]); }
  translate([16 - xa, -14, 0]) flat_xz(yo0, -1) intersection() { panel_left_r(); box(xa-1, xa+46, yo0-1, yi0+1, -1, 52); }
  translate([16 - 8, 14 - yp0, floor_t]) intersection() { floor_full(); box(8, 52, yp0-1, yi0+9, zf-1, skirt_h+1); }
}

/* ================= assembly ================= */
module frame()  { if (bed == "256") { frame_a(); frame_b(); } else frame_full(); }
module floor_()  { if (bed == "256") { floor_a(); floor_b(); } else floor_full(); }
module lid()    { if (bed == "256") { lid_a(); lid_b(); } else lid_full(); }
module structure() { frame(); floor_(); posts(); panels(); lid(); handle(); feet(); cradle(); bracket_holder(); psu_spacer(); }
module zones()       { ghost_zones(xo0, xo1, false, false); color("orange", 0.25) psu_access_zone(); }
module ghosts()      { ghost_board(); ghost_card_detail(); ghost_psu(); zones(); }
module ghosts_hard() { ghost_board(); ghost_card(); ghost_psu(); zones(); }
module collision() { intersection() { union() { structure(); inside_extras(); } ghosts_hard(); } }
module assembly() {
  color("#3a4a63") frame();  color("#4a6fa5") floor_();  color("#2f4f7f") posts();  color("#9dbbe0", 0.85) panels();
  color("#7fa3d1", 0.85) lid();  color("#e9a23b") { handle(); feet(); }  color("#2e4a7a") { cradle(); bracket_holder(); psu_spacer(); }
  rods_drawn();  plate_screws_drawn();  ghosts();
}
module flat_yz(x0, out = 1) { rotate([0, 90*out, 0]) translate([out > 0 ? -x0 - wall : -x0, 0, 0]) children(); }   // a wall panel on its outer face
module flat_xz(y0, out = 1) { rotate([-90*out, 0, 0]) translate([0, out > 0 ? -y0 - wall : -y0, 0]) children(); }
module M() { mirror([0, MIRROR ? 1 : 0, 0]) children(); }
n_rim = len(sk_rear[0]) + len(sk_rear[1]) + len(sk_far[0]) + len(sk_far[1]) + 2*len(sk_long[0]) + 2*len(sk_long[1]);
echo(str("fasteners bed ", bed, ": plate ", len(plate_screws()), ", board ", len(holes), ", posts ", 4*len(screw_za) + 4*len(screw_zb) + 4*len(screw_za),
         ", feet ", len(foot_screws()), ", rims ", n_rim, ", rods ", len(rods()), bed == "256" ? str(", base splice ", 2*len(frame_lines), ", lid seam 5") : ""));

M() {
if (part == "assembly") assembly();
else if (part == "structure") structure();
else if (part == "collision") collision();
else if (part == "ghosts") ghosts_hard();
else if (part == "none") {}
// in place, for viewers and for the checks
else if (part == "asm_frame") frame();
else if (part == "asm_frame_a") frame_a();
else if (part == "asm_frame_b") frame_b();
else if (part == "asm_floor") floor_();
else if (part == "asm_floor_a") floor_a();
else if (part == "asm_floor_b") floor_b();
else if (part == "asm_lid") lid();
else if (part == "asm_lid_a") lid_a();
else if (part == "asm_lid_b") lid_b();
else if (part == "asm_posts") posts();
else if (part == "asm_post_corner_0") at_corner(0) corner_post_local();
else if (part == "asm_post_corner_1") at_corner(1) corner_post_local();
else if (part == "asm_post_corner_2") at_corner(2) corner_post_local();
else if (part == "asm_post_corner_3") at_corner(3) corner_post_local();
else if (part == "asm_post_mid_0") at_mid(0) mid_post_local();
else if (part == "asm_post_mid_1") at_mid(1) mid_post_local();
else if (part == "asm_panel_rear") panel_rear();
else if (part == "asm_panel_far") panel_far();
else if (part == "asm_panel_left_r") panel_left_r();
else if (part == "asm_panel_left_f") panel_left_f();
else if (part == "asm_panel_right_r") panel_right_r();
else if (part == "asm_panel_right_f") panel_right_f();
else if (part == "asm_handle") handle();
else if (part == "asm_feet") feet();
else if (part == "asm_cradle") cradle();
else if (part == "asm_bracket_holder") bracket_holder();
else if (part == "asm_psu_spacer") psu_spacer();
else if (part == "asm_rods") rods_drawn();
else if (part == "asm_screws") plate_screws_drawn();
else if (part == "asm_board") ghost_board();
else if (part == "asm_card") ghost_card_detail();
else if (part == "asm_psu") ghost_psu();
else if (part == "asm_zones") zones();
// laid out for printing
else if (part == "frame")   translate([0, 0, -zr]) frame_full();
else if (part == "frame_a") translate([0, 0, -zr]) frame_a();
else if (part == "frame_b") translate([0, 0, -zr]) frame_b();
else if (part == "floor")   translate([0, 0, floor_t]) floor_full();
else if (part == "floor_a") translate([0, 0, floor_t]) floor_a();
else if (part == "floor_b") translate([0, 0, floor_t]) floor_b();
else if (part == "lid")   rotate([180, 0, 0]) translate([0, 0, -zt]) lid_full();
else if (part == "lid_a") rotate([180, 0, 0]) translate([0, 0, -zt]) lid_a();
else if (part == "lid_b") rotate([180, 0, 0]) translate([0, 0, -zt]) lid_b();
else if (part == "post_corner") corner_post_local();
else if (part == "post_mid") mid_post_local();
else if (part == "panel_rear")    flat_yz(xo0, -1) panel_rear();
else if (part == "panel_far")     flat_yz(xi1) panel_far();
else if (part == "panel_left_r")  flat_xz(yo0, -1) panel_left_r();
else if (part == "panel_left_f")  flat_xz(yo0, -1) panel_left_f();
else if (part == "panel_right_r") flat_xz(yi1) panel_right_r();
else if (part == "panel_right_f") flat_xz(yi1) panel_right_f();
else if (part == "handle") rotate([0, -90, 0]) translate([-(x_mid - handle_w/2), 0, -zt]) handle();
else if (part == "foot_corner") translate([0, 0, -(zr-foot_h)]) foot_corner_local();
else if (part == "foot_mid")    translate([0, 0, -(zr-foot_h)]) foot_mid_local();
else if (part == "bracket_holder") rotate([0, -90, 0]) translate([-hx0, 0, 0]) bracket_holder();
else if (part == "bracket_washer") bracket_washer();
else if (part == "psu_spacer") psu_spacer();
else if (part == "cradle") rotate([0, 90, 0]) translate([-card_x1, 0, 0]) cradle();
else if (part == "coupon") coupon();
else echo(str("unknown part: ", part));
}
