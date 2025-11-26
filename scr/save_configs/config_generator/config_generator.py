"""
Enhanced config generator for VOQ/XPQ fabric switch
Generates build configurations for different switch sizes and parameters
"""

import math
import itertools
import re
from pathlib import Path
from typing import Dict, List

# ===================== USER PARAMETERS =====================

DEFINE_ORDER = [
    "NUM_PORTS",
    "DATA_WIDTH",
    "PACKET_ID_WIDTH",
    "QOS_LEVELS",
    "VOQ_DEPTH_PER_QOS",
    "XPQ_DEPTH",
    "PACKET_BUFFER_DEPTH",
    "QOS_TAG_WIDTH",
    "CLOCK_FREQ_MHZ",
    "PRIORITY_HIGH",
    "PRIORITY_MEDIUM",
    "PRIORITY_LOW",
]

DEFINE_SPACE = {
    "NUM_PORTS": [10, 20, 40],
    "DATA_WIDTH": [32, 64],
    "PACKET_ID_WIDTH": [10],
    "QOS_LEVELS": [3],
    "VOQ_DEPTH_PER_QOS": [1024, 2048],
    "XPQ_DEPTH": [512, 1024],
    "PACKET_BUFFER_DEPTH": [4096],
    "QOS_TAG_WIDTH": [3],
    "CLOCK_FREQ_MHZ": [250, 312],
    "PRIORITY_HIGH": ["3'b000"],
    "PRIORITY_MEDIUM": ["3'b001"],
    "PRIORITY_LOW": ["3'b010"],
}

FORCE_PART_NUMBER = None  # None for auto-selection

# ===================== PATHS =====================

ROOT_DIR     = Path(".")
SRC_DIR      = ROOT_DIR / "src"
INC_FILE     = SRC_DIR / "inc" / "fabric_params.vh"
CLK_FILE     = SRC_DIR / "xdc" / "timing.xdc"
PARTNUM_FILE = ROOT_DIR / "scr" / "build_hw" / "build_switches_main.tcl"
CONFIG_DIR   = ROOT_DIR / "scr" / "save_configs" / "config_generator" / "configs"

# ===================== HELPER FUNCTIONS =====================

def replace_defines(template: str, define_values: Dict[str, str]) -> str:
    """Replace `define NAME VALUE lines for keys in define_values"""
    lines = template.splitlines()
    hit = {k: False for k in define_values}
    pat = re.compile(r"^(\s*)`define\s+([A-Za-z_]\w*)\s+(.+?)\s*$")

    out = []
    for line in lines:
        m = pat.match(line)
        if m:
            indent, name, _ = m.groups()
            if name in define_values:
                out.append(f"{indent}`define {name} {define_values[name]}")
                hit[name] = True
            else:
                out.append(line)
        else:
            out.append(line)

    # Append missing defines
    missing = [k for k, seen in hit.items() if not seen]
    if missing:
        out.append("")
        for k in DEFINE_ORDER:
            if k in missing:
                out.append(f"`define {k} {define_values[k]}")

    return "\n".join(out) + "\n"

def set_clk_period_xdc(template: str, period_ns: float) -> str:
    """Set clock period in XDC file"""
    lines = template.splitlines()
    create_pat = re.compile(r"(create_clock\s+-period\s+)([\d.]+)(\s+-name\s+clk\b)", re.IGNORECASE)

    last_idx = -1
    for idx, line in enumerate(lines):
        if line.strip().startswith("#"):
            continue
        if create_pat.search(line):
            last_idx = idx

    if last_idx >= 0:
        lines[last_idx] = create_pat.sub(rf"\g<1>{period_ns}\3", lines[last_idx])
        return "\n".join(lines) + "\n"
    else:
        add = f"create_clock -period {period_ns} -name clk [get_ports clk]"
        return (template.rstrip() + "\n\n" + add + "\n")

def set_device_part_num_tcl(template: str, part: str) -> str:
    """Set device part number in TCL file"""
    out = []
    found_uncommented = False
    switch_pat = re.compile(r"(^\s*)(-device_part_num\s+)(\S+)(\s*$)", re.IGNORECASE)

    for line in template.splitlines():
        stripped = line.lstrip()
        if stripped.startswith("#"):
            out.append(line)
            continue

        m = switch_pat.match(line)
        if m:
            indent, sw, _old, trail = m.groups()
            if not found_uncommented:
                out.append(f"{indent}{sw}{part}{trail}")
                found_uncommented = True
            else:
                out.append("# " + line)
        else:
            out.append(line)

    if not found_uncommented:
        out = [f"-device_part_num {part}"] + out

    return "\n".join(out) + "\n"

