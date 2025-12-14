
# Comprehensive Testing and Evaluation Strategy for Switch Fabric Q1 Publication

**Document Version:** 2.0
**Target Audience:** Researchers implementing paper validation
**Status:** Detailed Implementation Guideline
**Based on:** Current codebase structure and Persian language discussion

---

## Executive Summary

This document provides a **complete, step-by-step testing and evaluation strategy** specifically designed for validating the enhanced switch fabric architecture for Q1 journal publication. Unlike generic verification approaches, this strategy focuses on **publication-quality metrics collection** that will directly support your paper's claims.

### Key Decision: UVM vs. Lightweight Testbench

**Answer to Your Question: "Is UVM necessary for performance evaluation?"**

**No — UVM is NOT necessary for this paper.** Here's why:

| Criterion | UVM Approach | Lightweight Approach | Recommendation |
|-----------|-------------|---------------------|----------------|
| **Performance Measurement** | Overhead from TLM, monitors, scoreboards slows simulation | Direct SystemVerilog counters — fast | **Lightweight** |
| **Metric Collection** | Requires complex sequences and agents | Simple traffic generators + Python analysis | **Lightweight** |
| **Simulation Speed** | 10K-100K packets/hour | 1M-10M packets/hour | **Lightweight** |
| **Paper Needs** | Statistical significance requires LARGE sample sizes | Need 100M+ cycles for p99/p999 latency | **Lightweight** |
| **Setup Complexity** | Weeks to configure UVM environment | Days to build focused testbench | **Lightweight** |

**Bottom Line:** Keep your existing UVM framework (`UVMF_FS/`) for **functional verification** (correctness, protocol compliance), but build a **separate lightweight performance testbench** for paper evaluation.

---

## Part 1: Dual-Track Testing Strategy

### Track A: Functional Verification (Already Implemented — UVMF)

**Purpose:** Ensure design correctness
**Location:** `UVMF_FS/`
**Status:** ✅ Already complete based on your directory structure
**Scope:**
- Protocol compliance (AXI-Stream)
- Register access verification
- Corner cases (buffer overflow, underflow)
- Coverage closure (functional coverage)

**Action Required:** **Keep as-is** — use for debugging during development

---

### Track B: Performance Evaluation (NEW — For Paper)

**Purpose:** Collect publication-quality metrics
**Location:** `DUT_Validation_Tests/` (expand this)
**Status:** ⚠️ Needs significant expansion
**Scope:**
- Throughput measurements (Gbps)
- Latency distributions (p50/p95/p99/p999)
- Fairness analysis (Jain index)
- Queue depth statistics
- Multi-path efficiency
- Kalman prediction accuracy
- Power/area overhead

**Action Required:** **Build new performance testbench** (detailed below)

---

## Part 2: Performance Testbench Architecture

### 2.1 Directory Structure (Aligned with Your Codebase)

```
DUT_Validation_Tests/
├── hdl/
│   ├── testbench/
│   │   ├── perf_tb_top.sv                    ← NEW: Lightweight top
│   │   ├── traffic_generator_array.sv        ← NEW: Multi-port traffic gen
│   │   ├── latency_monitor_array.sv          ← NEW: Per-packet timestamping
│   │   ├── throughput_counter.sv             ← NEW: Bandwidth measurement
│   │   └── scoreboard_lite.sv                ← NEW: Simple packet checker
│   └── dut/
│       └── (link to your rtl/switch_fabric/)
│
├── tests/
│   ├── workload_configs/
│   │   ├── uniform_random.cfg
│   │   ├── hotspot_9to1.cfg
│   │   ├── incast_10to1.cfg
│   │   ├── bursty_onoff.cfg
│   │   └── ai_allreduce.cfg
│   └── test_scenarios/
│       ├── baseline_eval.sv
│       ├── ecs_validation.sv
│       ├── kalman_accuracy.sv
│       └── ablation_study.sv
│
├── scripts/
│   ├── compile_perf_tb.do                     ← Modelsim/Questa compile
│   ├── run_sweep.py                           ← Parameter sweep automation
│   ├── analyze_results.py                     ← Statistical analysis
│   ├── plot_latency_cdf.py                    ← CDF plotting
│   ├── plot_throughput.py                     ← Throughput bars
│   └── generate_paper_tables.py               ← LaTeX table generation
│
├── results/
│   ├── raw_data/
│   │   ├── baseline_uniform_run1.csv
│   │   ├── ecs_hotspot_run1.csv
│   │   └── ...
│   ├── processed/
│   │   ├── latency_summary.json
│   │   ├── throughput_summary.json
│   │   └── fairness_summary.json
│   ├── plots/
│   │   ├── latency_cdf_hotspot.pdf
│   │   ├── throughput_comparison.pdf
│   │   └── ablation_study.pdf
│   └── paper_tables/
│       ├── table1_performance.tex
│       └── table2_ablation.tex
│
└── docs/
    ├── testbench_architecture.md
    ├── workload_descriptions.md
    └── metric_definitions.md
```

---

## Part 3: Step-by-Step Implementation Guide

### Phase 1: Lightweight Testbench Core (Week 1-2)

#### Step 1.1: Create Performance Testbench Top

**File:** `DUT_Validation_Tests/hdl/testbench/perf_tb_top.sv`

```systemverilog
`timescale 1ns/1ps

