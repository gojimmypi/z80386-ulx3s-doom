#!/usr/bin/env python3
"""Generate a standalone Verilog-2001 ROM module from selected binary ranges."""

from __future__ import annotations

import argparse
from dataclasses import dataclass
import hashlib
from pathlib import Path
import re


@dataclass(frozen=True)
class Mapping:
    binary_offset: int
    physical_address: int
    length: int | None


def parse_integer(text: str, what: str) -> int:
    try:
        value = int(text, 0)
    except ValueError as exc:
        raise argparse.ArgumentTypeError(f"invalid {what}: {text!r}") from exc
    if value < 0:
        raise argparse.ArgumentTypeError(f"{what} must not be negative: {text!r}")
    return value


def parse_map(text: str) -> Mapping:
    parts = text.split(":")
    if len(parts) not in (2, 3):
        raise argparse.ArgumentTypeError(
            "mapping must be BINARY_OFFSET:PHYSICAL_ADDRESS[:LENGTH]"
        )

    binary_offset = parse_integer(parts[0], "binary offset")
    physical_address = parse_integer(parts[1], "physical address")
    length = parse_integer(parts[2], "mapping length") if len(parts) == 3 else None

    if binary_offset & 3:
        raise argparse.ArgumentTypeError(
            f"binary offset must be DWORD-aligned: 0x{binary_offset:x}"
        )
    if physical_address & 3:
        raise argparse.ArgumentTypeError(
            f"physical address must be DWORD-aligned: 0x{physical_address:x}"
        )
    if physical_address > 0xFFFF_FFFF:
        raise argparse.ArgumentTypeError(
            f"physical address exceeds 32 bits: 0x{physical_address:x}"
        )
    if length == 0:
        raise argparse.ArgumentTypeError("mapping length must be greater than zero")

    return Mapping(binary_offset, physical_address, length)


def parse_identifier(text: str) -> str:
    if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_$]*", text):
        raise argparse.ArgumentTypeError(f"invalid Verilog identifier: {text!r}")
    return text


def format_verilog_hex(value: int, digits: int = 8) -> str:
    text = f"{value:0{digits}x}"
    return "_".join(text[index : index + 4] for index in range(0, len(text), 4))


def build_entries(
    binary: bytes,
    mappings: list[Mapping],
    pad_byte: int,
) -> list[tuple[int, int, int, bytes]]:
    entries: list[tuple[int, int, int, bytes]] = []
    occupied: dict[int, Mapping] = {}

    for mapping in mappings:
        if mapping.binary_offset >= len(binary):
            raise ValueError(
                "mapping starts beyond the end of the binary: "
                f"offset 0x{mapping.binary_offset:x}, binary size 0x{len(binary):x}"
            )

        available = len(binary) - mapping.binary_offset
        length = available if mapping.length is None else mapping.length
        if length > available:
            raise ValueError(
                "mapping extends beyond the end of the binary: "
                f"offset 0x{mapping.binary_offset:x}, length 0x{length:x}, "
                f"binary size 0x{len(binary):x}"
            )

        data = binary[mapping.binary_offset : mapping.binary_offset + length]
        padded_length = (len(data) + 3) & ~3
        data += bytes([pad_byte]) * (padded_length - len(data))

        for relative_offset in range(0, len(data), 4):
            physical_address = mapping.physical_address + relative_offset
            if physical_address > 0xFFFF_FFFC:
                raise ValueError(
                    "mapping exceeds the 32-bit physical address space: "
                    f"0x{physical_address:x}"
                )
            if physical_address in occupied:
                previous = occupied[physical_address]
                raise ValueError(
                    "physical mappings overlap at "
                    f"0x{physical_address:08x}: {previous} and {mapping}"
                )
            occupied[physical_address] = mapping

            word_bytes = data[relative_offset : relative_offset + 4]
            word = int.from_bytes(word_bytes, byteorder="little", signed=False)
            binary_offset = mapping.binary_offset + relative_offset
            entries.append((physical_address, word, binary_offset, word_bytes))

    return entries


def append_embedded_source(
    lines: list[str], source_name: str, source_text: str
) -> None:
    lines.append(f"// Source assembly: {source_name}")
    lines.append("//")
    lines.append("// ---- BEGIN SOURCE ASSEMBLY ----")
    for source_line in source_text.splitlines():
        lines.append(f"// | {source_line}")
    lines.append("// ---- END SOURCE ASSEMBLY ----")


