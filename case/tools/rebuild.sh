#!/usr/bin/env bash
# Rebuild everything that is made from xgm-lite-frame.scad, in order, stopping at the first step that fails.
# Run it after any change to the model. Needs openscad, rsvg-convert and OrcaSlicer (ORCA=/path/to/it if it
# is not in /opt/orca-slicer). Takes about four minutes.
# Usage: tools/rebuild.sh
set -eu
cd "$(dirname "$0")"
step() { printf '\n== %s\n' "$1"; }
step "1/8  every part, laid out for printing -> build/stl";           ./render.sh
step "2/8  every part in place -> build/assembled, and the 3MF";       ./render-assembled.sh
step "3/8  printed parts against the hardware";                        ./check-collision.sh
step "4/8  printed parts against each other";                          ./check_overlaps.py; ./check_overlaps.py -D use_inserts=false
step "5/8  floor plans -> docs";                                       ./make_plan.py
step "6/8  dimension tables -> docs/DIMENSIONS.md";                    ./dimensions.py
step "7/8  batches, arranged and sliced -> build/plates";              ./make_plates.py
step "8/8  the print pack -> print-pack";                              ./make_print_pack.py
