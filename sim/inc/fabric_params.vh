`ifndef FABRIC_PARAMS_VH
`define FABRIC_PARAMS_VH

`timescale 1ns / 1ps

//═══════════════════════════════════════════════════════════════════════════
// This file uses values from implement_options.vh
// Include it first if not already included
//═══════════════════════════════════════════════════════════════════════════

`ifndef NUM_PORTS
    `define NUM_PORTS 10
`endif

`ifndef NUM_PORT
    `define NUM_PORT 10
`endif

`ifndef DATA_WIDTH
    `define DATA_WIDTH 64
`endif

`ifndef PACKET_ID_WIDTH
    `define PACKET_ID_WIDTH 10
`endif

`ifndef OUTPUT_QUEUE_DEPTH
    `define OUTPUT_QUEUE_DEPTH 128
`endif

`ifndef QOS_LEVELS
    `define QOS_LEVELS 8
`endif

`ifndef QOS_TAG_WIDTH
    `define QOS_TAG_WIDTH 3
`endif

`ifndef META_DATA_WIDTH
    `define META_DATA_WIDTH 32
`endif

`ifndef META_QOS_OFFSET
    `define META_QOS_OFFSET 0
`endif

`ifndef VOQ_DEPTH_PER_QOS
    `define VOQ_DEPTH_PER_QOS 512
`endif

`ifndef PACKET_BUFFER_DEPTH
    `define PACKET_BUFFER_DEPTH 256
`endif

`endif // FABRIC_PARAMS_VH