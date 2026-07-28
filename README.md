# z386 on ULX3S

Initial ULX3S 85F bring-up scaffold for the z386 CPU used by
`nand2mario/z386_MiSTer`.

This first milestone is intentionally a **CPU-only synthesis and hardware
probe**. It does not yet contain SDRAM, BIOS loading, VGA, IDE, FreeDOS, or
Doom. Its purpose is to answer the first hard questions with the open ECP5
flow:

1. Can the current z386 SystemVerilog elaborate through `read_slang`?
2. Does the CPU with 8 KiB instruction and data caches fit the ECP5-85F?
3. What resource use and achievable frequency does nextpnr report?
4. Can the resulting bitstream execute a tiny reset-vector loop on ULX3S?

No upstream RTL is copied into this repository. The MiSTer project and its
nested z386 core are recursive Git submodules while licensing is being
clarified.

## Files

```text
constraints/ulx3s_v303_probe.lpf  Minimal clock, LEDs, and buttons
rtl/z386_synth_probe.sv           Complete z386 CPU plus synthetic bus target
scripts/setup-submodules.sh       Adds/updates recursive upstream submodules
scripts/build-cpu-probe.sh        Yosys/read_slang + nextpnr-ecp5 + ecppack
scripts/load-bitstream.sh         Loads the generated bitstream into SRAM
scripts/full-clean.sh              Removes generated build output
```

## Requirements

Use a recent OSS CAD Suite or equivalent installation containing:

- Yosys with the `read_slang` command
- nextpnr-ecp5
- Project Trellis `ecppack`
- openFPGALoader or fujprog for loading the board

`read_slang` is integrated into Yosys 0.67 and newer. Some older OSS CAD Suite
releases provide it through the `slang` plugin; the build script detects both
forms.

If using a special build of `yosys`, ensure it is in the path:

```
export PATH="/mnt/c/workspace/yosys/build-v0.67:$PATH"
```

The [patch](./patches/z386/0001-z386-yosys-slang-compat.patch) MUST be applied at this time.

There are pull requests to address each:

- [Fix assignment operator for shift_size z386#2](https://github.com/nand2mario/z386/pull/2)
- [Introduce Z386_DISABLE_CACHE_RAM_HINTS z386#3](https://github.com/nand2mario/z386/pull/3)
- [Clear halted register during reset z386#4](https://github.com/nand2mario/z386/pull/4)

## Initial setup

Extract these files into a new Git repository, then run:

```bash
git init
git add .
git commit -m "Add initial z386 ULX3S CPU probe"
make setup
git add .gitmodules third_party/z386_MiSTer
git commit -m "Add z386 MiSTer submodule"
```

The first commit before `make setup` is recommended because Git requires the
working tree to exist, but it is not otherwise special.

## Build

```bash
make probe
```

Generated files:

```text
build/z386_ulx3s_cpu_probe.json
build/z386_ulx3s_cpu_probe.config
build/z386_ulx3s_cpu_probe.bit
build/yosys.log
build/nextpnr.log
```

Optional build settings:

```bash
NEXTPNR_SEED=56 make probe
FREQ_MHZ=30 NEXTPNR_SEED=56 make probe
```

The default is deliberately conservative: ULX3S 85F, 25 MHz, seed 1.

## Load

```bash
make load
```

The synthetic bus returns `EB FE` at physical address `0xfffffff0`, which is an
x86 short jump back to itself. The CPU should therefore remain alive at the
reset vector while repeatedly exercising its fetch path.

## LED map

| LED | Meaning |
|---:|---|
| 0 | CPU reset released |
| 1 | Bus request valid |
| 2 | Bus request accepted |
| 3 | Read response valid |
| 4 | I/O request |
| 5 | Write request |
| 6 | Triple-fault reset requested |
| 7 | Accepted-request heartbeat |

The power button holds the CPU in reset. FIRE1 injects an interrupt, FIRE2
injects an NMI, UP requests single-step, DOWN disables A20 while held, and LEFT
injects a cache snoop event. RIGHT inverts the heartbeat LED for a simple input
check.

## What this result will and will not prove

A successful build proves that the CPU can be elaborated and implemented with
the ECP5 toolchain. The resource result is an early estimate, not yet the final
PC-system number: constant peripheral inputs and the synthetic memory target
may allow some optimization, while the later SDRAM, VGA, IDE, audio, and boot
logic will add resources.

The next milestone after a successful fit is an ULX3S SDRAM test wrapper using
the z386 ready/valid memory bus. Only after that should we integrate the full
`src/system.sv` PC chipset.
