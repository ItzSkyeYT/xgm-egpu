#!/usr/bin/env bash
# The printed parts against the real hardware: the board with its connectors, the card, the PSU, and the room
# their plugs and cables need. The model intersects the two, and the result must be empty. Both variants are
# tested: with inserts and screws (the default), and print-only.
# Usage: tools/check-collision.sh
set -u
cd "$(dirname "$0")/.."
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
check() {
  out=$(openscad -o "$tmp/collision-$1.stl" -D 'part="collision"' -D vents=false -D "use_inserts=$1" xgm-lite-frame.scad 2>&1)
  if printf '%s\n' "$out" | grep -q "Current top level object is empty"; then
    echo "use_inserts=$1: nothing touches the hardware"
  else
    echo "use_inserts=$1: COLLISION"
    printf '%s\n' "$out" | grep -E "Vertices|Facets|ERROR|WARNING" | sed 's/^/    /'
    return 1
  fi
}
check true & a=$!
check false & b=$!
wait $a; sa=$?
wait $b; sb=$?
[ $sa -eq 0 ] && [ $sb -eq 0 ]
