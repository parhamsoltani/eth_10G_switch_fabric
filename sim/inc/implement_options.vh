`ifndef IMPLEMENT_OPTIONS_VH
`define IMPLEMENT_OPTIONS_VH

`timescale 1ns / 1ps

//═══════════════════════════════════════════════════════════════════════════
// Switch Configuration - 10x10G with Multicast
//═══════════════════════════════════════════════════════════════════════════
`define LINE_RATE 10
`define N 10
`define S 10
`define W 64
`define D 16384
`define X 64
`define U 1

//═══════════════════════════════════════════════════════════════════════════
// Derived Parameters (BOTH forms for compatibility)
//═══════════════════════════════════════════════════════════════════════════
`define NUM_PORT 10              // Some files use NUM_PORT
`define NUM_PORTS 10             // Some files use NUM_PORTS
`define DATA_WIDTH 64
`define MAIN_MEM_DEPTH 16384
`define XPQ_DEPTH 64
`define OUTPUT_QUEUE_DEPTH 64
`define MULTICAST_SUPPORT 1
`define PACKET_BUFFER_DEPTH 256

//═══════════════════════════════════════════════════════════════════════════
// QoS Configuration
//═══════════════════════════════════════════════════════════════════════════
`define QOS_TAG_WIDTH 3
`define QOS_LEVELS 8
`define PACKET_ID_WIDTH 10
`define META_DATA_WIDTH 32
`define META_QOS_OFFSET 0
`define CREDIT_COUNT_WIDTH 4

//═══════════════════════════════════════════════════════════════════════════
// Priority Level Definitions
//═══════════════════════════════════════════════════════════════════════════
`define PRIORITY_BACKGROUND         3'd0
`define PRIORITY_BEST_EFFORT        3'd1
`define PRIORITY_STANDARD           3'd2
`define PRIORITY_EXCELLENT          3'd3
`define PRIORITY_CRITICAL           3'd4
`define PRIORITY_VIDEO              3'd5
`define PRIORITY_VOICE              3'd6
`define PRIORITY_NETWORK_CONTROL    3'd7
`define PRIORITY_INTERNETWORK_CTRL  3'd6

// Aliases for convenience
`define PRIORITY_LOW     3'd0
`define PRIORITY_MEDIUM  3'd2
`define PRIORITY_HIGH    3'd7

//═══════════════════════════════════════════════════════════════════════════
// Scheduler Configuration
//═══════════════════════════════════════════════════════════════════════════
`define SCHEDULER_ENABLE_AGING 1
`define SCHEDULER_AGING_THRESHOLD 1000

`endif // IMPLEMENT_OPTIONS_VH