def generate_module(
    binary_name: str,
    binary: bytes,
    source_name: str | None,
    source_text: str | None,
    module_name: str,
    function_name: str,
    address_port: str,
    data_port: str,
    default_word: int,
    entries: list[tuple[int, int, int, bytes]],
    mappings: list[Mapping],
) -> str:
    lines: list[str] = []
    lines.append("// Generated file. Do not edit by hand.")
    lines.append(f"// Source binary: {binary_name}")
    lines.append(f"// Binary SHA-256: {hashlib.sha256(binary).hexdigest()}")
    if source_name is not None and source_text is not None:
        lines.append(
            "// Assembly SHA-256: "
            f"{hashlib.sha256(source_text.encode('utf-8')).hexdigest()}"
        )
    lines.append("// Binary-to-physical mappings:")
    for mapping in mappings:
        length_text = (
            "to end of binary"
            if mapping.length is None
            else f"0x{mapping.length:x} bytes"
        )
        lines.append(
            "//   binary +0x"
            f"{mapping.binary_offset:08x} -> physical "
            f"0x{mapping.physical_address:08x}, {length_text}"
        )
    if source_name is not None and source_text is not None:
        lines.append("//")
        append_embedded_source(lines, source_name, source_text)
    lines.append("")
    lines.append(f"module {module_name} (")
    lines.append(f"    input  wire [31:0] {address_port},")
    lines.append(f"    output wire [31:0] {data_port}")
    lines.append(");")
    lines.append("")
    lines.append(f"function [31:0] {function_name};")
    lines.append("    input [31:0] address;")
    lines.append("    begin")
    lines.append("        case (address)")

    for physical_address, word, binary_offset, word_bytes in entries:
        byte_text = " ".join(f"{byte:02X}" for byte in word_bytes)
        lines.append(
            f"            32'h{format_verilog_hex(physical_address)}: "
            f"{function_name} = 32'h{format_verilog_hex(word)};  "
            f"// binary +0x{binary_offset:08x}: {byte_text}"
        )

    lines.append(
        f"            default: {function_name} = "
        f"32'h{format_verilog_hex(default_word)};"
    )
    lines.append("        endcase")
    lines.append("    end")
    lines.append("endfunction")
    lines.append("")
    lines.append(f"assign {data_port} = {function_name}({address_port});")
    lines.append("")
    lines.append("endmodule")
    lines.append("")
    return "\n".join(lines)


def build_argument_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Convert selected ranges of a flat x86 binary into a standalone "
            "Verilog-2001 combinational ROM module."
        )
    )
    parser.add_argument("--binary", required=True, type=Path, help="input flat binary")
    parser.add_argument("--output", required=True, type=Path, help="output .v file")
    parser.add_argument(
        "--map",
        dest="mappings",
        action="append",
        required=True,
        type=parse_map,
        metavar="OFFSET:ADDRESS[:LENGTH]",
        help=(
            "map a DWORD-aligned binary range to a DWORD-aligned 32-bit physical "
            "address; repeat for multiple regions"
        ),
    )
    parser.add_argument(
        "--module",
        required=True,
        type=parse_identifier,
        help="Verilog module name",
    )
    parser.add_argument(
        "--function",
        default="probe_read_data",
        type=parse_identifier,
        help="internal Verilog function name (default: probe_read_data)",
    )
    parser.add_argument(
        "--address-port",
        default="address",
        type=parse_identifier,
        help="address input port name (default: address)",
    )
    parser.add_argument(
        "--data-port",
        default="data",
        type=parse_identifier,
        help="data output port name (default: data)",
    )
    parser.add_argument(
        "--source-asm",
        type=Path,
        help="assembly source to embed as Verilog comments",
    )
    parser.add_argument(
        "--source-name",
        help="display name for the embedded assembly source",
    )
    parser.add_argument(
        "--default-word",
        default="0x90909090",
        help="word returned for unmapped addresses (default: 0x90909090)",
    )
    parser.add_argument(
        "--pad-byte",
        default="0x90",
        help="byte used to pad a final partial DWORD (default: 0x90)",
    )
    return parser


def main() -> int:
    parser = build_argument_parser()
    args = parser.parse_args()

    default_word = parse_integer(args.default_word, "default word")
    pad_byte = parse_integer(args.pad_byte, "pad byte")
    if default_word > 0xFFFF_FFFF:
        parser.error("--default-word must fit in 32 bits")
    if pad_byte > 0xFF:
        parser.error("--pad-byte must fit in 8 bits")

    try:
        binary = args.binary.read_bytes()
    except OSError as exc:
        parser.error(f"cannot read {args.binary}: {exc}")
    if not binary:
        parser.error(f"input binary is empty: {args.binary}")

    source_name: str | None = None
    source_text: str | None = None
    if args.source_asm is not None:
        try:
            source_text = args.source_asm.read_text(encoding="utf-8")
        except OSError as exc:
            parser.error(f"cannot read {args.source_asm}: {exc}")
        source_name = args.source_name or args.source_asm.name

    try:
        entries = build_entries(binary, args.mappings, pad_byte)
        output_text = generate_module(
            args.binary.name,
            binary,
            source_name,
            source_text,
            args.module,
            args.function,
            args.address_port,
            args.data_port,
            default_word,
            entries,
            args.mappings,
        )
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(output_text, encoding="utf-8", newline="\n")
    except (OSError, ValueError) as exc:
        parser.error(str(exc))

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
