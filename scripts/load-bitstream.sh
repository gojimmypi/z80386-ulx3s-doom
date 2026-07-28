#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd)
BIT_FILE=${1:-$REPO_ROOT/build/z386_ulx3s_cpu_probe.bit}

if [[ ! -f "$BIT_FILE" ]]; then
    printf 'Error: bitstream not found: %s\n' "$BIT_FILE" >&2
    printf 'Build it first with: make probe\n' >&2
    exit 1
fi

printf 'Loading FPGA bitstream:\n  %s\n\n' "$BIT_FILE"

if command -v openFPGALoader >/dev/null 2>&1; then
    openFPGALoader -b ulx3s "$BIT_FILE"
elif command -v fujprog >/dev/null 2>&1; then
    fujprog "$BIT_FILE"
else
    printf '%s\n' \
        'Error: neither openFPGALoader nor fujprog was found in PATH.' >&2
    exit 1
fi

printf '\nDone!\n'
