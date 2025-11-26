`timescale 1ns / 1ps
`default_nettype none

`ifndef QOS_DEFINES_VH
`define QOS_DEFINES_VH

//═══════════════════════════════════════════════════════════════════════════
// QoS Priority Definitions (IEEE 802.1p)
//═══════════════════════════════════════════════════════════════════════════

`ifndef QOS_LEVELS
    `define QOS_LEVELS 8  // FIXED: Changed from 3 to 8 (matches documentation)
`endif

`ifndef QOS_TAG_WIDTH
    `define QOS_TAG_WIDTH 3  // 3 bits = 8 levels
`endif

// ADDED: Missing macro for verification
`ifndef PRIORITY_LEVELS
    `define PRIORITY_LEVELS `QOS_LEVELS
`endif

//═══════════════════════════════════════════════════════════════════════════
// 8-Level Priority Mapping (Highest to Lowest)
//═══════════════════════════════════════════════════════════════════════════

`define PRIORITY_NETWORK_CONTROL  3'd7  // Network control (highest)
`define PRIORITY_VOICE            3'd6  // Voice (latency-sensitive)
`define PRIORITY_VIDEO            3'd5  // Streaming video
`define PRIORITY_CRITICAL         3'd4  // Critical applications
`define PRIORITY_EXCELLENT        3'd3  // Excellent effort
`define PRIORITY_STANDARD         3'd2  // Standard (default)
`define PRIORITY_BULK             3'd1  // Bulk transfer
`define PRIORITY_BACKGROUND       3'd0  // Background (lowest)

// Legacy 3-level aliases (for backward compatibility)
`define PRIORITY_HIGH    `PRIORITY_CRITICAL
`define PRIORITY_MEDIUM  `PRIORITY_STANDARD
`define PRIORITY_LOW     `PRIORITY_BACKGROUND

//═══════════════════════════════════════════════════════════════════════════
// QoS Configuration Parameters
//═══════════════════════════════════════════════════════════════════════════

`ifndef SCHEDULER_ENABLE_AGING
    `define SCHEDULER_ENABLE_AGING 1  // Enable anti-starvation
`endif

`ifndef SCHEDULER_AGING_THRESHOLD
    `define SCHEDULER_AGING_THRESHOLD 1000  // Cycles before priority boost
`endif

`ifndef CREDIT_COUNT_WIDTH
    `define CREDIT_COUNT_WIDTH 16  // Flow control credits
`endif

//═══════════════════════════════════════════════════════════════════════════
// DSCP to QoS Mapping (RFC 2474)
//═══════════════════════════════════════════════════════════════════════════

// Expedited Forwarding (EF) → NETWORK_CONTROL
`define DSCP_EF 6'd46

// Assured Forwarding Classes
`define DSCP_AF41 6'd34  // → VOICE
`define DSCP_AF31 6'd26  // → VIDEO
`define DSCP_AF21 6'd18  // → CRITICAL
`define DSCP_AF11 6'd10  // → EXCELLENT

// Class Selector (CS)
`define DSCP_CS7 6'd56  // → NETWORK_CONTROL
`define DSCP_CS6 6'd48  // → NETWORK_CONTROL
`define DSCP_CS0 6'd0   // → BACKGROUND

`endif // QOS_DEFINES_VH

`default_nettype wire
