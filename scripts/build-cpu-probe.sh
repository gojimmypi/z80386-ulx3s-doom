#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd)
BUILD_DIR=$REPO_ROOT/build
Z386_DIR=$REPO_ROOT/third_party/z386_MiSTer/src/z386
TOP_FILE=$REPO_ROOT/rtl/z386_synth_probe.sv
LPF_FILE=$REPO_ROOT/constraints/ulx3s_v303_probe.lpf
TOP=z386_synth_probe
JSON_FILE=$BUILD_DIR/z386_ulx3s_cpu_probe.json
CONFIG_FILE=$BUILD_DIR/z386_ulx3s_cpu_probe.config
BIT_FILE=$BUILD_DIR/z386_ulx3s_cpu_probe.bit
YOSYS_SCRIPT=$BUILD_DIR/z386_ulx3s_cpu_probe.ys
YOSYS_LOG=$BUILD_DIR/yosys.log
NEXTPNR_LOG=$BUILD_DIR/nextpnr.log

ECP5_DEVICE=${ECP5_DEVICE:-85k}
ECP5_PACKAGE=${ECP5_PACKAGE:-CABGA381}
FREQ_MHZ=${FREQ_MHZ:-25}
NEXTPNR_SEED=${NEXTPNR_SEED:-1}

for tool in yosys nextpnr-ecp5 ecppack; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        printf 'Error: required tool not found in PATH: %s\n' "$tool" >&2
        exit 1
    fi
done

if [[ ! -f "$Z386_DIR/z386.sv" ]]; then
    printf 'Error: z386 sources are missing. Run: make setup\n' >&2
    exit 1
fi

if [[ ! -f "$Z386_DIR/ucode.hex" ]]; then
    printf 'Error: z386 microcode image is missing:\n  %s\n' \
        "$Z386_DIR/ucode.hex" >&2
    exit 1
fi

if [[ ! -f "$TOP_FILE" ]]; then
    printf 'Error: probe top-level file is missing:\n  %s\n' \
        "$TOP_FILE" >&2
    exit 1
fi

if [[ ! -f "$LPF_FILE" ]]; then
    printf 'Error: ULX3S constraint file is missing:\n  %s\n' \
        "$LPF_FILE" >&2
    exit 1
fi

supports_read_slang() {
    local output
    output=$("$@" -Q -p 'help read_slang' 2>&1 || true)
    [[ "$output" == *read_slang* && "$output" != *'No such command'* ]]
}

YOSYS_CMD=(yosys)
if supports_read_slang yosys; then
    :
elif supports_read_slang yosys -m slang; then
    YOSYS_CMD=(yosys -m slang)
else
    printf '%s\n' \
        'Error: this design needs the read_slang SystemVerilog frontend.' \
        'Use Yosys 0.67 or newer, or an OSS CAD Suite build with the slang plugin.' >&2
    exit 1
fi

mkdir -p -- "$BUILD_DIR"

mapfile -d '' Z386_SOURCES < <(
    find "$Z386_DIR" -maxdepth 1 -type f -name '*.sv' -print0 | sort -z
)

if (( ${#Z386_SOURCES[@]} == 0 )); then
    printf 'Error: no SystemVerilog sources found in %s\n' "$Z386_DIR" >&2
    exit 1
fi

for path in "$Z386_DIR" "$TOP_FILE" "$JSON_FILE" "${Z386_SOURCES[@]}"; do
    if [[ "$path" =~ [[:space:]] ]]; then
        printf 'Error: Yosys script paths must not contain whitespace:\n  %s\n' \
            "$path" >&2
        exit 1
    fi
done

# Never allow a previous JSON/configuration/bitstream to survive a failed build.
rm -f -- \
    "$JSON_FILE" \
    "$CONFIG_FILE" \
    "$BIT_FILE" \
    "$YOSYS_LOG" \
    "$NEXTPNR_LOG"

{
    printf 'read_slang --allow-use-before-declare --no-implicit-memories -DZ386_DISABLE_CACHE_RAM_HINTS --top %s -I%s' \
        "$TOP" "$Z386_DIR"
    for source in "${Z386_SOURCES[@]}" "$TOP_FILE"; do
        printf ' %s' "$source"
    done
    printf '\n'
    printf 'hierarchy -check -top %s\n' "$TOP"

    # ABC9 crashes in Yosys 0.67 on this z386 netlist during its &mfs step.
    # Use the established classic ABC mapper instead of accepting a partial
    # ABC9 result after the assertion failure.
    printf 'synth_ecp5 -noabc9 -top %s -json %s\n' \
        "$TOP" "$JSON_FILE"
    printf 'stat -top %s\n' "$TOP"
} > "$YOSYS_SCRIPT"

printf 'Synthesizing z386 CPU probe for ECP5-%s with classic ABC...\n' \
    "$ECP5_DEVICE"
if ! (
    cd -- "$Z386_DIR"
    "${YOSYS_CMD[@]}" -Q -l "$YOSYS_LOG" -s "$YOSYS_SCRIPT"
); then
    printf 'Error: Yosys synthesis failed. See:\n  %s\n' "$YOSYS_LOG" >&2
    exit 1
fi

if grep -q 'Executing ABC9' "$YOSYS_LOG"; then
    printf '%s\n' \
        'Error: ABC9 unexpectedly ran despite synth_ecp5 -noabc9.' \
        "See: $YOSYS_LOG" >&2
    exit 1
fi

if grep -Eq \
    'Assertion .* failed|Aborted \(core dumped\)|ABC: execution of command .* failed: return code [1-9][0-9]*' \
    "$YOSYS_LOG"; then
    printf '%s\n' \
        'Error: an ABC mapper process crashed; refusing to use its output.' \
        "See: $YOSYS_LOG" >&2
    exit 1
fi

if [[ ! -s "$JSON_FILE" ]]; then
    printf 'Error: synthesis did not create a nonempty JSON netlist:\n  %s\n' \
        "$JSON_FILE" >&2
    exit 1
fi

printf '\nPlacing and routing for ULX3S %sF, seed %s...\n' \
    "${ECP5_DEVICE%k}" "$NEXTPNR_SEED"
nextpnr-ecp5 \
    "--$ECP5_DEVICE" \
    --package "$ECP5_PACKAGE" \
    --json "$JSON_FILE" \
    --lpf "$LPF_FILE" \
    --textcfg "$CONFIG_FILE" \
    --freq "$FREQ_MHZ" \
    --seed "$NEXTPNR_SEED" \
    2>&1 | tee "$NEXTPNR_LOG"

if [[ ! -s "$CONFIG_FILE" ]]; then
    printf 'Error: nextpnr did not create a nonempty configuration:\n  %s\n' \
        "$CONFIG_FILE" >&2
    exit 1
fi

printf '\nPacking bitstream...\n'
ecppack --compress "$CONFIG_FILE" "$BIT_FILE"

if [[ ! -s "$BIT_FILE" ]]; then
    printf 'Error: ecppack did not create a nonempty bitstream:\n  %s\n' \
        "$BIT_FILE" >&2
    exit 1
fi

printf '\nBuild complete:\n'
ls -l --time-style=long-iso "$BIT_FILE" "$JSON_FILE" "$CONFIG_FILE"
printf '\nReports:\n  %s\n  %s\n' "$YOSYS_LOG" "$NEXTPNR_LOG"
