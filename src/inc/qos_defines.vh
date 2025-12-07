`ifndef QOS_DEFINES_VH
`define QOS_DEFINES_VH

`timescale 1ns / 1ps

// This file should match sim/inc/qos_defines.vh

//═══════════════════════════════════════════════════════════════════════════
// System Configuration (ADDED)
//═══════════════════════════════════════════════════════════════════════════
`ifndef NUM_PORTS
    `define NUM_PORTS 8
`endif

//═══════════════════════════════════════════════════════════════════════════
// QoS Level Definitions
//═══════════════════════════════════════════════════════════════════════════
`ifndef QOS_LEVELS
    `define QOS_LEVELS 8
`endif

`ifndef QOS_TAG_WIDTH
    `define QOS_TAG_WIDTH 3
`endif

//═══════════════════════════════════════════════════════════════════════════
// Priority Levels
//═══════════════════════════════════════════════════════════════════════════
`ifndef PRIORITY_BACKGROUND
    `define PRIORITY_BACKGROUND         3'd0
    `define PRIORITY_BEST_EFFORT        3'd1
    `define PRIORITY_STANDARD           3'd2
    `define PRIORITY_EXCELLENT          3'd3
    `define PRIORITY_CRITICAL           3'd4
    `define PRIORITY_VIDEO              3'd5
    `define PRIORITY_VOICE              3'd6
    `define PRIORITY_NETWORK_CONTROL    3'd7
`endif

// Aliases
`ifndef PRIORITY_LOW
    `define PRIORITY_LOW                3'd0
    `define PRIORITY_MEDIUM             3'd2
    `define PRIORITY_HIGH               3'd7
`endif

//═══════════════════════════════════════════════════════════════════════════
// Metadata Configuration
//═══════════════════════════════════════════════════════════════════════════
`ifndef META_DATA_WIDTH
    `define META_DATA_WIDTH         32
`endif

`ifndef META_QOS_OFFSET
    `define META_QOS_OFFSET         0
`endif

//═══════════════════════════════════════════════════════════════════════════
// Scheduler Parameters
//═══════════════════════════════════════════════════════════════════════════
`ifndef SCHEDULER_ENABLE_AGING
    `define SCHEDULER_ENABLE_AGING      1
    `define SCHEDULER_AGING_THRESHOLD   1000
`endif

`endif // QOS_DEFINES_VH