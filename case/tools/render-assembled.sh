#!/usr/bin/env bash
# Render every part where it sits in the case to build/assembled/<name>.stl, then pack them into one 3MF
# (xgm-lite-frame-assembled.3mf) where each part is a separate, named, coloured object you can hide in a viewer.
# A part that fails leaves its log in build/logs/.
# Usage: tools/render-assembled.sh [-j N]
set -u
cd "$(dirname "$0")/.."
jobs=$(nproc)
if [ "${1:-}" = "-j" ]; then jobs=$2; shift 2; fi
parts=(floor_rl floor_rr floor_fl floor_fr lid_l lid_r
       post_corner_rl post_corner_rr post_corner_fl post_corner_fr post_mid_rear post_mid_far post_mid_left post_mid_right
       panel_rear_l panel_rear_r panel_far_l panel_far_r panel_left_r panel_left_f panel_right_r panel_right_f
       cradle bracket_holder bracket_washer bridges board card psu zones screws inserts)
mkdir -p build/assembled build/logs
printf '%s\n' "${parts[@]}" | xargs -P "$jobs" -I{} sh -c '
  openscad -o "build/assembled/{}.stl" -D "part=\"asm_{}\"" xgm-lite-frame.scad >"build/logs/assembled-{}.log" 2>&1
  n=$(grep -c "facet normal" "build/assembled/{}.stl" 2>/dev/null || true)
  if [ "${n:-0}" -gt 0 ]; then
    rm -f "build/logs/assembled-{}.log"
    echo "{}: $n facets"
  else
    echo "{}: FAILED, see build/logs/assembled-{}.log"; exit 1
  fi'
status=$?
rmdir build/logs 2>/dev/null
[ $status -eq 0 ] || exit $status
python3 tools/make_3mf.py
