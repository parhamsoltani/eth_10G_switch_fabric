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
// QoS Weighted Fair Queuing (ADDED)
//═══════════════════════════════════════════════════════════════════════════
`ifndef QOS_WEIGHTS
    // Weights for each priority level (Level 7 = highest, Level 0 = lowest)
    // Format: {L7, L6, L5, L4, L3, L2, L1, L0}
    `define QOS_WEIGHTS '{8'd50, 8'd40, 8'd35, 8'd30, 8'd25, 8'd25, 8'd25, 8'd25}
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

//═══════════════════════════════════════════════════════════════════════════
// Token Bucket Shaper Parameters (ADDED)
//═══════════════════════════════════════════════════════════════════════════
`ifndef TOKEN_WIDTH
    `define TOKEN_WIDTH         16
    `define BUCKET_DEPTH        65536
    `define REFILL_RATE         1024
`endif

//═══════════════════════════════════════════════════════════════════════════
// Credit-Based Flow Control (ADDED)
//═══════════════════════════════════════════════════════════════════════════
`ifndef CREDIT_COUNT_WIDTH
    `define CREDIT_COUNT_WIDTH      12
    `define VOQ_DEPTH_PER_QOS       2048
`endif

//═══════════════════════════════════════════════════════════════════════════
// Packet ID Management (ADDED)
//═══════════════════════════════════════════════════════════════════════════
`ifndef PACKET_ID_WIDTH
    `define PACKET_ID_WIDTH         10
`endif

//═══════════════════════════════════════════════════════════════════════════
// Aliases for compatibility
//═══════════════════════════════════════════════════════════════════════════
`ifndef PRIORITY_LEVELS
    `define PRIORITY_LEVELS `QOS_LEVELS
`endif

`endif // QOS_DEFINES_VH