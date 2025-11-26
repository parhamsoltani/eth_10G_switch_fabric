#!/usr/bin/env python3
import sys
import csv
import os
import re
from typing import List, Dict, Tuple

# Required define names in the desired order (prefix columns)
DEFINE_ORDER = [
    "LINE_RATE",
    "N",
    "D",
    "S",
    "X",
    "U",
    "W",
    "OUTPUT_QUEUE_DEPTH",
    "MULTICAST_SUPPORT",
]

# Hist columns to take (inclusive range)
HIST_START_COL = "Slices/CLBs"
HIST_END_COL = "Timing Status"

def norm(s: str) -> str:
    return re.sub(r"\s+", " ", (s or "").strip())

def parse_defines(inc_path: str) -> Dict[str, str]:
    defines = {}
    if not os.path.isfile(inc_path):
        raise FileNotFoundError(f"incFile not found: {inc_path}")

    define_re = re.compile(r"^\s*`define\s+([A-Za-z_][A-Za-z0-9_]*)\s+(.+?)\s*$")
    with open(inc_path, "r", encoding="utf-8", errors="ignore") as f:
        for line in f:
            m = define_re.match(line)
            if not m:
                continue
            key, val = m.group(1), m.group(2)
            key = key.strip()
            val = re.split(r"\s*//", val, maxsplit=1)[0].strip()
            val = val.strip('`"\'')
            defines[key] = val

    for k in DEFINE_ORDER:
        defines.setdefault(k, "")
    return defines

def parse_clk(clk_path: str) -> str:
    """Return last non-commented -period value for -name clk"""
    if not os.path.isfile(clk_path):
        raise FileNotFoundError(f"clkFile not found: {clk_path}")

    clk_val = ""
    pat = re.compile(r"create_clock\s+-period\s+([\d.]+)\s+-name\s+clk\b", re.IGNORECASE)
    with open(clk_path, "r", encoding="utf-8", errors="ignore") as f:
        for line in f:
            if line.strip().startswith("#"):
                continue
            m = pat.search(line)
            if m:
                clk_val = m.group(1)
    return clk_val

def parse_partnum(tcl_path: str) -> str:
    """Return last non-commented value after -device_part_num"""
    if not os.path.isfile(tcl_path):
        raise FileNotFoundError(f"partNumFile not found: {tcl_path}")

    part = ""
    pat = re.compile(r"(?:^|\s)-device_part_num\s+(\S+)", re.IGNORECASE)
    with open(tcl_path, "r", encoding="utf-8", errors="ignore") as f:
        for line in f:
            if line.strip().startswith("#"):
                continue
            m = pat.search(line)
            if m:
                part = m.group(1)
    return part

def read_hist_last_row(hist_path: str) -> Tuple[List[str], List[str]]:
    if not os.path.isfile(hist_path):
        raise FileNotFoundError(f"hist not found: {hist_path}")

    rows = []
    with open(hist_path, "r", encoding="utf-8-sig", errors="ignore", newline="") as f:
        reader = csv.reader(f, delimiter=",")
        for raw in reader:
            row = [c.strip() for c in raw]
            if not row:
                continue
            # skip separator rows full of dashes/spaces
            if all((set(c) <= {"-", " "} and c.strip("- ") != "") or c.strip() == "" for c in row):
                continue
            rows.append(row)

    if not rows:
        raise ValueError("hist.csv appears empty after filtering separators.")

    header_idx = None
    start_idx = end_idx = None
    for i, r in enumerate(rows):
        headers = [norm(c) for c in r]
        if HIST_START_COL in headers and HIST_END_COL in headers:
            header_idx = i
            start_idx = headers.index(HIST_START_COL)
            end_idx = headers.index(HIST_END_COL)
            break

    if header_idx is None:
        raise ValueError("Could not locate required hist columns.")

    headers = [norm(c) for c in rows[header_idx]]
    data_rows = rows[header_idx + 1 :]
    if not data_rows:
        raise ValueError("No data rows present in hist.csv.")

    last_row = data_rows[-1]
    if len(last_row) < len(headers):
        last_row = last_row + [""] * (len(headers) - len(last_row))
    elif len(last_row) > len(headers):
        last_row = last_row[: len(headers)]

    selected_headers = headers[start_idx : end_idx + 1]
    selected_values = [last_row[i] if i < len(last_row) else "" for i in range(start_idx, end_idx + 1)]
    return selected_headers, selected_values