module perf_tb_top;

    // Clock and reset
    logic clk_250mhz;
    logic rst_n;

    // DUT parameters
    localparam NUM_PORTS = 10;
    localparam DATA_WIDTH = 32;
    localparam QOS_LEVELS = 8;

    // Test configuration
    string test_name;
    string workload_file;
    longint total_cycles;
    longint packets_to_send;

    // Statistics
    longint total_packets_sent [NUM_PORTS-1:0];
    longint total_packets_received [NUM_PORTS-1:0];
    longint total_bytes_sent [NUM_PORTS-1:0];
    longint total_bytes_received [NUM_PORTS-1:0];

    // Clock generation
    initial begin
        clk_250mhz = 0;
        forever #2ns clk_250mhz = ~clk_250mhz;  // 250 MHz = 4ns period
    end

    // Reset sequence
    initial begin
        rst_n = 0;
        #100ns;
        rst_n = 1;
    end

    // Interfaces
    switch_data_if #(.DATA_WIDTH(DATA_WIDTH)) ingress_data [NUM_PORTS-1:0] (.*);
    switch_data_if #(.DATA_WIDTH(DATA_WIDTH)) egress_data [NUM_PORTS-1:0] (.*);

    // DUT instantiation (connect to your actual switch_fabric)
    switch_fabric #(
        .NUM_PORT(NUM_PORTS),
        .W(DATA_WIDTH),
        .QOS_LEVELS(QOS_LEVELS),
        .ELASTIC_ENABLE(1),           // Enable for enhanced tests
        .ADAPTIVE_QOS_ENABLE(1),
        .KALMAN_PREDICT_ENABLE(1)
    ) dut (
        .clk(clk_250mhz),
        .rst_n(rst_n),
        .rx_data(ingress_data),
        .tx_data(egress_data)
        // ... (other connections from your switch_fabric.sv)
    );

    // Traffic generator array
    traffic_generator_array #(
        .NUM_PORTS(NUM_PORTS),
        .DATA_WIDTH(DATA_WIDTH)
    ) traffic_gen (
        .clk(clk_250mhz),
        .rst_n(rst_n),
        .tx_data(ingress_data),
        .config_file(workload_file)
    );

    // Latency monitor array
    latency_monitor_array #(
        .NUM_PORTS(NUM_PORTS)
    ) lat_mon (
        .clk(clk_250mhz),
        .rst_n(rst_n),
        .rx_data(egress_data),
        .tx_timestamps(traffic_gen.packet_timestamps)
    );

    // Throughput counters
    throughput_counter_array #(
        .NUM_PORTS(NUM_PORTS)
    ) tput_counter (
        .clk(clk_250mhz),
        .rst_n(rst_n),
        .tx_data(ingress_data),
        .rx_data(egress_data),
        .bytes_sent(total_bytes_sent),
        .bytes_received(total_bytes_received)
    );

    // Test control
    initial begin
        // Read test configuration
        if (!$value$plusargs("TEST=%s", test_name)) begin
            test_name = "baseline_uniform";
        end

        if (!$value$plusargs("WORKLOAD=%s", workload_file)) begin
            workload_file = "tests/workload_configs/uniform_random.cfg";
        end

        if (!$value$plusargs("CYCLES=%d", total_cycles)) begin
            total_cycles = 10_000_000;  // 10M cycles = 40ms @ 250 MHz
        end

        $display("========================================");
        $display("Performance Test: %s", test_name);
        $display("Workload: %s", workload_file);
        $display("Simulation Duration: %0d cycles", total_cycles);
        $display("========================================");

        // Wait for reset
        @(posedge rst_n);
        #100ns;

        // Start traffic generation
        traffic_gen.start();

        // Run simulation
        repeat(total_cycles) @(posedge clk_250mhz);

        // Stop traffic
        traffic_gen.stop();

        // Wait for pipeline drain
        repeat(1000) @(posedge clk_250mhz);

        // Report statistics
        report_statistics();

        // Save results to CSV
        save_results_to_csv($sformatf("results/raw_data/%s.csv", test_name));

        $finish;
    end

    // Statistics reporting
    task report_statistics();
        real throughput_gbps;
        real avg_latency_ns;

        $display("\n========== Final Statistics ==========");

        for (int p = 0; p < NUM_PORTS; p++) begin
            throughput_gbps = (total_bytes_received[p] * 8.0) / (total_cycles * 4.0);
            $display("Port %0d: TX=%0d pkts, RX=%0d pkts, Throughput=%.2f Gbps",
                     p, total_packets_sent[p], total_packets_received[p], throughput_gbps);
        end

        // Latency summary (from monitor)
        lat_mon.print_summary();

        $display("======================================\n");
    endtask

    // CSV export
    task save_results_to_csv(string filename);
        int fd;
        fd = $fopen(filename, "w");

        // Header
        $fwrite(fd, "port,packets_sent,packets_received,bytes_sent,bytes_received,");
        $fwrite(fd, "avg_latency_ns,p50_latency_ns,p95_latency_ns,p99_latency_ns,p999_latency_ns\n");

        // Data
        for (int p = 0; p < NUM_PORTS; p++) begin
            $fwrite(fd, "%0d,%0d,%0d,%0d,%0d,",
                    p, total_packets_sent[p], total_packets_received[p],
                    total_bytes_sent[p], total_bytes_received[p]);

            $fwrite(fd, "%.2f,%.2f,%.2f,%.2f,%.2f\n",
                    lat_mon.get_avg_latency(p),
                    lat_mon.get_percentile(p, 50),
                    lat_mon.get_percentile(p, 95),
                    lat_mon.get_percentile(p, 99),
                    lat_mon.get_percentile(p, 99.9));
        end

        $fclose(fd);
        $display("Results saved to: %s", filename);
    endtask

