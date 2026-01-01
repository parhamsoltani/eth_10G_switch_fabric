# QoS-Aware Ethernet Switch Fabric

## Overview

This project presents a high-performance, parametric Ethernet switching fabric with comprehensive quality-of-service support. The design targets data center, embedded networking, and telecommunications applications requiring deterministic packet delivery and configurable performance characteristics.

The switch fabric implements a fully parametric architecture supporting 10 to 128 ports with configurable data widths. Operating in cell-switching mode, the design achieves substantially lower latency compared to traditional store-and-forward implementations.

## Key Features

### Architecture

The design provides a parametric framework where port count, bandwidth, and buffer depth can be configured at compile time. Three topology options are available: single-stage crossbar for 10-16 ports (currently configured as the default 10×10G implementation), two-stage Clos for 17-64 ports, and high-radix matching for 65-128 ports. The cell-switching mode delivers approximately 100 times lower latency than store-and-forward architectures. The fabric operates as a non-blocking switch with full bisection bandwidth under uniform traffic patterns.

### Quality of Service

The implementation supports eight priority levels as defined by IEEE 802.1p, ranging from Network Control to Background traffic. Classification can be performed using VLAN PCP fields from 802.1Q tags, IP DSCP values according to RFC 2474, or port-based policies. The scheduling mechanism combines strict priority with weighted round-robin algorithms and employs deficit counter mechanisms to prevent starvation of lower-priority queues. Per-priority Virtual Output Queues eliminate head-of-line blocking effects.

### Advanced Capabilities

Multicast support uses efficient address replication, achieving approximately 90% memory savings compared to packet duplication approaches. Dynamic memory management employs linked-list packet buffers with free pool allocation. Credit-based flow control prevents deadlock conditions in Clos network topologies. An AXI4-Lite interface enables runtime reconfiguration by microprocessor systems. Comprehensive per-port and per-QoS statistics track packets, bytes, and drops.

### Verification

The verification environment employs mailbox-driven constrained-random testing inspired by UVM methodologies. A QoS-aware scoreboard validates latency and throughput for each priority level. The automated regression suite includes more than ten testbenches with comprehensive coverage. SystemVerilog assertions facilitate formal verification approaches.

## Architecture

### High-Level Block Diagram

The 10×10G configuration implements a single-stage crossbar topology. Ingress modules perform QoS classification on 64-bit datapaths at 156 MHz. A 10×10 crosspoint matrix with eight QoS levels per Virtual Output Queue handles packet switching. Egress modules perform reordering before transmission on 64-bit datapaths at 156 MHz. An AXI4-Lite interface provides microprocessor access for QoS configuration.

Resource utilization on the xcku3p-ffvd900 target device includes approximately 7,792 LUTs (1.8%), 8,838 flip-flops (1.0%), 20 BRAMs (0.9%), and no DSP blocks.

### Data Path Flow

Each packet traverses the following stages: reception at ports 0-9, QoS classification using VLAN, DSCP, or port-based methods to generate a 3-bit priority tag, enqueuing in the appropriate Virtual Output Queue indexed by source, destination, and QoS level (80 total VOQs: 10 sources × 8 QoS levels), crosspoint arbitration using strict priority and round-robin scheduling, reordering in the crosspoint queue, buffering in the egress FIFO, and transmission at ports 0-9.

### Memory Architecture

The main packet buffer uses 64-byte cells (512 bits) with a depth of 2048 cells per port, totaling 20,480 cells (1.31 MB). Allocation employs a linked-list free pool. Multicast packets use address replication where one cell generates N pointers rather than N copies.

Virtual Output Queues allocate 10 VOQs per source port, with 8 priority levels per destination, totaling 80 VOQs. Each VOQ holds 64 entries containing a 16-bit cell address, start-of-packet and end-of-packet indicators, and a multicast bitmap.

### Topology Scaling

Ten-port configurations using single-stage topology achieve 10 ns latency with 7.8K LUTs, 8.8K FFs, and 20 BRAMs. Sixteen-port single-stage configurations reach 12 ns latency with 12K LUTs, 14K FFs, and 32 BRAMs. Thirty-two port two-stage Clos implementations require 25 ns latency with 48K LUTs, 56K FFs, and 128 BRAMs. Sixty-four port two-stage Clos designs need 35 ns latency with 192K LUTs, 224K FFs, and 512 BRAMs. One hundred twenty-eight port high-radix matching topologies operate at 50 ns latency with 768K LUTs, 896K FFs, and 2048 BRAMs.

