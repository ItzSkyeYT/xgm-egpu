#!/usr/bin/env bash
# install.sh — put xgm-egpu somewhere sudo can find it.
#
# Deliberately minimal. It does NOT install the udev/modprobe rules, because
# those pin a specific root-port address that differs per machine; run
# `sudo xgm-egpu install-rules` once you have set your constants (docs/PORTING.md).

set -euo pipefail

PREFIX=${PREFIX:-/usr/local}
BIN_DIR="$PREFIX/bin"
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/bin/xgm-egpu"

if [[ $EUID -ne 0 ]]; then
    echo "This needs root to write to $BIN_DIR. Re-run with sudo." >&2
    exit 1
fi

[[ -f $SRC ]] || { echo "Cannot find $SRC" >&2; exit 1; }

install -Dm755 "$SRC" "$BIN_DIR/xgm-egpu"
echo "installed $BIN_DIR/xgm-egpu"

cat <<'EOF'

Next steps:

  1. Read docs/RECOVERY.md. Do this before your first activation, not after.
     egpu_enable is persistent EC state and survives a power-off.

  2. Check what it worked out about your machine. Topology is autodetected;
     there is normally nothing to configure.

       xgm-egpu detect

  3. Check the interface is present and your dock is detected:

       xgm-egpu status

     egpu_connected must read 1 before anything else will work.

  4. Once activation succeeds, persist the runtime-PM pinning or the link will
     drop ~10s after the GPU goes idle:

       sudo xgm-egpu install-rules

EOF