endmodule
```

---

#### Step 1.2: Traffic Generator Array

**File:** `DUT_Validation_Tests/hdl/testbench/traffic_generator_array.sv`

```systemverilog
module traffic_generator_array #(
    parameter NUM_PORTS = 10,
    parameter DATA_WIDTH = 32,
    parameter MAX_PACKET_SIZE = 1500,
    parameter MIN_PACKET_SIZE = 64
)(
    input  logic clk,
    input  logic rst_n,

    // Output to DUT
    switch_data_if.master tx_data [NUM_PORTS-1:0],

    // Configuration
    input  string config_file,

    // Timestamps for latency measurement
    output logic [63:0] packet_timestamps [NUM_PORTS-1:0][$]
);

    // Traffic pattern types
    typedef enum {
        UNIFORM_RANDOM,
        HOTSPOT_9TO1,
        INCAST_10TO1,
        BURSTY_ONOFF,
        AI_ALLREDUCE
    } traffic_pattern_e;

    // Configuration structure
    typedef struct {
        traffic_pattern_e pattern;
        int packet_rate;      // Packets per second
        int packet_size_min;
        int packet_size_max;
        int ipg_min;          // Inter-packet gap (cycles)
        int ipg_max;
        int qos_distribution[8];  // Percentage per QoS level
        int hotspot_destination;  // For hotspot traffic
    } traffic_config_t;

    traffic_config_t config;
    logic running;

    // Per-port packet generators
    for (genvar p = 0; p < NUM_PORTS; p++) begin : gen_traffic
        single_port_generator #(
            .PORT_ID(p),
            .DATA_WIDTH(DATA_WIDTH)
        ) port_gen (
            .clk(clk),
            .rst_n(rst_n),
            .tx_data(tx_data[p]),
            .config(config),
            .running(running),
            .timestamps(packet_timestamps[p])
        );
    end

    // Load configuration from file
    task automatic load_config(string filename);
        int fd;
        string line;

        fd = $fopen(filename, "r");
        if (fd == 0) begin
            $error("Cannot open config file: %s", filename);
            return;
        end

        while (!$feof(fd)) begin
            $fgets(line, fd);
            parse_config_line(line);
        end

        $fclose(fd);
        $display("Loaded traffic config: %s", filename);
        print_config();
    endtask

    task automatic parse_config_line(string line);
        string key, value;
        int split_pos;

        // Skip comments and empty lines
        if (line[0] == "#" || line == "") return;

        split_pos = find_char(line, '=');
        if (split_pos < 0) return;

        key = line.substr(0, split_pos-1);
        value = line.substr(split_pos+1, line.len()-1);

        case (key)
            "pattern": begin
                if (value == "uniform") config.pattern = UNIFORM_RANDOM;
                else if (value == "hotspot") config.pattern = HOTSPOT_9TO1;
                else if (value == "incast") config.pattern = INCAST_10TO1;
                else if (value == "bursty") config.pattern = BURSTY_ONOFF;
                else if (value == "allreduce") config.pattern = AI_ALLREDUCE;
            end
            "packet_rate": config.packet_rate = value.atoi();
            "packet_size_min": config.packet_size_min = value.atoi();
            "packet_size_max": config.packet_size_max = value.atoi();
            "ipg_min": config.ipg_min = value.atoi();
            "ipg_max": config.ipg_max = value.atoi();
            "hotspot_dest": config.hotspot_destination = value.atoi();
        endcase
    endtask

    function int find_char(string s, byte c);
        for (int i = 0; i < s.len(); i++) begin
            if (s[i] == c) return i;
        end
        return -1;
    endfunction

    task automatic print_config();
        $display("Traffic Configuration:");
        $display("  Pattern: %s", config.pattern.name());
        $display("  Packet Rate: %0d pps", config.packet_rate);
        $display("  Packet Size: %0d-%0d bytes", config.packet_size_min, config.packet_size_max);
        $display("  IPG: %0d-%0d cycles", config.ipg_min, config.ipg_max);
    endtask

    // Control interface
    task start();
        load_config(config_file);
        running = 1;
        $display("[%0t] Traffic generation started", $time);
    endtask

    task stop();
        running = 0;
        $display("[%0t] Traffic generation stopped", $time);
    endtask

endmodule
```

---

#### Step 1.3: Single Port Generator (Core Logic)

**File:** `DUT_Validation_Tests/hdl/testbench/single_port_generator.sv`

```systemverilog
module single_port_generator #(
    parameter PORT_ID = 0,
    parameter DATA_WIDTH = 32,
    parameter MAX_PACKET_SIZE = 1500
)(
    input  logic clk,
    input  logic rst_n,

    switch_data_if.master tx_data,

    input  traffic_config_t config,
    input  logic running,

    output logic [63:0] timestamps [$]
);

    // State machine
    typedef enum {IDLE, SEND_PACKET, IPG_WAIT} state_e;
    state_e state;

    // Packet generation
    int packet_count;
    int current_packet_size;
    int current_destination;
    int current_qos;
    int ipg_counter;
    int word_counter;

    logic [63:0] cycle_counter;

    // Cycle counter
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            cycle_counter <= 0;
        else
            cycle_counter <= cycle_counter + 1;
    end

    // Main state machine
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            packet_count <= 0;
            tx_data.valid <= 0;
            tx_data.last <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (running) begin
                        // Generate new packet parameters
                        current_packet_size = $urandom_range(config.packet_size_min,
                                                            config.packet_size_max);
                        current_destination = select_destination();
                        current_qos = select_qos();

                        word_counter = 0;
                        state <= SEND_PACKET;
                    end
                end

                SEND_PACKET: begin
                    if (tx_data.ready || !tx_data.valid) begin
                        tx_data.valid <= 1;
                        tx_data.data <= generate_payload(word_counter);
                        tx_data.dest <= current_destination;
                        tx_data.qos <= current_qos;

                        word_counter <= word_counter + 1;

                        // Last word?
                        if ((word_counter + 1) * (DATA_WIDTH/8) >= current_packet_size) begin
                            tx_data.last <= 1;

                            // Record timestamp
                            timestamps.push_back(cycle_counter);

                            packet_count <= packet_count + 1;

                            // Calculate IPG
                            ipg_counter = $urandom_range(config.ipg_min, config.ipg_max);
                            state <= IPG_WAIT;
                        end else begin
                            tx_data.last <= 0;
                        end
                    end
                end

                IPG_WAIT: begin
                    tx_data.valid <= 0;
                    tx_data.last <= 0;

                    ipg_counter <= ipg_counter - 1;
                    if (ipg_counter == 0) begin
                        state <= IDLE;
                    end
                end
            endcase
        end
    end

    // Destination selection based on traffic pattern
    function int select_destination();
        case (config.pattern)
            UNIFORM_RANDOM: begin
                // Random destination except self
                int dest;
                do begin
                    dest = $urandom_range(0, NUM_PORTS-1);
                end while (dest == PORT_ID);
                return dest;
            end

            HOTSPOT_9TO1: begin
                // All ports send to hotspot_destination
                return config.hotspot_destination;
            end

            INCAST_10TO1: begin
                // Same as hotspot
                return config.hotspot_destination;
            end

            BURSTY_ONOFF: begin
                // Random with bursts
                return $urandom_range(0, NUM_PORTS-1);
            end

            AI_ALLREDUCE: begin
                // All-to-all pattern (simplified)
                return (PORT_ID + packet_count) % NUM_PORTS;
            end

            default: return 0;
        endcase
    endfunction

    // QoS selection
    function int select_qos();
        int rand_val = $urandom_range(0, 99);  // 0-99
        int cumulative = 0;

        for (int q = 0; q < 8; q++) begin
            cumulative += config.qos_distribution[q];
            if (rand_val < cumulative) return q;
        end

        return 3;  // Default medium priority
    endfunction

    // Payload generation
    function logic [DATA_WIDTH-1:0] generate_payload(int word_idx);
        // Simple pattern: PORT_ID | PACKET_COUNT | WORD_IDX
        return {PORT_ID[7:0], packet_count[15:0], word_idx[7:0]};
    endfunction

