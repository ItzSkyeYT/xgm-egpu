#!/usr/bin/env bash
# Proves that hardware.scad draws the same board, card, PSU and cable room as v1's model (../case/xgm-lite-frame.scad),
# with v2's two deliberate differences undone for the comparison: the PSU touching the far wall (v1: 1.9 short of it)
# and the walls' thickness. Run it after any change to hardware.scad.
# Usage: tools/check_hardware.sh
set -eu
cd "$(dirname "$0")/.."
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
cat > "$tmp/v2.scad" <<SCAD
include <$PWD/hardware.scad>
\$fn = 40;
mirror([0, 1, 0]) { ghost_board(); ghost_card(); ghost_psu(); ghost_zones(xi0 - 3, xi1 + 3); }
SCAD
openscad -o "$tmp/v1.stl" -D 'part="ghosts"' ../case/xgm-lite-frame.scad >/dev/null 2>&1
openscad -o "$tmp/v2.stl" -D psu_far_gap=1.9 "$tmp/v2.scad" >/dev/null 2>&1
python3 - "$tmp/v1.stl" "$tmp/v2.stl" <<'PY'
import re, sys
def load(p):
    v = [tuple(float(a) for a in m) for m in re.findall(r'vertex\s+(\S+)\s+(\S+)\s+(\S+)', open(p).read())]
    return [v[i:i+3] for i in range(0, len(v), 3)]
def volume(t):
    return abs(sum((a[0]*(b[1]*c[2]-b[2]*c[1]) - a[1]*(b[0]*c[2]-b[2]*c[0]) + a[2]*(b[0]*c[1]-b[1]*c[0])) / 6 for a, b, c in t))
def bbox(t):
    p = [q for f in t for q in f]
    return [(round(min(q[i] for q in p), 3), round(max(q[i] for q in p), 3)) for i in range(3)]
a, b = load(sys.argv[1]), load(sys.argv[2])
va, vb = volume(a), volume(b)
same = abs(va - vb) < 0.5 and bbox(a) == bbox(b)
print(f"v1 hardware: {va:.1f} mm3, box {bbox(a)}")
print(f"v2 hardware: {vb:.1f} mm3, box {bbox(b)}")
print("same hardware envelope" if same else "DIFFERENT: hardware.scad no longer matches v1")
sys.exit(0 if same else 1)
PY
