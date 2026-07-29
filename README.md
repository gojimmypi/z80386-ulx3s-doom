# z386 on ULX3S

CPU-only z386 bring-up for the ULX3S 85F using the open ECP5 toolchain.
The CPU is taken from `nand2mario/z386_MiSTer` through recursive Git
submodules.

This milestone does not yet contain SDRAM, BIOS loading, VGA, IDE, audio,
FreeDOS, or Doom. It establishes that the patched z386 CPU can be synthesized,
placed, routed, loaded, reset deterministically, and execute a small 16-bit ROM
program on real ULX3S hardware.

## Current status

The initial hardware milestone is working on an ULX3S 85F.

The CPU successfully:

- releases from a deterministic `FIRE1` reset;
- fetches the reset vector at physical address `0xFFFFFFF0`;
- performs a far jump to `F000:0000`;
- executes a small 16-bit ROM program;
- writes to I/O port `0x0080`; and
- alternates the ULX3S LEDs between `0x55` and `0xAA`.

The visible success pattern is alternating even and odd LEDs:

```text
0x55 = 01010101
0xAA = 10101010
```

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
Reset input:        FIRE1 (`btn[1]`)
Expected output:    0x55 <-> 0xAA
```

Each cache uses four ways, 16-byte lines, and 16 sets:

```text
4 ways * 16 bytes * 16 sets = 1,024 bytes
```

## Repository layout

```text
constraints/ulx3s_v303_probe.lpf  Clock, LEDs, FIRE1 reset, and wifi_gpio0
rtl/z386_synth_probe.sv           Complete z386 CPU plus ROM and bus target
patches/z386/                      Temporary upstream compatibility fixes
scripts/setup-submodules.sh       Initializes recursive upstream submodules
scripts/build-cpu-probe.sh        Slang/Yosys + nextpnr-ecp5 + ecppack
scripts/load-bitstream.sh         Loads the generated bitstream into SRAM
scripts/full-clean.sh              Removes generated build output
```

The top level drives `wifi_gpio0` high so the onboard ESP32 does not interfere
with the FPGA configuration after loading.

## Requirements

Use a recent OSS CAD Suite or equivalent installation containing:

- Yosys with the `read_slang` command;
- nextpnr-ecp5;
- Project Trellis `ecppack`; and
- openFPGALoader or fujprog for loading the board.

`read_slang` is integrated into Yosys 0.67 and newer. Some installations expose
it through the `slang` plugin; the build script detects both forms.

When using a custom Yosys build, place it first in `PATH`:

```bash
export PATH="/path/to/yosys/bin:$PATH"
```

for example:

```
export PATH="/mnt/c/workspace/yosys/build-v0.67:$PATH"
```

The current build script rejects repository paths containing whitespace because
the generated Yosys command file uses unquoted path tokens.

## Submodules and required z386 fixes

Clone recursively:

```bash
git clone --recurse-submodules <repository-url>
cd z80386_ULX3S_Doom
```

For an existing clone:

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

The build can take a substantial amount of time. The longest synthesis and
routing phases may appear quiet, and nextpnr is largely single-threaded during
routing.

Generated files:

```text
build/z386_ulx3s_cpu_probe.json
build/z386_ulx3s_cpu_probe.config
build/z386_ulx3s_cpu_probe.bit
build/z386_ulx3s_cpu_probe.ys
build/yosys.log
build/nextpnr.log
```

The validated defaults are ULX3S 85F, 25 MHz, and seed 1. A different placement
seed can be tested with:

```bash
NEXTPNR_SEED=56 make probe
```

Higher frequency targets are experimental. The latest known-good build reports
a maximum frequency of 27.12 MHz, so 30 MHz is not currently a validated target.

The generated Yosys script uses:

```text
read_slang --allow-use-before-declare --no-implicit-memories \
    -DZ386_DISABLE_CACHE_RAM_HINTS ...

synth_ecp5 -noabc9 ...
```

ABC9 crashed on this netlist in Yosys 0.67. The working hardware build uses the
classic ABC mapper through `synth_ecp5 -noabc9`.

Confirm the expected mapper and reject known crash signatures:

```bash
grep -n "Executing ABC pass" build/yosys.log

! grep -Eq \
    'Executing ABC9|Assertion .* failed|Aborted \(core dumped\)|return code 134' \
    build/yosys.log

