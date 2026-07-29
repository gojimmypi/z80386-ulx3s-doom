#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd)
SUBMODULE_PATH=third_party/z386_MiSTer
SUBMODULE_URL=https://github.com/nand2mario/z386_MiSTer.git

cd -- "$REPO_ROOT"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    printf 'Error: initialize this directory as a Git repository first.\n' >&2
    printf 'Example: git init\n' >&2
    exit 1
fi

if git ls-files --stage -- "$SUBMODULE_PATH" | grep -q '^160000 '; then
    printf 'Updating existing z386_MiSTer submodule...\n'
    git submodule sync --recursive
    git submodule update --init --recursive
else
    if [[ -e "$SUBMODULE_PATH" ]]; then
        printf 'Error: %s exists but is not tracked as a submodule.\n' "$SUBMODULE_PATH" >&2
        printf 'Move it aside, then rerun this script.\n' >&2
        exit 1
    fi

    printf 'Adding z386_MiSTer as a recursive submodule...\n'
    git submodule add --force --branch main \
        "$SUBMODULE_URL" "$SUBMODULE_PATH"
    git submodule update --init --recursive
fi

if [[ ! -f "$SUBMODULE_PATH/src/z386/z386.sv" ]]; then
    printf 'Error: the nested src/z386 submodule was not populated.\n' >&2
    exit 1
fi

printf '\nSubmodules ready:\n'
git submodule status --recursive

git -C "$SUBMODULE_PATH" config --local core.autocrlf false
git -C "$SUBMODULE_PATH" config --local core.filemode false

git -C "$SUBMODULE_PATH/src/z386" config --local core.autocrlf false
git -C "$SUBMODULE_PATH/src/z386" config --local core.filemode false

# Patches!

Z386_PATH=$REPO_ROOT/$SUBMODULE_PATH/src/z386
Z386_PATCH=$REPO_ROOT/patches/z386/0001-z386-yosys-slang-compat.patch

if [[ ! -f "$Z386_PATCH" ]]; then
    printf 'Error: required z386 patch is missing:\n  %s\n' \
        "$Z386_PATCH" >&2
    exit 1
fi

if git -C "$Z386_PATH" apply \
        --reverse --check "$Z386_PATCH" >/dev/null 2>&1; then
    printf 'z386 compatibility patch is already applied.\n'
elif git -C "$Z386_PATH" apply --check "$Z386_PATCH"; then
    printf 'Applying z386 compatibility patch...\n'
    git -C "$Z386_PATH" apply "$Z386_PATCH"
else
    printf 'Error: z386 compatibility patch does not apply cleanly:\n' >&2
    printf '  %s\n' "$Z386_PATCH" >&2
    printf 'Nested z386 commit:\n  %s\n' \
        "$(git -C "$Z386_PATH" rev-parse HEAD)" >&2
    exit 1
fi