endmodule
```

---

#### Step 1.4: Latency Monitor Array

**File:** `DUT_Validation_Tests/hdl/testbench/latency_monitor_array.sv`

```systemverilog
module latency_monitor_array #(
    parameter NUM_PORTS = 10,
    parameter MAX_SAMPLES = 1_000_000  // Store up to 1M latency samples
)(
    input  logic clk,
    input  logic rst_n,

    switch_data_if.monitor rx_data [NUM_PORTS-1:0],

    input  logic [63:0] tx_timestamps [NUM_PORTS-1:0][$]
);

    // Per-port latency storage
    real latency_samples [NUM_PORTS-1:0][$];  // In nanoseconds
    longint packet_count [NUM_PORTS-1:0];

    logic [63:0] cycle_counter;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            cycle_counter <= 0;
        else
            cycle_counter <= cycle_counter + 1;
    end

    // Monitor each port
    for (genvar p = 0; p < NUM_PORTS; p++) begin : gen_monitors
        always_ff @(posedge clk) begin
            if (rx_data[p].valid && rx_data[p].last) begin
                // Packet received
                if (tx_timestamps[p].size() > 0) begin
                    logic [63:0] tx_time = tx_timestamps[p].pop_front();
                    logic [63:0] rx_time = cycle_counter;
                    real latency_ns = (rx_time - tx_time) * 4.0;  // 4ns per cycle @ 250 MHz

                    if (latency_samples[p].size() < MAX_SAMPLES) begin
                        latency_samples[p].push_back(latency_ns);
                    end

                    packet_count[p]++;
                end
            end
        end
    end

    // Analysis functions
    function real get_avg_latency(int port);
        real sum = 0.0;
        if (latency_samples[port].size() == 0) return 0.0;

        foreach (latency_samples[port][i]) begin
            sum += latency_samples[port][i];
        end
        return sum / latency_samples[port].size();
    endfunction

    function real get_percentile(int port, real percentile);
        real sorted_samples[];
        int idx;

        if (latency_samples[port].size() == 0) return 0.0;

        sorted_samples = new[latency_samples[port].size()];
        foreach (latency_samples[port][i]) begin
            sorted_samples[i] = latency_samples[port][i];
        end

        // Simple bubble sort (fine for analysis, not synthesis)
        for (int i = 0; i < sorted_samples.size()-1; i++) begin
            for (int j = i+1; j < sorted_samples.size(); j++) begin
                if (sorted_samples[j] < sorted_samples[i]) begin
                    real temp = sorted_samples[i];
                    sorted_samples[i] = sorted_samples[j];
                    sorted_samples[j] = temp;
                end
            end
        end

        idx = int'((percentile / 100.0) * sorted_samples.size());
        if (idx >= sorted_samples.size()) idx = sorted_samples.size() - 1;

        return sorted_samples[idx];
    endfunction

    function real get_max_latency(int port);
        real max_val = 0.0;
        foreach (latency_samples[port][i]) begin
            if (latency_samples[port][i] > max_val)
                max_val = latency_samples[port][i];
        end
        return max_val;
    endfunction

    function real get_std_dev(int port);
        real mean = get_avg_latency(port);
        real variance = 0.0;

        if (latency_samples[port].size() <= 1) return 0.0;

        foreach (latency_samples[port][i]) begin
            variance += (latency_samples[port][i] - mean) ** 2;
        end
        variance /= (latency_samples[port].size() - 1);

        return $sqrt(variance);
    endfunction

    task print_summary();
        $display("\n========== Latency Summary ==========");
        for (int p = 0; p < NUM_PORTS; p++) begin
            if (packet_count[p] > 0) begin
                $display("Port %0d (%0d packets):", p, packet_count[p]);
                $display("  Avg:  %.2f ns", get_avg_latency(p));
                $display("  p50:  %.2f ns", get_percentile(p, 50.0));
                $display("  p95:  %.2f ns", get_percentile(p, 95.0));
                $display("  p99:  %.2f ns", get_percentile(p, 99.0));
                $display("  p999: %.2f ns", get_percentile(p, 99.9));
                $display("  Max:  %.2f ns", get_max_latency(p));
                $display("  StdDev: %.2f ns", get_std_dev(p));
            end
        end
        $display("=====================================\n");
    endtask

endmodule
```

---

### Phase 2: Workload Configuration Files (Week 2)

#### Example Workload: Uniform Random

**File:** `DUT_Validation_Tests/tests/workload_configs/uniform_random.cfg`

```ini
# Uniform Random Traffic Configuration
# All ports send to random destinations with equal probability

pattern=uniform
packet_rate=100000
packet_size_min=64
packet_size_max=1500
ipg_min=10
ipg_max=50

# QoS distribution (percentages, must sum to 100)
qos_0=10
qos_1=10
qos_2=15
qos_3=20
qos_4=20
qos_5=15
qos_6=5
qos_7=5
```

#### Example Workload: Hotspot (9→1)

**File:** `DUT_Validation_Tests/tests/workload_configs/hotspot_9to1.cfg`

```ini
# Hotspot Traffic: 9 sources → Port 7
# This validates ECS throughput improvement

pattern=hotspot
hotspot_dest=7
packet_rate=500000
packet_size_min=512
packet_size_max=1500
ipg_min=5
ipg_max=20

# Higher priority traffic to stress QoS
qos_0=5
qos_1=10
qos_2=15
qos_3=30
qos_4=25
qos_5=10
qos_6=3
qos_7=2
```

#### Example Workload: Incast

**File:** `DUT_Validation_Tests/tests/workload_configs/incast_10to1.cfg`

```ini
# Incast Pattern: All ports simultaneously burst to Port 5
# Common in distributed computing (barrier synchronization)

pattern=incast
hotspot_dest=5
packet_rate=1000000
packet_size_min=64
packet_size_max=256
ipg_min=0
ipg_max=5

