`timescale 1ns / 1ps
`default_nettype none

`include "fabric_params.vh"

module xpq_buffer #(
    parameter DATA_WIDTH    = `DATA_WIDTH,
    parameter ID_WIDTH      = `PACKET_ID_WIDTH,
    parameter DEPTH         = `XPQ_DEPTH,
    parameter MAX_PKT_SIZE  = 512
)(
    input  logic clk,
    input  logic rst_n,

    // Write interface (from crosspoint)
    input  logic                    wr_valid,
    input  logic [DATA_WIDTH-1:0]   wr_data,
    input  logic [DATA_WIDTH/8-1:0] wr_keep,
    input  logic                    wr_last,
    input  logic [ID_WIDTH-1:0]     wr_id,
    input  logic                    wr_is_bad,
    input  logic [2:0]              wr_qos,
    output logic                    wr_ready,

    // Read interface (to egress)
    output logic                    rd_valid,
    output logic [DATA_WIDTH-1:0]   rd_data,
    output logic [DATA_WIDTH/8-1:0] rd_keep,
    output logic                    rd_last,
    output logic [ID_WIDTH-1:0]     rd_id,
    output logic                    rd_is_bad,
    output logic [2:0]              rd_qos,
    input  logic                    rd_ready,

    // Status
    output logic [15:0]             packet_count,
    output logic                    almost_full
);

    // Use packet_buffer as base
    packet_buffer #(
        .DATA_WIDTH(DATA_WIDTH),
        .MAX_PACKET_SIZE(MAX_PKT_SIZE),
        .BUFFER_DEPTH(DEPTH),
        .ID_WIDTH(ID_WIDTH)
    ) buffer_inst (
        .clk(clk),
        .rst_n(rst_n),

        .wr_valid(wr_valid),
        .wr_data(wr_data),
        .wr_keep(wr_keep),
        .wr_last(wr_last),
        .wr_id(wr_id),
        .wr_is_bad(wr_is_bad),
        .wr_ready(wr_ready),

        .rd_valid(rd_valid),
        .rd_data(rd_data),
        .rd_keep(rd_keep),
        .rd_last(rd_last),
        .rd_id(rd_id),
        .rd_is_bad(rd_is_bad),
        .rd_ready(rd_ready),

        .packet_count(packet_count),
        .word_count()
    );

    // QoS stored separately (simplified - can be enhanced)
    logic [2:0] qos_storage [2**ID_WIDTH];

    always_ff @(posedge clk) begin
        if (wr_valid && wr_last) begin
            qos_storage[wr_id] <= wr_qos;
        end
    end

    assign rd_qos = qos_storage[rd_id];
    assign almost_full = (packet_count > (DEPTH * 3 / 4));

endmodule

`default_nettype wire