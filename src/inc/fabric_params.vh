`timescale 1ns / 1ps
`default_nettype none

`ifndef FABRIC_PARAMS_VH
`define FABRIC_PARAMS_VH

//═══════════════════════════════════════════════════════════════════════════
// Fabric Configuration Parameters
//═══════════════════════════════════════════════════════════════════════════

`ifndef NUM_PORTS
    `define NUM_PORTS 10
`endif

`ifndef DATA_WIDTH
    `define DATA_WIDTH 512  // Mini-cell width
`endif

`ifndef PACKET_ID_WIDTH
    `define PACKET_ID_WIDTH 10
`endif

//═══════════════════════════════════════════════════════════════════════════
// QoS Parameters (FIXED)
//═══════════════════════════════════════════════════════════════════════════

`ifndef QOS_LEVELS
    `define QOS_LEVELS 8  // CHANGED FROM 3 (matches documentation Section 9.1)
`endif

`ifndef QOS_TAG_WIDTH
    `define QOS_TAG_WIDTH 3  // 3 bits for 8 levels
`endif

`ifndef ENABLE_QOS
    `define ENABLE_QOS 1  // Enable QoS by default
`endif

//═══════════════════════════════════════════════════════════════════════════
// Buffer Depth Parameters
//═══════════════════════════════════════════════════════════════════════════

`ifndef VOQ_DEPTH_PER_QOS
    `define VOQ_DEPTH_PER_QOS 512  // Per priority level
`endif

`ifndef XPQ_DEPTH
    `define XPQ_DEPTH 256
`endif

`ifndef PACKET_BUFFER_DEPTH
    `define PACKET_BUFFER_DEPTH 2048
`endif

//═══════════════════════════════════════════════════════════════════════════
// Metadata Parameters
//═══════════════════════════════════════════════════════════════════════════

`ifndef META_DATA_WIDTH
    `define META_DATA_WIDTH 16  // Metadata bus width
`endif

`ifndef META_QOS_OFFSET
    `define META_QOS_OFFSET 0  // QoS tag position in metadata
`endif

`endif // FABRIC_PARAMS_VH

`default_nettype wire
