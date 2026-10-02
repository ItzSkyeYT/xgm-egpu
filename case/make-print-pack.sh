#!/usr/bin/env bash
# Build print-pack/ (one folder per stage, README.md with settings, pictures and checklists).
# Usage: ./make-print-pack.sh [destination]   (default: ./print-pack, inside the repo)
set -eu
cd "$(dirname "$0")"
exec python3 make_print_pack.py "$@"
