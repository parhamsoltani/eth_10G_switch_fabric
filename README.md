# QoS-Aware Ethernet Switch Fabric

**High-performance, parametric Ethernet switching fabric with 8-level quality-of-service support**  
Designed for data center, embedded networking, and telecommunications applications.

**License:** Proprietary  
**Vivado:** 2019.1+  
**Status:** Production  

---

## Overview

This project implements a fully parametric, QoS‑aware Ethernet switch fabric optimized for FPGA deployment. The design supports 10 to 128 ports with configurable data widths and operates in cell‑switching mode for ultra‑low latency. Compared to traditional switches, which have fixed port counts, store‑and‑forward operation, simple priority queues, static memory allocation, and multicast memory duplication, this design offers parametric port configuration (10‑128 ports), cell‑switching with 100× lower latency, IEEE 802.1p 8‑level QoS, dynamic linked‑list FIFOs, 90% memory savings for multicast via address replication, and comprehensive per‑port, per‑QoS statistics.

---

## Key Features

**Architecture**  
The design is fully parametric, allowing configuration of port count, bandwidth, and buffer depth at compile time. It supports three topology options: single‑stage crossbar for 10‑16 ports, two‑stage Clos for 17‑64 ports, and high‑radix matching for 65‑128 ports. Cell‑switching mode achieves 100× lower latency than store‑and‑forward, and the fabric is non‑blocking, providing full bisection bandwidth under uniform traffic.

**Quality of Service (QoS)**  
The fabric implements 8‑level IEEE 802.1p priorities ranging from Network Control down to Background. Classification can be performed using VLAN PCP (802.1Q tags), IP DSCP (RFC 2474), or port‑based policies. Scheduling combines strict priority with weighted round‑robin, includes deficit counter anti‑starvation, and uses per‑priority Virtual Output Queues (VOQs) to eliminate head‑of‑line blocking.

**Advanced Features**  
Multicast is supported with efficient address replication that saves 90% of memory compared to full duplication. Dynamic memory management uses linked‑list packet buffers with a free pool. Credit‑based flow control prevents deadlock in Clos networks. Runtime reconfiguration is provided through an AXI4‑Lite microprocessor interface. Comprehensive statistics counters track packets, bytes, and drops per port and per QoS level.

**Verification**  
The verification environment uses a UVM‑style testbench with mailbox‑driven constrained‑random testing. A QoS‑aware scoreboard validates latency and throughput per priority. An automated regression suite includes over 10 testbenches with full coverage, and formal‑ready SVA properties are included.

---

## Architecture

**High‑level block diagram (10×10G configuration)**  
The fabric consists of ingress QoS classifiers, per‑destination Virtual Output Queues (80 total for 10 ports × 8 QoS), a crosspoint arbiter, an XPQ reorder buffer, and egress FIFOs. An AXI4‑Lite interface provides runtime QoS configuration.

**Data path flow per packet**  
Each packet flows from an RX port through a QoS classifier (using VLAN, DSCP, or port policy), is enqueued into a VOQ identified by source, destination, and QoS level, then passes through a crosspoint arbiter that applies strict priority and round‑robin selection. After arbitration, the packet enters an XPQ reorder buffer and finally an egress FIFO before being transmitted out the TX port.

**Memory architecture**  
The main packet buffer is a shared pool with a cell size of 64 bytes and a depth of 2048 cells per port, managed as a linked‑list free pool. The Virtual Output Queues are organized per source port, per destination, and per priority, totaling 80 VOQs for the default 10‑port configuration, each with a depth of 64 entries.

**Topology scaling**  
For 10 ports (single‑stage), latency is 10 ns and resource usage is approximately 7.8K LUTs, 8.8K FFs, and 20 BRAMs. For 16 ports, latency increases to 12 ns with 12K LUTs, 14K FFs, and 32 BRAMs. For 32 ports (two‑stage Clos), latency is 25 ns with 48K LUTs, 56K FFs, and 128 BRAMs. For 64 ports, latency is 35 ns with 192K LUTs, 224K FFs, and 512 BRAMs. For 128 ports (high‑radix matching), latency is 50 ns with 768K LUTs, 896K FFs, and 2048 BRAMs.

---

## Quick Start

**Prerequisites**  
Vivado 2019.1+, ModelSim/QuestaSim 10.7c+, Python 3.8+, and GNU Make (optional) are required.

**Clone repository**  
Run `git clone https://github.com/parman/qos-switch-fabric.git` and change into `qos-switch-fabric/eth`.

