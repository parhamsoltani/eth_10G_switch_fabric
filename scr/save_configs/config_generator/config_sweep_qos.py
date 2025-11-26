#!/usr/bin/env python3
"""
Advanced QoS configuration sweep with Design Space Exploration (DSE)
Intelligently prunes invalid/redundant configs and prioritizes critical paths
"""

import json
import itertools
import math
from pathlib import Path
from typing import Dict, List, Tuple
import argparse

# Import base generator
import sys
sys.path.append(str(Path(__file__).parent))
from config_generator_qos import (
    DEFINE_ORDER, DEFINE_SPACE, adjust_clk_for_qos, pick_part_with_qos,
    replace_defines, set_clk_period_xdc, set_device_part_num_tcl,
    ROOT_DIR, SRC_DIR, INC_FILE, CLK_FILE, PARTNUM_FILE, CONFIG_DIR
)

# ===================== ADVANCED SWEEP PARAMETERS =====================

# Multi-objective optimization weights
OBJECTIVES = {
    "throughput": 0.4,      # Maximize aggregate throughput
    "latency": 0.3,         # Minimize average latency
    "resource": 0.2,        # Minimize LUT/BRAM usage
    "power": 0.1            # Minimize dynamic power
}

# Pruning heuristics
PRUNE_RULES = {
    "skip_large_low_speedup": True,     # Skip N>40 with S<8
    "skip_small_deep_mem": True,        # Skip N<20 with D>2048
    "skip_redundant_qos": True,         # Skip QoS_LEVELS>4 if ENABLE_QOS=0
}

# Pareto frontier tracking
class ParetoFrontier:
    def __init__(self):
        self.frontier: List[Dict] = []

    def dominates(self, cfg1: Dict, cfg2: Dict) -> bool:
        """Check if cfg1 Pareto-dominates cfg2"""
        # Smaller is better for all metrics
        better_in_one = False
        for metric in ["latency_est", "lut_est", "power_est"]:
            if cfg1[metric] > cfg2[metric]:
                return False
            if cfg1[metric] < cfg2[metric]:
                better_in_one = True
        return better_in_one

    def add(self, cfg: Dict):
        """Add config if non-dominated"""
        # Remove dominated configs
        self.frontier = [f for f in self.frontier if not self.dominates(cfg, f)]

        # Add if not dominated by any existing
        if not any(self.dominates(f, cfg) for f in self.frontier):
            self.frontier.append(cfg)

# ===================== ESTIMATION MODELS =====================

def estimate_latency(n: int, s: int, d: int, qos_levels: int, enable_qos: bool) -> float:
    """Estimate average packet latency (ns) - simplified model"""
    # Base latency: queueing delay + fabric delay
    base_lat = (d / s) * 10.0  # Proportional to VOQ depth / speedup
    fabric_lat = (n / s) * 5.0  # Proportional to fabric stages

    # QoS overhead (priority comparison adds latency)
    qos_penalty = (math.log2(qos_levels) * 2.0) if enable_qos else 0.0

    return base_lat + fabric_lat + qos_penalty

def estimate_lut_usage(n: int, s: int, d: int, w: int, qos_levels: int, enable_qos: bool) -> int:
    """Estimate LUT count - empirical model from past builds"""
    # Base switch fabric LUTs
    base_luts = n * s * 500 + d * 10 + w * 20

    # QoS classifier overhead per port
    qos_luts = n * (150 + qos_levels * 20) if enable_qos else 0

    # Matching logic overhead
    match_luts = (n * s * 50) if enable_qos else (n * s * 30)

    return int(base_luts + qos_luts + match_luts)

def estimate_power(n: int, clk_mhz: float, lut_count: int) -> float:
    """Estimate dynamic power (W) - very rough approximation"""
    # Power ~ #toggles × voltage^2 × capacitance
    # Simplified: power ∝ LUTs × frequency
    return (lut_count * clk_mhz) / 1e6  # Normalized units

# ===================== INTELLIGENT PRUNING =====================