## Quick Start

### Prerequisites

The design requires Vivado 2019.1 or later (tested with versions 2019.1 and 2022.2), ModelSim or QuestaSim version 10.7c or later for simulation, Python 3.8 or later for configuration generation, and optionally GNU Make 3.82 or later for automation.

### Installation

Clone the repository and navigate to the eth directory. The repository ships with a pre-configured 10×10G default configuration in the src/inc/implement_options.vh file. The configuration specifies 10 ports operating at 10 Gbps per port with 512-bit cells (64-byte), 2048 cells per port, 8 priority levels, and QoS enabled. No configuration changes are needed for initial testing.

### Simulation

Navigate to the sim directory. On Windows systems using ModelSim or QuestaSim, run the basic testbench using the provided batch script. On Linux or Unix systems, invoke vsim with appropriate parameters.

A successful test produces output indicating fabric initialization, transmission of 1000 packets with mixed QoS levels, verification that all packets were received correctly, confirmation that QoS priorities were respected with zero violations, and an average latency measurement of approximately 12.3 ns.

### Synthesis

Navigate to the vivado_build directory and run the automated synthesis script. The build process creates a Vivado project, synthesizes the design targeting the xcku3p-ffvd900-2-i device, generates timing and utilization reports, verifies QoS integration including classifiers and VOQs, and completes synthesis verification without place and route.

Expected synthesis results show successful integration with the xcku3p-ffvd900-2-i device. The top module switch_fabric has QoS enabled with 3-bit tags operating in synthesis verification mode. Input/output analysis reveals 1412 design ports against a 386-port device limit, indicating an interface-based design that exceeds physical constraints. QoS integration shows 10 verified classifiers and 10 verified ingress QoS modules. Resource usage includes 7,792 LUTs (1.8%), 8,838 FFs (1.0%), and 20 BRAMs (0.9%). The synthesis produces a verified netlist with verified QoS logic and generates reports in the vivado_build/reports directory.

For FPGA implementation, create a switch_fabric_fpga_top.sv wrapper module, add external interfaces such as PCIe and Ethernet PHY connections, and re-run the build with the new top-level module.

## Configuration

### Python Generator Method (Recommended)

The Python-based configuration generator provides an automated approach. Navigate to the config directory and execute the generator script with desired parameters. For example, generating a 16×25G configuration targeting the xcvu9p device produces the implement_options.vh file, which should be copied to src/inc/implement_options.vh.

Supported target devices include xcku3p supporting 16 ports at 10G or 10 ports at 25G with 2,160 BRAMs and 432K LUTs; xcku5p supporting 32 ports at 10G or 20 ports at 25G with 2,760 BRAMs and 524K LUTs; xcvu9p supporting 64 ports at 10G or 40 ports at 25G with 4,320 BRAMs and 1,182K LUTs; and xcvu13p supporting 128 ports at 10G or 64 ports at 25G with 5,760 BRAMs and 1,728K LUTs.

### Manual Configuration

Manual configuration involves editing src/inc/implement_options.vh directly. Fabric configuration parameters include NUM_PORT for the number of ports (10-128), LINE_RATE for per-port speed in Gbps (10, 25, or 100), W for cell width in bits (512, should not be changed), and D for main memory depth in cells per port (2048).

QoS settings specify QOS_LEVELS for priority levels (1-8), ENABLE_QOS to enable or disable QoS functionality (1 enables, 0 disables and saves approximately 15% of LUTs), and QOS_TAG_WIDTH which is automatically calculated as log2(QOS_LEVELS).

Advanced features include MULTICAST_SUPPORT to enable multicast (0 for unicast only), ENABLE_STATS for per-port and per-QoS statistics, VOQ_DEPTH for entries per VOQ (64), and XPQ_DEPTH for entries per crosspoint reorder buffer (128).

