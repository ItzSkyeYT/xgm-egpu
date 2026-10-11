#!/usr/bin/env python3
"""The hand calculations behind README.md, in one place, so that every figure quoted there can be checked and redone.
Beam and thin-wall formulas, not a simulation. PETG: E 2000 MPa, 45 MPa along the layers, 20 MPa across them.

usage: tools/numbers.py 350|256        (after tools/balance.py, whose loaded weight and balance point it uses)"""
import sys
sys.dont_write_bytecode = True
import json, math, os, re

HERE = os.path.dirname(os.path.abspath(__file__))
V2 = os.path.dirname(HERE)
bed = sys.argv[1] if len(sys.argv) > 1 else '350'
src = open(os.path.join(V2, 'xgm-v2.scad')).read() + open(os.path.join(V2, 'hardware.scad')).read()
def par(name):
    return float(re.search(rf'(?:^|;\s+){name} = (-?[\d.]+);', src, re.M).group(1))
bal = json.load(open(os.path.join(V2, 'build', bed, 'balance.json')))
E, G, S_IN, S_X = 2000.0, 741.0, 45.0, 20.0
kg = bal['loaded_kg'];  F = 3 * 9.81 * kg                      # design load: the loaded case at 3 g
print(f'loaded {kg:.2f} kg -> design load {F:.0f} N (3 g)')

# ---- interior and outline (from hardware.scad and the model's parameters)
wall, edge, core, sole, base_h, floor_t, lid_t = par('wall'), par('edge'), par('core'), par('sole'), par('base_h'), par('floor_t'), par('lid_t')
yi0, yi1 = -134.0 - 11, 65.0 + 24;  xi0, xi1 = -4.0, 13.7 + 240 + 3;  zi1 = 177.9
rod_y = (yi0 + core/2, yi1 - core/2);  span = rod_y[1] - rod_y[0]
g = [float(a) for a in re.search(r'^handle_grip = \[(-?[\d.]+), (-?[\d.]+)\];', src, re.M).groups()]
hand = (g[0] + g[1]) / 2

# ---- handle
print('\nhandle (printed on its side: every stress runs along the layers)')
bar_w, bar_h, L = par('handle_w'), par('handle_bar'), g[1] - g[0]
M = F * L / 12;  s = M / (bar_w * bar_h**2 / 6)
print(f'  grip bar {bar_w:.0f} x {bar_h:.0f}, {L:.0f} clear: {s:.1f} MPa, safety factor {S_IN / s:.0f}')
R = (F * (rod_y[1] - hand) / span, F * (hand - rod_y[0]) / span)
print(f'  pull on the two rods: {R[0]:.0f} N (PSU side), {R[1]:.0f} N (fan side)')
pb = yi1 - core - 4;  worst = 0
for y in [pb - 0.5 * k for k in range(0, 100)]:                 # along the haunch on the fan side, the longer arm
    if y < g[1] + bar_h: break
    d = par('handle_base') + (28 - par('handle_base')) * (pb - y) / (pb - (g[1] + bar_h))
    worst = max(worst, R[1] * (rod_y[1] - y) / (bar_w * d**2 / 6))
print(f'  beam between grip and rod: {worst:.1f} MPa at worst, safety factor {S_IN / worst:.0f}')

# ---- rods
print('\nrods (M4, class 4.8: stress area 8.78 mm2, yield 320 MPa)')
pre = 280.0
print(f'  preload {pre:.0f} N + lift {R[0]:.0f} N = {(pre + R[0]) / 8.78:.0f} MPa, safety factor {320 * 8.78 / (pre + R[0]):.1f}')
post_area = (wall + edge + core)**2 - 2 * (wall + 0.4) * 8 - math.pi * 2.3**2
print(f'  a corner post under that preload: {pre / post_area:.1f} MPa on {post_area:.0f} mm2')
Lc = base_h + floor_t + zi1 + lid_t;  k_rod = 200000 * 8.78 / Lc;  k_post = E * post_area / zi1
k_joint = 1 / (1 / k_rod + 1 / k_post);  k_spring = (329 / 0.19) / 4;  k_sprung = 1 / (1 / k_joint + 1 / k_spring)
dT = (60e-6 - 12e-6) * Lc
print(f'  plastic outgrows steel by {dT * 1000:.1f} um per K over {Lc:.0f} mm: preload changes {k_joint * dT:.0f} N/K without springs, {k_sprung * dT:.1f} N/K with four disc springs')
print(f'  0.2 mm of creep costs {min(pre, k_joint * 0.2):.0f} N without springs, {k_sprung * 0.2:.0f} N with them')

