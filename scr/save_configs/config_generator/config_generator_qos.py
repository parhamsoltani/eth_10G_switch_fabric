"""
QoS-aware config generator with multi-dimensional sweep
Extends config_generator.py with QoS parameter space
"""

import math
import itertools
import re
from pathlib import Path
from typing import Dict, List
import json

# ===================== QoS-SPECIFIC PARAMETERS =====================

# Extend existing DEFINE_SPACE with QoS parameters
DEFINE_ORDER = [
    "LINE_RATE", "N", "D", "S", "X", "U", "W",
    "OUTPUT_QUEUE_DEPTH", "MULTICAST_SUPPORT",
    "ENABLE_QOS", "QOS_LEVELS", "QOS_TAG_WIDTH", "PACKET_ID_WIDTH"  # NEW
]

DEFINE_SPACE = {
    "LINE_RATE": [25],
    "N": [20, 40, 60, 80],
    "D": [512, 1024, 2048],
    "S": [8, 10],
    "X": [64],
    "U": [1],
    "W": [112],
    "OUTPUT_QUEUE_DEPTH": [32, 64],
    "MULTICAST_SUPPORT": [0],
    # QoS sweep dimensions
    "ENABLE_QOS": [0, 1],              # Compare QoS on/off
    "QOS_LEVELS": [3, 4],              # 3-level vs 4-level priority
    "QOS_TAG_WIDTH": [3],              # Fixed at 3 bits (up to 8 levels)
    "PACKET_ID_WIDTH": [8, 10],        # Packet tracking width
}

# Timing adjustments for QoS-enabled configs
QOS_TIMING_PENALTY = {
    # QoS levels → additional setup margin (ns)
    3: 0.05,
    4: 0.08,
    8: 0.10
}

# Device selection with QoS resource overhead
QOS_RESOURCE_FACTOR = 1.15  # 15% resource overhead for QoS

# ===================== PATHS =====================
ROOT_DIR     = Path(".")
SRC_DIR      = ROOT_DIR / "src"
INC_FILE     = SRC_DIR / "inc" / "implement_options.vh"
CLK_FILE     = SRC_DIR / "xdc" / "timing.xdc"
PARTNUM_FILE = ROOT_DIR / "scr" / "build_hw" / "build_switches_main.tcl"
CONFIG_DIR   = ROOT_DIR / "scr" / "save_configs" / "config_generator" / "configs"

# ===================== ENHANCED FUNCTIONS =====================

def adjust_clk_for_qos(clk_base: float, qos_levels: int, enable_qos: bool) -> float:
    """Apply timing penalty for QoS logic"""
    if not enable_qos or qos_levels not in QOS_TIMING_PENALTY:
        return clk_base

    penalty = QOS_TIMING_PENALTY[qos_levels]
    adjusted = clk_base + penalty
    return float(f"{adjusted:.4f}")

def pick_part_with_qos(n_val: int, d_val: int, enable_qos: bool, forced: str | None) -> str:
    """Select FPGA part considering QoS resource overhead"""
    if forced:
        return forced

    # Effective port count with QoS overhead
    eff_n = int(n_val * QOS_RESOURCE_FACTOR) if enable_qos else n_val

    # Adjust memory depth threshold
    mem_threshold = 1024 if enable_qos else 512

    if eff_n <= 16:
        return "xcku3p-ffvb676-3-e"
    if eff_n <= 40:
        return "xcvu3p-ffvc1517-3-e"
    if eff_n <= 80:
        return "xcvu5p-flvc2104-3-e"

    if d_val > mem_threshold:
        if eff_n <= 104:
            return "xcvu9p-flga2577-3-e"
    else:
        if eff_n <= 120:
            return "xcvu9p-flga2577-3-e"

    return "xcvu13p-flga2577-3-e"

def replace_defines(template: str, define_values: Dict[str, str]) -> str:
    """Enhanced with QoS-specific defines"""
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
        out.append("\n// QoS-specific parameters (auto-generated)")
        for k in DEFINE_ORDER:
            if k in missing:
                out.append(f"`define {k} {define_values[k]}")

    return "\n".join(out) + "\n"

def set_clk_period_xdc(template: str, period_ns: float) -> str:
    """Enhanced with QoS timing annotation"""
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
    """Same as original"""
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

def cartesian_define_dicts() -> List[Dict[str, str]]:
    """Generate Cartesian product of all parameters"""
    keys = list(DEFINE_SPACE.keys())
    lists = [DEFINE_SPACE[k] for k in keys]
    combos = []
    for vals in itertools.product(*lists):
        combos.append({k: str(v) for k, v in zip(keys, vals)})
    return combos