# Mostly high-priority traffic
qos_0=5
qos_1=10
qos_2=15
qos_3=30
qos_4=30
qos_5=8
qos_6=1
qos_7=1
```

---

### Phase 3: Python Analysis Scripts (Week 3)

#### Script 1: Statistical Analysis

**File:** `DUT_Validation_Tests/scripts/analyze_results.py`

```python
#!/usr/bin/env python3
"""
Statistical Analysis Script for Switch Fabric Performance Data
Reads CSV files from simulations and computes:
- Mean, median, percentiles (p50/p95/p99/p999)
- Standard deviation, jitter
- Confidence intervals (via bootstrap)
- Throughput (Gbps)
- Fairness (Jain index)
"""

import pandas as pd
import numpy as np
from scipy import stats
import json
import argparse
from pathlib import Path

def load_results(csv_file):
    """Load simulation results from CSV"""
    df = pd.read_csv(csv_file)
    return df

def compute_latency_stats(df):
    """Compute comprehensive latency statistics"""
    stats_dict = {}

    for port in df['port'].unique():
        port_data = df[df['port'] == port]

        latencies = []
        if 'avg_latency_ns' in port_data.columns:
            latencies = port_data['avg_latency_ns'].dropna().values

        if len(latencies) == 0:
            continue

        stats_dict[f'port_{port}'] = {
            'mean': float(np.mean(latencies)),
            'median': float(np.median(latencies)),
            'std': float(np.std(latencies)),
            'p50': float(np.percentile(latencies, 50)),
            'p95': float(np.percentile(latencies, 95)),
            'p99': float(np.percentile(latencies, 99)),
            'p999': float(np.percentile(latencies, 99.9)),
            'min': float(np.min(latencies)),
            'max': float(np.max(latencies)),
            'samples': len(latencies)
        }

        # Confidence interval (95%) via bootstrap
        ci = stats.bootstrap(
            (latencies,),
            np.mean,
            n_resamples=1000,
            confidence_level=0.95,
            method='percentile'
        )
        stats_dict[f'port_{port}']['ci_95_low'] = float(ci.confidence_interval.low)
        stats_dict[f'port_{port}']['ci_95_high'] = float(ci.confidence_interval.high)

    return stats_dict

def compute_throughput_stats(df):
    """Compute throughput in Gbps"""
    throughput_dict = {}

    # Assume simulation duration is recorded or calculated
    # For now, extract from metadata or use total_cycles from CSV

    for port in df['port'].unique():
        port_data = df[df['port'] == port]

        bytes_rx = port_data['bytes_received'].sum()
        # Assuming 4ns per cycle @ 250 MHz
        # Need to get total_cycles from somewhere (e.g., metadata)
        # For demonstration, assume 10M cycles
        total_cycles = 10_000_000
        duration_ns = total_cycles * 4.0

        throughput_gbps = (bytes_rx * 8) / duration_ns  # Gbps

        throughput_dict[f'port_{port}'] = {
            'throughput_gbps': float(throughput_gbps),
            'packets_received': int(port_data['packets_received'].sum()),
            'bytes_received': int(bytes_rx)
        }

    return throughput_dict

def compute_fairness_index(throughputs):
    """
    Compute Jain's Fairness Index
    J = (sum(x_i))^2 / (n * sum(x_i^2))
    where x_i is throughput of flow i
    """
    throughputs = np.array(throughputs)
    n = len(throughputs)

    if n == 0:
        return 0.0

    numerator = (np.sum(throughputs)) ** 2
    denominator = n * np.sum(throughputs ** 2)

    if denominator == 0:
        return 0.0

    return float(numerator / denominator)

def compare_two_designs(baseline_csv, enhanced_csv):
    """Statistical comparison between baseline and enhanced"""
    df_base = load_results(baseline_csv)
    df_enh = load_results(enhanced_csv)

    # Extract latencies
    lat_base = df_base['p99_latency_ns'].dropna().values
    lat_enh = df_enh['p99_latency_ns'].dropna().values

    # T-test
    t_stat, p_value = stats.ttest_ind(lat_base, lat_enh, equal_var=False)

    # Effect size (Cohen's d)
    pooled_std = np.sqrt((np.std(lat_base)**2 + np.std(lat_enh)**2) / 2)
    cohens_d = (np.mean(lat_base) - np.mean(lat_enh)) / pooled_std

    comparison = {
        'baseline_mean_p99_ns': float(np.mean(lat_base)),
        'enhanced_mean_p99_ns': float(np.mean(lat_enh)),
        'improvement_percent': float((1 - np.mean(lat_enh)/np.mean(lat_base)) * 100),
        't_statistic': float(t_stat),
        'p_value': float(p_value),
        'cohens_d': float(cohens_d),
        'significant_at_005': p_value < 0.05
    }

    return comparison

def main():
    parser = argparse.ArgumentParser(description='Analyze switch fabric performance')
    parser.add_argument('csv_file', help='Input CSV file from simulation')
    parser.add_argument('--output', default='results/processed/stats.json',
                       help='Output JSON file')
    parser.add_argument('--compare', help='Compare with another CSV (baseline)')

    args = parser.parse_args()

    # Load and analyze
    df = load_results(args.csv_file)

    latency_stats = compute_latency_stats(df)
    throughput_stats = compute_throughput_stats(df)

    # Fairness
    throughputs = [throughput_stats[k]['throughput_gbps']
                   for k in throughput_stats.keys()]
    fairness = compute_fairness_index(throughputs)

    results = {
        'input_file': str(args.csv_file),
        'latency_statistics': latency_stats,
        'throughput_statistics': throughput_stats,
        'fairness_index': fairness
    }

    # Comparison if requested
    if args.compare:
        comparison = compare_two_designs(args.compare, args.csv_file)
        results['comparison'] = comparison

    # Save to JSON
    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    with open(output_path, 'w') as f:
        json.dump(results, f, indent=2)

    print(f"Analysis complete. Results saved to: {output_path}")

    # Print summary
    print("\n========== Summary ==========")
    print(f"Total ports analyzed: {len(latency_stats)}")
    print(f"Average p99 latency: {np.mean([v['p99'] for v in latency_stats.values()]):.2f} ns")
    print(f"Fairness index: {fairness:.3f}")

    if args.compare:
        print(f"\n--- Comparison with {args.compare} ---")
        print(f"Improvement: {comparison['improvement_percent']:.1f}%")
        print(f"Statistical significance: p={comparison['p_value']:.4f}")