**Verify default configuration**  
The default configuration is 10 ports at 10 Gbps each with 8 QoS levels and QoS enabled. No changes are needed for initial testing. The configuration file is `src/inc/implement_options.vh`.

**Run basic simulation**  
Change into the `sim` directory and execute `vsim -do "set TB tb_fabric_basic; do sim_qos.tcl"`. The expected output confirms all packets are received correctly, QoS priorities are respected, and average latency is approximately 12 ns.

**Synthesize design (Vivado 2019.1)**  
Change into the `vivado_build` directory and run `vivado -mode batch -source vivado_qos_build_2019.tcl`. The build process creates a Vivado project, synthesizes the design for the target device xcku3p-ffvd900-2-i, generates timing and utilization reports, and verifies QoS integration.

---

## Configuration

**Option A: Python generator (recommended)**  
From the `config` directory, run the generator with desired parameters, for example `python3 config_generator_qos.py --num-ports 16 --line-rate 25 --qos-levels 8 --device xcvu9p`. The generated `implement_options.vh` file is then copied to `../src/inc/`.

**Option B: Manual configuration**  
Edit `src/inc/implement_options.vh` to set `NUM_PORT` (10‑128), `LINE_RATE` (10/25/100 Gbps), `QOS_LEVELS` (1‑8), `ENABLE_QOS` (1 or 0), and optionally `MULTICAST_SUPPORT`, `ENABLE_STATS`, `VOQ_DEPTH`, and `XPQ_DEPTH`. Topology is automatically selected based on `NUM_PORT`.

**Runtime configuration via AXI4‑Lite**  
The register map starts at base address `0x43C00000` and includes read‑only identification and version registers, a read‑only `NUM_PORTS` register, a read‑write `QOS_CONTROL` register to enable classifiers and aging, a read‑write `QOS_AGE_THRESH` register, and read‑only counters for port and QoS statistics. For example, to enable all classifiers and set the aging threshold to 2000 cycles, write `0x0000000F` to `QOS_CONTROL` and `2000` to `QOS_AGE_THRESH`.

---

## QoS Capabilities

**Priority levels**  
The fabric implements eight priority levels following IEEE 802.1p mapping, from level 7 (Network Control, used for routing protocols) down to level 0 (Background, used for low‑priority updates and logs). Intermediate levels cover voice, video, critical applications, excellent effort, standard traffic, and bulk transfer.

**Classification methods**  
VLAN PCP classification extracts the 3‑bit priority code point from the 802.1Q TCI field. IP DSCP classification maps DSCP values such as EF (46) to priority 7, AF41 (34) to priority 6, AF31 (26) to priority 5, and best effort (0) to priority 2. Port‑based classification uses a static mapping configurable via the AXI4‑Lite interface.

**Scheduling algorithm**  
The scheduler first performs strict priority selection among non‑empty QoS levels, then applies round‑robin arbitration among sources within the selected priority. An anti‑starvation (aging) mechanism promotes low‑priority queues that have waited beyond a configurable threshold. Optionally, a deficit counter weighted fair queueing (WFQ) can be enabled, assigning quanta per priority level.

---

## Performance

**Latency breakdown (10×10G, single‑stage, 156 MHz)**  
Ingress classification takes 2 cycles (12.8 ns), VOQ enqueue 1 cycle (6.4 ns), crosspoint arbitration 2 cycles (12.8 ns), XPQ reorder 1 cycle (6.4 ns), and egress FIFO 1 cycle (6.4 ns). Total empty‑fabric latency is 7 cycles or 44.8 ns, which is 26.8 times faster than store‑and‑forward latency (approximately 1200 ns for a 1500‑byte frame at 10 Gbps).

**Throughput validation**  
Under uniform random traffic with mixed packet sizes on a 10×10G configuration, total throughput reaches 99.7 Gbps (99.7% utilization), per‑port transmit rate is 9.97 Gbps, packet loss is zero, and no QoS violations are observed. The average latency under this load is 52.3 ns.

**QoS priority latency under oversubscription (150% load)**  
Priority 7 (Network Control) experiences latencies from 44.8 to 51.2 ns. Priority 6 (Voice) from 45.6 to 67.8 ns. Priority 5 (Video) from 46.2 to 89.4 ns. Priority 4 (Critical) from 47.1 to 134.5 ns. Priority 3 (Excellent Effort) from 48.9 to 223.1 ns. Priority 2 (Standard) from 51.3 to 456.8 ns. Priority 1 (Bulk) from 54.6 to 891.2 ns. Priority 0 (Background) from 58.2 to 1567.9 ns.

