#~/bin/bash

cd /mnt/c/workspace/z80386_ULX3S_Doom

Z386_DIR=third_party/z386_MiSTer/src/z386
PATCH_DIR=$PWD/patches/z386
PATCH_FILE=$PATCH_DIR/0001-z386-yosys-slang-compat.patch

mkdir -p "$PATCH_DIR"

# Use the exact nested-z386 commit recorded by z386_MiSTer as the base.
BASE=$(
    git -C third_party/z386_MiSTer \
        ls-tree HEAD src/z386 |
    awk '{print $3}'
)

printf 'Patch base: %s\n' "$BASE"

git -C "$Z386_DIR" diff \
    --binary \
    --full-index \
    "$BASE" \
    -- l1_cache.sv l1_icache.sv z386.sv \
    > "$PATCH_FILE"

test -s "$PATCH_FILE" || {
    printf 'Error: generated patch is empty.\n' >&2
    exit 1
}

ls -al "$PATCH_FILE"