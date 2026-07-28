.DEFAULT_GOAL := help

.PHONY: help setup probe load clean

help:
	@printf '%s\n' \
		'z386 ULX3S initial targets:' \
		'  make setup  Add/update the recursive z386_MiSTer submodule' \
		'  make probe  Synthesize, place, route, and pack the CPU-only probe' \
		'  make load   Load build/z386_ulx3s_cpu_probe.bit into SRAM' \
		'  make clean  Remove generated build output'

setup:
	./scripts/setup-submodules.sh

probe:
	./scripts/build-cpu-probe.sh

load:
	./scripts/load-bitstream.sh

clean:
	./scripts/full-clean.sh