def load_existing_csv(path: str):
    if not os.path.isfile(path):
        return [], []
    with open(path, "r", encoding="utf-8-sig", errors="ignore", newline="") as f:
        reader = list(csv.reader(f))
        if not reader:
            return [], []
        header = [c.strip() for c in reader[0]]
        rows = [[c.strip() for c in r] for r in reader[1:]]
        return header, rows

def write_csv(path: str, header: List[str], rows: List[List[str]]) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(header)
        for r in rows:
            if len(r) < len(header):
                r = r + [""] * (len(header) - len(r))
            elif len(r) > len(header):
                r = r[: len(header)]
            writer.writerow(r)

def merge_rows_to_new_header(old_header: List[str], old_rows: List[List[str]], new_header: List[str]) -> List[List[str]]:
    idx_map = {}
    norm_old = [norm(h) for h in old_header]
    norm_new = [norm(h) for h in new_header]
    for j, h in enumerate(norm_new):
        idx_map[j] = norm_old.index(h) if h in norm_old else None

    new_rows = []
    for r in old_rows:
        new_r = []
        for j in range(len(new_header)):
            src_idx = idx_map[j]
            new_r.append(r[src_idx] if (src_idx is not None and src_idx < len(r)) else "")
        new_rows.append(new_r)
    return new_rows

def main():
    # Usage:
    #   save_configs.py true <hist> <config_hist> <inc> <clk> <partnum_tcl>
    if len(sys.argv) < 2 or sys.argv[1].lower() != "true":
        print("Usage: save_configs.py true <hist> <config_hist> <inc> <clk> <partnum_tcl>")
        sys.exit(1)

    hist_path = sys.argv[2] if len(sys.argv) > 2 else "../../out/hw_history/hist.csv"
    config_hist_path = sys.argv[3] if len(sys.argv) > 3 else "../../out/hw_history/config_hist.csv"
    inc_path = sys.argv[4] if len(sys.argv) > 4 else "../../src/hdl/inc/implement_options.vh"
    clk_path = sys.argv[5] if len(sys.argv) > 5 else "../../src/hdl/xdc/timing.xdc"
    partnum_path = sys.argv[6] if len(sys.argv) > 6 else "../../scr/build_hw/build_switches_main.tcl"

    defines = parse_defines(inc_path)
    define_headers = DEFINE_ORDER
    define_values = [defines.get(k, "") for k in DEFINE_ORDER]

    clk_val = parse_clk(clk_path)
    part_val = parse_partnum(partnum_path)

    clk_header = ["clk"]
    part_header = ["part_number"]

    hist_headers, hist_values = read_hist_last_row(hist_path)

    target_header = define_headers + clk_header + part_header + hist_headers
    new_row = define_values + [clk_val] + [part_val] + hist_values

    existing_header, existing_rows = load_existing_csv(config_hist_path)
    if not existing_header:
        write_csv(config_hist_path, target_header, [new_row])
        print(f"Created '{config_hist_path}' with header and 1 row.")
        return

    norm_existing = [norm(h) for h in existing_header]
    norm_required = [norm(h) for h in target_header]
    required_missing = any(h not in norm_existing for h in norm_required)

    if required_missing:
        preserved_rows = merge_rows_to_new_header(existing_header, existing_rows, target_header)
        preserved_rows.append(new_row)
        write_csv(config_hist_path, target_header, preserved_rows)
        print(f"Rewrote '{config_hist_path}' with correct header and appended new row.")
    else:
        value_by_col = {norm(h): v for h, v in zip(target_header, new_row)}
        appended = [value_by_col.get(norm(h), "") for h in existing_header]
        with open(config_hist_path, "a", encoding="utf-8", newline="") as f:
            writer = csv.writer(f)
            writer.writerow(appended)
        print(f"Appended new row to '{config_hist_path}'.")

if __name__ == "__main__":
    main()