# ---- base
print('\nbase: floor plate, rails and sole as one section')
depth = floor_t + base_h;  rails = base_h - sole
na = (sole * sole / 2 + floor_t * (depth - floor_t / 2)) / (sole + floor_t)                    # skins only, per mm of width, from the underside
I = sole**3 / 12 + sole * (na - sole / 2)**2 + floor_t**3 / 12 + floor_t * (depth - floor_t / 2 - na)**2
print(f'  {depth:.0f} mm deep, skins {floor_t:.0f} and {sole:.0f}: I = {I:.0f} mm4 per mm of width ({I / (3**3 / 12):.0f} times a 3 mm plate, {I / (floor_t**3 / 12):.0f} times its own {floor_t:.0f} mm plate alone)')
psu, card = 3 * 9.81 * 1.65, 3 * 9.81 * 1.30                   # at 3 g; card with the board
a, b = -91 - rod_y[0], rod_y[1] - 30                            # PSU's and card's distance from the nearer rod
R1 = (psu * (span - a) + card * b) / span;  Mb = R1 * a
width = 100.0
print(f'  hung from the two handle rods, a strip {width:.0f} mm wide: sole {Mb * na / (I * width):.2f} MPa in tension along the layers')
for w, what in [(width, f'that {width:.0f} mm strip'), (xi1 - xi0 + 2 * (wall + edge), 'the whole width')]:
    d3 = (psu + card) * span**3 / (48 * E * I * w)
    print(f'  sag under PSU and card, {what}: {d3:.3f} mm at 3 g, {d3 / 3:.3f} mm at 1 g')
I1 = 3**3 / 12 * (xi1 - xi0 + 6)
print(f'  v1, same model, its 3 mm floor taken as one seamless plate: {(psu + card) / 3 * span**3 / (48 * E * I1):.1f} mm at 1 g')

# ---- walls
print('\nwalls')
bw, bp = par('bar_w'), par('bar_p')
gt_lat = E * bw * wall / (2 * bp);  gt_solid = G * wall
slot_bar = 12 * E * (3 * 3**3 / 12) / 20**3;  gt_v1 = slot_bar * 24 / 6
print(f'  lattice: G.t = {gt_lat:.0f} N/mm, {100 * gt_lat / gt_solid:.0f} % of the solid {wall:.0f} mm wall ({gt_solid:.0f}); open area {100 * ((bp - bw) / bp)**2:.0f} %')
print(f"  v1's slots in its 3 mm wall: G.t = {gt_v1:.0f} N/mm, {100 * gt_v1 / (G * 3):.1f} % of solid; open area {100 * 3 / 6 * 20 / 24:.0f} %")
print(f'  -> a vented field is {gt_lat / gt_v1:.0f} times stiffer in shear than in v1')
wy, wz = yi1 - yi0 + wall, zi1 + (floor_t + base_h) / 2 + lid_t / 2          # the closed cell seen along X
gt_wall = 1 / (0.45 / gt_solid + 0.55 / gt_lat);  gt_lid = 1 / (0.7 / (G * lid_t) + 0.3 / (E * bw * lid_t / (2 * bp)))
GJ = 4 * (wy * wz)**2 / (wy / (G * (floor_t + sole)) + wy / gt_lid + 2 * wz / gt_wall)
T = 60 * 250.0;  twist = T * (xi1 - xi0) / GJ
print(f'  box as one closed tube about its long axis (Bredt): GJ = {GJ:.2e} N.mm2')
print(f'  60 N on one corner: twist {math.degrees(twist):.3f} degrees, {twist * 250:.2f} mm at that corner, if no joint slips')
print(f'  rim screw in bearing: {3 * (edge - 0.2) * S_IN:.0f} N each;  rim at its root, in shear along the layers: {(edge - 0.2) * S_X / math.sqrt(3):.0f} N per mm')
print(f'  post screw in bearing on the panel: {3 * wall * S_IN:.0f} N each, three per panel end')
