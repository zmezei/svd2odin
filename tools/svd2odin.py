#!/usr/bin/env python3
"""
svd2odin.py — CMSIS-SVD to Odin register definition generator

Usage:
    python3 svd2odin.py <input.svd> <output.odin> [--package <name>]

Parses a CMSIS-SVD XML file and generates Odin source with:
  - Peripheral base address constants
  - Register structs with correct field offsets
  - Field bit-position and mask constants
  - Enumerated values as Odin enum types
  - Peripheral instance pointers

The output is generated code — do not edit by hand.
Re-run the script when the SVD file changes.
"""

import argparse
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path


def sanitize_odin_identifier(name: str) -> str:
    """Convert SVD names to valid Odin identifiers."""
    # Odin identifiers: letters, digits, underscore. Must not start with digit.
    result = re.sub(r"[^A-Za-z0-9_]", "_", name)
    if result and result[0].isdigit():
        result = "_" + result
    return result


def parse_int(text: str) -> int:
    """Parse an SVD integer value (hex, decimal, or with # prefix)."""
    text = text.strip()
    if text.startswith("0x") or text.startswith("0X"):
        return int(text, 16)
    if text.startswith("#"):
        return int(text[1:], 16)
    if text.startswith("0b") or text.startswith("0B"):
        return int(text, 2)
    return int(text)


def get_text(elem: ET.Element, tag: str, default: str = "") -> str:
    child = elem.find(tag)
    if child is not None and child.text:
        return child.text.strip()
    return default


def get_int(elem: ET.Element, tag: str, default: int = 0) -> int:
    text = get_text(elem, tag)
    if text:
        return parse_int(text)
    return default


def get_description(elem: ET.Element) -> str:
    desc = get_text(elem, "description")
    if not desc:
        return ""
    # Clean up whitespace
    desc = re.sub(r"\s+", " ", desc).strip()
    # Truncate long descriptions
    if len(desc) > 120:
        desc = desc[:117] + "..."
    return desc


class FieldInfo:
    def __init__(self, name, bit_offset, bit_width, description, enumerated_values=None):
        self.name = name
        self.bit_offset = bit_offset
        self.bit_width = bit_width
        self.description = description
        self.enumerated_values = enumerated_values or []


class EnumValue:
    def __init__(self, name, value, description):
        self.name = name
        self.value = value
        self.description = description


class RegisterInfo:
    def __init__(self, name, description, offset, size, access, reset_value, fields):
        self.name = name
        self.description = description
        self.offset = offset
        self.size = size  # in bits (8, 16, 32)
        self.access = access
        self.reset_value = reset_value
        self.fields = fields


class PeripheralInfo:
    def __init__(self, name, description, base_address, group_name, registers):
        self.name = name
        self.description = description
        self.base_address = base_address
        self.group_name = group_name
        self.registers = registers


def parse_enumerated_values(elem: ET.Element) -> list[EnumValue]:
    values = []
    for ev in elem.findall(".//enumeratedValue"):
        name = get_text(ev, "name")
        value_text = get_text(ev, "value")
        desc = get_description(ev)
        if name and value_text and name not in ("reserved", "Reserved"):
            try:
                value = parse_int(value_text)
                values.append(EnumValue(sanitize_odin_identifier(name), value, desc))
            except ValueError:
                pass
    return values


def parse_fields(reg_elem: ET.Element) -> list[FieldInfo]:
    fields = []
    for f in reg_elem.findall(".//field"):
        name = get_text(f, "name")
        if not name:
            continue
        bit_offset = get_int(f, "bitOffset")
        bit_width = get_int(f, "bitWidth", 1)
        desc = get_description(f)
        enum_values = parse_enumerated_values(f)
        fields.append(FieldInfo(
            sanitize_odin_identifier(name),
            bit_offset,
            bit_width,
            desc,
            enum_values,
        ))
    return fields


def parse_registers(periph_elem: ET.Element) -> list[RegisterInfo]:
    registers = []
    for reg in periph_elem.findall(".//register"):
        name = get_text(reg, "name")
        if not name:
            continue
        desc = get_description(reg)
        offset = get_int(reg, "addressOffset")
        size = get_int(reg, "size", 32)
        access = get_text(reg, "access", "read-write")
        reset_value = get_int(reg, "resetValue", 0)
        fields = parse_fields(reg)
        registers.append(RegisterInfo(
            sanitize_odin_identifier(name),
            desc,
            offset,
            size,
            access,
            reset_value,
            fields,
        ))
    return registers