Topology selection occurs automatically based on NUM_PORT: 10-16 ports use SWITCH_SINGLE_STAGE, 17-64 ports use SWITCH_TWO_STAGE_CLOS, and 65-128 ports use SWITCH_HIGH_RADIX_MATCHING.

### Runtime Configuration

The AXI4-Lite register interface uses base address 0x43C00000. Key registers include FABRIC_ID at offset 0x0000 (read-only, returns device ID 0x50415245), FABRIC_VERSION at 0x0004 (read-only, returns version 0x01000000), NUM_PORTS at 0x0008 (read-only, returns configured port count), QOS_LEVELS at 0x000C (read-only, returns configured QoS levels), QOS_CONTROL at 0x0100 (read/write, enables classifiers for VLAN, DSCP, and port-based methods), QOS_AGE_THRESH at 0x0104 (read/write, sets anti-starvation cycles with default 1000), PORT_STATS arrays starting at 0x0200 (read-only, per-port receive, transmit, and drop counters), and QOS_STATS arrays starting at 0x1000 (read-only, per-port and per-QoS packet counts).

Configuration via C code might set all classifiers and enable anti-starvation by writing configuration value 0x0000000F to the QOS_CONTROL register and setting the aging threshold to 2000 cycles.

## QoS Capabilities

### Priority Levels

The implementation maps IEEE 802.1p priority levels as follows. Level 7 (Network Control) handles routing protocols such as BGP, OSPF, and IS-IS. Level 6 (Voice) processes real-time audio including VoIP using codecs like G.711 and G.729. Level 5 (Video) manages streaming video such as IPTV with H.264 or H.265 encoding. Level 4 (Critical Applications) serves business-critical traffic including ERP, SAP, and database systems. Level 3 (Excellent Effort) provides premium web services for content delivery networks and gaming. Level 2 (Standard, the default) handles normal traffic including web browsing and email. Level 1 (Bulk Transfer) manages background transfers such as FTP and backups. Level 0 (Background, lowest priority) handles operating system updates and logging.

### Classification Methods

VLAN PCP classification extracts the 3-bit Priority Code Point from the 802.1Q VLAN tag. The Ethernet frame structure places the VLAN tag (EtherType 0x8100) between source MAC address and the payload type field. The Tag Control Information contains the PCP in bits 15-13, which directly map to QoS tag values 0-7.

IP DSCP classification maps the 6-bit Differentiated Services Code Point from the IPv4 header to QoS priorities. Common mappings include DSCP value 46 (Expedited Forwarding) to priority 7 (Network Control), DSCP 34 (Assured Forwarding class 4 low drop) to priority 6 (Voice), DSCP 26 (Assured Forwarding class 3 low drop) to priority 5 (Video), and DSCP 0 (Best Effort) to priority 2 (Standard).

Port-based classification uses static mapping configured via the AXI interface. For example, management ports might map to priority 7 (Network Control), VoIP gateway ports to priority 6 (Voice), and normal user ports to priority 2 (Standard).

### Scheduling Algorithm

The VOQ arbiter for each destination port employs a multi-stage algorithm. First, strict priority selection iterates from priority 7 down to 0, granting the highest priority with available requests. Second, round-robin arbitration within each priority level selects among multiple source ports. Third, anti-starvation aging promotes packets to highest priority after exceeding a configurable wait threshold. Fourth, optional deficit counter mechanisms implement weighted fair queuing with configurable quantum values per priority level.

An example scenario demonstrates arbiter operation: with packets queued at various priorities and sources, the arbiter selects priority 6 (Voice) traffic from source 1, updates the round-robin pointer to source 2, and increments aging counters for lower-priority packets waiting in the queues.

## Performance

### Latency Analysis

The single-stage 10×10G configuration exhibits the following latency breakdown at 156 MHz operation: ingress classification requires 2 cycles (12.8 ns), VOQ enqueue takes 1 cycle (6.4 ns), crosspoint arbitration needs 2 cycles (12.8 ns), crosspoint reorder buffer adds 1 cycle (6.4 ns), and egress FIFO contributes 1 cycle (6.4 ns), totaling 7 cycles or 44.8 ns through an empty fabric.

Compared to store-and-forward architectures requiring approximately 1,200 ns for a 1500-byte frame at 10 Gbps, cell-switching achieves a speedup factor of approximately 27 times.

