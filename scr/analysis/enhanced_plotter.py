#!/usr/bin/env python3
"""
Enhanced Thesis Figure Generator
IEEE-style plots for academic publications
"""

import matplotlib
matplotlib.use('Agg')  # Non-interactive backend
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from pathlib import Path
import json

# IEEE-compliant style
plt.style.use('seaborn-v0_8-paper')
plt.rcParams.update({
    'font.family': 'serif',
    'font.serif': ['Times New Roman', 'DejaVu Serif'],
    'font.size': 10,
    'axes.labelsize': 11,
    'axes.titlesize': 12,
    'legend.fontsize': 9,
    'xtick.labelsize': 9,
    'ytick.labelsize': 9,
    'figure.figsize': (7, 4),  # IEEE single-column: 3.5", double: 7"
    'figure.dpi': 300,
    'savefig.dpi': 300,
    'savefig.bbox': 'tight',
    'axes.grid': True,
    'grid.alpha': 0.3,
    'grid.linestyle': ':',
})

class ThesisPlotter:
    """Generate all thesis figures"""
    
    def __init__(self, data_dir: Path, output_dir: Path):
        self.data_dir = Path(data_dir)
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(parents=True, exist_ok=True)
        
        # Color scheme (colorblind-friendly)
        self.colors = {
            'high_priority': '#1f77b4',   # Blue
            'low_priority': '#d62728',    # Red
            'medium': '#ff7f0e',          # Orange
            'neutral': '#7f7f7f'          # Gray
        }
    
    def load_latency_data(self):
        """Load latency CSV"""
        csv_path = self.data_dir / "latency_data.csv"
        if not csv_path.exists():
            print(f"Warning: {csv_path} not found")
            return None
        return pd.read_csv(csv_path)
    
    def plot_qos_latency_comparison(self):
        """Figure 1: Latency by QoS Priority"""
        df = self.load_latency_data()
        if df is None or df.empty:
            return
        
        # Aggregate by QoS level
        grouped = df.groupby('QoS Level').agg({
            'Avg Latency (ns)': 'mean',
            'Min Latency (ns)': 'min',
            'Max Latency (ns)': 'max'
        }).reset_index()
        
        fig, ax = plt.subplots()
        
        x = grouped['QoS Level']
        y_avg = grouped['Avg Latency (ns)']
        y_min = grouped['Min Latency (ns)']
        y_max = grouped['Max Latency (ns)']
        
        # Plot bars with error bars
        ax.bar(x, y_avg, color=self.colors['high_priority'], alpha=0.7, 
               edgecolor='black', linewidth=0.5)
        ax.errorbar(x, y_avg, yerr=[y_avg - y_min, y_max - y_avg],
                   fmt='none', ecolor='black', capsize=4, capthick=1.5)
        
        ax.set_xlabel('QoS Priority Level')
        ax.set_ylabel('Latency (ns)')
        ax.set_title('Packet Latency vs. QoS Priority (802.1p)')
        ax.set_xticks(x)
        ax.set_xticklabels([f'P{int(p)}' for p in x])
        
        # Add value labels
        for i, (xi, yi) in enumerate(zip(x, y_avg)):
            ax.text(xi, yi + 10, f'{yi:.0f}', ha='center', va='bottom', fontsize=8)
        
        plt.tight_layout()
        plt.savefig(self.output_dir / 'fig1_qos_latency.pdf')
        plt.savefig(self.output_dir / 'fig1_qos_latency.png')
        plt.close()
        print(f"  ✓ Generated: fig1_qos_latency.pdf")
    
    def plot_resource_utilization(self, util_data: dict):
        """Figure 2: FPGA Resource Utilization"""
        fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(10, 4))
        
        # Left: Bar chart
        resources = ['LUTs', 'FFs', 'BRAM', 'DSP']
        used = [util_data.get(f'{r}_used', 0) for r in ['lut', 'ff', 'bram', 'dsp']]
        total = [util_data.get(f'{r}_total', 1) for r in ['lut', 'ff', 'bram', 'dsp']]
        pct = [100 * u / t if t > 0 else 0 for u, t in zip(used, total)]
        
        ax1.barh(resources, pct, color=self.colors['high_priority'], edgecolor='black')
        ax1.set_xlabel('Utilization (%)')
        ax1.set_title('FPGA Resource Utilization')
        ax1.set_xlim(0, 100)
        
        for i, (r, p, u) in enumerate(zip(resources, pct, used)):
            ax1.text(p + 2, i, f'{p:.1f}% ({u:,})', va='center', fontsize=8)
        
        # Right: Pie chart of LUT breakdown
        lut_logic = util_data.get('lut_logic', 0)
        lut_ram = util_data.get('lut_ram', 0)
        lut_srl = util_data.get('lut_srl', 0)
        lut_unused = util_data['lut_total'] - util_data['lut_used']
        
        labels = ['Logic', 'Dist. RAM', 'SRL', 'Unused']
        sizes = [lut_logic, lut_ram, lut_srl, lut_unused]
        colors = [self.colors['high_priority'], self.colors['medium'], 
                 self.colors['low_priority'], self.colors['neutral']]
        
        ax2.pie(sizes, labels=labels, colors=colors, autopct='%1.1f%%', startangle=90)
        ax2.set_title('LUT Usage Breakdown')
        
        plt.tight_layout()
        plt.savefig(self.output_dir / 'fig2_resources.pdf')
        plt.savefig(self.output_dir / 'fig2_resources.png')
        plt.close()
        print(f"  ✓ Generated: fig2_resources.pdf")
    
    def plot_throughput_vs_load(self):
        """Figure 3: Throughput vs. Offered Load"""
        # Generate synthetic data (replace with real measurements)
        loads = np.linspace(0, 1.0, 20)
        throughput_qos = 100 * np.minimum(loads * 1.02, 0.98)
        throughput_no_qos = 100 * np.minimum(loads * 0.95, 0.90)
        ideal = 100 * loads
        
        fig, ax = plt.subplots()
        
        ax.plot(loads * 100, throughput_qos, 'o-', label='With QoS', 
               color=self.colors['high_priority'], linewidth=2, markersize=4)
        ax.plot(loads * 100, throughput_no_qos, 's--', label='Without QoS (FIFO)',
               color=self.colors['low_priority'], linewidth=2, markersize=4)
        ax.plot(loads * 100, ideal, ':', label='Ideal', 
               color=self.colors['neutral'], linewidth=1)
        
        ax.set_xlabel('Offered Load (%)')
        ax.set_ylabel('Aggregate Throughput (Gbps)')
        ax.set_title('Switch Fabric Throughput (10×10G Configuration)')
        ax.legend(loc='lower right')
        ax.set_xlim(0, 105)
        ax.set_ylim(0, 110)
        
        plt.tight_layout()
        plt.savefig(self.output_dir / 'fig3_throughput.pdf')
        plt.savefig(self.output_dir / 'fig3_throughput.png')
        plt.close()
        print(f"  ✓ Generated: fig3_throughput.pdf")

def main():
    data_dir = Path("results")
    output_dir = Path("thesis_figures")
    
    plotter = ThesisPlotter(data_dir, output_dir)
    
    print("\nGenerating thesis figures...")
    plotter.plot_qos_latency_comparison()
    
    # Example resource data (parse from your utilization report)
    util_data = {
        'lut_used': 6319, 'lut_total': 162720,
        'lut_logic': 4733, 'lut_ram': 1555, 'lut_srl': 31,
        'ff_used': 8838, 'ff_total': 325440,
        'bram_used': 22.5, 'bram_total': 360,
        'dsp_used': 0, 'dsp_total': 1368
    }
    plotter.plot_resource_utilization(util_data)
    plotter.plot_throughput_vs_load()
    
    print(f"\n✓ All figures saved to: {output_dir}")

if __name__ == "__main__":
    main()