def derive_group_name(name: str, group: str) -> str:
    """Derive a group name from the peripheral name if the SVD doesn't provide one.

    SVD files are inconsistent — some GPIO ports have groupName=GPIO, others
    have no groupName at all. We normalize by stripping trailing digits and
    a single trailing uppercase letter from the peripheral name.

    Rules:
    - If the SVD provides a groupName, use it.
    - Strip trailing digits: TIM2 -> TIM, USART2 -> USART
    - Strip a single trailing uppercase letter ONLY if digits were stripped
      and the remaining name is all uppercase: GPIOB -> GPIO, GPIOF -> GPIO
    - Don't strip letters if no digits were present: TIM -> TIM (not TI)
    """
    if group:
        return sanitize_odin_identifier(group)
    # Strip trailing digits
    base = re.sub(r"\d+$", "", name)
    if base != name:
        # Digits were stripped — now strip a single trailing uppercase letter
        # only if the entire remaining string is uppercase (e.g., GPIOB -> GPIO)
        if base and base.isupper() and len(base) > 2:
            base = base[:-1]
    return sanitize_odin_identifier(base) if base else sanitize_odin_identifier(name)


def parse_peripherals(root: ET.Element) -> list[PeripheralInfo]:
    # First pass: collect all peripherals with their raw XML elements
    # so we can resolve derivedFrom references
    raw_peripherals = {}
    order = []
    for p in root.findall(".//peripheral"):
        name = get_text(p, "name")
        if not name:
            continue
        raw_peripherals[name] = p
        order.append(name)

    # Second pass: parse with derivedFrom resolution
    peripherals = []
    for name in order:
        p = raw_peripherals[name]
        derived_from = p.get("derivedFrom")

        desc = get_description(p)
        base = get_int(p, "baseAddress")
        group = get_text(p, "groupName")
        registers = parse_registers(p)

        # If this peripheral derives from another, inherit missing fields
        if derived_from and derived_from in raw_peripherals:
            base_p = raw_peripherals[derived_from]
            if not desc:
                desc = get_description(base_p)
            if not group:
                group = get_text(base_p, "groupName")
            if not registers:
                registers = parse_registers(base_p)
            # baseAddress is always overridden by the derived peripheral
            if base == 0:
                base = get_int(base_p, "baseAddress")

        peripherals.append(PeripheralInfo(
            sanitize_odin_identifier(name),
            desc,
            base,
            derive_group_name(name, group),
            registers,
        ))
    return peripherals


def odin_type_for_size(size_bits: int) -> str:
    if size_bits <= 8:
        return "u8"
    elif size_bits <= 16:
        return "u16"
    elif size_bits <= 32:
        return "u32"
    elif size_bits <= 64:
        return "u64"
    return "u32"


def odin_access_comment(access: str) -> str:
    mapping = {
        "read-only": "RO",
        "write-only": "WO",
        "read-write": "RW",
        "writeOnce": "WO",
        "read-writeOnce": "RW",
    }
    return mapping.get(access, "RW")


def is_all_single_bit(reg: RegisterInfo) -> bool:
    """True if the register has fields and every field is exactly 1 bit wide."""
    return bool(reg.fields) and all(f.bit_width == 1 for f in reg.fields)