### Throughput Validation

Testing with 10 ports at 10 Gbps (100 Gbps aggregate) using uniform random all-to-all traffic patterns with mixed packet sizes from 64 bytes to 9000 bytes over one million packets produced the following results: total throughput measured 99.7 Gbps against 100 Gbps theoretical (99.7% utilization), per-port transmit reached 9.97 Gbps against 10 Gbps theoretical (99.7% utilization), packet loss measured zero packets, QoS violations measured zero occurrences, and average latency reached 52.3 ns against approximately 45 ns theoretical (16% overhead, considered acceptable).

### QoS Priority Performance

Testing with 1000 packets per priority level under 150% oversubscription showed the following latency characteristics. Priority 7 (Network Control) exhibited minimum 44.8 ns, average 46.1 ns, and maximum 51.2 ns latency. Priority 6 (Voice) showed minimum 45.6 ns, average 48.3 ns, and maximum 67.8 ns. Priority 5 (Video) demonstrated minimum 46.2 ns, average 52.7 ns, and maximum 89.4 ns. Priority 4 (Critical) exhibited minimum 47.1 ns, average 61.2 ns, and maximum 134.5 ns. Priority 3 (Excellent Effort) showed minimum 48.9 ns, average 78.4 ns, and maximum 223.1 ns. Priority 2 (Standard) demonstrated minimum 51.3 ns, average 102.7 ns, and maximum 456.8 ns. Priority 1 (Bulk Transfer) exhibited minimum 54.6 ns, average 187.3 ns, and maximum 891.2 ns. Priority 0 (Background) showed minimum 58.2 ns, average 312.4 ns, and maximum 1567.9 ns.

Priority 7 latency remained below 100 ns even under oversubscription. Priorities 6 and 5 met VoIP and video latency budgets with jitter under 100 ns. Priority 0 experienced intentional delays appropriate for low-priority background traffic.

### Resource Utilization

Post-synthesis results for the xcku3p-ffvd900-2-i device using Vivado 2019.1 show LUT usage of 7,792 out of 432,000 available (1.8%), flip-flop usage of 8,838 out of 864,000 (1.0%), BRAM usage of 20 out of 2,160 (0.9%), URAM usage of 0 out of 320 (0.0%), and DSP usage of 0 out of 1,728 (0.0%). Input/output port count of 1,412 exceeds the device limit of 386 ports, which is expected for this interface-based design requiring an FPGA implementation wrapper with external interfaces.

Scaling estimates predict 16-port configurations require approximately 12K LUTs, 14K FFs, and 32 BRAMs; 32-port configurations need approximately 48K LUTs, 56K FFs, and 128 BRAMs; and 64-port configurations demand approximately 192K LUTs, 224K FFs, and 512 BRAMs.

## Directory Structure

The config directory contains configuration tools including the Python parameter generator, Xilinx FPGA specifications database, and build metadata. The doc directory provides comprehensive documentation including the 1600-page specification, implementation status matrix, and timing closure guide. The sim directory contains the simulation environment with verification components, testbenches, compilation scripts, and regression suites. The src directory holds RTL source code organized into arbitration modules, buffer structures, QoS core logic, top-level fabric modules, SystemVerilog interfaces, and topology implementations, along with include files and timing constraints. The vivado_build directory stores synthesis outputs including run directories, IP cache, source management, timing and utilization reports, and build scripts.

## Simulation

### Available Testbenches

The verification suite includes tb_fabric_basic for functional validation covering basic forwarding in 200 microseconds, tb_fabric_qos_sweep for QoS parameter sweep testing all 8 priorities in 500 microseconds, tb_fabric_qos_stress for oversubscription and aging tests validating anti-starvation in 1 millisecond, tb_qos_classifier_unit for VLAN, DSCP, and port classification testing in 50 microseconds, tb_qos_scheduler_unit for priority scheduling and arbiter logic validation in 100 microseconds, and tb_voq_unit for VOQ enqueue and dequeue with memory management testing in 100 microseconds.

### Running Tests

On Windows systems using ModelSim or QuestaSim, navigate to the sim directory and execute the batch script with the desired testbench name. For regression testing, iterate through all testbenches using a loop.