grep -n "Max frequency" build/nextpnr.log
```

The build script removes stale JSON, configuration, bitstream, and log files
before synthesis. A failed build should therefore not leave an old bitstream
appearing to be current.

## Latest measured implementation

The latest known-good 25 MHz, seed-1, classic-ABC build reported:

```text
Total LUT4s:        60,701 / 83,640   72%
  logic LUTs:       58,633 / 83,640   70%
  carry LUTs:        2,068 / 83,640    2%
TRELLIS_COMB:       61,127 / 83,640   73%
TRELLIS_FF:         26,408 / 83,640   31%
DP16KD:                  6 / 208       2%
MULT18X18D:              2 / 156       1%
Maximum frequency:  27.12 MHz
Timing at 25 MHz:   PASS
```

These values describe the CPU-only wrapper with 1 KiB instruction and data
caches. The later SDRAM, VGA, IDE, audio, BIOS, and system integration will add
resources. LUT headroom is therefore limited and must be considered in the next
milestones.

## Load

Use the project target:

```bash
make load
```

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

For the known ULX3S 85F board, do not use that identification string to infer
the FPGA density selected by the build. This project explicitly uses
`nextpnr-ecp5 --85k --package CABGA381`.

## Reset and expected behavior

FIRE1 is the dedicated active-high CPU reset. It asserts reset asynchronously
and releases it synchronously after 16 clock cycles.

After programming:

1. Hold FIRE1 briefly.
2. Release FIRE1.
3. Observe alternating even and odd LEDs.

Do not use the ULX3S power button as the CPU reset for this probe.

The reset-vector ROM first writes `0xFF` to port `0x0080`, then immediately
jumps to the longer program at `F000:0000`. The `0xFF` value lasts for only a
few processor cycles and is not expected to be visible. The observable success
pattern is `0x55`, `0xAA`, `0x55`, `0xAA`, and so on.

## LED diagnostics

Before the first successful I/O write, the LEDs show diagnostic state:

| LED | Meaning |
|---:|---|
| D7 | FPGA clock heartbeat |
| D6 | CPU reset released |
| D5 | Triple fault observed |
| D4 | Demo ROM fetch at `0x000F0000` observed |
| D3 | Reset-vector fetch at `0xFFFFFFF0` observed |
| D2 | Read response returned |
| D1 | Bus request accepted |
| D0 | FIRE1 held |

After the first successful write to port `0x0080`, all eight LEDs display the
x86 output byte instead of the diagnostic map.

Useful signatures:

```text
FIRE1 held:
    D0 is on and D7 continues blinking. CPU diagnostic state is cleared.

D7 blinking; D6, D3, D2, and D1 on; D5 and D4 off:
    Reset released and the reset-vector transaction completed, but no x86
    output was observed. This was the signature of the missing halted reset.

Alternating even and odd LEDs:
    Complete CPU blinky success: 0x55 <-> 0xAA.
```

## What this milestone proves

A successful build proves that the patched CPU can be elaborated, synthesized,
placed, routed, and packed by the selected open ECP5 toolchain.

The alternating `0x55`/`0xAA` hardware result additionally proves that the CPU:

- exits reset;
- fetches and decodes instructions;
- starts its instruction and microcode execution paths;
- executes the small reset ROM, including arithmetic and branches; and
- performs external port-I/O writes through the ready/valid bus interface.

It does not yet prove:

- complete x86 compatibility;
- every shift and rotate corner case;
- SDRAM operation;
- interrupt, paging, or protected-mode operation;
- BIOS compatibility; or
- VGA, IDE, audio, FreeDOS, or Doom operation.

## Next validation and system milestones

Preserve `make probe` as the known-good `0x55`/`0xAA` hardware milestone.
The focused shifter regression should use a separate top level, build target,
and output bitstream rather than replacing this probe. It should exercise
`SHL`, `SHR`, `SAR`, `ROL`, `ROR`, `RCL`, `RCR`, `SHLD`, `SHRD`, and `BSR`,
including counts 0, 1, operand width, and operand width plus one where the
instruction has a count operand.

After the focused CPU regressions, the next system milestone is an ULX3S SDRAM
test wrapper using the z386 ready/valid memory bus. Only after that should the
full `src/system.sv` PC chipset be integrated.

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
