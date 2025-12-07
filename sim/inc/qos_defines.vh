`ifndef QOS_DEFINES_VH
`define QOS_DEFINES_VH

`timescale 1ns / 1ps

//═══════════════════════════════════════════════════════════════════════════
// QoS Level Definitions
//═══════════════════════════════════════════════════════════════════════════
`define QOS_LEVELS              8
`define QOS_TAG_WIDTH           3

//═══════════════════════════════════════════════════════════════════════════
// Priority Levels (3-bit values for 8 levels)
//═══════════════════════════════════════════════════════════════════════════
`define PRIORITY_BACKGROUND         3'd0
`define PRIORITY_BEST_EFFORT        3'd1
`define PRIORITY_STANDARD           3'd2
`define PRIORITY_EXCELLENT          3'd3
`define PRIORITY_CRITICAL           3'd4
`define PRIORITY_VIDEO              3'd5
`define PRIORITY_VOICE              3'd6
`define PRIORITY_NETWORK_CONTROL    3'd7

// Convenience aliases
`define PRIORITY_LOW                3'd0
`define PRIORITY_MEDIUM             3'd2
`define PRIORITY_HIGH               3'd7

//═══════════════════════════════════════════════════════════════════════════
// DSCP to QoS Mapping
//═══════════════════════════════════════════════════════════════════════════
`define DSCP_EF     6'd46    // Expedited Forwarding
`define DSCP_AF41   6'd34    // Assured Forwarding 4-1
`define DSCP_AF31   6'd26    // Assured Forwarding 3-1
`define DSCP_CS0    6'd0     // Class Selector 0 (Best Effort)

//═══════════════════════════════════════════════════════════════════════════
// Metadata Configuration
//═══════════════════════════════════════════════════════════════════════════
`define META_DATA_WIDTH         32
`define META_QOS_OFFSET         0           // QoS tag position in metadata
`define META_PORT_OFFSET        3           // Port ID position
`define META_TIMESTAMP_OFFSET   8           // Timestamp position

//═══════════════════════════════════════════════════════════════════════════
// Scheduler Parameters
//═══════════════════════════════════════════════════════════════════════════
`define SCHEDULER_ENABLE_AGING      1
`define SCHEDULER_AGING_THRESHOLD   1000
`define SCHEDULER_QUANTUM_SIZE      64      // Bytes per quantum

//═══════════════════════════════════════════════════════════════════════════
// Traffic Shaping Parameters
//═══════════════════════════════════════════════════════════════════════════
`define SHAPER_TOKEN_BITS           16
`define SHAPER_RATE_BITS            16
`define SHAPER_BUCKET_SIZE          65535

`endif // QOS_DEFINES_VH