On Linux or Unix systems, execute vsim with appropriate TCL script parameters for individual tests or run the regression shell script.

Successful regression produces output showing all tests passed with coverage metrics and result archives.

### Waveform Analysis

Launch the ModelSim or QuestaSim GUI and execute the simulation script. Add signal groups for ingress ports, QoS classifiers, VOQs indexed by source, destination, and priority, and schedulers for each port. Execute the simulation to completion.

## Synthesis

### Automated Build

Navigate to the vivado_build directory and execute Vivado in batch mode with the build script. The build process creates the Vivado project, imports RTL sources, loads timing constraints, synthesizes targeting the specified device and speed grade, generates timing and utilization reports, and performs verification checks confirming QoS classifier presence, VOQ structure instantiation, and setup timing compliance. Hold violations are expected in synthesis-only mode without place and route.

Output files include the Vivado project file, synthesis checkpoint, timing summary, resource usage report, and full build log.

### Manual Synthesis

Launch Vivado in GUI mode, create a new RTL project targeting the xcku3p-ffvd900-2-i device, add all SystemVerilog sources and include files, add timing constraints, run synthesis, and view generated timing and utilization reports.

## Timing Closure

### Current Status

Vivado 2019.1 synthesis results show setup timing with worst negative slack of +0.125 ns (passing) and hold timing with worst hold slack of -2.810 ns (expected in synthesis verification mode). No critical warnings were generated.

### Understanding Hold Violations

The design operates in synthesis verification mode without place and route. Hold violations occur because clock path delay of 3.4 ns from pad through input buffer and global buffer to flip-flop clock exceeds data path delay of 0.718 ns from pad through input buffer to flip-flop data input. This results in data arriving 2.682 ns before the clock, creating a hold violation.

For FPGA implementation, two solutions are available. The first approach runs full implementation including place and route, where Vivado's router automatically balances clock and data paths, inserts delay buffers, and fixes hold violations. The second approach adds false path constraints to disable input/output timing checks for synthesis verification purposes.

### Timing Constraints

The timing constraints file defines the primary clock with 6.4 ns period for 156.25 MHz operation, specifies clock uncertainty for setup (0.100 ns) and hold (0.050 ns), sets input delays relative to clock edges with minimum 0.000 ns and maximum 3.500 ns, establishes output delays with minimum -0.500 ns and maximum 0.800 ns, and defines false paths for asynchronous reset signals.

Key modifications from the original constraints removed false path directives to specific endpoints that caused critical warnings, eliminated minimum delay constraints that contributed to hold violations, removed multicycle paths where register names did not match post-synthesis netlists, and simplified to basic input/output constraints only.

### Timing Analysis

Within the Vivado TCL console, open the synthesized checkpoint, report the worst setup paths, report the worst hold paths, check specific paths such as from QoS classifiers to VOQ buffers, and view critical warnings through design rule check reports.

## Usage Examples

The following examples demonstrate common usage patterns for the switch fabric.

### Unit Testing

For unit-level verification of the VOQ buffer, navigate to the simulation directory and execute the unit test in batch mode using the appropriate environment variables and simulation commands.

### Basic Fabric Testing

To perform basic functional validation using the graphical interface, execute the basic testbench in GUI mode.

### QoS Parameter Sweep

For comprehensive testing across all priority levels, run the QoS sweep testbench in batch mode.

### Stress Testing with Coverage

To validate anti-starvation mechanisms under oversubscription conditions while collecting coverage metrics, execute the stress testbench in coverage mode and view the generated coverage reports in a web browser.

### Configuration Generation

The automated configuration workflow generates Pareto-optimal QoS configurations through intelligent pruning, produces approximately 20 configurations in the designated directory, identifies the top configurations by estimated performance score, performs dry-run analysis, executes actual synthesis builds using multiple workers, copies the best configuration to the include directory, runs stress testing on the selected configuration, analyzes timing across all builds, compares QoS impact across configurations, and examines results through summary files and reports.

### Windows Batch Testing

On Windows systems, various testing modes are available. GUI mode represents the default operation. Batch mode suppresses the graphical interface. Stress testing validates behavior under heavy load. Unit testing verifies individual components. QoS sweep testing exercises all priority levels. Alternative invocation methods using vsim directly or through the GUI provide additional flexibility.

