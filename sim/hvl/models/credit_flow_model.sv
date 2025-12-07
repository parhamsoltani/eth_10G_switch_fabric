`timescale 1ns/1ps
// `default_nettype none

module credit_flow_model #(
    parameter MAX_CREDITS = 1024,
    parameter CREDIT_WIDTH = 11
)(
    input  logic clk,
    input  logic rst_n,

    input  logic consume,
    input  logic return_credit,

    output logic [CREDIT_WIDTH-1:0] credits,
    output logic credits_exhausted
);

    logic [CREDIT_WIDTH-1:0] credit_count;

    assign credits = credit_count;
    assign credits_exhausted = (credit_count == 0);

    initial begin
        credit_count = MAX_CREDITS[CREDIT_WIDTH-1:0];
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            credit_count <= MAX_CREDITS[CREDIT_WIDTH-1:0];
        end else begin
            case ({consume, return_credit})
                2'b01: credit_count <= credit_count + 1;
                2'b10: credit_count <= credit_count - 1;
                2'b11: credit_count <= credit_count;
                default: credit_count <= credit_count;
            endcase
        end
    end

    // Verification assertions
    always @(posedge clk) begin
        if (rst_n) begin
            if (consume && credit_count == 0)
                $warning("Credit underflow at time %0t", $time);
            if (return_credit && credit_count >= MAX_CREDITS)
                $warning("Credit overflow at time %0t", $time);
        end
    end

endmodule

`default_nettype wire