def pick_part_number(num_ports: int, voq_depth: int, forced: str | None) -> str:
    """Select FPGA part based on resource requirements"""
    if forced:
        return forced

    # Estimate total memory: VOQ + XPQ arrays
    # VOQ: NUM_PORTS × NUM_PORTS × VOQ_DEPTH × DATA_WIDTH
    # XPQ: NUM_PORTS × NUM_PORTS × XPQ_DEPTH × DATA_WIDTH
    total_voq_bits = num_ports * num_ports * voq_depth * 64
    total_xpq_bits = num_ports * num_ports * 512 * 64  # Assume XPQ_DEPTH=512
    total_mem_bits = total_voq_bits + total_xpq_bits

    total_mem_mb = total_mem_bits / (8 * 1024 * 1024)

    if total_mem_mb < 5:
        return "xcku3p-ffvb676-3-e"
    elif total_mem_mb < 15:
        return "xcvu3p-ffvc1517-3-e"
    elif total_mem_mb < 30:
        return "xcvu5p-flvc2104-3-e"
    elif total_mem_mb < 50:
        return "xcvu9p-flga2577-3-e"
    else:
        return "xcvu13p-flga2577-3-e"

def calc_clock_period(freq_mhz: int) -> float:
    """Calculate clock period in ns from frequency in MHz"""
    return round(1000.0 / freq_mhz, 4)

def cartesian_define_dicts() -> List[Dict[str, str]]:
    """Generate all combinations from DEFINE_SPACE"""
    keys = list(DEFINE_SPACE.keys())
    lists = [DEFINE_SPACE[k] for k in keys]
    combos = []
    for vals in itertools.product(*lists):
        combos.append({k: str(v) for k, v in zip(keys, vals)})
    return combos

def generate_qos_enabled_configs():
    """Generate configs with QoS on/off sweep"""
    base_configs = cartesian_define_dicts()

    qos_configs = []
    for cfg in base_configs:
        # QoS enabled variant
        cfg_qos_on = cfg.copy()
        cfg_qos_on["ENABLE_QOS"] = "1"
        cfg_qos_on["QOS_LEVELS"] = "3"
        qos_configs.append(cfg_qos_on)

        # QoS disabled variant (backward compatibility)
        cfg_qos_off = cfg.copy()
        cfg_qos_off["ENABLE_QOS"] = "0"
        cfg_qos_off["QOS_LEVELS"] = "1"
        qos_configs.append(cfg_qos_off)

    return qos_configs

# ===================== MAIN LOGIC =====================

def main():
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)

    # Load template files
    inc_tmpl = INC_FILE.read_text(encoding="utf-8", errors="ignore")
    clk_tmpl = CLK_FILE.read_text(encoding="utf-8", errors="ignore")
    tcl_tmpl = PARTNUM_FILE.read_text(encoding="utf-8", errors="ignore")

    define_dicts = generate_qos_enabled_configs()
    if not define_dicts:
        print("No combinations (DEFINE_SPACE is empty). Nothing to do.")
        return

    generated = 0
    for i, dvals in enumerate(define_dicts, start=1):
        # Ensure every define exists
        for must in DEFINE_ORDER:
            dvals.setdefault(must, "")

        # Parse numeric values
        try:
            num_ports = int(float(dvals["NUM_PORTS"]))
            voq_depth = int(float(dvals["VOQ_DEPTH_PER_QOS"]))
            clock_freq = int(float(dvals["CLOCK_FREQ_MHZ"]))
        except Exception as e:
            raise SystemExit(f"Bad numeric in DEFINE_SPACE: {e}")

        # Calculate clock period
        clk_period = calc_clock_period(clock_freq)

        # Select part number
        part = pick_part_number(num_ports, voq_depth, FORCE_PART_NUMBER)

        # Render files
        inc_out = replace_defines(inc_tmpl, dvals)
        clk_out = set_clk_period_xdc(clk_tmpl, clk_period)
        tcl_out = set_device_part_num_tcl(tcl_tmpl, part)

        # Write configuration folder
        folder = CONFIG_DIR / f"{i:03d}"
        folder.mkdir(parents=True, exist_ok=True)

        (folder / "fabric_params.vh").write_text(inc_out, encoding="utf-8")
        (folder / "timing.xdc").write_text(clk_out, encoding="utf-8")
        (folder / "build_switches_main.tcl").write_text(tcl_out, encoding="utf-8")

        # Write metadata summary
        (folder / "meta.txt").write_text(
            "CONFIG #{idx}\n"
            "Clock Period: {clk} ns ({freq} MHz)\n"
            "Part Number: {part}\n"
            "Estimated Memory: {mem:.2f} MB\n"
            "\nDefines:\n{defs}\n".format(
                idx=i,
                clk=clk_period,
                freq=clock_freq,
                part=part,
                mem=(num_ports * num_ports * voq_depth * 64) / (8 * 1024 * 1024),
                defs="\n".join([f"  {k} = {dvals[k]}" for k in DEFINE_ORDER]),
            ),
            encoding="utf-8",
        )

        generated += 1

    print(f"Generated {generated} config(s) under: {CONFIG_DIR}")
    print(f"Configurations span {DEFINE_SPACE['NUM_PORTS'][0]} to {DEFINE_SPACE['NUM_PORTS'][-1]} ports")

if __name__ == "__main__":
    main()