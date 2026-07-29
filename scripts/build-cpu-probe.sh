#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd)
BUILD_DIR=$REPO_ROOT/build
Z386_DIR=$REPO_ROOT/third_party/z386_MiSTer/src/z386
ASM_BUILD_SCRIPT=$SCRIPT_DIR/build-asm-rom.sh
ASM_FILE=$REPO_ROOT/rom/shift_regression.asm
ROM_FILE=$REPO_ROOT/rtl/generated/shift_regression_probe_rom.v
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
NEXTPNR_SEED=${NEXTPNR_SEED:-56}
NEXTPNR_SEEDS=${NEXTPNR_SEEDS:-"$NEXTPNR_SEED 17 23 31 173 76 46 33 205 201 13"}
REUSE_SYNTHESIS=${REUSE_SYNTHESIS:-0}
ALLOW_TIMING_FAILURE=${ALLOW_TIMING_FAILURE:-0}

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

if [[ ! -f "$ASM_BUILD_SCRIPT" ]]; then
    printf 'Error: assembly ROM build script is missing:\n  %s\n' \
        "$ASM_BUILD_SCRIPT" >&2
    exit 1
fi

if [[ ! -f "$ASM_FILE" ]]; then
    printf 'Error: shift regression assembly source is missing:\n  %s\n' \
        "$ASM_FILE" >&2
    exit 1
fi

case "$REUSE_SYNTHESIS" in
    0|1) ;;
    *)
        printf 'Error: REUSE_SYNTHESIS must be 0 or 1, not: %s\n' \
            "$REUSE_SYNTHESIS" >&2
        exit 1
        ;;
esac

case "$ALLOW_TIMING_FAILURE" in
    0|1) ;;
    *)
        printf 'Error: ALLOW_TIMING_FAILURE must be 0 or 1, not: %s\n' \
            "$ALLOW_TIMING_FAILURE" >&2
        exit 1
        ;;
esac

if [[ "$REUSE_SYNTHESIS" == 0 ]]; then
    printf 'Regenerating focused regression ROM from assembly...\n'
    bash "$ASM_BUILD_SCRIPT" "$ASM_FILE" --verilog-output "$ROM_FILE"
fi

if [[ ! -s "$ROM_FILE" ]]; then
    printf 'Error: generated Verilog ROM is missing or empty:\n  %s\n' \
        "$ROM_FILE" >&2
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

for path in "$Z386_DIR" "$ROM_FILE" "$TOP_FILE" "$JSON_FILE" "${Z386_SOURCES[@]}"; do
    if [[ "$path" =~ [[:space:]] ]]; then
        printf 'Error: Yosys script paths must not contain whitespace:\n  %s\n' \
            "$path" >&2
        exit 1
    fi
done

# Never allow a previous configuration or bitstream to survive a failed build.
rm -f -- \
    "$CONFIG_FILE" \
    "$BIT_FILE" \
    "$NEXTPNR_LOG" \
    "$BUILD_DIR"/nextpnr-seed-*.log \
    "$BUILD_DIR"/z386_ulx3s_cpu_probe.seed-*.config

