`timescale 1ns / 1ps
`default_nettype none

`include "fabric_params.vh"

module fabric_crosspoint #(
    parameter NUM_PORTS     = `NUM_PORTS,
    parameter DATA_WIDTH    = `DATA_WIDTH,
    parameter ID_WIDTH      = `PACKET_ID_WIDTH
)(
    input  logic clk,
    input  logic rst_n,

    // From VOQs (NUM_PORTS sources × NUM_PORTS destinations)
    input  logic                    voq_rd_valid [NUM_PORTS][NUM_PORTS],
    input  logic [DATA_WIDTH-1:0]   voq_rd_data [NUM_PORTS][NUM_PORTS],
    input  logic [DATA_WIDTH/8-1:0] voq_rd_keep [NUM_PORTS][NUM_PORTS],
    input  logic                    voq_rd_last [NUM_PORTS][NUM_PORTS],
    input  logic [ID_WIDTH-1:0]     voq_rd_id [NUM_PORTS][NUM_PORTS],
    input  logic                    voq_rd_is_bad [NUM_PORTS][NUM_PORTS],
    input  logic [2:0]              voq_rd_qos [NUM_PORTS][NUM_PORTS],
    output logic                    voq_rd_ready [NUM_PORTS][NUM_PORTS],

    // To XPQs
    output logic                    xpq_wr_valid [NUM_PORTS][NUM_PORTS],
    output logic [DATA_WIDTH-1:0]   xpq_wr_data [NUM_PORTS][NUM_PORTS],
    output logic [DATA_WIDTH/8-1:0] xpq_wr_keep [NUM_PORTS][NUM_PORTS],
    output logic                    xpq_wr_last [NUM_PORTS][NUM_PORTS],
    output logic [ID_WIDTH-1:0]     xpq_wr_id [NUM_PORTS][NUM_PORTS],
    output logic                    xpq_wr_is_bad [NUM_PORTS][NUM_PORTS],
    output logic [2:0]              xpq_wr_qos [NUM_PORTS][NUM_PORTS],
    input  logic                    xpq_wr_ready [NUM_PORTS][NUM_PORTS]
);

    // Arbiters: one per destination port
    logic [NUM_PORTS-1:0]           arb_request [NUM_PORTS];
    logic [2:0]                     arb_request_qos [NUM_PORTS][NUM_PORTS];
    logic [NUM_PORTS-1:0]           arb_grant [NUM_PORTS];
    logic [$clog2(NUM_PORTS)-1:0]   arb_grant_id [NUM_PORTS];
    logic                           arb_grant_valid [NUM_PORTS];

    genvar dst, src;
    generate
        // One arbiter per destination
        for (dst = 0; dst < NUM_PORTS; dst++) begin : gen_dst_arbiter

            // Collect requests for this destination
            always_comb begin
                for (int s = 0; s < NUM_PORTS; s++) begin
                    arb_request[dst][s] = voq_rd_valid[s][dst] && xpq_wr_ready[s][dst];
                    arb_request_qos[dst][s] = voq_rd_qos[s][dst];
                end
            end

            crosspoint_arbiter #(
                .NUM_SOURCES(NUM_PORTS)
            ) dst_arbiter (
                .clk(clk),
                .rst_n(rst_n),
                .request(arb_request[dst]),
                .request_qos(arb_request_qos[dst]),
                .grant(arb_grant[dst]),
                .grant_id(arb_grant_id[dst]),
                .grant_valid(arb_grant_valid[dst])
            );

            // Connect granted source to XPQ
            always_comb begin
                for (int s = 0; s < NUM_PORTS; s++) begin
                    if (arb_grant[dst][s]) begin
                        xpq_wr_valid[s][dst] = voq_rd_valid[s][dst];
                        xpq_wr_data[s][dst] = voq_rd_data[s][dst];
                        xpq_wr_keep[s][dst] = voq_rd_keep[s][dst];
                        xpq_wr_last[s][dst] = voq_rd_last[s][dst];
                        xpq_wr_id[s][dst] = voq_rd_id[s][dst];
                        xpq_wr_is_bad[s][dst] = voq_rd_is_bad[s][dst];
                        xpq_wr_qos[s][dst] = voq_rd_qos[s][dst];
                        voq_rd_ready[s][dst] = xpq_wr_ready[s][dst];
                    end else begin
                        xpq_wr_valid[s][dst] = 1'b0;
                        xpq_wr_data[s][dst] = '0;
                        xpq_wr_keep[s][dst] = '0;
                        xpq_wr_last[s][dst] = 1'b0;
                        xpq_wr_id[s][dst] = '0;
                        xpq_wr_is_bad[s][dst] = 1'b0;
                        xpq_wr_qos[s][dst] = 3'b010;
                        voq_rd_ready[s][dst] = 1'b0;
                    end
                end
            end

        end
    endgenerate

endmodule

`default_nettype wire