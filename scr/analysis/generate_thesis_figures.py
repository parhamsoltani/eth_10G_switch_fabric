#!/usr/bin/env python3
"""
Generate thesis-quality figures from QoS simulation results
Requires: pip install matplotlib numpy

Usage: python generate_thesis_figures.py <results_dir>
"""

import os
import sys
import csv
from pathlib import Path
from typing import Dict, List
from collections import defaultdict

# Try to import matplotlib
try:
    import matplotlib
    matplotlib.use('Agg')  # Non-interactive backend for servers
    import matplotlib.pyplot as plt
    import numpy as np
    HAS_MATPLOTLIB = True
except ImportError:
    HAS_MATPLOTLIB = False
    print("Warning: matplotlib not installed.")
    print("Install with: pip install matplotlib numpy")

# Color scheme for QoS levels (IEEE-friendly, grayscale-compatible)
QOS_COLORS = {
    7: '#1a472a',  # Dark green - Network Control
    6: '#2e7d32',  # Green - Voice
    5: '#43a047',  # Light green - Video
    4: '#66bb6a',  # Lighter green - Critical
    3: '#81c784',  # Pale green - Excellent
    2: '#a5d6a7',  # Very pale green - Standard
    1: '#c8e6c9',  # Near white green - Best Effort
    0: '#e8f5e9',  # Lightest green - Background
}

QOS_NAMES = {
    0: 'Background',
    1: 'Best Effort',
    2: 'Standard', 
    3: 'Excellent',
    4: 'Critical',
    5: 'Video',
    6: 'Voice',
    7: 'Network Control'
}


def load_latency_csv(filepath: str) -> Dict[int, Dict]:
    """Load latency data from CSV file"""
    data = defaultdict(lambda: {'avg': [], 'min': [], 'max': [], 'count': 0})
    
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            for row in reader:
                try:
                    qos = int(row['QoS Level'])
                    avg = float(row['Avg Latency (ns)'])
                    
                    data[qos]['avg'].append(avg)
                    
                    if 'Min Latency (ns)' in row:
                        min_val = float(row['Min Latency (ns)'])
                        if min_val > 0:
                            data[qos]['min'].append(min_val)
                    
                    if 'Max Latency (ns)' in row:
                        max_val = float(row['Max Latency (ns)'])
                        if max_val > 0:
                            data[qos]['max'].append(max_val)
                    
                    if 'Packet Count' in row:
                        data[qos]['count'] += int(row['Packet Count'])
                    else:
                        data[qos]['count'] += 1
                        
                except (ValueError, KeyError) as e:
                    continue
    except FileNotFoundError:
        print(f"Error: File not found: {filepath}")
        return {}
    
    return dict(data)


def load_test_summary(filepath: str) -> List[Dict]:
    """Load test summary CSV"""
    results = []
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            for row in reader:
                results.append(row)
    except FileNotFoundError:
        print(f"Warning: Summary file not found: {filepath}")
    return results


