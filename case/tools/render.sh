#!/usr/bin/env bash
# Render every printable part of xgm-lite-frame.scad to build/stl/<part>.stl, laid out for the bed.
# Several OpenSCAD processes run side by side. A part that fails leaves its log in build/logs/.
# Usage: tools/render.sh [-j N] [part ...]
set -u
cd "$(dirname "$0")/.."
jobs=$(nproc)
if [ "${1:-}" = "-j" ]; then jobs=$2; shift 2; fi
parts=("$@")
if [ ${#parts[@]} -eq 0 ]; then
  parts=(floor_rl floor_rr floor_fl floor_fr lid_l lid_r lid_rl lid_rr lid_fl lid_fr post_corner post_mid bracket_holder bracket_washer shim_05 shim_10 shim_15
         panel_rear_l panel_rear_r panel_far_l panel_far_r panel_left_r panel_left_f panel_right_r panel_right_f
         cradle bridge_centre bridge_strap coupon coupon_rear coupon_grommet coupon_inserts)
fi
mkdir -p build/stl build/logs
printf '%s\n' "${parts[@]}" | xargs -P "$jobs" -I{} sh -c '
  start=$(date +%s)
  openscad -o "build/stl/{}.stl" -D "part=\"{}\"" xgm-lite-frame.scad >"build/logs/{}.log" 2>&1
  n=$(grep -c "facet normal" "build/stl/{}.stl" 2>/dev/null || true)
  if [ "${n:-0}" -gt 0 ] && python3 tools/normalize_stl.py "build/stl/{}.stl" >/dev/null; then
    rm -f "build/logs/{}.log"
    echo "{}: $(( $(date +%s) - start )) s, $n facets"
  else
    echo "{}: FAILED, see build/logs/{}.log"; exit 1
  fi'
status=$?
rmdir build/logs 2>/dev/null
exit $status
