`timescale 1ns / 1ps
`default_nettype none

`include "fabric_params.vh"

module voq_arbiter #(
    parameter NUM_QOS_LEVELS = `QOS_LEVELS
)(
    input  logic clk,
    input  logic rst_n,

    // Queue status (one bit per QoS level)
    input  logic [NUM_QOS_LEVELS-1:0] queue_not_empty,

    // Grant (one-hot on QoS levels)
    output logic [NUM_QOS_LEVELS-1:0] grant,
    output logic grant_valid
);

    // Strict priority with deficit counter for fairness
    logic [15:0] deficit [NUM_QOS_LEVELS];

    localparam QUANTUM_P0 = 500;  // 50%
    localparam QUANTUM_P1 = 300;  // 30%
    localparam QUANTUM_P2 = 200;  // 20%

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            deficit[0] <= QUANTUM_P0;
            deficit[1] <= QUANTUM_P1;
            deficit[2] <= QUANTUM_P2;
            grant <= '0;
            grant_valid <= 1'b0;
        end else begin
            grant <= '0;
            grant_valid <= 1'b0;

            // Select highest priority with positive deficit
            if (queue_not_empty[0] && deficit[0] > 0) begin
                grant[0] <= 1'b1;
                grant_valid <= 1'b1;
                deficit[0] <= deficit[0] - 1;
            end else if (queue_not_empty[1] && deficit[1] > 0) begin
                grant[1] <= 1'b1;
                grant_valid <= 1'b1;
                deficit[1] <= deficit[1] - 1;
            end else if (queue_not_empty[2] && deficit[2] > 0) begin
                grant[2] <= 1'b1;
                grant_valid <= 1'b1;
                deficit[2] <= deficit[2] - 1;
            end else begin
                // Replenish deficits
                deficit[0] <= QUANTUM_P0;
                deficit[1] <= QUANTUM_P1;
                deficit[2] <= QUANTUM_P2;
            end
        end
    end

endmodule

`default_nettype wire