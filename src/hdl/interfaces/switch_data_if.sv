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
    logic [KEEP_WIDTH-1:0]      keep;
    logic                       valid;
    logic                       ready;
    logic                       last;

    // Metadata
    logic                       is_bad_frame;
    logic [ID_WIDTH-1:0]        id;
    logic [2:0]                 qos_tag;

    // FIXED: Added master_mp/slave_mp for array instantiation compatibility
    modport master_mp (
        input  ready,
        output data, keep, valid, last, is_bad_frame, id, qos_tag
    );

    modport slave_mp (
        input  data, keep, valid, last, is_bad_frame, id, qos_tag,
        output ready
    );

    // Legacy modports (for backward compatibility)
    modport master (
        input  ready,
        output data, keep, valid, last, is_bad_frame, id, qos_tag
    );

    modport slave (
        input  data, keep, valid, last, is_bad_frame, id, qos_tag,
        output ready
    );

    modport monitor (
        input  data, keep, valid, ready, last, is_bad_frame, id, qos_tag
    );

endinterface

`endif // SWITCH_DATA_IF_SV

`default_nettype wire
