#!/usr/bin/env python3
"""
Compare QoS ON vs OFF Impact
Run from: project root or scr/analysis/
Requires: Two builds (QoS enabled and disabled)
"""

import re
from pathlib import Path
import sys

# Auto-detect project root
SCRIPT_DIR = Path(__file__).parent
PROJECT_ROOT = SCRIPT_DIR.parent.parent

QOS_ON_DIR = PROJECT_ROOT / "vivado_build"
QOS_OFF_DIR = PROJECT_ROOT / "vivado_build_no_qos"

def parse_report(rpt_file: Path) -> dict:
    """Extract key metrics from Vivado reports"""
    if not rpt_file.exists():
        print(f" Warning: {rpt_file} not found")
        return {}
    
    text = rpt_file.read_text(encoding='utf-8', errors='ignore')
    
    # Timing
    wns_match = re.search(r'WNS\(ns\)\s+([-\d.]+)', text)
    whs_match = re.search(r'WHS\(ns\)\s+([-\d.]+)', text)
    
    # Resources
    lut_match = re.search(r'CLB LUTs\*?\s+\|\s+([\d,]+)', text)
    ff_match = re.search(r'CLB Registers\s+\|\s+([\d,]+)', text)
    bram_match = re.search(r'Block RAM Tile\s+\|\s+([\d.]+)', text)
    dsp_match = re.search(r'DSPs\s+\|\s+([\d,]+)', text)
    
    # Power (if available)
    power_match = re.search(r'Total On-Chip Power \(W\)\s+\|\s+([\d.]+)', text)
    
    return {
        'wns': float(wns_match.group(1)) if wns_match else None,
        'whs': float(whs_match.group(1)) if whs_match else None,
        'lut': int(lut_match.group(1).replace(',', '')) if lut_match else 0,
        'ff': int(ff_match.group(1).replace(',', '')) if ff_match else 0,
        'bram': float(bram_match.group(1)) if bram_match else 0.0,
        'dsp': int(dsp_match.group(1).replace(',', '')) if dsp_match else 0,
        'power': float(power_match.group(1)) if power_match else None
    }

def print_comparison(qos_on: dict, qos_off: dict):
    """Pretty-print comparison table"""
    print("\n" + "="*70)
    print("  QoS IMPACT ANALYSIS")
    print("="*70)
    
    if not qos_on or not qos_off:
        print(" Error: Missing build data")
        print(f"   QoS ON:  {QOS_ON_DIR / 'reports/utilization_synth.rpt'}")
        print(f"   QoS OFF: {QOS_OFF_DIR / 'reports/utilization_synth.rpt'}")
        return
    
    print(f"\n{'Metric':<20} {'QoS ON':>15} {'QoS OFF':>15} {'Delta':>15} {'% Change':>10}")
    print("-"*70)
    
    # Timing
    if qos_on.get('wns') and qos_off.get('wns'):
        wns_delta = qos_on['wns'] - qos_off['wns']
        print(f"{'WNS (ns)':<20} {qos_on['wns']:>15.3f} {qos_off['wns']:>15.3f} "
              f"{wns_delta:>15.3f} {(wns_delta/qos_off['wns']*100):>9.1f}%")
    
    if qos_on.get('whs') and qos_off.get('whs'):
        whs_delta = qos_on['whs'] - qos_off['whs']
        print(f"{'WHS (ns)':<20} {qos_on['whs']:>15.3f} {qos_off['whs']:>15.3f} "
              f"{whs_delta:>15.3f} {(whs_delta/qos_off['whs']*100):>9.1f}%")
    
    print("-"*70)
    
    # Resources
    for metric, name in [('lut', 'LUTs'), ('ff', 'Flip-Flops'), 
                          ('bram', 'BRAMs'), ('dsp', 'DSPs')]:
        if qos_on.get(metric) and qos_off.get(metric):
            delta = qos_on[metric] - qos_off[metric]
            pct = (delta / qos_off[metric] * 100) if qos_off[metric] > 0 else 0
            print(f"{name:<20} {qos_on[metric]:>15,} {qos_off[metric]:>15,} "
                  f"{delta:>15,} {pct:>9.1f}%")
    
    print("-"*70)
    
    # Power
    if qos_on.get('power') and qos_off.get('power'):
        power_delta = qos_on['power'] - qos_off['power']
        pct = (power_delta / qos_off['power'] * 100) if qos_off['power'] > 0 else 0
        print(f"{'Power (W)':<20} {qos_on['power']:>15.3f} {qos_off['power']:>15.3f} "
              f"{power_delta:>15.3f} {pct:>9.1f}%")
    
    print("="*70)
    
    # Interpretation
    print("\n📊 KEY FINDINGS:")
    
    if qos_on.get('lut'):
        lut_overhead = ((qos_on['lut'] - qos_off['lut']) / qos_off['lut'] * 100) if qos_off['lut'] > 0 else 0
        print(f"  • QoS logic overhead: {lut_overhead:.1f}% LUTs")
    
    if qos_on.get('wns') and qos_off.get('wns'):
        timing_impact = qos_on['wns'] - qos_off['wns']
        if timing_impact < -0.5:
            print(f"   QoS reduces slack by {abs(timing_impact):.2f} ns (may need freq reduction)")
        elif abs(timing_impact) < 0.1:
            print(f"   QoS has minimal timing impact ({abs(timing_impact):.2f} ns)")
        else:
            print(f"   QoS improves slack by {timing_impact:.2f} ns")
    
    print()

def main():
    print("Searching for build outputs...")
    
    # Try multiple report filenames
    for rpt_name in ["utilization_synth.rpt", "switch_fabric_utilization_synth.rpt"]:
        qos_on_rpt = QOS_ON_DIR / "reports" / rpt_name
        if qos_on_rpt.exists():
            break
    
    for rpt_name in ["utilization_synth.rpt", "switch_fabric_utilization_synth.rpt"]:
        qos_off_rpt = QOS_OFF_DIR / "reports" / rpt_name
        if qos_off_rpt.exists():
            break
    
    if not qos_on_rpt.exists():
        print(f"\n QoS ON build not found:")
        print(f"   Expected: {QOS_ON_DIR / 'reports'}")
        print(f"   Run: vivado_qos_build_2019.tcl with ENABLE_QOS=1")
        sys.exit(1)
    
    if not qos_off_rpt.exists():
        print(f"\n QoS OFF build not found:")
        print(f"   Expected: {QOS_OFF_DIR / 'reports'}")
        print(f"\n   To generate:")
        print(f"   1. Edit src/inc/implement_options.vh: set ENABLE_QOS to 0")
        print(f"   2. Run: vivado_qos_build_2019.tcl")
        print(f"   3. Rename vivado_build to vivado_build_no_qos")
        print(f"   4. Re-enable QoS and rebuild")
        sys.exit(1)
    
    print(" Found both builds\n")
    
    qos_on = parse_report(qos_on_rpt)
    qos_off = parse_report(qos_off_rpt)
    
    print_comparison(qos_on, qos_off)

if __name__ == "__main__":
    main()