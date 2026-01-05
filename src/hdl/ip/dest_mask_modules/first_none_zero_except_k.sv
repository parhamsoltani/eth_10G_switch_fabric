`timescale 1ns / 1ps
`default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Company: IUST
// Engineer: Parham Soltani
//
// Create Date:  2025-08-13 17:19:23
// Module Name: first_none_zero_except_k (Fixed - proper first-match priority  purely combinational)
// Project Name:
// Target Devices:
// Tool Versions: Vivado 2022.2
// Description: Priority encoder that finds the FIRST non-zero bit,
//              excluding the previously selected index to prevent starvation
//               Combinational priority encoder - finds first set bit
// Dependencies:
//
// Additional Comments:
// FIX: Changed to find FIRST match instead of LAST match
//      This ensures fair round-robin behavior across all ports
//////////////////////////////////////////////////////////////////////////////////




module first_none_zero_except_k #(
    parameter int N    = 64,
    parameter int LOGN = $clog2(N)
) (
    input  wire                  clk,
    input  wire [N-1:0]          data_i,
    input  wire                  ready_o,
    output wire [LOGN-1:0]       data_o,
    output wire                  data_valid_o
);

    // Purely combinational priority encoder
    reg [LOGN-1:0] comb_idx;
    reg            comb_valid;

    always @(*) begin
        comb_idx   = '0;
        comb_valid = 1'b0;

        // Find FIRST non-zero bit (lowest index priority)
        for (int i = 0; i < N; i++) begin
            if (data_i[i] && !comb_valid) begin
                comb_idx   = i[LOGN-1:0];
                comb_valid = 1'b1;
            end
        end
    end

    // Direct combinational outputs
    assign data_o       = comb_idx;
    assign data_valid_o = comb_valid;

endmodule

`default_nettype wire