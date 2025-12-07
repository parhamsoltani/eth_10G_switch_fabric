`ifndef SIM_OPTIONS_VH
`define SIM_OPTIONS_VH

`timescale 1ns / 1ps

//═══════════════════════════════════════════════════════════════════════════
// Simulation-Specific Options
//═══════════════════════════════════════════════════════════════════════════

// Simulation control
`define SIM
`define SIM_TIME_LIMIT 200us

// Debug enables
`define DEBUG_QOS 1
`define DEBUG_FABRIC 1
`define DEBUG_ARBITER 0

// Coverage enables
`define ENABLE_COVERAGE 1
`define ENABLE_ASSERTIONS 1

// Waveform control
`define DUMP_WAVEFORMS 1
`define WAVEFORM_DEPTH 0  // 0 = all levels

`endif // SIM_OPTIONS_VH