def generate_latency_bar_chart(data: Dict[int, Dict], output_file: str):
    """Generate bar chart comparing average latency across QoS levels"""
    if not HAS_MATPLOTLIB or not data:
        return
    
    fig, ax = plt.subplots(figsize=(10, 6))
    
    qos_levels = sorted(data.keys(), reverse=True)
    avg_latencies = []
    min_latencies = []
    max_latencies = []
    
    for q in qos_levels:
        avg_latencies.append(np.mean(data[q]['avg']) if data[q]['avg'] else 0)
        min_latencies.append(np.min(data[q]['min']) if data[q]['min'] else 0)
        max_latencies.append(np.max(data[q]['max']) if data[q]['max'] else 0)
    
    colors = [QOS_COLORS.get(q, '#888888') for q in qos_levels]
    labels = [f"QoS {q}\n({QOS_NAMES.get(q, 'Unknown')})" for q in qos_levels]
    
    x = np.arange(len(qos_levels))
    bars = ax.bar(x, avg_latencies, color=colors, edgecolor='black', linewidth=0.5)
    
    # Add error bars for min/max
    for i, (avg, mn, mx) in enumerate(zip(avg_latencies, min_latencies, max_latencies)):
        if mx > 0 and mn > 0:
            ax.errorbar(i, avg, yerr=[[avg-mn], [mx-avg]], fmt='none', 
                       color='black', capsize=3, capthick=1)
    
    ax.set_ylabel('Average Latency (ns)', fontsize=12)
    ax.set_xlabel('QoS Priority Level', fontsize=12)
    ax.set_title('Packet Latency by QoS Priority Level', fontsize=14, fontweight='bold')
    ax.set_xticks(x)
    ax.set_xticklabels(labels, fontsize=9)
    
    # Add value labels on bars
    for bar, val in zip(bars, avg_latencies):
        if val > 0:
            height = bar.get_height()
            ax.annotate(f'{val:.1f}',
                       xy=(bar.get_x() + bar.get_width()/2, height),
                       xytext=(0, 3), textcoords="offset points",
                       ha='center', va='bottom', fontsize=9)
    
    ax.grid(axis='y', alpha=0.3)
    ax.set_axisbelow(True)
    
    plt.tight_layout()
    plt.savefig(output_file, dpi=300, bbox_inches='tight')
    plt.close()
    print(f"Generated: {output_file}")


def generate_latency_comparison_chart(data: Dict[int, Dict], output_file: str):
    """Generate grouped bar chart for min/avg/max latency comparison"""
    if not HAS_MATPLOTLIB or not data:
        return
    
    fig, ax = plt.subplots(figsize=(12, 6))
    
    qos_levels = sorted(data.keys(), reverse=True)
    x = np.arange(len(qos_levels))
    width = 0.25
    
    min_vals = [np.min(data[q]['min']) if data[q]['min'] else 0 for q in qos_levels]
    avg_vals = [np.mean(data[q]['avg']) if data[q]['avg'] else 0 for q in qos_levels]
    max_vals = [np.max(data[q]['max']) if data[q]['max'] else 0 for q in qos_levels]
    
    ax.bar(x - width, min_vals, width, label='Minimum', color='#4caf50', edgecolor='black')
    ax.bar(x, avg_vals, width, label='Average', color='#2196f3', edgecolor='black')
    ax.bar(x + width, max_vals, width, label='Maximum', color='#f44336', edgecolor='black')
    
    ax.set_ylabel('Latency (ns)', fontsize=12)
    ax.set_xlabel('QoS Priority Level', fontsize=12)
    ax.set_title('Latency Distribution by QoS Level (Min/Avg/Max)', fontsize=14, fontweight='bold')
    ax.set_xticks(x)
    ax.set_xticklabels([f"QoS {q}" for q in qos_levels])
    ax.legend()
    ax.grid(axis='y', alpha=0.3)
    
    plt.tight_layout()
    plt.savefig(output_file, dpi=300, bbox_inches='tight')
    plt.close()
    print(f"Generated: {output_file}")


def generate_priority_enforcement_chart(data: Dict[int, Dict], output_file: str):
    """Generate chart showing strict priority enforcement"""
    if not HAS_MATPLOTLIB or not data:
        return
    
    fig, ax = plt.subplots(figsize=(10, 6))
    
    qos_levels = sorted(data.keys(), reverse=True)
    avg_latencies = [np.mean(data[q]['avg']) if data[q]['avg'] else 0 for q in qos_levels]
    
    # Create x positions (0 = highest priority)
    x_positions = list(range(len(qos_levels)))
    
    # Plot as scatter with connecting line
    for i, (q, lat) in enumerate(zip(qos_levels, avg_latencies)):
        ax.scatter(i, lat, s=200, c=QOS_COLORS.get(q, '#888888'), 
                  edgecolors='black', linewidths=1.5, zorder=5)
    
    ax.plot(x_positions, avg_latencies, 'k--', alpha=0.5, linewidth=1, zorder=1)
    
    ax.set_ylabel('Average Latency (ns)', fontsize=12)
    ax.set_xlabel('Priority Level (Higher = Better Service)', fontsize=12)
    ax.set_title('QoS Priority Enforcement Verification\n(Lower Latency = Better Service)', 
                fontsize=14, fontweight='bold')
    ax.set_xticks(x_positions)
    ax.set_xticklabels([f"QoS {q}\n{QOS_NAMES.get(q, '')}" for q in qos_levels], 
                       rotation=45, ha='right', fontsize=9)
    
    ax.grid(True, alpha=0.3)
    
    plt.tight_layout()
    plt.savefig(output_file, dpi=300, bbox_inches='tight')
    plt.close()
    print(f"Generated: {output_file}")


