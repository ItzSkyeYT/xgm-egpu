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

# --link installs a symlink to the repo instead of a copy, so edits are live.
# Without it, every `git pull` or local edit leaves an older copy in $BIN_DIR
# that sudo runs in preference to the one you just changed — which cost a wasted
# activation attempt on 2026-09-09.
if [[ ${1:-} == --link ]]; then
    ln -sfn "$SRC" "$BIN_DIR/xgm-egpu"
    echo "linked  $BIN_DIR/xgm-egpu -> $SRC"
else
    install -Dm755 "$SRC" "$BIN_DIR/xgm-egpu"
    echo "installed $BIN_DIR/xgm-egpu   (re-run after every change, or use --link)"
fi

# A stale copy earlier on the user's PATH silently shadows this one for
# unprivileged calls, while `sudo xgm-egpu` (secure_path) runs the new one —
# so `xgm-egpu preflight` says "unknown command" and `sudo xgm-egpu on` works.
# Bit the author on 2026-09-09. Check the invoking user's ~/.local/bin.
home=$(getent passwd "${SUDO_USER:-$USER}" | cut -d: -f6)
stale="$home/.local/bin/xgm-egpu"
if [[ -e $stale && ! -L $stale ]] && ! cmp -s "$stale" "$BIN_DIR/xgm-egpu"; then
    echo
    echo "WARNING: $stale is a DIFFERENT, older copy and ~/.local/bin is usually"
    echo "         first on PATH. Unprivileged 'xgm-egpu' will run the old one."
    echo "         Replace it with a symlink:"
    echo "           ln -sf $BIN_DIR/xgm-egpu $stale"
fi

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

  4. BEFORE activating, disarm NVIDIA RTD3 and pin runtime PM, or the link
     will drop exactly ~10s after the GPU goes idle:

       sudo xgm-egpu install-rules      # modprobe shadow + udev + initramfs
       sudo reboot
       xgm-egpu preflight               # must report DynamicPowerManagement 0

     `xgm-egpu on` refuses to run until preflight passes.

EOF