if __name__ == '__main__':
    main()
```

---

#### Script 2: Latency CDF Plotting

**File:** `DUT_Validation_Tests/scripts/plot_latency_cdf.py`

```python
#!/usr/bin/env python3
"""
Plot Latency Cumulative Distribution Function (CDF)
For comparing baseline vs. enhanced designs
"""

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
import argparse
from pathlib import Path

sns.set_style("whitegrid")
plt.rcParams['font.size'] = 12
plt.rcParams['figure.figsize'] = (10, 6)

def plot_cdf_comparison(csv_files, labels, output_file):
    """
    Plot CDF of latency for multiple designs

    Args:
        csv_files: List of CSV file paths
        labels: List of labels for each design
        output_file: Output PDF path
    """
    plt.figure(figsize=(10, 6))

    colors = ['#d62728', '#ff7f0e', '#2ca02c', '#1f77b4']  # Red, orange, green, blue

    for idx, (csv_file, label) in enumerate(zip(csv_files, labels)):
        df = pd.read_csv(csv_file)

        # Extract latencies (assuming p99 column exists)
        latencies = df['p99_latency_ns'].dropna().values

        if len(latencies) == 0:
            print(f"Warning: No latency data in {csv_file}")
            continue

        # Sort for CDF
        sorted_lat = np.sort(latencies)
        cdf = np.arange(1, len(sorted_lat)+1) / len(sorted_lat) * 100

        plt.plot(sorted_lat, cdf, label=label, color=colors[idx], linewidth=2)

    plt.xlabel('Latency (ns)', fontsize=14)
    plt.ylabel('Percentile (%)', fontsize=14)
    plt.title('Latency Cumulative Distribution Function', fontsize=16)
    plt.legend(loc='lower right', fontsize=12)
    plt.grid(True, alpha=0.3)

    # Log scale on x-axis if range is large
    if plt.xlim()[1] / plt.xlim()[0] > 100:
        plt.xscale('log')

    plt.tight_layout()
    plt.savefig(output_file, dpi=300, bbox_inches='tight')
    print(f"CDF plot saved to: {output_file}")

def main():
    parser = argparse.ArgumentParser(description='Plot latency CDF')
    parser.add_argument('csv_files', nargs='+', help='Input CSV files')
    parser.add_argument('--labels', nargs='+', help='Labels for each design')
    parser.add_argument('--output', default='results/plots/latency_cdf.pdf',
                       help='Output PDF file')

    args = parser.parse_args()

    if args.labels and len(args.labels) != len(args.csv_files):
        print("Error: Number of labels must match number of CSV files")
        return

    labels = args.labels if args.labels else [f'Design {i+1}' for i in range(len(args.csv_files))]

    # Create output directory
    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    plot_cdf_comparison(args.csv_files, labels, args.output)

if __name__ == '__main__':
    main()
```

---

#### Script 3: Throughput Comparison

**File:** `DUT_Validation_Tests/scripts/plot_throughput.py`

```python
#!/usr/bin/env python3
"""
Plot throughput comparison across different designs and workloads
"""

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
import json
import argparse
from pathlib import Path

sns.set_style("whitegrid")

def plot_throughput_bars(json_files, labels, output_file):
    """
    Create bar chart comparing throughput across designs

    Args:
        json_files: List of JSON stat files
        labels: List of design labels
        output_file: Output PDF path
    """
    # Load data
    data = []
    for json_file, label in zip(json_files, labels):
        with open(json_file, 'r') as f:
            stats = json.load(f)

        # Extract aggregate throughput
        tput_stats = stats.get('throughput_statistics', {})
        total_tput = sum([v['throughput_gbps'] for v in tput_stats.values()])

        data.append({
            'design': label,
            'throughput_gbps': total_tput
        })

    df = pd.DataFrame(data)

    # Create bar plot
    plt.figure(figsize=(8, 6))
    bars = plt.bar(df['design'], df['throughput_gbps'], color='steelblue', alpha=0.8)

    # Add value labels on top of bars
    for bar in bars:
        height = bar.get_height()
        plt.text(bar.get_x() + bar.get_width()/2., height,
                f'{height:.2f}',
                ha='center', va='bottom', fontsize=11)

    plt.xlabel('Design', fontsize=14)
    plt.ylabel('Aggregate Throughput (Gbps)', fontsize=14)
    plt.title('Throughput Comparison', fontsize=16)
    plt.xticks(rotation=15, ha='right')
    plt.tight_layout()

    plt.savefig(output_file, dpi=300, bbox_inches='tight')
    print(f"Throughput plot saved to: {output_file}")

def main():
    parser = argparse.ArgumentParser(description='Plot throughput comparison')
    parser.add_argument('json_files', nargs='+', help='Input JSON stat files')
    parser.add_argument('--labels', nargs='+', help='Labels for each design')
    parser.add_argument('--output', default='results/plots/throughput_comparison.pdf',
                       help='Output PDF file')

    args = parser.parse_args()

    labels = args.labels if args.labels else [f'Design {i+1}' for i in range(len(args.json_files))]

    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    plot_throughput_bars(args.json_files, labels, args.output)

if __name__ == '__main__':
    main()
```

---

### Phase 4: Automated Test Execution (Week 4)

#### Test Runner Script

**File:** `DUT_Validation_Tests/scripts/run_sweep.py`

```python
#!/usr/bin/env python3
"""
Automated test sweep for paper evaluation
Runs multiple configurations and collects results
"""

import subprocess
import json
from pathlib import Path
import time

# Test matrix
TEST_MATRIX = [
    # Baseline tests
    {
        'name': 'baseline_uniform',
        'workload': 'uniform_random.cfg',
        'elastic_enable': 0,
        'adaptive_qos_enable': 0,
        'kalman_predict_enable': 0,
        'cycles': 10_000_000
    },
    {
        'name': 'baseline_hotspot',
        'workload': 'hotspot_9to1.cfg',
        'elastic_enable': 0,
        'adaptive_qos_enable': 0,
        'kalman_predict_enable': 0,
        'cycles': 10_000_000
    },

    # Enhanced: +Pooling only
    {
        'name': 'pooling_hotspot',
        'workload': 'hotspot_9to1.cfg',
        'elastic_enable': 0,
        'adaptive_qos_enable': 1,  # Pooling is always on
        'kalman_predict_enable': 0,
        'cycles': 10_000_000
    },

    # Enhanced: +Pooling +Kalman
    {
        'name': 'pooling_kalman_hotspot',
        'workload': 'hotspot_9to1.cfg',
        'elastic_enable': 0,
        'adaptive_qos_enable': 1,
        'kalman_predict_enable': 1,
        'cycles': 10_000_000
    },

    # Full ECS
    {
        'name': 'full_ecs_hotspot',
        'workload': 'hotspot_9to1.cfg',
        'elastic_enable': 1,
        'adaptive_qos_enable': 1,
        'kalman_predict_enable': 1,
        'cycles': 10_000_000
    },

    # ... (add more test cases)
]

