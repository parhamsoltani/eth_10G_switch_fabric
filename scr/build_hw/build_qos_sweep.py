#!/usr/bin/env python3
"""
Batch runner for QoS configuration sweep
Reads manifest.json and builds all configs in parallel
"""

import json
import subprocess
import shutil
from pathlib import Path
from concurrent.futures import ProcessPoolExecutor, as_completed
from typing import Dict
import argparse

ROOT = Path(__file__).resolve().parents[2]
CONFIG_DIR = ROOT / "scr/save_configs/config_generator/configs"
MANIFEST = CONFIG_DIR / "manifest.json"
BUILD_SCRIPT = ROOT / "scr/build_hw/build_switches_run.tcl"

def build_config(cfg: Dict, dry_run: bool = False) -> Dict:
    """Build a single configuration"""
    cfg_id = cfg["config_id"]
    cfg_folder = CONFIG_DIR / f"{cfg_id:03d}"

    # Copy config files to src/
    inc_src = ROOT / "src/inc/implement_options.vh"
    clk_src = ROOT / "src/xdc/timing.xdc"
    tcl_src = ROOT / "scr/build_hw/build_switches_main.tcl"

    try:
        shutil.copy(cfg_folder / "implement_options.vh", inc_src)
        shutil.copy(cfg_folder / "timing.xdc", clk_src)
        shutil.copy(cfg_folder / "build_switches_main.tcl", tcl_src)

        if dry_run:
            print(f"[DRY-RUN] Would build config {cfg_id}")
            return {"config_id": cfg_id, "status": "skipped"}

        # Run Vivado build
        result = subprocess.run(
            ["vivado", "-mode", "batch", "-source", str(BUILD_SCRIPT)],
            cwd=ROOT / "scr/build_hw",
            capture_output=True,
            text=True,
            timeout=7200  # 2-hour timeout
        )

        if result.returncode == 0:
            print(f"[SUCCESS] Config {cfg_id} built successfully")
            return {"config_id": cfg_id, "status": "success"}
        else:
            print(f"[FAIL] Config {cfg_id} build failed")
            return {"config_id": cfg_id, "status": "failed", "error": result.stderr[:200]}

    except Exception as e:
        print(f"[ERROR] Config {cfg_id}: {e}")
        return {"config_id": cfg_id, "status": "error", "error": str(e)}

def main():
    parser = argparse.ArgumentParser(description="Batch QoS config builder")
    parser.add_argument("--dry-run", action="store_true", help="Simulate builds without running Vivado")
    parser.add_argument("--max-workers", type=int, default=4, help="Parallel build workers")
    parser.add_argument("--filter", help="Only build configs matching criteria (e.g., 'ENABLE_QOS=1')")
    args = parser.parse_args()

    if not MANIFEST.exists():
        raise FileNotFoundError(f"Manifest not found: {MANIFEST}\nRun config_generator_qos.py first")

    with open(MANIFEST, "r") as f:
        all_configs = json.load(f)

    # Apply filter
    if args.filter:
        key, val = args.filter.split("=")
        configs = [c for c in all_configs if str(c["defines"].get(key)) == val]
        print(f"Filtered {len(configs)}/{len(all_configs)} configs with {args.filter}")
    else:
        configs = all_configs

    if not configs:
        print("No configs to build after filtering")
        return

    print(f"\n{'='*60}")
    print(f"Building {len(configs)} configurations")
    print(f"Max workers: {args.max_workers}")
    print(f"Dry run: {args.dry_run}")
    print(f"{'='*60}\n")

    results = []
    with ProcessPoolExecutor(max_workers=args.max_workers) as executor:
        futures = {executor.submit(build_config, cfg, args.dry_run): cfg for cfg in configs}

        for future in as_completed(futures):
            result = future.result()
            results.append(result)

    # Summary
    success = sum(1 for r in results if r["status"] == "success")
    failed = sum(1 for r in results if r["status"] == "failed")

    print(f"\n{'='*60}")
    print(f"Build Summary:")
    print(f"  Success: {success}")
    print(f"  Failed:  {failed}")
    print(f"{'='*60}\n")

    # Save results
    results_file = CONFIG_DIR / "build_results.json"
    with open(results_file, "w") as f:
        json.dump(results, f, indent=2)

    print(f"Results saved to: {results_file}")

if __name__ == "__main__":
    main()