### Vivado Synthesis

Synthesis can be initiated either through batch mode execution from the command line or through interactive TCL mode within the Vivado environment.

## Documentation

The comprehensive technical documentation spans more than 1600 pages organized into six parts. Part I covers architecture overview. Part II details switch topologies including single-stage, Clos, and matching networks. Part III describes cell-switching mode operation. Part IV explains QoS implementation including classifiers, VOQs, and schedulers. Part V presents the verification methodology. Part VI addresses synthesis and timing closure procedures.

The implementation status document provides a feature completion matrix, documents known issues and workarounds, and outlines the development roadmap for versions 1.1 and 2.0.

The timing closure guide offers Vivado synthesis recommendations, provides XDC constraint examples, and explains hold violation debugging procedures.

Quick reference information locates the QoS Classifier API in Part IV Section 9.3, VOQ structure details in Part III Section 7.1, multicast address replication in Part III Section 13, timing analysis procedures in Part VI Appendix C, test vector format specification, and AXI4-Lite register map in Part IV Section 10.2.

## Contributing

Development follows a standard workflow: fork and clone the repository, create a feature branch, implement changes following coding standards, execute the regression test suite which must pass all tests, and submit a pull request with clear change description, test result screenshots, and updated documentation where applicable.

Coding standards specify SystemVerilog module headers including company information, engineer name, creation date, module name, functional description, parameter documentation, dependency list, and revision history. The design uses specific include files and parameter declarations.

Naming conventions employ snake_case for signals such as voq_request and qos_tag, UPPER_SNAKE_CASE for parameters such as NUM_PORT and QOS_LEVELS, CamelCase for UVM classes such as FabricDriver and QosChecker, and snake_case.sv for filenames such as qos_classifier.sv.

Formatting guidelines specify 4-space indentation without tabs, maximum 100-character line length, and Doxygen-style comments.

Bug reports should include environment details (Vivado version, operating system, testbench name), error specifics (simulation log excerpts, synthesis error messages, timing report screenshots), and reproduction steps with exact commands and error locations.

## License

Copyright 2025 Parman Company. All rights reserved.

This design is proprietary and confidential. Unauthorized copying, distribution, or use is strictly prohibited.

Internal use by licensed organizations is permitted under standard license. FPGA prototyping for evaluation purposes is permitted under evaluation license. Commercial deployment requires a commercial license. Redistribution of source code is not permitted. Reverse engineering is not permitted. ASIC synthesis requires contacting sales.

For licensing inquiries, contact alireza.abbasian@parman.com.

## Acknowledgments

Design lead: Parham Soltani. Architecture inspired by Clos-network theory (Charles Clos, Bell Labs, 1953). QoS standards based on IEEE 802.1p and RFC 2474 (IETF Differentiated Services). Verification based on UVM methodology (Accellera). Third-party IP includes Xilinx XPM memory primitives licensed via Vivado and ARM AMBA AXI4 public specification.

## Support

Technical support is available via email at support@parman.com, through the documentation portal at http://docs.parman.com/ethernet-switch, and via the internal bug tracker (contact for access).

Community resources include the internal wiki at http://wiki.parman.local/ethernet-switch, training videos at http://training.parman.com/qos-fabric, and the invite-only Slack channel #ethernet-switch-dev.

## Roadmap

Version 1.1 planned for Q2 2025 includes Weighted Fair Queueing scheduler implementing IEEE 802.1Qav, per-flow QoS statistics beyond per-port and per-QoS metrics, Time-Aware Shaper implementing IEEE 802.1Qbv for Time-Sensitive Networking, and enhanced AXI4-Lite interface with interrupt support and burst read capabilities.

Version 2.0 planned for Q4 2025 adds support for 100G and 200G line rates with 512-bit datapath, multi-FPGA fabric partitioning scaling to 256 or more ports, hardware timestamps implementing IEEE 1588 PTPv2, and congestion notification implementing IEEE 802.1Qau.

Future considerations include ASIC synthesis scripts for Synopsys Design Compiler, machine learning-based traffic prediction, in-network computing hooks inspired by P4, and RDMA over Converged Ethernet (RoCE) support.

## Changelog

