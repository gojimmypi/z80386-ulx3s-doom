#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd)
GENERATOR=$SCRIPT_DIR/bin-to-probe-rom.py

usage() {
    cat <<'USAGE'
Usage:
  ./scripts/build-asm-rom.sh [options] ASM_FILE

Assemble a 16-bit x86 GNU-as source file, emit a flat binary and disassembly,
and generate a standalone Verilog-2001 ROM module from selected binary ranges.
The generated .v file embeds the assembly source as comments by default.

Options:
  -o, --output-dir DIR
      Build-output directory. Default: build/rom/<assembly-basename>

  --verilog-output FILE
      Generated .v path. Default: <output-dir>/<basename>_probe_rom.v

  --map OFFSET:PHYSICAL_ADDRESS[:LENGTH]
      Map a DWORD-aligned range from the flat binary to a DWORD-aligned 32-bit
      physical address. Repeat for multiple ranges. Numeric values may be
      decimal or 0x-prefixed hexadecimal.

      If LENGTH is omitted, the mapping continues to the end of the binary.
      Supplying any --map option replaces the default mappings.

  --module NAME
      Generated Verilog module name. Default: <assembly-basename>_probe_rom

  --function NAME
      Internal Verilog function name. Default: probe_read_data

  --address-port NAME
      Address input port name. Default: address

  --data-port NAME
      Data output port name. Default: data

  --no-embed-source
      Do not copy the assembly source into the generated .v comments.

  --default-word VALUE
      Value returned for unmapped addresses. Default: 0x90909090

  --pad-byte VALUE
      Byte used to pad the final partial DWORD of a mapping. Default: 0x90

  --section NAME
      ELF section copied into the flat binary. Default: .text

  -h, --help
      Show this help.

Default mappings for the ULX3S z386 probe layout:
  --map 0x00000:0xfffffff0:0x10
  --map 0x10000:0x000f0000

Examples:
  ./scripts/build-asm-rom.sh rom/shift_regression.asm

  ./scripts/build-asm-rom.sh rom/another_test.asm \
      --module another_test_probe_rom \
      --map 0x0:0xfffffff0:0x10 \
      --map 0x2000:0x00080000

  ./scripts/build-asm-rom.sh rom/flat_test.asm \
      --map 0x0:0x000f0000 \
      --verilog-output rtl/generated/flat_test_probe_rom.v

Tool overrides:
  X86_AS, X86_OBJCOPY, X86_OBJDUMP, PYTHON
USAGE
}

fail() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