if [[ "$REUSE_SYNTHESIS" == 0 ]]; then
    rm -f -- \
        "$JSON_FILE" \
        "$YOSYS_LOG"

    {
        printf 'read_slang --allow-use-before-declare --no-implicit-memories -DZ386_DISABLE_CACHE_RAM_HINTS --top %s -I%s' \
            "$TOP" "$Z386_DIR"
        for source in "${Z386_SOURCES[@]}" "$ROM_FILE" "$TOP_FILE"; do
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
else
    printf 'Reusing existing synthesized JSON netlist:\n  %s\n' "$JSON_FILE"
fi

if [[ ! -s "$JSON_FILE" ]]; then
    printf 'Error: synthesis did not create a nonempty JSON netlist:\n  %s\n' \
        "$JSON_FILE" >&2
    exit 1
fi

extract_max_frequency() {
    local log_file=$1

    sed -nE \
        's/.*Max frequency for clock .*: ([0-9]+([.][0-9]+)?) MHz.*/\1/p' \
        "$log_file" | tail -n 1
}

frequency_is_better() {
    local candidate=$1
    local current=$2

    awk -v candidate="$candidate" -v current="$current" \
        'BEGIN { exit !(candidate + 0 > current + 0) }'
}

read -r -a seed_candidates <<< "$NEXTPNR_SEEDS"
if (( ${#seed_candidates[@]} == 0 )); then
    printf 'Error: NEXTPNR_SEEDS does not contain any seeds.\n' >&2
    exit 1
fi

declare -A seed_seen=()
best_seed=
best_frequency=
best_config=
best_log=
selected_seed=
selected_frequency=

for seed in "${seed_candidates[@]}"; do
    if [[ ! "$seed" =~ ^[0-9]+$ ]]; then
        printf 'Error: invalid nextpnr seed: %s\n' "$seed" >&2
        exit 1
    fi

    if [[ -n ${seed_seen[$seed]+x} ]]; then
        continue
    fi
    seed_seen[$seed]=1

    seed_config=$BUILD_DIR/z386_ulx3s_cpu_probe.seed-$seed.config
    seed_log=$BUILD_DIR/nextpnr-seed-$seed.log
    rm -f -- "$seed_config" "$seed_log"

    printf '\nPlacing and routing for ULX3S %sF, seed %s...\n' \
        "${ECP5_DEVICE%k}" "$seed"

    set +e
    nextpnr-ecp5 \
        "--$ECP5_DEVICE" \
        --package "$ECP5_PACKAGE" \
        --json "$JSON_FILE" \
        --lpf "$LPF_FILE" \
        --textcfg "$seed_config" \
        --freq "$FREQ_MHZ" \
        --seed "$seed" \
        2>&1 | tee "$seed_log"
    nextpnr_status=${PIPESTATUS[0]}
    set -e

    max_frequency=$(extract_max_frequency "$seed_log")

    if (( nextpnr_status == 0 )) && [[ -s "$seed_config" ]]; then
        selected_seed=$seed
        selected_frequency=$max_frequency
        mv -- "$seed_config" "$CONFIG_FILE"
        cp -- "$seed_log" "$NEXTPNR_LOG"
        break
    fi

    if grep -q 'ERROR: Max frequency .*FAIL at' "$seed_log" && \
       grep -q 'Program finished normally\.' "$seed_log" && \
       [[ -s "$seed_config" ]]; then
        printf 'Seed %s completed routing but missed %s MHz timing' \
            "$seed" "$FREQ_MHZ" >&2
        if [[ -n "$max_frequency" ]]; then
            printf ' (reported %s MHz)' "$max_frequency" >&2
        fi
        printf '. Trying the next seed.\n' >&2

        if [[ -n "$max_frequency" ]] && \
           { [[ -z "$best_frequency" ]] || \
             frequency_is_better "$max_frequency" "$best_frequency"; }; then
            best_seed=$seed
            best_frequency=$max_frequency
            best_config=$seed_config
            best_log=$seed_log
        fi
        continue
    fi

    cp -- "$seed_log" "$NEXTPNR_LOG"
    printf 'Error: nextpnr failed for seed %s for a reason other than timing.\n' \
        "$seed" >&2
    printf 'See:\n  %s\n' "$seed_log" >&2
    exit 1
done

if [[ -z "$selected_seed" ]]; then
    if [[ "$ALLOW_TIMING_FAILURE" == 1 && -n "$best_config" ]]; then
        selected_seed=$best_seed
        selected_frequency=$best_frequency
        mv -- "$best_config" "$CONFIG_FILE"
        cp -- "$best_log" "$NEXTPNR_LOG"
        printf '%s\n' \
            'WARNING: no seed met timing; packing the best result because' \
            'ALLOW_TIMING_FAILURE=1 was explicitly requested.' >&2
    else
        if [[ -n "$best_log" ]]; then
            cp -- "$best_log" "$NEXTPNR_LOG"
        fi
        printf 'Error: none of the requested nextpnr seeds met %s MHz timing.\n' \
            "$FREQ_MHZ" >&2
        printf 'Seeds tried: %s\n' "$NEXTPNR_SEEDS" >&2
        if [[ -n "$best_frequency" ]]; then
            printf 'Best result: seed %s at %s MHz.\n' \
                "$best_seed" "$best_frequency" >&2
        fi
        printf '%s\n' \
            'Add more seeds with NEXTPNR_SEEDS="..." and reuse the JSON with' \
            'REUSE_SYNTHESIS=1, or explicitly permit the best timing miss with' \
            'ALLOW_TIMING_FAILURE=1.' >&2
        exit 1
    fi
fi

printf '\nPacking bitstream...\n'
ecppack --compress "$CONFIG_FILE" "$BIT_FILE"

if [[ ! -s "$BIT_FILE" ]]; then
    printf 'Error: ecppack did not create a nonempty bitstream:\n  %s\n' \
        "$BIT_FILE" >&2
    exit 1
fi

printf '\nBuild complete:\n'
printf '  Selected nextpnr seed: %s\n' "$selected_seed"
if [[ -n "$selected_frequency" ]]; then
    printf '  Reported maximum frequency: %s MHz\n' "$selected_frequency"
fi
ls -l --time-style=long-iso "$BIT_FILE" "$JSON_FILE" "$CONFIG_FILE"
printf '\nReports:\n  %s\n  %s\n' "$YOSYS_LOG" "$NEXTPNR_LOG"
