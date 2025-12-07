`timescale 1ns / 1ps
// `default_nettype none

`include "fabric_params.vh"

module fabric_egress #(
    parameter NUM_PORTS     = `NUM_PORTS,
    parameter DATA_WIDTH    = `DATA_WIDTH,
    parameter ID_WIDTH      = `PACKET_ID_WIDTH
)(
    input  logic clk,
    input  logic rst_n,

    // From XPQs (NUM_PORTS sources per destination)
    input  logic                    xpq_rd_valid [NUM_PORTS][NUM_PORTS],
    input  logic [DATA_WIDTH-1:0]   xpq_rd_data [NUM_PORTS][NUM_PORTS],
    input  logic [DATA_WIDTH/8-1:0] xpq_rd_keep [NUM_PORTS][NUM_PORTS],
    input  logic                    xpq_rd_last [NUM_PORTS][NUM_PORTS],
    input  logic [ID_WIDTH-1:0]     xpq_rd_id [NUM_PORTS][NUM_PORTS],
    input  logic                    xpq_rd_is_bad [NUM_PORTS][NUM_PORTS],
    input  logic [2:0]              xpq_rd_qos [NUM_PORTS][NUM_PORTS],
    output logic                    xpq_rd_ready [NUM_PORTS][NUM_PORTS],

    // To line modules
    switch_data_if.master           tx_data_if [NUM_PORTS],

    // ID release interface
    output logic [NUM_PORTS-1:0]    id_release_req,
    output logic [ID_WIDTH-1:0]     release_id [NUM_PORTS]
);

    // Egress arbiter per destination port
    logic [NUM_PORTS-1:0]           arb_request [NUM_PORTS];
    logic [2:0]                     arb_request_qos [NUM_PORTS][NUM_PORTS];
    logic [NUM_PORTS-1:0]           arb_grant [NUM_PORTS];
    logic [$clog2(NUM_PORTS)-1:0]   arb_grant_id [NUM_PORTS];
    logic                           arb_grant_valid [NUM_PORTS];

    // Transmission state
    typedef enum logic [1:0] {
        TX_IDLE,
        TX_PACKET,
        TX_RELEASE
    } tx_state_t;

    tx_state_t tx_state [NUM_PORTS];
    logic [$clog2(NUM_PORTS)-1:0] tx_source [NUM_PORTS];

    genvar dst;
    generate
        for (dst = 0; dst < NUM_PORTS; dst++) begin : gen_egress_port

            // Collect requests for this destination
            always_comb begin
                for (int s = 0; s < NUM_PORTS; s++) begin
                    arb_request[dst][s] = xpq_rd_valid[s][dst];
                    arb_request_qos[dst][s] = xpq_rd_qos[s][dst];
                end
            end

            // Arbiter for this destination
            crosspoint_arbiter #(
                .NUM_SOURCES(NUM_PORTS)
            ) egress_arbiter (
                .clk(clk),
                .rst_n(rst_n),
                .request(arb_request[dst]),
                .request_qos(arb_request_qos[dst]),
                .grant(arb_grant[dst]),
                .grant_id(arb_grant_id[dst]),
                .grant_valid(arb_grant_valid[dst])
            );

            // Egress FSM
            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    tx_state[dst] <= TX_IDLE;
                    tx_data_if[dst].valid <= 1'b0;
                    id_release_req[dst] <= 1'b0;
                end else begin
                    case (tx_state[dst])
                        TX_IDLE: begin
                            id_release_req[dst] <= 1'b0;

                            if (arb_grant_valid[dst]) begin
                                tx_source[dst] <= arb_grant_id[dst];
                                tx_state[dst] <= TX_PACKET;
                            end
                        end

                        TX_PACKET: begin
                            automatic int src = tx_source[dst];

                            tx_data_if[dst].data <= xpq_rd_data[src][dst];
                            tx_data_if[dst].keep <= xpq_rd_keep[src][dst];
                            tx_data_if[dst].last <= xpq_rd_last[src][dst];
                            tx_data_if[dst].id <= xpq_rd_id[src][dst];
                            tx_data_if[dst].is_bad_frame <= xpq_rd_is_bad[src][dst];
                            tx_data_if[dst].qos_tag <= xpq_rd_qos[src][dst];
                            tx_data_if[dst].valid <= xpq_rd_valid[src][dst];

                            for (int s = 0; s < NUM_PORTS; s++) begin
                                xpq_rd_ready[s][dst] = (s == src) ? tx_data_if[dst].ready : 1'b0;
                            end

                            if (tx_data_if[dst].valid && tx_data_if[dst].ready && tx_data_if[dst].last) begin
                                release_id[dst] <= xpq_rd_id[src][dst];
                                tx_state[dst] <= TX_RELEASE;
                            end
                        end

                        TX_RELEASE: begin
                            tx_data_if[dst].valid <= 1'b0;
                            id_release_req[dst] <= 1'b1;
                            tx_state[dst] <= TX_IDLE;
                        end
                    endcase
                end
            end

        end
    endgenerate

endmodule

`default_nettype wire