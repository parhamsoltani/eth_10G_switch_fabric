`timescale 1ns / 1ps
`default_nettype none

`include "fabric_params.vh"

module egress_arbiter #(
    parameter NUM_SOURCES = `NUM_PORTS
)(
    input  logic clk,
    input  logic rst_n,

    // XPQ status (per source)
    input  logic [NUM_SOURCES-1:0]  xpq_valid,
    input  logic [2:0]              xpq_qos [NUM_SOURCES],

    // Output selection
    output logic [$clog2(NUM_SOURCES)-1:0] selected_xpq,
    output logic                           select_valid,

    // Atomic packet transmission
    input  logic                           packet_complete
);

    typedef enum logic [1:0] {
        IDLE,
        TRANSMITTING
    } state_t;

    state_t state;
    logic [$clog2(NUM_SOURCES)-1:0] current_source;

    // Use crosspoint arbiter for selection
    logic [NUM_SOURCES-1:0] arb_grant;
    logic [$clog2(NUM_SOURCES)-1:0] arb_grant_id;
    logic arb_grant_valid;

    crosspoint_arbiter #(
        .NUM_SOURCES(NUM_SOURCES)
    ) arb (
        .clk(clk),
        .rst_n(rst_n),
        .request(xpq_valid),
        .request_qos(xpq_qos),
        .grant(arb_grant),
        .grant_id(arb_grant_id),
        .grant_valid(arb_grant_valid)
    );

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            select_valid <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (arb_grant_valid) begin
                        current_source <= arb_grant_id;
                        selected_xpq <= arb_grant_id;
                        select_valid <= 1'b1;
                        state <= TRANSMITTING;
                    end else begin
                        select_valid <= 1'b0;
                    end
                end

                TRANSMITTING: begin
                    selected_xpq <= current_source;  // Hold selection
                    select_valid <= 1'b1;

                    if (packet_complete) begin
                        state <= IDLE;
                        select_valid <= 1'b0;
                    end
                end
            endcase
        end
    end

endmodule

`default_nettype wire