`timescale 1ns / 1ps
`default_nettype none

`ifndef SWITCH_DATA_IF_SV
`define SWITCH_DATA_IF_SV

interface switch_data_if #(
    parameter DATA_WIDTH    = 32,
    parameter ID_WIDTH      = 10,
    parameter KEEP_WIDTH    = $clog2((DATA_WIDTH/8) + 1)
);
    // Data path signals
    logic [DATA_WIDTH-1:0]      data;
    logic [KEEP_WIDTH-1:0]      keep;       // Byte enables
    logic                       valid;
    logic                       ready;
    logic                       last;       // End of packet

    // Metadata
    logic                       is_bad_frame;
    logic [ID_WIDTH-1:0]        id;         // Packet identifier

    // QoS (optional, can be separated)
    logic [2:0]                 qos_tag;    // Priority level

    // Master modport (driver)
    modport master (
        input  ready,
        output data, keep, valid, last, is_bad_frame, id, qos_tag
    );

    // Slave modport (receiver)
    modport slave (
        input  data, keep, valid, last, is_bad_frame, id, qos_tag,
        output ready
    );

    // Monitor modport
    modport monitor (
        input  data, keep, valid, ready, last, is_bad_frame, id, qos_tag
    );

endinterface

`endif // SWITCH_DATA_IF_SV

`default_nettype wire