def generate_peripheral(p: PeripheralInfo, group_name: str = None) -> str:
    lines = []

    # Use group name for the struct, peripheral name for everything else
    struct_base = group_name if group_name else p.name
    field_prefix_base = group_name if group_name else p.name

    # Header comment
    if p.description:
        lines.append(f"// ── {p.name}: {p.description} ──")
    else:
        lines.append(f"// ── {p.name} ──")
    lines.append("")

    # Base address
    lines.append(f"{p.name}_BASE :: 0x{p.base_address:08X}")
    lines.append("")

    # For registers composed entirely of 1-bit flags, generate a Flag enum
    # and a bit_set type alias so the struct field can be type-safe.
    bit_set_types: dict[str, str] = {}  # reg.name -> set_type_name
    for reg in p.registers:
        if not is_all_single_bit(reg):
            continue
        flag_name = f"{field_prefix_base}_{reg.name}_Flag"
        set_name = f"{field_prefix_base}_{reg.name}_Set"
        bit_set_types[reg.name] = set_name

        backing_type = odin_type_for_size(reg.size)
        lines.append(f"{flag_name} :: enum {backing_type} {{")
        for f in reg.fields:
            lines.append(f"    {f.name} = {f.bit_offset},")
        lines.append("}")
        lines.append("")
        lines.append(f"{set_name} :: bit_set[{flag_name}; {backing_type}]")
        lines.append("")

    # Register struct — named after the group so shared peripherals reuse it
    struct_name = f"{struct_base}_Reg"
    lines.append(f"{struct_name} :: struct {{")
    prev_offset = 0
    for reg in p.registers:
        # Skip registers that overlap with the previous one (alternate views
        # of the same physical register, e.g. CCMR1_Output vs CCMR1_Input)
        if reg.offset < prev_offset:
            continue
        # Insert padding if there are gaps
        gap = reg.offset - prev_offset
        if gap > 0 and prev_offset > 0:
            lines.append(f"    _reserved_{reg.offset:04X}: [{gap}]u8,  // padding")
        if reg.name in bit_set_types:
            field_type = bit_set_types[reg.name]
        else:
            field_type = odin_type_for_size(reg.size)
        access_tag = odin_access_comment(reg.access)
        comment = f"  // 0x{reg.offset:02X} {access_tag}"
        if reg.description:
            comment += f" — {reg.description}"
        lines.append(f"    {reg.name}: {field_type},{comment}")
        prev_offset = reg.offset + (reg.size // 8)
    lines.append("}")
    lines.append("")

    # Compile-time size check — catches layout bugs immediately
    if prev_offset > 0:
        lines.append(f"#assert(size_of({struct_name}) == {prev_offset})")
        lines.append("")

    # Instance pointer
    lines.append(f"{p.name.lower()} := (^{struct_name})(rawptr(uintptr({p.name}_BASE)))")
    lines.append("")

    # Field constants — use group name as prefix so all peripherals
    # in the same group share the same field constants
    for reg in p.registers:
        if not reg.fields:
            continue
        for f in reg.fields:
            prefix = f"{field_prefix_base}_{reg.name}_{f.name}"
            lines.append(f"{prefix}_POS :: {f.bit_offset}")
            lines.append(f"{prefix}_MSK :: 0x{((1 << f.bit_width) - 1) << f.bit_offset:X}")
            if f.bit_width == 1:
                lines.append(f"{prefix}_BIT :: 1 << {f.bit_offset}")
            # Enumerated values
            if f.enumerated_values:
                enum_name = f"{field_prefix_base}_{reg.name}_{f.name}_Val"
                lines.append(f"{enum_name} :: enum u32 {{")
                for ev in f.enumerated_values:
                    lines.append(f"    {ev.name} = {ev.value},")
                lines.append("}")
            lines.append("")

    return "\n".join(lines)


def generate_odin(peripherals: list[PeripheralInfo], package_name: str, svd_filename: str) -> str:
    lines = []

    lines.append(f"// ──────────────────────────────────────────────────────────────────────")
    lines.append(f"// Generated by svd2odin.py from {svd_filename}")
    lines.append(f"// DO NOT EDIT — re-run the generator to update.")
    lines.append(f"// ──────────────────────────────────────────────────────────────────────")
    lines.append("")
    lines.append(f"package {package_name}")
    lines.append("")
    lines.append("import \"base:intrinsics\"")
    lines.append("")

    # Collect all enumerated values that appear across peripherals
    # for a given register group (e.g., GPIOA, GPIOB share the same fields)
    # We only emit field constants for the first peripheral in each group
    seen_groups = set()

    for p in peripherals:
        group_key = p.group_name
        if group_key in seen_groups:
            # Same register layout as a previous peripheral — just emit base + pointer
            lines.append(f"// ── {p.name} (same register layout as {p.group_name}) ──")
            lines.append("")
            lines.append(f"{p.name}_BASE :: 0x{p.base_address:08X}")
            lines.append("")
            struct_name = f"{p.group_name}_Reg"
            lines.append(f"{p.name.lower()} := (^{struct_name})(rawptr(uintptr({p.name}_BASE)))")
            lines.append("")
            continue
        seen_groups.add(group_key)

        # Use group name for the struct so shared peripherals reuse it,
        # but keep the original peripheral name for the instance pointer
        lines.append(generate_peripheral(p, group_name=p.group_name))

    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(
        description="Generate Odin register definitions from a CMSIS-SVD file."
    )
    parser.add_argument("input", help="Path to the input .svd file")
    parser.add_argument("output", help="Path to the output .odin file")
    parser.add_argument(
        "--package",
        default="mcu",
        help="Odin package name for the generated file (default: mcu)",
    )
    args = parser.parse_args()

    svd_path = Path(args.input)
    if not svd_path.exists():
        print(f"Error: SVD file not found: {svd_path}", file=sys.stderr)
        sys.exit(1)

    print(f"Parsing SVD: {svd_path}")
    tree = ET.parse(svd_path)
    root = tree.getroot()

    peripherals = parse_peripherals(root)
    print(f"  Found {len(peripherals)} peripherals")

    total_regs = sum(len(p.registers) for p in peripherals)
    total_fields = sum(
        len(r.fields)
        for p in peripherals for r in p.registers
    )
    print(f"  Found {total_regs} registers, {total_fields} fields")

    print(f"Generating Odin code...")
    odin_code = generate_odin(peripherals, args.package, svd_path.name)

    out_path = Path(args.output)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(odin_code)
    print(f"  Written: {out_path} ({len(odin_code)} bytes)")

    print("Done.")


if __name__ == "__main__":
    main()