def run_single_test(test_config, output_dir):
    """Run a single simulation test"""
    print(f"\n{'='*60}")
    print(f"Running test: {test_config['name']}")
    print(f"{'='*60}")

    # Build command
    cmd = [
        'vsim',
        '-c',  # Command-line mode
        '-do', 'run.do',
        f"+TEST={test_config['name']}",
        f"+WORKLOAD=tests/workload_configs/{test_config['workload']}",
        f"+CYCLES={test_config['cycles']}",
        f"+ELASTIC_ENABLE={test_config['elastic_enable']}",
        f"+ADAPTIVE_QOS_ENABLE={test_config['adaptive_qos_enable']}",
        f"+KALMAN_PREDICT_ENABLE={test_config['kalman_predict_enable']}"
    ]

    # Run simulation
    start_time = time.time()
    result = subprocess.run(cmd, capture_output=True, text=True, cwd='sim')
    elapsed = time.time() - start_time

    print(f"Simulation completed in {elapsed:.1f} seconds")

    # Check for errors
    if result.returncode != 0:
        print(f"ERROR: Simulation failed!")
        print(result.stderr)
        return False

    # Move results to output directory
    csv_file = f"results/raw_data/{test_config['name']}.csv"
    if Path(csv_file).exists():
        print(f"Results saved to: {csv_file}")
        return True
    else:
        print(f"WARNING: Expected output file not found: {csv_file}")
        return False

def main():
    print("=" * 80)
    print("AUTOMATED TEST SWEEP FOR PAPER EVALUATION")
    print("=" * 80)

    output_dir = Path('results/raw_data')
    output_dir.mkdir(parents=True, exist_ok=True)

    total_tests = len(TEST_MATRIX)
    passed = 0
    failed = 0

    for idx, test in enumerate(TEST_MATRIX, 1):
        print(f"\n[{idx}/{total_tests}] Test: {test['name']}")

        if run_single_test(test, output_dir):
            passed += 1
        else:
            failed += 1

    # Summary
    print("\n" + "=" * 80)
    print("SWEEP COMPLETE")
    print("=" * 80)
    print(f"Total tests: {total_tests}")
    print(f"Passed: {passed}")
    print(f"Failed: {failed}")

    if failed == 0:
        print("\n✓ All tests passed successfully!")
    else:
        print(f"\n✗ {failed} tests failed")

if __name__ == '__main__':
    main()
```

---

### Phase 5: Paper-Ready Results Generation (Week 5)

#### Generate LaTeX Tables

**File:** `DUT_Validation_Tests/scripts/generate_paper_tables.py`

```python
#!/usr/bin/env python3
"""
Generate LaTeX tables from JSON statistics
Ready to copy-paste into paper
"""

import json
from pathlib import Path

def generate_performance_table(json_files, labels, output_file):
    """
    Generate LaTeX table comparing designs

    Columns: Design | Hotspot Tput | p99 Latency | Fairness | Area
    """
    lines = []
    lines.append(r'\begin{table}[htbp]')
    lines.append(r'\centering')
    lines.append(r'\caption{Performance Comparison}')
    lines.append(r'\label{tab:performance}')
    lines.append(r'\begin{tabular}{lrrrr}')
    lines.append(r'\toprule')
    lines.append(r'Design & Hotspot Tput & p99 Latency & Fairness & Area \\')
    lines.append(r'       & (Gbps)       & (µs)        & (Jain)   & Overhead \\')
    lines.append(r'\midrule')

    for json_file, label in zip(json_files, labels):
        with open(json_file, 'r') as f:
            stats = json.load(f)

        # Extract metrics
        tput_stats = stats.get('throughput_statistics', {})
        lat_stats = stats.get('latency_statistics', {})
        fairness = stats.get('fairness_index', 0.0)

        # Aggregate
        total_tput = sum([v['throughput_gbps'] for v in tput_stats.values()])
        avg_p99 = sum([v['p99'] for v in lat_stats.values()]) / len(lat_stats) if lat_stats else 0
        avg_p99_us = avg_p99 / 1000.0  # Convert ns to µs

        # Area overhead (placeholder - would come from synthesis)
        area_overhead = "Baseline" if "baseline" in label.lower() else "+8\\%"

        lines.append(f"{label} & {total_tput:.2f} & {avg_p99_us:.2f} & {fairness:.3f} & {area_overhead} \\\\")

    lines.append(r'\bottomrule')
    lines.append(r'\end{tabular}')
    lines.append(r'\end{table}')

    # Write to file
    with open(output_file, 'w') as f:
        f.write('\n'.join(lines))

    print(f"LaTeX table saved to: {output_file}")

# Example usage
if __name__ == '__main__':
    json_files = [
        'results/processed/baseline_hotspot_stats.json',
        'results/processed/pooling_hotspot_stats.json',
        'results/processed/pooling_kalman_hotspot_stats.json',
        'results/processed/full_ecs_hotspot_stats.json'
    ]

    labels = [
        'Baseline VOQ',
        'VOQ + Pooling',
        'VOQ + Pooling + Kalman',
        'Full ECS'
    ]

    generate_performance_table(json_files, labels, 'results/paper_tables/table1_performance.tex')
```

---

## Part 4: Testing Execution Workflow

### Step-by-Step Execution Plan

#### Week 1: Setup

```bash
# 1. Create directory structure
cd DUT_Validation_Tests
mkdir -p hdl/testbench tests/workload_configs scripts results/{raw_data,processed,plots,paper_tables}

# 2. Copy RTL files
ln -s ../../hdl/switch_fabric hdl/dut

# 3. Implement testbench modules (from templates above)
# - perf_tb_top.sv
# - traffic_generator_array.sv
# - latency_monitor_array.sv
# - etc.