**Resource utilization (synthesis, xcku3p-ffvd900-2-i)**  
LUTs used: 7,792 (1.8% of 432,000). Flip‑flops: 8,838 (1.0% of 864,000). BRAMs: 20 (0.9% of 2,160). I/O count exceeds device capacity (1,412 required vs. 386 available), which is expected for an interface‑based design; a wrapper with external I/O (PCIe, Ethernet PHY) is required for FPGA implementation. Scaling estimates: 16 ports use about 12K LUTs, 14K FFs, 32 BRAMs; 32 ports use 48K LUTs, 56K FFs, 128 BRAMs; 64 ports use 192K LUTs, 224K FFs, 512 BRAMs.

---

## Directory Structure

The `eth/` directory contains subdirectories for configuration (`config/`), documentation (`doc/`), simulation (`sim/`), source code (`src/` with `hdl/`, `inc/`, `xdc/` subdirectories), and Vivado build outputs (`vivado_build/`). The `sim/` directory includes verification components (`hvl/`), testbenches (`tb/`), simulation script `sim_qos.tcl`, and regression script `run_regression.sh`. The `src/hdl/` folder contains RTL for arbitration, buffers, core QoS logic, fabric top‑level modules, interfaces, and switch IP topologies. The `src/inc/` folder holds parameter include files, and `src/xdc/` contains the timing constraints file `timing_qos.xdc`.

---

## Simulation

Available testbenches include `tb_fabric_basic` for functional validation, `tb_fabric_qos_sweep` for QoS parameter sweep over all eight priorities, `tb_fabric_qos_stress` for oversubscription and aging tests, and unit tests for the classifier, scheduler, and VOQ. On Windows, run `run_sim.bat <testbench_name>`. On Linux, use `vsim -do "set TB <name>; do sim_qos.tcl"` or execute `./run_regression.sh`. The regression suite passes all six tests with line coverage exceeding 90%.

---

## Synthesis

**Automated build**  
From the `vivado_build` directory, run `vivado -mode batch -source vivado_qos_build_2019.tcl`. The script creates a Vivado project, imports all RTL sources, loads the timing constraints, synthesizes the design targeting the xcku3p-ffvd900-2-i device, and generates timing and utilization reports. It also verifies that QoS classifiers and VOQ structures are present and that setup timing is met (WNS > 0). Hold violations are expected in synthesis‑only mode because place and route is not performed.

**Outputs**  
The build produces a Vivado project file (`qos_fabric_10x10g.xpr`), a synthesis checkpoint (`switch_fabric.dcp`), a timing report (`reports/timing_synth.rpt`), and a utilization report (`reports/utilization_synth.rpt`).

---

## Timing Closure

**Current status**  
In synthesis verification mode, setup timing passes with WNS = +0.125 ns, but hold timing shows violations (WHS = -2.810 ns). This is expected because no place and route has been performed; clock and data paths are unbalanced at the I/O level.

**Solutions**  
To resolve hold violations, run full implementation (place and route) in Vivado using `launch_runs impl_1 -to_step route_design`, which allows the router to balance paths and insert delay buffers. Alternatively, for synthesis‑only verification, add `set_false_path` constraints on I/O ports to disable I/O timing checks. The constraints file `src/xdc/timing_qos.xdc` defines a 156.25 MHz clock, input/output delays, and false paths for asynchronous reset.

---

## Documentation

The primary documentation is `doc/QoS_Ethernet_Switch_Fabric.pdf` (over 1600 pages), covering architecture, topologies, cell‑switching mode, QoS implementation (classifiers, VOQs, schedulers), verification methodology, and synthesis and timing closure. Additional documents include `IMPLEMENTATION_STATUS.md` (feature matrix, known issues, roadmap) and `TIMING_CLOSURE_GUIDE.md` (Vivado synthesis tips, XDC examples, hold violation debugging).

---

## License

Copyright © 2025 Parman Company. All rights reserved. This design is proprietary and confidential. Unauthorized copying, distribution, or use is strictly prohibited. Internal use by licensed organizations and FPGA prototyping for evaluation are permitted under an appropriate license. Commercial deployment, redistribution of source code, reverse engineering, and ASIC synthesis are not permitted without explicit authorization. For licensing inquiries, contact alireza.abbasian@parman.com.
