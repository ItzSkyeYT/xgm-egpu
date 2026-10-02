#!/usr/bin/env bash
# Render every part in its assembled position to stl/assembled/<name>.stl, then pack them into one 3MF
# (xgm-lite-frame-assembled.3mf) where each part is a separate, named, coloured object you can hide in a viewer.
set -u
cd "$(dirname "$0")"
jobs=${JOBS:-6}
parts=(floor_rl floor_rr floor_fl floor_fr lid_l lid_r
       post_corner_rl post_corner_rr post_corner_fl post_corner_fr post_mid_rear post_mid_far post_mid_left post_mid_right
       panel_rear_l panel_rear_r panel_far_l panel_far_r panel_left_r panel_left_f panel_right_r panel_right_f
       cradle bracket_holder board card psu zones)
mkdir -p stl/assembled
printf '%s\n' "${parts[@]}" | xargs -P "$jobs" -I{} sh -c \
  'openscad -o "stl/assembled/{}.stl" -D "part=\"asm_{}\"" xgm-lite-frame.scad >"stl/assembled/{}.log" 2>&1; echo "{}: $(grep -c "facet normal" "stl/assembled/{}.stl" 2>/dev/null || echo 0) facets"'
python3 make_3mf.py stl/assembled xgm-lite-frame-assembled.3mf
