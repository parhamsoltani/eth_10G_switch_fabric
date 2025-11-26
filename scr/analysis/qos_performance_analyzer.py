#!/usr/bin/env python3
"""
Analyze QoS impact on throughput, latency, and resource usage
Parses Vivado reports and generates comparison charts
"""

import json
import re
from pathlib import Path
from typing import Dict, List
import csv

ROOT = Path(__file__).resolve().parents[2]
REPORTS_DIR = ROOT / "out/reports"
HIST_FILE = ROOT / "out/hw_history/config_hist.csv"
MANIFEST = ROOT / "scr/save_configs/config_generator/configs/manifest.json"

def parse_timing_report(cfg_id: int) -> Dict:
    """Extract WNS, WHS from timing summary"""
    report = REPORTS_DIR / f"config_{cfg_id:03d}/route_timing_summary.rpt"
    if not report.exists():
        return {}

    text = report.read_text(errors="ignore")
    wns_match = re.search(r"WNS\(ns\)\s+([-\d.]+)", text)
    whs_match = re.search(r"WHS\(ns\)\s+([-\d.]+)", text)

    return {
        "wns": float(wns_match.group(1)) if wns_match else None,
        "whs": float(whs_match.group(1)) if whs_match else None,
        "timing_met": bool(wns_match and float(wns_match.group(1)) >= 0)
    }

def parse_utilization_report(cfg_id: int) -> Dict:
    """Extract resource usage"""
    report = REPORTS_DIR / f"config_{cfg_id:03d}/route_utilization.rpt"
    if not report.exists():
        return {}

    text = report.read_text(errors="ignore")

    def extract_util(pattern: str) -> float:
        match = re.search(pattern, text)
        return float(match.group(1)) if match else 0.0

    return {
        "lut": extract_util(r"CLB LUTs\*?\s+\|\s+([\d.]+)"),
        "ff": extract_util(r"CLB Registers\s+\|\s+([\d.]+)"),
        "bram": extract_util(r"Block RAM Tile\s+\|\s+([\d.]+)"),
        "dsp": extract_util(r"DSPs\s+\|\s+([\d.]+)")
    }

def compare_qos_impact():
    """Compare QoS-enabled vs disabled configs"""
    if not MANIFEST.exists():
        raise FileNotFoundError(f"Missing manifest: {MANIFEST}")

    with open(MANIFEST, "r") as f:
        configs = json.load(f)

    # Group by base parameters (N, D, S, W)
    groups = {}
    for cfg in configs:
        defs = cfg["defines"]
        base_key = (defs["N"], defs["D"], defs["S"], defs["W"])

        if base_key not in groups:
            groups[base_key] = {"qos_off": None, "qos_on": []}

        if int(defs["ENABLE_QOS"]) == 0:
            groups[base_key]["qos_off"] = cfg
        else:
            groups[base_key]["qos_on"].append(cfg)

    # Analyze each group
    results = []
    for base_key, group in groups.items():
        if not group["qos_off"] or not group["qos_on"]:
            continue

        cfg_off = group["qos_off"]
        cfg_on = group["qos_on"][0]  # Use first QoS variant

        timing_off = parse_timing_report(cfg_off["config_id"])
        timing_on = parse_timing_report(cfg_on["config_id"])

        util_off = parse_utilization_report(cfg_off["config_id"])
        util_on = parse_utilization_report(cfg_on["config_id"])

        results.append({
            "config": f"N={base_key[0]}_D={base_key[1]}_S={base_key[2]}",
            "qos_overhead_lut": util_on.get("lut", 0) - util_off.get("lut", 0),
            "qos_overhead_bram": util_on.get("bram", 0) - util_off.get("bram", 0),
            "timing_degradation_ns": (timing_off.get("wns", 0) - timing_on.get("wns", 0)),
            "qos_timing_met": timing_on.get("timing_met", False)
        })

    # Print results
    print("\n" + "="*80)
    print("QoS IMPACT ANALYSIS")
    print("="*80)
    print(f"{'Config':<20} {'LUT Δ%':<10} {'BRAM Δ%':<10} {'Timing Δ(ns)':<15} {'Met?':<5}")
    print("-"*80)

    for r in results:
        print(f"{r['config']:<20} {r['qos_overhead_lut']:>8.1f}% "
              f"{r['qos_overhead_bram']:>8.1f}% {r['timing_degradation_ns']:>13.3f} "
              f"{'✓' if r['qos_timing_met'] else '✗':<5}")

    print("="*80 + "\n")

    # Save CSV
    csv_file = ROOT / "out/qos_impact_analysis.csv"
    with open(csv_file, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=results[0].keys())
        writer.writeheader()
        writer.writerows(results)

    print(f"Analysis saved to: {csv_file}")

if __name__ == "__main__":
    compare_qos_impact()