make_identifier() {
    local text=$1
    text=${text//[^A-Za-z0-9_$]/_}
    if [[ ! "$text" =~ ^[A-Za-z_] ]]; then
        text=_$text
    fi
    printf '%s' "$text"
}

OUTPUT_DIR=
VERILOG_OUTPUT=
MODULE_NAME=
FUNCTION_NAME=probe_read_data
ADDRESS_PORT=address
DATA_PORT=data
DEFAULT_WORD=0x90909090
PAD_BYTE=0x90
SECTION=.text
EMBED_SOURCE=1
ASM_FILE=
MAPS=()

while (($# > 0)); do
    case "$1" in
        -o|--output-dir)
            (($# >= 2)) || fail "$1 requires a directory"
            OUTPUT_DIR=$2
            shift 2
            ;;
        --verilog-output)
            (($# >= 2)) || fail "$1 requires a file"
            VERILOG_OUTPUT=$2
            shift 2
            ;;
        --map)
            (($# >= 2)) || fail "$1 requires OFFSET:ADDRESS[:LENGTH]"
            MAPS+=("$2")
            shift 2
            ;;
        --module)
            (($# >= 2)) || fail "$1 requires a module name"
            MODULE_NAME=$2
            shift 2
            ;;
        --function)
            (($# >= 2)) || fail "$1 requires a function name"
            FUNCTION_NAME=$2
            shift 2
            ;;
        --address-port)
            (($# >= 2)) || fail "$1 requires a port name"
            ADDRESS_PORT=$2
            shift 2
            ;;
        --data-port)
            (($# >= 2)) || fail "$1 requires a port name"
            DATA_PORT=$2
            shift 2
            ;;
        --no-embed-source)
            EMBED_SOURCE=0
            shift
            ;;
        --default-word)
            (($# >= 2)) || fail "$1 requires a value"
            DEFAULT_WORD=$2
            shift 2
            ;;
        --pad-byte)
            (($# >= 2)) || fail "$1 requires a value"
            PAD_BYTE=$2
            shift 2
            ;;
        --section)
            (($# >= 2)) || fail "$1 requires a section name"
            SECTION=$2
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --)
            shift
            (($# == 1)) || fail "expected exactly one assembly file after --"
            ASM_FILE=$1
            shift
            ;;
        -*)
            fail "unknown option: $1"
            ;;
        *)
            [[ -z "$ASM_FILE" ]] || fail "only one assembly file may be specified"
            ASM_FILE=$1
            shift
            ;;
    esac
done

[[ -n "$ASM_FILE" ]] || {
    usage >&2
    exit 2
}

SOURCE_DISPLAY=$ASM_FILE
if [[ "$ASM_FILE" != /* ]]; then
    ASM_FILE=$REPO_ROOT/$ASM_FILE
fi
[[ -f "$ASM_FILE" ]] || fail "assembly source not found: $ASM_FILE"
[[ -f "$GENERATOR" ]] || fail "generator not found: $GENERATOR"

X86_AS=${X86_AS:-as}
X86_OBJCOPY=${X86_OBJCOPY:-objcopy}
X86_OBJDUMP=${X86_OBJDUMP:-objdump}
PYTHON=${PYTHON:-python3}

for tool in "$X86_AS" "$X86_OBJCOPY" "$X86_OBJDUMP" "$PYTHON"; do
    command -v "$tool" >/dev/null 2>&1 || fail "required tool not found: $tool"
done

if ((${#MAPS[@]} == 0)); then
    MAPS=(
        0x00000:0xfffffff0:0x10
        0x10000:0x000f0000
    )
fi

ASM_BASENAME=$(basename -- "$ASM_FILE")
STEM=${ASM_BASENAME%.*}
if [[ -z "$MODULE_NAME" ]]; then
    MODULE_NAME=$(make_identifier "${STEM}_probe_rom")
fi

if [[ -z "$OUTPUT_DIR" ]]; then
    OUTPUT_DIR=$REPO_ROOT/build/rom/$STEM
elif [[ "$OUTPUT_DIR" != /* ]]; then
    OUTPUT_DIR=$REPO_ROOT/$OUTPUT_DIR
fi

if [[ -z "$VERILOG_OUTPUT" ]]; then
    VERILOG_OUTPUT=$OUTPUT_DIR/${STEM}_probe_rom.v
elif [[ "$VERILOG_OUTPUT" != /* ]]; then
    VERILOG_OUTPUT=$REPO_ROOT/$VERILOG_OUTPUT
fi

mkdir -p -- "$OUTPUT_DIR" "$(dirname -- "$VERILOG_OUTPUT")"

OBJECT_FILE=$OUTPUT_DIR/$STEM.o
BINARY_FILE=$OUTPUT_DIR/$STEM.bin
DISASM_FILE=$OUTPUT_DIR/$STEM.disasm.txt
RELOC_FILE=$OUTPUT_DIR/$STEM.relocations.txt

rm -f -- \
    "$OBJECT_FILE" \
    "$BINARY_FILE" \
    "$DISASM_FILE" \
    "$RELOC_FILE" \
    "$VERILOG_OUTPUT"

printf 'Assembling 16-bit x86 ROM source:\n  %s\n' "$ASM_FILE"
"$X86_AS" --32 -o "$OBJECT_FILE" "$ASM_FILE"

"$X86_OBJDUMP" -r "$OBJECT_FILE" > "$RELOC_FILE"
if grep -Eq '^[[:space:]]*[[:xdigit:]]+[[:space:]]+R_' "$RELOC_FILE"; then
    cat "$RELOC_FILE" >&2
    fail "unresolved relocations remain; the flat ROM image must be self-contained"
fi

"$X86_OBJCOPY" -O binary -j "$SECTION" "$OBJECT_FILE" "$BINARY_FILE"
[[ -s "$BINARY_FILE" ]] || fail "objcopy produced an empty binary: $BINARY_FILE"

"$X86_OBJDUMP" -D -Mintel,i8086 "$OBJECT_FILE" > "$DISASM_FILE"

GENERATOR_ARGS=(
    --binary "$BINARY_FILE"
    --output "$VERILOG_OUTPUT"
    --module "$MODULE_NAME"
    --function "$FUNCTION_NAME"
    --address-port "$ADDRESS_PORT"
    --data-port "$DATA_PORT"
    --default-word "$DEFAULT_WORD"
    --pad-byte "$PAD_BYTE"
)
if ((EMBED_SOURCE)); then
    GENERATOR_ARGS+=(
        --source-asm "$ASM_FILE"
        --source-name "$SOURCE_DISPLAY"
    )
fi
for mapping in "${MAPS[@]}"; do
    GENERATOR_ARGS+=(--map "$mapping")
done

"$PYTHON" "$GENERATOR" "${GENERATOR_ARGS[@]}"

printf '\nBuild complete:\n'
printf '  Object:       %s\n' "$OBJECT_FILE"
printf '  Binary:       %s (%s bytes)\n' "$BINARY_FILE" "$(wc -c < "$BINARY_FILE")"
printf '  Disassembly:  %s\n' "$DISASM_FILE"
printf '  Relocations:  %s\n' "$RELOC_FILE"
printf '  Verilog ROM:  %s\n' "$VERILOG_OUTPUT"
printf '  Module:       %s\n' "$MODULE_NAME"
printf '  Function:     %s\n' "$FUNCTION_NAME"
