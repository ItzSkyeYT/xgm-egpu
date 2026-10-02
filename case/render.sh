#!/usr/bin/env bash
# Render every printable part of xgm-lite-frame.scad to stl/<part>.stl (runs several OpenSCAD processes in parallel).
# Usage: ./render.sh [-j N] [part ...]
set -u
cd "$(dirname "$0")"
jobs=4
if [ "${1:-}" = "-j" ]; then jobs=$2; shift 2; fi
parts=("$@")
if [ ${#parts[@]} -eq 0 ]; then
  parts=(floor_rl floor_rr floor_fl floor_fr lid_l lid_r lid_rl lid_rr lid_fl lid_fr post_corner post_mid bracket_holder shim_05 shim_10 shim_15
         panel_rear_l panel_rear_r panel_far_l panel_far_r panel_left_r panel_left_f panel_right_r panel_right_f
         cradle coupon coupon_rear)
fi
mkdir -p stl
printf '%s\n' "${parts[@]}" | xargs -P "$jobs" -I{} sh -c \
  'start=$(date +%s); openscad -o "stl/{}.stl" -D "part=\"{}\"" xgm-lite-frame.scad >"stl/{}.log" 2>&1; echo "{}: $(( $(date +%s) - start )) s, $(grep -c "facet normal" "stl/{}.stl" 2>/dev/null || echo 0) facets"'