def generate_test_status_chart(summary_data: List[Dict], output_file: str):
    """Generate pie chart of test pass/fail status"""
    if not HAS_MATPLOTLIB or not summary_data:
        return
    
    fig, ax = plt.subplots(figsize=(8, 6))
    
    status_counts = defaultdict(int)
    for row in summary_data:
        status = row.get('Status', 'UNKNOWN')
        status_counts[status] += 1
    
    labels = list(status_counts.keys())
    sizes = list(status_counts.values())
    colors = {'PASSED': '#4caf50', 'FAILED': '#f44336', 'UNKNOWN': '#9e9e9e'}
    pie_colors = [colors.get(s, '#888888') for s in labels]
    
    wedges, texts, autotexts = ax.pie(sizes, labels=labels, colors=pie_colors,
                                       autopct='%1.1f%%', startangle=90,
                                       wedgeprops={'edgecolor': 'black', 'linewidth': 1})
    
    ax.set_title('Test Suite Results', fontsize=14, fontweight='bold')
    
    plt.tight_layout()
    plt.savefig(output_file, dpi=300, bbox_inches='tight')
    plt.close()
    print(f"Generated: {output_file}")


def main():
    if len(sys.argv) < 2:
        print("Usage: generate_thesis_figures.py <results_dir>")
        print("  Generates thesis-quality figures from simulation results")
        sys.exit(1)
    
    results_dir = Path(sys.argv[1])
    figures_dir = results_dir / "figures"
    figures_dir.mkdir(exist_ok=True)
    
    print(f"\nQoS Switch Fabric - Figure Generator")
    print(f"="*50)
    print(f"Results directory: {results_dir}")
    print(f"Figures directory: {figures_dir}")
    print()
    
    if not HAS_MATPLOTLIB:
        print("Error: matplotlib is required for figure generation")
        print("Install with: pip install matplotlib numpy")
        sys.exit(1)
    
    # Find latest latency CSV
    latency_files = list(results_dir.glob("latency_data_*.csv"))
    if not latency_files:
        print("No latency data files found!")
        sys.exit(1)
    
    latest_latency = max(latency_files, key=lambda x: x.stat().st_mtime)
    print(f"Using latency data: {latest_latency.name}")
    
    # Find latest summary CSV
    summary_files = list(results_dir.glob("test_summary_*.csv"))
    latest_summary = max(summary_files, key=lambda x: x.stat().st_mtime) if summary_files else None
    
    # Load data
    latency_data = load_latency_csv(str(latest_latency))
    summary_data = load_test_summary(str(latest_summary)) if latest_summary else []
    
    if not latency_data:
        print("No latency data found in CSV!")
        sys.exit(1)
    
    print(f"Found data for QoS levels: {sorted(latency_data.keys())}")
    print()
    
    # Generate figures
    print("Generating figures...")
    generate_latency_bar_chart(latency_data, str(figures_dir / "fig_latency_by_qos.png"))
    generate_latency_comparison_chart(latency_data, str(figures_dir / "fig_latency_minmaxavg.png"))
    generate_priority_enforcement_chart(latency_data, str(figures_dir / "fig_priority_enforcement.png"))
    
    if summary_data:
        generate_test_status_chart(summary_data, str(figures_dir / "fig_test_status.png"))
    
    print(f"\nAll figures saved to: {figures_dir}")
    return 0


if __name__ == "__main__":
    sys.exit(main())