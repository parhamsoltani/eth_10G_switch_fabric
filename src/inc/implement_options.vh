`ifndef IMPLEMENT_OPTIONS_VH
`define IMPLEMENT_OPTIONS_VH

`timescale 1ns / 1ps

//═══════════════════════════════════════════════════════════════════════════
// MASTER CONFIGURATION FILE
// All other header files should include this one
//═══════════════════════════════════════════════════════════════════════════

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
// Port Configuration (both forms for compatibility)
//═══════════════════════════════════════════════════════════════════════════
`ifndef NUM_PORT
    `define NUM_PORT 10
`endif

`ifndef NUM_PORTS
    `define NUM_PORTS `NUM_PORT
`endif
//═══════════════════════════════════════════════════════════════════════════
// Data Path Widths
//═══════════════════════════════════════════════════════════════════════════
`define DATA_WIDTH 64            // Cell/flit width
`define META_DATA_WIDTH 32       // Metadata bus width

//═══════════════════════════════════════════════════════════════════════════
// Buffer Depths
//═══════════════════════════════════════════════════════════════════════════
`define MAIN_MEM_DEPTH 16384
`define XPQ_DEPTH 64
`define OUTPUT_QUEUE_DEPTH 64
`define VOQ_DEPTH_PER_QOS 512
`define PACKET_BUFFER_DEPTH 256

//═══════════════════════════════════════════════════════════════════════════
// Feature Enables
//═══════════════════════════════════════════════════════════════════════════
`define MULTICAST_SUPPORT 1
`define ENABLE_QOS 1

//═══════════════════════════════════════════════════════════════════════════
// QoS Configuration
//═══════════════════════════════════════════════════════════════════════════
`ifndef QOS_LEVELS
    `define QOS_LEVELS 8
`endif

`ifndef QOS_TAG_WIDTH
    `define QOS_TAG_WIDTH 3
`endif

`ifndef PRIORITY_LEVELS
    `define PRIORITY_LEVELS `QOS_LEVELS
`endif

`ifndef META_QOS_OFFSET
    `define META_QOS_OFFSET     0           // QoS tag position in metadata
`endif

//═══════════════════════════════════════════════════════════════════════════
// Priority Level Definitions (802.1p compatible)
//═══════════════════════════════════════════════════════════════════════════
`define PRIORITY_BACKGROUND         3'd0
`define PRIORITY_BEST_EFFORT        3'd1
`define PRIORITY_STANDARD           3'd2
`define PRIORITY_EXCELLENT          3'd3
`define PRIORITY_CRITICAL           3'd4
`define PRIORITY_VIDEO              3'd5
`define PRIORITY_VOICE              3'd6
`define PRIORITY_NETWORK_CONTROL    3'd7
`define PRIORITY_INTERNETWORK_CTRL  3'd6  // Alias

// Convenience aliases
`define PRIORITY_LOW     3'd0
`define PRIORITY_MEDIUM  3'd2
`define PRIORITY_HIGH    3'd7

//═══════════════════════════════════════════════════════════════════════════
// QoS Weighted Fair Queuing
//═══════════════════════════════════════════════════════════════════════════
// Weights: {Level7, Level6, Level5, Level4, Level3, Level2, Level1, Level0}
`define QOS_WEIGHTS '{8'd50, 8'd40, 8'd35, 8'd30, 8'd25, 8'd20, 8'd15, 8'd10}

//═══════════════════════════════════════════════════════════════════════════
// DSCP Mappings
//═══════════════════════════════════════════════════════════════════════════
`define DSCP_WIDTH 6
`define DSCP_CS0    6'd0     // Best Effort
`define DSCP_CS1    6'd8
`define DSCP_CS2    6'd16
`define DSCP_CS3    6'd24
`define DSCP_CS4    6'd32
`define DSCP_CS5    6'd40
`define DSCP_CS6    6'd48
`define DSCP_CS7    6'd56
`define DSCP_EF     6'd46    // Expedited Forwarding
`define DSCP_AF41   6'd34    // Assured Forwarding 4-1
`define DSCP_AF31   6'd26    // Assured Forwarding 3-1

//═══════════════════════════════════════════════════════════════════════════
// Packet ID Management
//═══════════════════════════════════════════════════════════════════════════
`define PACKET_ID_WIDTH 10

//═══════════════════════════════════════════════════════════════════════════
// Credit-Based Flow Control
//═══════════════════════════════════════════════════════════════════════════
`define CREDIT_COUNT_WIDTH 12

//═══════════════════════════════════════════════════════════════════════════
// Token Bucket Shaper Parameters
//═══════════════════════════════════════════════════════════════════════════
`define SHAPER_ENABLE 1
`define TOKEN_WIDTH 16
`define SHAPER_TOKEN_WIDTH 16
`define SHAPER_TOKEN_BITS 16
`define BUCKET_DEPTH 65536
`define SHAPER_BUCKET_DEPTH 65536
`define SHAPER_BUCKET_SIZE 65535
`define REFILL_RATE 1024
`define SHAPER_RATE_BITS 16

//═══════════════════════════════════════════════════════════════════════════
// Scheduler Configuration
//═══════════════════════════════════════════════════════════════════════════
`define SCHEDULER_ENABLE_AGING 1
`define SCHEDULER_AGING_THRESHOLD 1000
`define SCHEDULER_QUANTUM_SIZE 64
`define SCHEDULER_WRR_ENABLE 1
`define SCHEDULER_SP_LEVELS 2

//═══════════════════════════════════════════════════════════════════════════
// Metadata Field Offsets
//═══════════════════════════════════════════════════════════════════════════
`define META_PORT_OFFSET 3
`define META_TIMESTAMP_OFFSET 8

`endif // IMPLEMENT_OPTIONS_VH