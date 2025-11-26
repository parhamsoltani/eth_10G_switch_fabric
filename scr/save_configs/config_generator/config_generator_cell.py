
"""
Config generator (self-contained params; no CLI args)

- Uses current template files:
    src/inc/implement_options.vh
    src/xdc/timing.xdc
    scr/build_hw/build_switches_main.tcl
- Produces one folder per config under scr/save_configs/config_generator/configs/1, /2, ...
- Only edits:
    * nine `define`s
    * clk period (for -name clk)
    * -device_part_num
"""

import math
import itertools
import re
from pathlib import Path
from typing import Dict, List

# ===================== USER PARAMETERS (EDIT HERE) =====================

# Sweep space for Verilog `define`s (Cartesian product)
DEFINE_ORDER = [
    "LINE_RATE", "N", "D", "S", "X", "U", "W", "OUTPUT_QUEUE_DEPTH", "MULTICAST_SUPPORT",
]
DEFINE_SPACE = {
    "LINE_RATE": [25],
    "N": [96],
    "D": [8192],
    "S": [8],
    "X": [64],
    "U": [1],
    "W": [72],                 # Ignored when CELL_SWITCH == False (W becomes dependent)
    "OUTPUT_QUEUE_DEPTH": [512],
    "MULTICAST_SUPPORT": [0],
}

SP = 0.1

# Clock/geometry mode
CELL_SWITCH   = True          # True:  clk = W / LINE_RATE  (rounded to 4 decimals)
L_MIN         = 12.0          # Used only when CELL_SWITCH == False
GAP_MIN       = 4.0           # Used only when CELL_SWITCH == False

# Part number control
FORCE_PART_NUMBER = None      # e.g. "xcvu9p-flga2577-3-e" or None to auto-pick by N

# ===================== PATHS (relative to repo root) =====================

ROOT_DIR     = Path(".")
SRC_DIR      = ROOT_DIR / "src"
INC_FILE     = SRC_DIR / "inc" / "implement_options.vh"
CLK_FILE     = SRC_DIR / "xdc" / "timing.xdc"
PARTNUM_FILE = ROOT_DIR / "scr" / "build_hw" / "build_switches_main.tcl"

CONFIG_DIR   = ROOT_DIR / "scr" / "save_configs" / "config_generator" / "configs"

# ===================== Helpers to edit three files =====================

def replace_defines(template: str, define_values: Dict[str, str]) -> str:
    """Replace `define NAME VALUE` lines for keys present in define_values.
    If a key isn't found, append it at the end in DEFINE_ORDER order."""
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

    missing = [k for k, seen in hit.items() if not seen]
    if missing:
        out.append("")
        for k in DEFINE_ORDER:
            if k in missing:
                out.append(f"`define {k} {define_values[k]}")
    return "\n".join(out) + "\n"

def set_clk_period_xdc(template: str, period_ns: float) -> str:
    """Set the last *uncommented* create_clock -name clk line's -period.
    If none exists, append a new valid line at the end."""
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
    """Keep exactly one *uncommented* '-device_part_num <part>'.
    Comment-out any other uncommented -device_part_num lines."""
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

# ===================== Derived helpers =====================

def pick_part_number(n_val: int, forced: str | None, d = 512) -> str:
    """Return forced if provided; else pick by N thresholds."""
    
    if forced:
        return forced
    if n_val <= 16:
        return "xcku3p-ffvb676-3-e"
    if n_val <= 40:
        return "xcvu3p-ffvc1517-3-e"
    if n_val <= 80:
        return "xcvu5p-flvc2104-3-e"

    if d > 512:
        if n_val <= 104:
            return "xcvu9p-flga2577-3-e"
    else:
        if n_val <= 120:
            return "xcvu9p-flga2577-3-e"
    return "xcvu13p-flga2577-3-e"

def round4(x: float) -> float:
    return float(f"{x:.4f}")

def cartesian_define_dicts() -> List[Dict[str, str]]:
    keys = list(DEFINE_SPACE.keys())
    lists = [DEFINE_SPACE[k] for k in keys]
    combos = []
    for vals in itertools.product(*lists):
        combos.append({k: str(v) for k, v in zip(keys, vals)})
    return combos

# ===================== Main =====================

def main():
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)

    inc_tmpl = INC_FILE.read_text(encoding="utf-8", errors="ignore")
    clk_tmpl = CLK_FILE.read_text(encoding="utf-8", errors="ignore")
    tcl_tmpl = PARTNUM_FILE.read_text(encoding="utf-8", errors="ignore")

    define_dicts = cartesian_define_dicts()
    if not define_dicts:
        print("No combinations (DEFINE_SPACE is empty). Nothing to do.")
        return

    generated = 0
    for i, dvals in enumerate(define_dicts, start=1):
        # Ensure every define exists as string
        for must in DEFINE_ORDER:
            dvals.setdefault(must, "")

        # Parse numerics we need
        try:
            LINE_RATE = float(dvals["LINE_RATE"])
            S         = float(dvals["S"])
            N_int     = int(float(dvals["N"]))
            W_val     = float(dvals["W"]) if dvals["W"] != "" else 0.0
        except Exception as e:
            raise SystemExit(f"Bad numeric in DEFINE_SPACE: {e}")

        # Compute clk and (optionally) dependent W
        if CELL_SWITCH:
            clk = round4((W_val / LINE_RATE) / (1+SP))
            # keep W as given
        else:
            # clk = (L_MIN + GAP_MIN) * 8 / (S * LINE_RATE)
            clk = (L_MIN + GAP_MIN) * 8.0 / (S * LINE_RATE)
            # W is dependent:
            # W_cell = 2*S*LINE_RATE*clk - (GAP_MIN + 1)*8
            W_cell = 2.0 * S * LINE_RATE * clk - (GAP_MIN + 1.0) * 8.0
            # W = ceil((W_cell / S)/8) * 8
            W_dep = int(math.ceil((W_cell / S) / 8.0) * 8.0)
            dvals["W"] = str(W_dep)

        part = pick_part_number(N_int, FORCE_PART_NUMBER, int(float(dvals["D"])))

        # Render files
        inc_out = replace_defines(inc_tmpl, dvals)
        clk_out = set_clk_period_xdc(clk_tmpl, clk)
        tcl_out = set_device_part_num_tcl(tcl_tmpl, part)

        folder = CONFIG_DIR / f"{i:03d}"
        folder.mkdir(parents=True, exist_ok=True)
        (folder / "implement_options.vh").write_text(inc_out, encoding="utf-8")
        (folder / "timing.xdc").write_text(clk_out, encoding="utf-8")
        (folder / "build_switches_main.tcl").write_text(tcl_out, encoding="utf-8")
        (folder / "meta.txt").write_text(
            "CONFIG #{idx}\n"
            "clk = {clk}\n"
            "part_number = {part}\n"
            "defines:\n{defs}\n".format(
                idx=i,
                clk=clk,
                part=part,
                defs="\n".join([f"  {k} = {dvals[k]}" for k in DEFINE_ORDER]),
            ),
            encoding="utf-8",
        )
        generated += 1

    print(f"Generated {generated} config(s) under: {CONFIG_DIR}")

if __name__ == "__main__":
    main()
