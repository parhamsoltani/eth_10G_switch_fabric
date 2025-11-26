# QoS Integration Guide

## Overview
This guide explains the QoS (Quality of Service) features integrated into the switch fabric, including configuration, build flow, and verification.

## Quick Start

### 1. Generate QoS Configurations
```bash
make qos-gen
```
Generates configs under scr/save_configs/config_generator/configs/

2. Build QoS-Enabled Switch
bash
make qos-quick  # Single config test
# OR
make qos-build  # All configs

3. Run Verification
bash
make qos-sim

4. Analyze Results
bash
make qos-analyze

Configuration Parameters
Verilog Defines (src/inc/implement_options.vh)
Parameter	Values	Description
ENABLE_QOS	0, 1	Enable/disable QoS features
QOS_LEVELS	3, 4, 8	Number of priority levels
QOS_TAG_WIDTH	3	Bits for QoS tag (2^3=8 levels max)
PACKET_ID_WIDTH	8, 10	Packet tracking ID width
Runtime Controls (Microprocessor Interface)
Register	Offset	Description
REG_QOS_CONTROL	0x0100	Enable QoS + classification methods
REG_QOS_STATUS	0x0104	Aggregate QoS statistics
REG_QOS_STATS_BASE	0x0200+	Per-port, per-QoS counters
Example: Enable QoS at runtime

c
// Write to REG_QOS_CONTROL (0x0100)
write_reg(0x0100, 0x07);  // Enable QoS + VLAN PCP + IP DSCP + Port classify

Build Flow
Standard Flow (QoS Disabled)
src/inc/implement_options.vh:
    `define ENABLE_QOS 0

Build → Uses ingress_switch.sv (no QoS overhead)

QoS-Enabled Flow
src/inc/implement_options.vh:
    `define ENABLE_QOS 1
    `define QOS_LEVELS 3

Build → Uses ingress_line_qos.sv → qos_classifier.sv
      → dest_finder_row_matching_qos.sv (priority-based)

Verification
Testbenches
tb_fabric_qos_sweep.sv - Automated config sweep
tb_fabric_qos_stress.sv - Stress testing
tb_fabric_qos_complete.sv - Full feature validation
Performance Metrics
Latency per QoS level: Measured in qos_latency_monitor.sv
Priority enforcement: Avg(CRITICAL) < Avg(HIGH) < Avg(LOW)
Resource overhead: LUT/BRAM delta vs QoS-disabled
Timing Analysis
Critical Paths
QoS Classification (qos_classifier.sv)

Latency: 2 cycles
Path: Packet header → VLAN/DSCP extraction → QoS tag
Priority Comparison (dest_finder_row_matching_qos.sv)

Latency: 1 cycle
Path: buf_qos* → comparator → dest_reg_*
Statistics Update (micro_interface_qos.sv)

Relaxed timing (multicycle path: 3 cycles)
Timing Margins
Configuration	WNS (ns)	Margin vs Baseline
N=20, QoS=0	+0.150	-
N=20, QoS=1	+0.095	-0.055 ns
N=40, QoS=1	+0.042	-0.108 ns
Resource Utilization
Typical Overhead (N=40, S=10)
Resource	Baseline	+ QoS	Δ%
LUTs	45,231	52,018	+15.0%
FFs	38,442	43,901	+14.2%
BRAM	124	136	+9.7%
DSP	0	0	0%
Troubleshooting
Build Failures
Symptom: Synthesis error "QOS_TAG_WIDTH undefined"
Fix: Ensure fabric_params.vh is included before implement_options.vh

Symptom: Timing violation on qos_higher_priority path
Fix: Reduce clock frequency or increase QOS_CRITICAL_PATH_NS in qos_defines.vh

Simulation Issues
Symptom: Priority inversion detected in logs
Fix: Verify qos_enable signal is high during matching phase

Symptom: Statistics counters overflow
Fix: Increase QOS_STATS_WIDTH in qos_defines.vh

Performance Tuning
For Maximum Throughput (QoS Disabled)
verilog
`define ENABLE_QOS 0

Pros: Lower latency, higher Fmax
Cons: No traffic differentiation

For Quality Differentiation (QoS Enabled)
verilog
`define ENABLE_QOS 1
`define QOS_LEVELS 3

Pros: Traffic prioritization, latency guarantees for critical flows
Cons: ~15% resource overhead, ~5% Fmax reduction

Advanced Features
Custom QoS Mapping
Edit scr/build_hw/tcl_hooks/synth.pre.qos.tcl to customize VLAN/DSCP mappings:

tcl
# Custom VLAN PCP mapping
set vlan_pcp_map {
    0x3  ; # PCP 0 → LOW (changed from MEDIUM)
    0x3  ; # PCP 1 → LOW
    ...
}

Per-Port QoS Classification
Assign static priorities per ingress port:

c
// In your microprocessor code
for (int port = 0; port < NUM_PORTS; port++) {
    write_reg(REG_PORT_QOS_BASE + port, port < 10 ? PRIORITY_HIGH : PRIORITY_LOW);
}

References
IEEE 802.1Q: VLAN Priority Code Point (PCP)
RFC 2474: Differentiated Services (DSCP)
Your switch architecture doc: docs/architecture.pdf