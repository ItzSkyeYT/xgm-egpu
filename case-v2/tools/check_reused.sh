#!/usr/bin/env bash
# Proves that reused.scad still produces the bracket holder and the cradle exactly as v1 prints them
# (../case/build/stl/bracket_holder.stl and cradle.stl), so parts printed for v1 fit a v2 case.
# Usage: tools/check_reused.sh
set -eu
cd "$(dirname "$0")/.."
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
cat > "$tmp/r.scad" <<SCAD
include <$PWD/hardware.scad>
include <$PWD/reused.scad>
\$fn = 40;
which = "holder";
mirror([0, 1, 0]) {
  if (which == "holder") rotate([0,-90,0]) translate([-hx0, 0, 0]) bracket_holder();
  if (which == "cradle") rotate([0,90,0]) translate([-card_x1, 0, 0]) cradle();
}
SCAD
ok=0
for pair in holder:bracket_holder cradle:cradle; do
  which=${pair%%:*}; name=${pair##*:}
  openscad -o "$tmp/$name.stl" -D "which=\"$which\"" "$tmp/r.scad" >/dev/null 2>&1
  python3 ../case/tools/normalize_stl.py --shift "$tmp/$name.stl" >/dev/null
  if cmp -s "$tmp/$name.stl" "../case/build/stl/$name.stl"; then echo "$name: identical to v1's"; else echo "$name: DIFFERS from v1's"; ok=1; fi
done
exit $ok