def prune_config(dvals: Dict) -> Tuple[bool, str]:
    """Return (should_prune, reason)"""
    try:
        n = int(dvals["N"])
        s = int(dvals["S"])
        d = int(dvals["D"])
        enable_qos = int(dvals["ENABLE_QOS"])
        qos_levels = int(dvals["QOS_LEVELS"])

        # Rule 1: Large switch with low speedup → poor performance
        if PRUNE_RULES["skip_large_low_speedup"]:
            if n > 40 and s < 8:
                return (True, f"Large N={n} with low S={s} causes HOL blocking")

        # Rule 2: Small switch with deep memory → wasted resources
        if PRUNE_RULES["skip_small_deep_mem"]:
            if n < 20 and d > 2048:
                return (True, f"Small N={n} doesn't need D={d} (oversized)")

        # Rule 3: QoS disabled but levels > 1
        if PRUNE_RULES["skip_redundant_qos"]:
            if not enable_qos and qos_levels > 1:
                return (True, f"QoS disabled but QOS_LEVELS={qos_levels}")

        # Rule 4: Insufficient tag width for levels
        qos_tag_width = int(dvals["QOS_TAG_WIDTH"])
        if 2**qos_tag_width < qos_levels:
            return (True, f"QOS_TAG_WIDTH={qos_tag_width} cannot encode {qos_levels} levels")

        return (False, "")

    except Exception as e:
        return (True, f"Invalid parameters: {e}")

# ===================== MAIN SWEEP LOGIC =====================

def cartesian_sweep() -> List[Dict]:
    """Generate full Cartesian product"""
    keys = list(DEFINE_SPACE.keys())
    lists = [DEFINE_SPACE[k] for k in keys]
    combos = []

    for vals in itertools.product(*lists):
        combo = {k: str(v) for k, v in zip(keys, vals)}
        combos.append(combo)

    return combos

def annotate_estimates(cfg: Dict) -> Dict:
    """Add performance/resource estimates to config"""
    try:
        n = int(cfg["N"])
        s = int(cfg["S"])
        d = int(cfg["D"])
        w = int(cfg["W"])
        line_rate = float(cfg["LINE_RATE"])
        qos_levels = int(cfg["QOS_LEVELS"])
        enable_qos = bool(int(cfg["ENABLE_QOS"]))

        # Compute clock
        clk_base = w / line_rate
        clk = adjust_clk_for_qos(clk_base, qos_levels, enable_qos)
        clk_mhz = 1000.0 / clk

        # Estimates
        cfg["latency_est"] = estimate_latency(n, s, d, qos_levels, enable_qos)
        cfg["lut_est"] = estimate_lut_usage(n, s, d, w, qos_levels, enable_qos)
        cfg["power_est"] = estimate_power(n, clk_mhz, cfg["lut_est"])
        cfg["clk_mhz"] = clk_mhz

        # Composite score (weighted sum, normalized)
        cfg["score"] = (
            OBJECTIVES["latency"] * (1000.0 / cfg["latency_est"]) +
            OBJECTIVES["resource"] * (1e6 / cfg["lut_est"]) +
            OBJECTIVES["power"] * (10.0 / cfg["power_est"])
        )

        return cfg

    except Exception as e:
        print(f"Warning: Estimation failed for config: {e}")
        cfg["latency_est"] = 0
        cfg["lut_est"] = 0
        cfg["power_est"] = 0
        cfg["score"] = 0
        return cfg

