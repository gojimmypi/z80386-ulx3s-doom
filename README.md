# z386 on ULX3S

CPU-only z386 bring-up and focused instruction regression for the ULX3S 85F
using the open ECP5 toolchain. The CPU is taken from
`nand2mario/z386_MiSTer` through recursive Git submodules.

This milestone does not yet contain SDRAM, BIOS loading, VGA, IDE, audio,
FreeDOS, or Doom. It establishes that the z386 CPU can be synthesized, placed,
routed, loaded, reset deterministically, and execute a generated 16-bit ROM
regression on real ULX3S hardware.

## Current status

The focused CPU regression passes on an ULX3S 85F.

The CPU successfully:

- releases from a deterministic `FIRE1` reset;
- fetches the reset vector at physical address `0xFFFFFFF0`;
- performs a far jump to `F000:0000`;
- executes a 16-bit x86 regression ROM generated from assembly source;
- writes progress, failure, and success values to I/O port `0x0080`; and
- completes the focused shift, rotate, and bit-scan regression.

The regression exercises:

- `SHL`, `SHR`, and `SAR`;
- `ROL`, `ROR`, `RCL`, and `RCR`;
- `SHLD` and `SHRD`;
- `BSR`; and
- counts 0, 1, operand width, and operand width plus one where applicable.

The visible success pattern alternates between:

```text
0xA5 = 10100101 = D7, D5, D2, D0 on
0x5A = 01011010 = D6, D4, D3, D1 on
```

A stable value from `0x01` through `0x29` identifies the first failing test.

## Known-good configuration

```text
Board:              ULX3S 85F
FPGA:               ECP5-85K
Package:            CABGA381
Input clock:        25 MHz
Timing target:      25 MHz
I-cache:            1 KiB
D-cache:            1 KiB
Mapper:             classic ABC (`synth_ecp5 -noabc9`)
Validated seed:     56
Maximum frequency:  26.03 MHz
Reset input:        FIRE1 (`btn[1]`)
Expected output:    0xA5 <-> 0x5A
```

Each cache uses four ways, 16-byte lines, and 16 sets:

```text
4 ways * 16 bytes * 16 sets = 1,024 bytes
```

## Repository layout

```text
constraints/ulx3s_v303_probe.lpf
    Clock, LEDs, FIRE1 reset, and wifi_gpio0 constraints.

rom/shift_regression.asm
    Authoritative 16-bit x86 focused regression source.

rtl/z386_synth_probe.sv
    ULX3S top level, z386 instance, ready/valid target, and LED diagnostics.

rtl/generated/shift_regression_probe_rom.v
    Generated plain-Verilog ROM module. Do not edit it by hand.

patches/z386/
    Compatibility patch material retained for older upstream revisions.

scripts/
    Setup, ROM generation, build, timing, programming, and cleanup tools.
    See scripts/README.md.

third_party/z386_MiSTer/
    Upstream MiSTer project and nested z386 source submodule.

build/
    Generated objects, binaries, netlists, reports, routed configurations,
    and bitstreams. This directory is ignored by Git.
```

The top level drives `wifi_gpio0` high so the onboard ESP32 does not interfere
with the FPGA configuration after loading.

## Requirements

Use a recent OSS CAD Suite or equivalent installation containing:

- Yosys with the `read_slang` command;
- nextpnr-ecp5;
- Project Trellis `ecppack`;
- GNU x86 binutils: `as`, `objcopy`, and `objdump`;
- Python 3; and
- openFPGALoader or fujprog for loading the board.

`read_slang` is integrated into Yosys 0.67 and newer. Some installations expose
it through the `slang` plugin; the build script detects both forms.

When using a custom Yosys build, place it first in `PATH`:

```bash
export PATH="/path/to/yosys/bin:$PATH"
```

For example:

```bash
export PATH="/mnt/c/workspace/yosys/build-v0.67:$PATH"
```

The current synthesis script rejects repository paths containing whitespace
because the generated Yosys command file uses unquoted path tokens.

## Clone and initialize submodules

Clone recursively:

```bash
git clone --recurse-submodules <repository-url>
cd z80386_ULX3S_Doom
```

For an existing clone:

```bash
./scripts/setup-submodules.sh
```

Or individually:

```bash
git submodule sync --recursive
git submodule update --init --recursive
```

The temporary compatibility patch must currently be applied:

```text
patches/z386/0001-z386-yosys-slang-compat.patch
```

The patch was created with:

```bash
 ./scripts/create-patch.sh
```

It must provide all three changes:

1. Clear `halted` during CPU reset. Without this, the reset-vector fetch can
   complete while instruction execution remains disabled.
