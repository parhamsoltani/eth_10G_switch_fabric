`timescale 1ns / 1ps
// `default_nettype none

`include "fabric_params.vh"

module voq_buffer #(
    parameter DATA_WIDTH        = `DATA_WIDTH,
    parameter ID_WIDTH          = `PACKET_ID_WIDTH,
    parameter DEPTH_PER_QOS     = `VOQ_DEPTH_PER_QOS,
    parameter MAX_PACKET_SIZE   =  512,
    parameter NUM_QOS_LEVELS    = `QOS_LEVELS
)(
    input  logic clk,
    input  logic rst_n,

    // Write interface (from ingress)
    input  logic                    wr_valid,
    input  logic [DATA_WIDTH-1:0]   wr_data,
    input  logic [DATA_WIDTH/8-1:0] wr_keep,
    input  logic                    wr_last,
    input  logic [ID_WIDTH-1:0]     wr_id,
    input  logic                    wr_is_bad,
    input  logic [2:0]              wr_qos,
    output logic                    wr_ready,

    // Read interface (to crosspoint)
    output logic                    rd_valid,
    output logic [DATA_WIDTH-1:0]   rd_data,
    output logic [DATA_WIDTH/8-1:0] rd_keep,
    output logic                    rd_last,
    output logic [ID_WIDTH-1:0]     rd_id,
    output logic                    rd_is_bad,
    output logic [2:0]              rd_qos,
    input  logic                    rd_ready,

    // Per-priority status
    output logic [10:0]             occupancy [NUM_QOS_LEVELS],
    output logic                    empty [NUM_QOS_LEVELS],
    output logic                    almost_full [NUM_QOS_LEVELS]
);

    // Instantiate packet_buffer for each QoS level
    logic                       prio_wr_valid [NUM_QOS_LEVELS];
    logic                       prio_wr_ready [NUM_QOS_LEVELS];
    logic                       prio_rd_valid [NUM_QOS_LEVELS];
    logic [DATA_WIDTH-1:0]      prio_rd_data [NUM_QOS_LEVELS];
    logic [DATA_WIDTH/8-1:0]    prio_rd_keep [NUM_QOS_LEVELS];
    logic                       prio_rd_last [NUM_QOS_LEVELS];
    logic [ID_WIDTH-1:0]        prio_rd_id [NUM_QOS_LEVELS];
    logic                       prio_rd_is_bad [NUM_QOS_LEVELS];
    logic                       prio_rd_ready [NUM_QOS_LEVELS];
    logic [15:0]                prio_pkt_count [NUM_QOS_LEVELS];
    logic [31:0]                prio_word_count [NUM_QOS_LEVELS];

    genvar g;
    generate
        for (g = 0; g < NUM_QOS_LEVELS; g++) begin : gen_prio_buffers
            packet_buffer #(
                .DATA_WIDTH(DATA_WIDTH),
                .MAX_PACKET_SIZE(MAX_PACKET_SIZE),
                .BUFFER_DEPTH(DEPTH_PER_QOS),
                .ID_WIDTH(ID_WIDTH)
            ) prio_buffer (
                .clk(clk),
                .rst_n(rst_n),

                .wr_valid(prio_wr_valid[g]),
                .wr_data(wr_data),
                .wr_keep(wr_keep),
                .wr_last(wr_last),
                .wr_id(wr_id),
                .wr_is_bad(wr_is_bad),
                .wr_ready(prio_wr_ready[g]),

                .rd_valid(prio_rd_valid[g]),
                .rd_data(prio_rd_data[g]),
                .rd_keep(prio_rd_keep[g]),
                .rd_last(prio_rd_last[g]),
                .rd_id(prio_rd_id[g]),
                .rd_is_bad(prio_rd_is_bad[g]),
                .rd_ready(prio_rd_ready[g]),

                .packet_count(prio_pkt_count[g]),
                .word_count(prio_word_count[g])
            );

            assign occupancy[g] = prio_word_count[g][10:0];
            assign empty[g] = (prio_pkt_count[g] == 0);
            assign almost_full[g] = (prio_word_count[g] > (DEPTH_PER_QOS * 3 / 4));
        end
    endgenerate

    // Write demux based on QoS
    always_comb begin
        for (int i = 0; i < NUM_QOS_LEVELS; i++) begin
            prio_wr_valid[i] = (wr_qos == i[2:0]) ? wr_valid : 1'b0;
        end

        // Ready if target QoS buffer is ready
        wr_ready = prio_wr_ready[wr_qos];
    end

    // Read mux - strict priority scheduling
    logic [1:0] selected_qos;

    always_comb begin
        // Default: no selection
        rd_valid = 1'b0;
        rd_data = '0;
        rd_keep = '0;
        rd_last = 1'b0;
        rd_id = '0;
        rd_is_bad = 1'b0;
        rd_qos = 3'b010;  // Default to low priority
        selected_qos = 2'd2;

        for (int i = 0; i < NUM_QOS_LEVELS; i++) begin
            prio_rd_ready[i] = 1'b0;
        end

        // Strict priority: 0 > 1 > 2
        if (prio_rd_valid[0]) begin
            selected_qos = 2'd0;
            rd_valid = 1'b1;
            rd_data = prio_rd_data[0];
            rd_keep = prio_rd_keep[0];
            rd_last = prio_rd_last[0];
            rd_id = prio_rd_id[0];
            rd_is_bad = prio_rd_is_bad[0];
            rd_qos = 3'b000;
            prio_rd_ready[0] = rd_ready;
        end else if (prio_rd_valid[1]) begin
            selected_qos = 2'd1;
            rd_valid = 1'b1;
            rd_data = prio_rd_data[1];
            rd_keep = prio_rd_keep[1];
            rd_last = prio_rd_last[1];
            rd_id = prio_rd_id[1];
            rd_is_bad = prio_rd_is_bad[1];
            rd_qos = 3'b001;
            prio_rd_ready[1] = rd_ready;
        end else if (prio_rd_valid[2]) begin
            selected_qos = 2'd2;
            rd_valid = 1'b1;
            rd_data = prio_rd_data[2];
            rd_keep = prio_rd_keep[2];
            rd_last = prio_rd_last[2];
            rd_id = prio_rd_id[2];
            rd_is_bad = prio_rd_is_bad[2];
            rd_qos = 3'b010;
            prio_rd_ready[2] = rd_ready;
        end
    end

endmodule

`default_nettype wire