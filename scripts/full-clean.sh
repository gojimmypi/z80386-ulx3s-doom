#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd)
BUILD_DIR=$REPO_ROOT/build

case "$BUILD_DIR" in
    "$REPO_ROOT/build") ;;
    *)
        printf 'Error: refusing to remove unexpected path: %s\n' "$BUILD_DIR" >&2
        exit 1
        ;;
esac

if [[ -d "$BUILD_DIR" ]]; then
    printf 'Removing generated build directory:\n  %s\n' "$BUILD_DIR"
    rm -rf -- "$BUILD_DIR"
else
    printf 'Nothing to clean: %s does not exist.\n' "$BUILD_DIR"
fi