def main():
    parser = argparse.ArgumentParser(description="Intelligent QoS config sweep")
    parser.add_argument("--no-prune", action="store_true", help="Disable pruning heuristics")
    parser.add_argument("--pareto-only", action="store_true", help="Only generate Pareto-optimal configs")
    parser.add_argument("--max-configs", type=int, default=100, help="Maximum configs to generate")
    parser.add_argument("--output-dir", type=Path, default=CONFIG_DIR, help="Output directory")
    args = parser.parse_args()

    print("\n" + "="*70)
    print("QoS CONFIGURATION SWEEP - Design Space Exploration")
    print("="*70)

    # Generate full space
    all_configs = cartesian_sweep()
    print(f"Initial configuration space: {len(all_configs)} configs")

    # Apply pruning
    if not args.no_prune:
        pruned = []
        prune_reasons = {}

        for cfg in all_configs:
            should_prune, reason = prune_config(cfg)
            if should_prune:
                prune_reasons[reason] = prune_reasons.get(reason, 0) + 1
            else:
                pruned.append(cfg)

        print(f"\nPruning results:")
        for reason, count in prune_reasons.items():
            print(f"  - {reason}: {count} configs removed")

        all_configs = pruned
        print(f"After pruning: {len(all_configs)} configs\n")

    # Annotate with estimates
    print("Estimating performance metrics...")
    for cfg in all_configs:
        annotate_estimates(cfg)

    # Pareto filtering
    if args.pareto_only:
        print("Computing Pareto frontier...")
        pareto = ParetoFrontier()
        for cfg in all_configs:
            pareto.add(cfg)

        all_configs = pareto.frontier
        print(f"Pareto-optimal configs: {len(all_configs)}")

    # Sort by composite score (best first)
    all_configs.sort(key=lambda x: x["score"], reverse=True)

    # Limit to max_configs
    if len(all_configs) > args.max_configs:
        print(f"Limiting to top {args.max_configs} configs by score")
        all_configs = all_configs[:args.max_configs]

    # Generate output files
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)

    inc_tmpl = INC_FILE.read_text(encoding="utf-8", errors="ignore")
    clk_tmpl = CLK_FILE.read_text(encoding="utf-8", errors="ignore")
    tcl_tmpl = PARTNUM_FILE.read_text(encoding="utf-8", errors="ignore")

    manifest = []
    for i, cfg in enumerate(all_configs, start=1):
        # Extract parameters
        n = int(cfg["N"])
        d = int(cfg["D"])
        w = int(cfg["W"])
        line_rate = float(cfg["LINE_RATE"])
        qos_levels = int(cfg["QOS_LEVELS"])
        enable_qos = bool(int(cfg["ENABLE_QOS"]))

        # Compute timing
        clk_base = w / line_rate
        clk = adjust_clk_for_qos(clk_base, qos_levels, enable_qos)
        part = pick_part_with_qos(n, d, enable_qos, None)

        # Generate files
        inc_out = replace_defines(inc_tmpl, cfg)
        clk_out = set_clk_period_xdc(clk_tmpl, clk)
        tcl_out = set_device_part_num_tcl(tcl_tmpl, part)

        folder = CONFIG_DIR / f"{i:03d}"
        folder.mkdir(parents=True, exist_ok=True)

        (folder / "implement_options.vh").write_text(inc_out, encoding="utf-8")
        (folder / "timing.xdc").write_text(clk_out, encoding="utf-8")
        (folder / "build_switches_main.tcl").write_text(tcl_out, encoding="utf-8")

        # Metadata
        meta = {
            "config_id": i,
            "rank": i,
            "score": cfg["score"],
            "estimates": {
                "latency_ns": cfg["latency_est"],
                "lut_count": cfg["lut_est"],
                "power_w": cfg["power_est"]
            },
            "timing": {
                "clk_base_ns": clk_base,
                "clk_qos_ns": clk,
                "penalty_ns": clk - clk_base,
                "freq_mhz": cfg["clk_mhz"]
            },
            "device": part,
            "defines": {k: cfg[k] for k in DEFINE_ORDER}
        }

        (folder / "meta.json").write_text(json.dumps(meta, indent=2), encoding="utf-8")

        (folder / "meta.txt").write_text(
            f"CONFIG #{i} (Rank: {i}, Score: {cfg['score']:.3f})\n"
            f"═══════════════════════════════════════════\n"
            f"Timing:\n"
            f"  Base Clock:      {clk_base:.4f} ns ({1000/clk_base:.1f} MHz)\n"
            f"  QoS Clock:       {clk:.4f} ns ({cfg['clk_mhz']:.1f} MHz)\n"
            f"  Penalty:         {clk-clk_base:.4f} ns\n"
            f"\nEstimates:\n"
            f"  Latency:         {cfg['latency_est']:.2f} ns\n"
            f"  LUTs:            {cfg['lut_est']:,}\n"
            f"  Power:           {cfg['power_est']:.3f} W\n"
            f"\nDevice:            {part}\n"
            f"\nDefines:\n" +
            "\n".join([f"  {k:20s} = {cfg[k]}" for k in DEFINE_ORDER]),
            encoding="utf-8"
        )

        manifest.append(meta)

    # Save master manifest
    manifest_file = CONFIG_DIR / "manifest_sweep.json"
    with open(manifest_file, "w") as f:
        json.dump(manifest, f, indent=2)

    # Summary report
    print("\n" + "="*70)
    print("SWEEP SUMMARY")
    print("="*70)
    print(f"Total configs generated:  {len(manifest)}")
    print(f"Manifest saved to:        {manifest_file}")

    # Top 5 by score
    print("\nTop 5 Configurations:")
    print(f"{'Rank':<6} {'N':>4} {'S':>4} {'D':>6} {'QoS':>5} {'Score':>8} {'Latency':>10} {'LUTs':>10}")
    print("-"*70)
    for m in manifest[:5]:
        d = m["defines"]
        e = m["estimates"]
        print(f"{m['rank']:<6} {d['N']:>4} {d['S']:>4} {d['D']:>6} {d['ENABLE_QOS']:>5} "
              f"{m['score']:>8.3f} {e['latency_ns']:>10.2f} {e['lut_count']:>10,}")
    print("="*70 + "\n")

if __name__ == "__main__":
    main()