2. Use a nonblocking assignment for the registered `shift_size` value.
3. Allow the cache RAM attributes to be disabled with
   `Z386_DISABLE_CACHE_RAM_HINTS` for the current Slang/Yosys flow.

Relevant upstream pull requests:

- [Fix assignment operator for shift_size z386#2](https://github.com/nand2mario/z386/pull/2)
- [Introduce Z386_DISABLE_CACHE_RAM_HINTS z386#3](https://github.com/nand2mario/z386/pull/3)
- [Clear halted register during reset z386#4](https://github.com/nand2mario/z386/pull/4)

The patch is applied automatically in the submodule setup:

```
./scripts/setup-submodules.sh
```

Verify the required source state before a long build:

```bash
grep -n "halted <= 1'b0" \
    third_party/z386_MiSTer/src/z386/z386.sv

grep -n "shift_size <= count_raw" \
    third_party/z386_MiSTer/src/z386/z386.sv

grep -n "Z386_DISABLE_CACHE_RAM_HINTS" \
    third_party/z386_MiSTer/src/z386/l1_cache.sv \
    third_party/z386_MiSTer/src/z386/l1_icache.sv
```

## Build

For a clean build:

```bash
make clean
make probe
```

`make probe` performs these stages:

1. Assemble `rom/shift_regression.asm`.
2. Generate `rtl/generated/shift_regression_probe_rom.v`.
3. Elaborate and synthesize z386 with Slang and classic ABC.
4. Try nextpnr seeds until one meets the 25 MHz timing target.
5. Pack the selected configuration into an ECP5 bitstream.

The build can take a substantial amount of time. Synthesis and routing may
appear quiet for long periods, and nextpnr is largely single-threaded during
routing.

Important generated files:

```text
build/rom/shift_regression/shift_regression.o
build/rom/shift_regression/shift_regression.bin
build/rom/shift_regression/shift_regression.disasm.txt
build/rom/shift_regression/shift_regression.listing.txt
build/rom/shift_regression/shift_regression.relocations.txt
build/z386_ulx3s_cpu_probe.json
build/z386_ulx3s_cpu_probe.config
build/z386_ulx3s_cpu_probe.bit
build/z386_ulx3s_cpu_probe.ys
build/yosys.log
build/nextpnr.log
build/nextpnr-seed-<seed>.log
```

The default seed list is:

```text
56 17 23 31
```

Override it with:

```bash
NEXTPNR_SEEDS="47 73 101 127 257" make probe
```

The first seed may also be selected through `NEXTPNR_SEED`:

```bash
NEXTPNR_SEED=56 make probe
```

To retry place-and-route without repeating a valid synthesis:

```bash
REUSE_SYNTHESIS=1 \
NEXTPNR_SEEDS="47 73 101 127 257" \
    make probe
```

`REUSE_SYNTHESIS=1` also skips ROM regeneration. Use it only when the existing
JSON netlist already corresponds to the intended generated ROM and RTL.

To explicitly pack the best routed result even when no requested seed meets
timing:

```bash
REUSE_SYNTHESIS=1 \
ALLOW_TIMING_FAILURE=1 \
    make probe
```

A timing-failing bitstream is not the validated default and should be used only
for deliberate investigation.

The generated Yosys script uses:

```text
read_slang --allow-use-before-declare --no-implicit-memories \
    -DZ386_DISABLE_CACHE_RAM_HINTS ...

synth_ecp5 -noabc9 ...
```

ABC9 crashed on this netlist in Yosys 0.67. The working hardware build uses the
classic ABC mapper through `synth_ecp5 -noabc9`.

Confirm the expected mapper and timing result:

```bash
grep -n "Executing ABC pass" build/yosys.log

! grep -Eq \
    'Executing ABC9|Assertion .* failed|Aborted \(core dumped\)|return code 134' \
    build/yosys.log

grep -n "Max frequency" build/nextpnr.log
```

The build removes stale routed configurations, bitstreams, and nextpnr logs
before routing. A failed build should therefore not leave an old bitstream
appearing to be current.

## Latest measured implementation

The validated focused-regression build used classic ABC, nextpnr seed 56, and a
25 MHz timing target:

```text
Total LUT4s:        60,434 / 83,640   72%
TRELLIS_COMB:       60,860 / 83,640   72%
TRELLIS_FF:         26,408 / 83,640   31%
DP16KD:                  6 / 208       2%
MULT18X18D:              2 / 156       1%
Maximum frequency:  26.03 MHz
Timing at 25 MHz:   PASS
Hardware regression: PASS, 0xA5 <-> 0x5A
```

These values describe the CPU-only wrapper with 1 KiB instruction and data
caches and the generated regression ROM. SDRAM, VGA, IDE, audio, BIOS, and
system integration will add resources. LUT headroom is limited and must be
considered in later milestones.

## Load

Use the project target:

```bash
make load
```

Or specify another bitstream directly:

```bash
./scripts/load-bitstream.sh path/to/file.bit
```

The script uses openFPGALoader when available and otherwise uses `fujprog` from
`PATH`.


Or invoke fujprog directly:

```bash
FUJPROG=/path/to/fujprog-v48-win64.exe
"$FUJPROG" ./build/z386_ulx3s_cpu_probe.bit
```

for example:

```
/mnt/c/workspace/Hazard-Holding/Hazard3-Doom/bin/fujprog-v48-win64.exe ./build/z386_ulx3s_cpu_probe.bit
```

Some programmer firmware prints a cable identification such as:

```text
Using USB cable: ULX3S FPGA 12K v3.0.3
```

For the known ULX3S 85F board, do not use that cable identification string to
infer the FPGA density selected by the build. This project explicitly uses
`nextpnr-ecp5 --85k --package CABGA381`.

## Reset and expected behavior

FIRE1 is the dedicated active-high CPU reset. It asserts reset asynchronously
and releases it synchronously after 16 clock cycles.

After programming:

1. Hold FIRE1 briefly.
2. Confirm D7 continues blinking while reset is held.
3. Release FIRE1.
4. Observe the regression result on all eight LEDs.

Do not use the ULX3S power button as the CPU reset for this probe.

Success alternates between `0xA5` and `0x5A`. A stable value from `0x01`
through `0x29` is a regression failure code.

## LED diagnostics

Before the first successful I/O write, the LEDs show diagnostic state:

| LED | Meaning |
|---:|---|
| D7 | FPGA clock heartbeat |
| D6 | CPU reset released |
| D5 | Triple fault observed |
| D4 | Regression ROM fetch at `0x000F0000` observed |
| D3 | Reset-vector fetch at `0xFFFFFFF0` observed |
| D2 | Read response returned |
| D1 | Bus request accepted |
| D0 | FIRE1 held |

After the first write to port `0x0080`, all eight LEDs display the x86 output
byte instead of the diagnostic map.

Regression code ranges:

| Code | Test group |
|---:|---|
| `0x01`-`0x04` | `SHL`, counts 0, 1, 16, 17 |
| `0x05`-`0x08` | `SHR`, counts 0, 1, 16, 17 |
| `0x09`-`0x0C` | `SAR`, counts 0, 1, 16, 17 |
| `0x0D`-`0x10` | `ROL`, counts 0, 1, 16, 17 |
| `0x11`-`0x14` | `ROR`, counts 0, 1, 16, 17 |
| `0x15`-`0x18` | `RCL`, counts 0, 1, 16, 17 |
| `0x19`-`0x1C` | `RCR`, counts 0, 1, 16, 17 |
| `0x1D`-`0x20` | `SHLD`, counts 0, 1, 16, 17 |
| `0x21`-`0x24` | `SHRD`, counts 0, 1, 16, 17 |
| `0x25`-`0x29` | `BSR`, zero and selected highest-set-bit positions |

Useful signatures:

```text
FIRE1 held:
    D0 is on and D7 continues blinking. CPU diagnostic state is cleared.

Stable 0x01 through 0x29:
    The focused regression stopped at that test number.

Alternating D7,D5,D2,D0 and D6,D4,D3,D1:
    Complete focused regression success: 0xA5 <-> 0x5A.
```

## What this milestone proves

A successful build proves that the CPU and generated ROM can be elaborated,
synthesized, placed, routed, and packed by the selected open ECP5 toolchain.

The `0xA5`/`0x5A` hardware result additionally proves that the CPU:

- exits reset;
- fetches and decodes instructions;
- executes the reset vector and far jump;
- performs external port-I/O writes through the ready/valid bus interface; and
- passes the included shift, rotate, double-shift, and bit-scan checks.

It does not yet prove:

- complete x86 compatibility;
- all operand sizes, addressing modes, or flag combinations;
- SDRAM operation;
- interrupt, paging, or protected-mode operation;
- BIOS compatibility; or
- VGA, IDE, audio, FreeDOS, or Doom operation.

## Next validation and system milestones

Preserve the current focused CPU regression as a known-good hardware target.
The next system milestone is an ULX3S SDRAM test wrapper using the z386
ready/valid memory bus. Only after that should the full `src/system.sv` PC
chipset be integrated.

## Reproducibility information

Record the exact source and tool versions with each milestone:

```bash
git rev-parse HEAD
git submodule status --recursive
yosys -V
nextpnr-ecp5 --version
ecppack --version 2>/dev/null || true
```

Upstream projects remain recursive Git submodules and retain their respective
licenses. Review the upstream license files before redistributing source or
binary deliverables.