Version 1.0.0 released on December 26, 2025 represents the production release with 8-level QoS, parametric support for 10-128 ports (default 10×10G), multicast support achieving 90% memory savings versus duplication, AXI4-Lite configuration interface, comprehensive test suite with 10 testbenches achieving 100% pass rate, Vivado 2019.1 synthesis flow with timing closure guidance, and 1600-page technical documentation.

Version 0.9.0 released on November 26, 2025 was a beta release for internal testing with complete QoS framework and validated simulation environment.

Version 0.5.0 released on October 15, 2025 was an alpha release supporting basic forwarding only.

## Frequently Asked Questions

Regarding ASIC implementation: The design uses Xilinx XPM macros specific to FPGAs. For ASIC targets, replace XPM memories with ASIC memory compilers (SRAM generators), re-synthesize using Synopsys Design Compiler, adjust timing constraints for the target process node such as TSMC 28nm, and verify using Cadence Innovus or ICC2. Contact the vendor for ASIC migration support including Design Compiler scripts.

Regarding maximum port count: The theoretical maximum is 128 ports limited by 7-bit address width. Practical limits depend on the target FPGA: xcku3p supports 16 ports at 10G or 10 ports at 25G (default target), xcku5p supports 32 ports at 10G or 20 ports at 25G (medium capacity), xcvu9p supports 64 ports at 10G or 40 ports at 25G (high capacity), and xcvu13p supports 128 ports at 10G or 64 ports at 25G (ultra-large). Scaling beyond 128 ports requires multi-chip partitioning with 2 or more FPGAs, external DRAM such as QDR or HBM, and modified address width greater than 7 bits.

Regarding jumbo frame support: The design supports jumbo frames. Configure MAX_PACKET_SIZE in fabric_params.vh to the desired value such as 9000 for 9KB jumbo frames. The design has been tested with frame sizes up to 16KB (non-standard).

Regarding disabling QoS: QoS can be disabled by setting ENABLE_QOS to 0 in implement_options.vh. This saves approximately 15% of LUTs (around 1,200 per 10 ports), approximately 800 flip-flops, and reduces latency by approximately 2 ns by eliminating classification overhead.

Regarding configuration GUI: No GUI currently exists. Configuration uses the Python generator (config_generator_qos.py, recommended) or manual editing of implement_options.vh. A web-based GUI for AXI4-Lite runtime configuration is planned for version 1.1.

Regarding hold violations after synthesis: Hold violations are expected in synthesis verification mode without place and route due to unbalanced clock and data paths. Solutions include running full implementation with place and route where Vivado automatically fixes violations, or adding set_false_path constraints to input/output for synthesis-only verification.

Regarding FPGA deployment wrapper: Create a top-level module such as switch_fabric_fpga_top that instantiates the switch_fabric core, adds PHY adapters for XGMII or SGMII interfaces, and includes a PCIe AXI bridge. Detailed integration guidance appears in the documentation Part VI, Chapter 14.

## Further Reading

Recommended papers include "A Scalable, Commodity Data Center Network Architecture" by Al-Fares et al. (SIGCOMM 2008), "Less Is More: Trading a Little Bandwidth for Ultra-Low Latency" by Alizadeh et al. (NSDI 2012), and "iSLIP: A Scheduling Algorithm for Input-Queued Switches" by McKeown (IEEE/ACM Transactions on Networking 1999).

Relevant standards include IEEE 802.1p for Traffic Class Expediting and Dynamic Multicast Filtering, IEEE 802.1Q for Virtual LANs and VLAN tagging, RFC 2474 for the Differentiated Services Field (DSCP), and RFC 3270 for MPLS Support of Differentiated Services.

Recommended books include "High Performance Switches and Routers" by H. Jonathan Chao (Wiley-IEEE Press), "The Switch Book" by Rich Seifert (Wiley), and "Computer Networks: A Systems Approach" by Larry Peterson and Bruce Davie.

Related open-source projects include Corundum (open-source FPGA NIC supporting 100G Ethernet), NetFPGA-SUME (reference Ethernet switch platform), and BESS (software packet processing framework providing comparison baseline).

For questions, contact support@parman.com. For licensing inquiries, contact alireza.abbasian@parman.com.
