`timescale 1ns / 1ps
// `default_nettype none

`include "fabric_params.vh"
`include "qos_defines.vh"

module credit_manager #(
    parameter MAX_CREDITS = `VOQ_DEPTH_PER_QOS,
    parameter CREDIT_WIDTH = `CREDIT_COUNT_WIDTH
)(
    input  logic clk,
    input  logic rst_n,

    // Sender side (tracks receiver credits)
    output logic [CREDIT_WIDTH-1:0] available_credits,
    input  logic consume_credit,        // Packet transmitted

    // Receiver side (credit returns)
    input  logic return_credit,         // Packet consumed from buffer

    // Status
    output logic credits_low,           // Threshold warning
    output logic credits_exhausted
);

    localparam CREDIT_LOW_THRESH = MAX_CREDITS / 4;  // 25% threshold

    logic [CREDIT_WIDTH-1:0] credit_count;

    assign available_credits = credit_count;
    assign credits_low = (credit_count < CREDIT_LOW_THRESH);
    assign credits_exhausted = (credit_count == 0);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            credit_count <= MAX_CREDITS[CREDIT_WIDTH-1:0];
        end else begin
            case ({consume_credit, return_credit})
                2'b01: credit_count <= credit_count + 1'b1;  // Return only
                2'b10: credit_count <= credit_count - 1'b1;  // Consume only
                2'b11: credit_count <= credit_count;         // Both (no change)
                default: credit_count <= credit_count;
            endcase
        end
    end

    // Overflow/underflow protection
    // synthesis translate_off
    always @(posedge clk) begin
        if (rst_n) begin
            assert (consume_credit -> (credit_count > 0)) else
                $error("Credit underflow!");
            assert (return_credit -> (credit_count < MAX_CREDITS)) else
                $error("Credit overflow!");
        end
    end
    // synthesis translate_on

endmodule

`default_nettype wire