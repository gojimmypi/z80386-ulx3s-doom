# z386 ULX3S Scripts

Setup, ROM generation, synthesis, place-and-route, programming, validation, and
cleanup utilities for the ULX3S 85F z386 probe.

Run the scripts from the repository root unless a section explicitly states
otherwise. The scripts resolve the repository root from their own location, so
most also work when invoked through an absolute path.

## Quick reference

| Script | Purpose |
|---|---|
| `bin-to-probe-rom.py` | Convert selected ranges of a flat binary into a standalone plain-Verilog ROM module. |
| `build-asm-rom.sh` | Assemble a 16-bit x86 GNU-as source file and generate its Verilog ROM. |
| `build-cpu-probe.sh` | Generate the regression ROM, synthesize z386, route one or more seeds, and pack the bitstream. |
| `check-nettype.sh` | Check HDL source files for the repository's `default_nettype` policy. |
| `create-patch.sh` | Recreate the z386 compatibility patch for an older pinned upstream revision. |
| `full-clean.sh` | Safely remove the generated top-level `build/` directory. |
| `load-bitstream.sh` | Load a generated or explicitly selected bitstream into ULX3S SRAM. |
| `setup-submodules.sh` | Add or initialize the recursive `z386_MiSTer` submodule tree. |

## Common requirements

The complete workflow uses:

```text
bash
Git
Python 3
GNU x86 binutils: as, objcopy, objdump
Yosys with read_slang
nextpnr-ecp5
ecppack
openFPGALoader or fujprog
```

Optional development checks may also use `shellcheck`.

## `bin-to-probe-rom.py`

Internal binary-to-Verilog converter used by `build-asm-rom.sh`. Direct use is
supported when an existing flat binary and explicit address mappings are
already available.

The output is a standalone Verilog-2001 module containing a combinational
`probe_read_data` function. It is a normal `.v` compilation unit, not an `.svh`
include fragment.

Basic direct invocation:

```bash
python3 scripts/bin-to-probe-rom.py \
    --binary build/rom/example/example.bin \
    --output rtl/generated/example_probe_rom.v \
    --module example_probe_rom \
    --map 0x00000:0xfffffff0:0x10 \
    --map 0x10000:0x000f0000
```

Required options:

| Option | Meaning |
|---|---|
| `--binary FILE` | Input flat binary. |
| `--output FILE` | Generated plain-Verilog `.v` file. |
| `--module NAME` | Generated module name. |
| `--map OFFSET:ADDRESS[:LENGTH]` | Map a binary range to a 32-bit physical address. Repeat as needed. |

Optional options:

| Option | Default | Meaning |
|---|---|---|
| `--function NAME` | `probe_read_data` | Internal Verilog function name. |
| `--address-port NAME` | `address` | Address input port name. |
| `--data-port NAME` | `data` | Data output port name. |
| `--default-word VALUE` | `0x90909090` | Word returned for unmapped addresses. |
| `--pad-byte VALUE` | `0x90` | Byte used to pad a final partial DWORD. |
| `--source-asm FILE` | none | Assembly source used for inline annotations. |
| `--listing FILE` | none | GNU assembler listing that maps source lines to bytes. |
| `--source-name TEXT` | source basename | Display name used in generated comments. |

`--source-asm` and `--listing` must be supplied together. When present, each
assembly statement is placed immediately above the generated ROM word or words
containing its bytes. Each data line also includes its binary offset and byte
values on the same line.

Binary offsets and physical addresses must be DWORD-aligned. Mapping overlap,
out-of-range mappings, invalid identifiers, and values wider than their fields
are rejected.

The generator strips trailing spaces and tabs from every generated line.

## `build-asm-rom.sh`

Front end for assembling a 16-bit x86 GNU-as source and generating a plain
Verilog ROM module.

Typical use:

```bash
./scripts/build-asm-rom.sh rom/shift_regression.asm
```

The script:

1. Runs GNU `as --32` and emits an assembler listing.
2. Rejects unresolved relocations.
3. Extracts the selected section into a flat binary.
4. Produces an Intel/i8086 disassembly.
5. Calls `bin-to-probe-rom.py`.
6. Rejects trailing whitespace in the generated Verilog.

Default outputs for `rom/shift_regression.asm`:

```text
build/rom/shift_regression/shift_regression.o
build/rom/shift_regression/shift_regression.bin
build/rom/shift_regression/shift_regression.disasm.txt
build/rom/shift_regression/shift_regression.listing.txt
build/rom/shift_regression/shift_regression.relocations.txt
build/rom/shift_regression/shift_regression_probe_rom.v
```

The CPU build overrides the final path so the tracked/generated module is:

```text
rtl/generated/shift_regression_probe_rom.v
```

Default probe mappings:

```text
binary +0x00000 -> physical 0xFFFFFFF0, length 0x10
binary +0x10000 -> physical 0x000F0000, through end of binary
```

Common options:

```text
-o, --output-dir DIR
--verilog-output FILE
--map OFFSET:PHYSICAL_ADDRESS[:LENGTH]
--module NAME
--function NAME
--address-port NAME
--data-port NAME
--no-embed-source
--default-word VALUE
--pad-byte VALUE
--section NAME
-h, --help
```

Supplying any `--map` replaces both default mappings. Repeat `--map` for
multiple regions.

Example with custom mappings and output:

