`ifndef QOS_DEFINES_VH
`define QOS_DEFINES_VH

// Include fabric parameters for consistency
`include "fabric_params.vh"

//═══════════════════════════════════════════════════════════════════════════════
// QoS Priority Level Definitions (IEEE 802.1p)
//═══════════════════════════════════════════════════════════════════════════════
// Priority levels: 0 (lowest) to 7 (highest)
// Uses QOS_LEVELS and QOS_TAG_WIDTH from fabric_params.vh
//═══════════════════════════════════════════════════════════════════════════════

// 8-Level Priority Definitions (802.1p standard)
`define PRIORITY_NETWORK_CONTROL  3'd7  // Highest - Network control traffic
`define PRIORITY_VOICE            3'd6  // Voice (low latency)
`define PRIORITY_VIDEO            3'd5  // Video streaming
`define PRIORITY_CRITICAL         3'd4  // Critical applications
`define PRIORITY_EXCELLENT        3'd3  // Business-critical data
`define PRIORITY_STANDARD         3'd2  // Standard applications
`define PRIORITY_BEST_EFFORT      3'd1  // Normal traffic
`define PRIORITY_BACKGROUND       3'd0  // Lowest - Background/bulk

//═══════════════════════════════════════════════════════════════════════════════
// 4-Queue Mapping (for schedulers with 4 priority queues)
//═══════════════════════════════════════════════════════════════════════════════
// Maps 8 priority levels to 4 hardware queues

`define QUEUE_CRITICAL    2'd3  // Maps priorities 7, 6
`define QUEUE_HIGH        2'd2  // Maps priorities 5, 4
`define QUEUE_MEDIUM      2'd1  // Maps priorities 3, 2
`define QUEUE_LOW         2'd0  // Maps priorities 1, 0

//═══════════════════════════════════════════════════════════════════════════════
// DSCP to QoS Priority Mapping (for IP-based classification)
//═══════════════════════════════════════════════════════════════════════════════

`define DSCP_EF           6'd46  // Expedited Forwarding → PRIORITY_VOICE
`define DSCP_AF41         6'd34  // Assured Forwarding 4-1 → PRIORITY_VIDEO
`define DSCP_AF31         6'd26  // Assured Forwarding 3-1 → PRIORITY_CRITICAL
`define DSCP_AF21         6'd18  // Assured Forwarding 2-1 → PRIORITY_EXCELLENT
`define DSCP_AF11         6'd10  // Assured Forwarding 1-1 → PRIORITY_STANDARD
`define DSCP_BE           6'd0   // Best Effort → PRIORITY_BEST_EFFORT

//═══════════════════════════════════════════════════════════════════════════════
// Queue Weight Definitions (for WRR/WFQ scheduling)
//═══════════════════════════════════════════════════════════════════════════════

`define WEIGHT_NETWORK_CONTROL    8'd255
`define WEIGHT_VOICE              8'd200
`define WEIGHT_VIDEO              8'd150
`define WEIGHT_CRITICAL           8'd100
`define WEIGHT_EXCELLENT          8'd75
`define WEIGHT_STANDARD           8'd50
`define WEIGHT_BEST_EFFORT        8'd25
`define WEIGHT_BACKGROUND         8'd10

//═══════════════════════════════════════════════════════════════════════════════
// Helper Macros
//═══════════════════════════════════════════════════════════════════════════════

// Map 8-level priority to 4-queue index
`define QOS_TO_QUEUE(qos) ((qos) >> 1)

// Check if priority is high (>= 4)
`define IS_HIGH_PRIORITY(qos) ((qos) >= 3'd4)

// Check if priority is critical (>= 6)
`define IS_CRITICAL_PRIORITY(qos) ((qos) >= 3'd6)

`endif // QOS_DEFINES_VH