def filter_invalid_configs(configs: List[Dict[str, str]]) -> List[Dict[str, str]]:
    """Remove invalid QoS parameter combinations"""
    valid = []
    for cfg in configs:
        enable_qos = int(cfg["ENABLE_QOS"])
        qos_levels = int(cfg["QOS_LEVELS"])
        qos_tag_width = int(cfg["QOS_TAG_WIDTH"])

        # Skip if QoS disabled but levels > 1
        if not enable_qos and qos_levels > 1:
            continue

        # Skip if tag width insufficient for levels
        if 2**qos_tag_width < qos_levels:
            continue

        valid.append(cfg)

    return valid

# ===================== MAIN =====================

def main():
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)

    inc_tmpl = INC_FILE.read_text(encoding="utf-8", errors="ignore")
    clk_tmpl = CLK_FILE.read_text(encoding="utf-8", errors="ignore")
    tcl_tmpl = PARTNUM_FILE.read_text(encoding="utf-8", errors="ignore")

    define_dicts = cartesian_define_dicts()
    define_dicts = filter_invalid_configs(define_dicts)  # Remove invalid combos

    if not define_dicts:
        print("No valid combinations generated.")
        return

    generated = 0
    manifest = []  # Track all configs for batch processing

    for i, dvals in enumerate(define_dicts, start=1):
        # Ensure all defines exist
        for must in DEFINE_ORDER:
            dvals.setdefault(must, "")

        # Parse key parameters
        try:
            LINE_RATE = float(dvals["LINE_RATE"])
            S         = float(dvals["S"])
            N_int     = int(float(dvals["N"]))
            W_val     = float(dvals["W"])
            D_val     = int(float(dvals["D"]))
            enable_qos = bool(int(dvals["ENABLE_QOS"]))
            qos_levels = int(dvals["QOS_LEVELS"])
        except Exception as e:
            raise SystemExit(f"Bad numeric in config {i}: {e}")

        # Compute base clock (cell-switching mode)
        CELL_SWITCH = True
        if CELL_SWITCH:
            clk_base = float(f"{(W_val / LINE_RATE):.4f}")
        else:
            L_MIN, GAP_MIN = 64, 13
            clk_base = (L_MIN + GAP_MIN) * 8.0 / (S * LINE_RATE)
            W_dep = int(math.ceil((2.0*S*LINE_RATE*clk_base - (GAP_MIN+1)*8.0)/S/8.0)*8.0)
            dvals["W"] = str(W_dep)

        # Adjust clock for QoS timing penalty
        clk = adjust_clk_for_qos(clk_base, qos_levels, enable_qos)

        # Select part considering QoS overhead
        part = pick_part_with_qos(N_int, D_val, enable_qos, None)

        # Render files
        inc_out = replace_defines(inc_tmpl, dvals)
        clk_out = set_clk_period_xdc(clk_tmpl, clk)
        tcl_out = set_device_part_num_tcl(tcl_tmpl, part)

        folder = CONFIG_DIR / f"{i:03d}"
        folder.mkdir(parents=True, exist_ok=True)

        (folder / "implement_options.vh").write_text(inc_out, encoding="utf-8")
        (folder / "timing.xdc").write_text(clk_out, encoding="utf-8")
        (folder / "build_switches_main.tcl").write_text(tcl_out, encoding="utf-8")

        meta_dict = {
            "config_id": i,
            "clk_base": clk_base,
            "clk_qos_adjusted": clk,
            "part_number": part,
            "qos_enabled": enable_qos,
            "qos_levels": qos_levels,
            "timing_penalty_ns": clk - clk_base,
            "defines": {k: dvals[k] for k in DEFINE_ORDER}
        }

        (folder / "meta.txt").write_text(
            f"CONFIG #{i}\n"
            f"clk (base) = {clk_base} ns\n"
            f"clk (QoS)  = {clk} ns (penalty: {clk-clk_base:.4f} ns)\n"
            f"part_number = {part}\n"
            f"QoS: enabled={enable_qos}, levels={qos_levels}\n"
            f"defines:\n" + "\n".join([f"  {k} = {dvals[k]}" for k in DEFINE_ORDER]),
            encoding="utf-8"
        )

        (folder / "meta.json").write_text(json.dumps(meta_dict, indent=2), encoding="utf-8")

        manifest.append(meta_dict)
        generated += 1

    # Write master manifest for batch builds
    manifest_file = CONFIG_DIR / "manifest.json"
    manifest_file.write_text(json.dumps(manifest, indent=2), encoding="utf-8")

    print(f"Generated {generated} QoS-aware config(s) under: {CONFIG_DIR}")
    print(f"Manifest: {manifest_file}")

if __name__ == "__main__":
    main()