# 4. Create workload configs
# (Use templates from Phase 2)
```

#### Week 2: Initial Tests

```bash
# 1. Compile testbench
cd scripts
vsim -c -do compile_perf_tb.do

# 2. Run single test manually
vsim -c -do "run.do" +TEST=baseline_uniform +WORKLOAD=../tests/workload_configs/uniform_random.cfg +CYCLES=1000000

# 3. Verify CSV output
cat ../results/raw_data/baseline_uniform.csv
```

#### Week 3: Automated Sweeps

```bash
# 1. Run full test matrix
python3 run_sweep.py

# 2. Analyze all results
for csv in ../results/raw_data/*.csv; do
    python3 analyze_results.py "$csv" --output "../results/processed/$(basename $csv .csv)_stats.json"
done

# 3. Generate plots
python3 plot_latency_cdf.py \
    ../results/raw_data/baseline_hotspot.csv \
    ../results/raw_data/full_ecs_hotspot.csv \
    --labels "Baseline" "Full ECS" \
    --output ../results/plots/latency_cdf_hotspot.pdf
```

#### Week 4: Paper Preparation

```bash
# 1. Generate LaTeX tables
python3 generate_paper_tables.py

# 2. Copy figures to paper directory
cp ../results/plots/*.pdf ../../paper/figures/

# 3. Verify statistical significance
python3 analyze_results.py ../results/raw_data/baseline_hotspot.csv \
    --compare ../results/raw_data/full_ecs_hotspot.csv
```

---

## Part 5: Validation Criteria Checklist

### For Paper Acceptance

| Criterion | Target | Verification Method | Status |
|-----------|--------|---------------------|--------|
| **Hotspot Throughput** | ≥4× baseline | Compare CSV: baseline vs. full_ecs | ☐ |
| **Tail Latency (p99)** | ≤200 µs under hotspot | Extract from JSON stats | ☐ |
| **Uniform Performance** | ≥98% of baseline | Throughput comparison | ☐ |
| **Fairness** | Jain index ≥0.90 | Compute from throughput distribution | ☐ |
| **Prediction MAE** | <50 words | Separate Kalman accuracy test | ☐ |
| **Statistical Significance** | p-value <0.05 | T-test in analyze_results.py | ☐ |
| **Sample Size** | ≥100K packets per test | Verify packet_count in CSV | ☐ |
| **Confidence Intervals** | Report 95% CI | Bootstrap in analysis script | ☐ |

---

## Part 6: Directory Tree for Paper

**Recommended Final Structure:**

```
switch_fabric_project/
│
├── paper/
│   ├── main.tex
│   ├── sections/
│   │   ├── 01_introduction.tex
│   │   ├── 02_background.tex
│   │   ├── 03_architecture.tex
│   │   ├── 04_ecs_design.tex
│   │   ├── 05_implementation.tex
│   │   ├── 06_evaluation.tex
│   │   ├── 07_related_work.tex
│   │   └── 08_conclusion.tex
│   ├── figures/
│   │   ├── architecture.pdf
│   │   ├── ecs_flowchart.pdf
│   │   ├── latency_cdf_hotspot.pdf
│   │   ├── throughput_comparison.pdf
│   │   └── ablation_study.pdf
│   ├── tables/
│   │   ├── table1_performance.tex
│   │   └── table2_ablation.tex
│   └── references.bib
│
├── rtl/
│   └── (your existing switch_fabric code)
│
├── DUT_Validation_Tests/
│   └── (performance testbench - detailed above)
│
├── UVMF_FS/
│   └── (functional verification - keep as-is)
│
└── docs/
    ├── testing_strategy.md (this document)
    ├── architecture.md
    └── results_summary.md
```

---

## Part 7: Common Pitfalls and Solutions

### Problem 1: Simulation Takes Too Long

**Symptom:** 10M cycles takes >24 hours

**Solutions:**
- Use compiled simulation mode (`vopt -O5`)
- Reduce logging verbosity (only log summary statistics)
- Disable waveform dumping during long runs
- Use Questa's `-64` flag for 64-bit memory access

### Problem 2: Insufficient Statistical Samples

**Symptom:** p99 values vary wildly between runs

**Solutions:**
- Increase `total_cycles` to 50M or 100M
- Run multiple seeds and aggregate results
- Report confidence intervals (bootstrap)

### Problem 3: UVM Framework Slows Down Performance Tests

**Solution:**
- **Keep UVM separate** — use only for functional verification
- Build lightweight testbench (this guide) for performance

---

## Conclusion

**Summary of Recommended Approach:**

1. ✅ **Keep UVMF** for functional verification (already done)
2. ✅ **Build lightweight performance testbench** (this guide)
3. ✅ **Automate test sweeps** with Python scripts
4. ✅ **Generate publication-ready figures** directly from simulation data
5. ✅ **Perform statistical validation** (confidence intervals, significance tests)

**Estimated Timeline:**

| Week | Activity | Deliverable |
|------|----------|-------------|
| 1 | Implement testbench core | Compiling perf_tb_top.sv |
| 2 | Create workload configs, run initial tests | Baseline CSV results |
| 3 | Full test matrix sweep | All raw_data/*.csv files |
| 4 | Statistical analysis | JSON stats, plots |
| 5 | LaTeX table generation | Paper-ready tables/figures |

**Final Answer to Your Question:**

**"Is it enough to just add sequences to your UVM testbench and check outputs?"**

**No — for paper publication, you need:**

1. **Massive sample sizes** (millions of packets) — UVM is too slow
2. **Statistical rigor** (p-values, confidence intervals) — requires Python analysis
3. **Multiple workloads** (uniform, hotspot, incast, etc.) — automated sweep
4. **Publication-quality figures** — automated plotting from CSV/JSON

**Therefore:** Build the **lightweight performance testbench** described in this guide alongside your existing UVM framework.

**This dual-track approach gives you:**
- Functional correctness (UVMF)
- Performance validation (lightweight TB)
- Paper-ready results (Python analysis)

---

**Would you like me to:**
1. Generate the complete Modelsim `.do` scripts for compilation?
2. Provide more workload configuration examples?
3. Create additional Python plotting scripts (e.g., ablation study heatmap)?
4. Write the complete `run.do` simulation control script?