```bash
./scripts/build-asm-rom.sh rom/another_test.asm \
    --module another_test_probe_rom \
    --map 0x0:0xfffffff0:0x10 \
    --map 0x2000:0x00080000 \
    --verilog-output rtl/generated/another_test_probe_rom.v
```

Tool commands can be overridden without editing the script:

```bash
X86_AS=/path/to/as \
X86_OBJCOPY=/path/to/objcopy \
X86_OBJDUMP=/path/to/objdump \
PYTHON=/path/to/python3 \
    ./scripts/build-asm-rom.sh rom/shift_regression.asm
```

## `build-cpu-probe.sh`

Complete CPU-probe build. This is the implementation behind:

```bash
make probe
```

Normal stages:

1. Regenerate `rtl/generated/shift_regression_probe_rom.v` from assembly.
2. Discover the z386 SystemVerilog sources.
3. Generate the Yosys command file.
4. Synthesize with `read_slang` and `synth_ecp5 -noabc9`.
5. Try nextpnr seeds in order until one meets timing.
6. Pack the selected routed configuration with `ecppack`.

Environment variables:

| Variable | Default | Purpose |
|---|---:|---|
| `ECP5_DEVICE` | `85k` | nextpnr ECP5 device option. |
| `ECP5_PACKAGE` | `CABGA381` | FPGA package. |
| `FREQ_MHZ` | `25` | nextpnr timing target. |
| `NEXTPNR_SEED` | `56` | First/default seed. |
| `NEXTPNR_SEEDS` | `56 17 23 31` | Ordered seeds to try. |
| `REUSE_SYNTHESIS` | `0` | Set to `1` to reuse the existing JSON netlist. |
| `ALLOW_TIMING_FAILURE` | `0` | Set to `1` to pack the best routed timing miss. |

A normal build:

```bash
./scripts/build-cpu-probe.sh
```

Retry routing without repeating synthesis:

```bash
REUSE_SYNTHESIS=1 \
NEXTPNR_SEEDS="47 73 101 127 257" \
    ./scripts/build-cpu-probe.sh
```

`REUSE_SYNTHESIS=1` skips both ROM regeneration and Yosys. Use it only when the
existing JSON netlist is known to match the intended generated ROM and RTL.

Each attempted seed receives its own report:

```text
build/nextpnr-seed-<seed>.log
```

The selected result is copied to:

```text
build/nextpnr.log
build/z386_ulx3s_cpu_probe.config
build/z386_ulx3s_cpu_probe.bit
```

A non-timing nextpnr error stops immediately. A normal timing miss advances to
the next seed. `ALLOW_TIMING_FAILURE=1` is an explicit diagnostic escape hatch,
not the validated default.

## `check-nettype.sh`

Checks HDL files for the repository's `default_nettype` policy and exits
nonzero when a violation is found.

Run it before committing changes to Verilog or SystemVerilog:

```bash
./scripts/check-nettype.sh
```

This is a source-hygiene check; it does not synthesize the design.

## `create-patch.sh`

Recreates the compatibility patch under `patches/z386/` from changes in the
nested z386 source checkout.

```bash
./scripts/create-patch.sh
```

The three original compatibility changes have now been merged upstream, so a
current recursive submodule checkout should not need this patch. Keep the
script for reproducing an older pinned revision or preparing a future narrowly
scoped upstream compatibility patch.

Before running it, inspect the nested checkout and ensure it contains only the
intended changes:

```bash
git -C third_party/z386_MiSTer/src/z386 status --short
git -C third_party/z386_MiSTer/src/z386 diff --check
```

Review the generated patch before committing it.

## `full-clean.sh`

Safely removes the repository's generated top-level `build/` directory:

```bash
./scripts/full-clean.sh
```

The script verifies the resolved path before using `rm -rf`. It does not remove
tracked source files such as:

```text
rom/shift_regression.asm
rtl/generated/shift_regression_probe_rom.v
```

The Makefile wrapper is:

```bash
make clean
```

## `load-bitstream.sh`

Loads an ECP5 bitstream into ULX3S SRAM.

Default bitstream:

```bash
./scripts/load-bitstream.sh
```

Equivalent path:

```text
build/z386_ulx3s_cpu_probe.bit
```

Load another bitstream:

```bash
./scripts/load-bitstream.sh path/to/another.bit
```

The script prefers `openFPGALoader` when it is available in `PATH`; otherwise it
uses `fujprog`. It fails rather than silently continuing when the selected file
or both programmer tools are missing.

The Makefile wrapper is:

```bash
make load
```

## `setup-submodules.sh`

Adds the upstream `z386_MiSTer` repository as a submodule when it is not already
tracked, or synchronizes and initializes the existing recursive submodule tree.

```bash
./scripts/setup-submodules.sh
```

The script verifies that the nested CPU source exists at:

```text
third_party/z386_MiSTer/src/z386/z386.sv
```

It also prints recursive submodule status for reproducibility. The Makefile
wrapper is:

```bash
make setup
```

Current upstream revisions already contain the three bring-up fixes; normal
setup must not reapply the former compatibility patch.

## Validation helpers

Check shell syntax:

```bash
bash -n scripts/*.sh
```

Check Python syntax:

```bash
python3 -m py_compile scripts/bin-to-probe-rom.py
```

Check trailing whitespace in generated Verilog:

```bash
if grep -nE '[[:blank:]]+$' rtl/generated/*.v; then
    printf 'Generated Verilog contains trailing whitespace.\n' >&2
    exit 1
fi
```
