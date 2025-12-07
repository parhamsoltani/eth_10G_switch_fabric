`timescale 1ns / 1ps
// `default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Company: IUST
// Engineer: Parham Soltani
//
// Create Date:  2025-08-14 20:04:54
// Module Name: one_hot_none_zero
// Project Name:
// Target Devices:
// Tool Versions: Vivado 2022.2
// Description:
// Dependencies:
//
// Additional Comments:

//////////////////////////////////////////////////////////////////////////////////



module one_hot_none_zero #(
    parameter N     = 64,
    // DO NOT CHANGE BELOW
    parameter LOGN  = N==1 ? 1 : $clog2(N)
)
(
    input  wire                 clk,
    input  wire [N-1:0]         data_i,
    output reg  [N-1:0]         data_o,         // one-hot of selected bit
    output reg                  data_valid_o
);

    reg [N-1:0] comb_out;
    reg         comb_valid;

    always @(*) begin
        comb_out   = {N{1'b0}};
        comb_valid = 1'b0;
        for (int i = 0; i < N; ++i) begin
            if (data_i[i]) begin
                comb_out         = {N{1'b0}};
                comb_out[i]      = 1'b1; // one-hot at index i
                comb_valid       = 1'b1;
            end
        end
    end

    always @(posedge clk) begin
        data_o       <= comb_out;
        data_valid_o <= comb_valid;
    end

endmodule


`default_nettype wire