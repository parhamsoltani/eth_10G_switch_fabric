`timescale 1ns / 1ps
`default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Company: IUST
// Engineer: Parham Soltani
// 
// Create Date:  2025-08-13 09:27:26
// Module Name: first_non_zero_after_k
// Project Name: 
// Target Devices: 
// Tool Versions: Vivado 2022.2
// Description: 
// Dependencies: 
// 
// Additional Comments: 

//////////////////////////////////////////////////////////////////////////////////



module first_non_zero_after_k #(
    parameter N     = 64,
    // DO NOT CHANGE BELOW
    parameter LOGN  = $clog2(N)
)
(
    input  wire                     clk,
    input  wire [N-1:0]              data_i,
    input  wire [LOGN-1:0]             k,
    output reg  [LOGN-1:0]           data_o,
    output reg                       data_valid_o
);

    reg [LOGN-1:0] comb_out;
    reg comb_valid;

    always @(*) begin
        comb_out   = 0;
        comb_valid = 0;
        for (int i = N-1; i >= 0; i--) begin
            if ((i < k) && (data_i[i] == 1)) begin
                comb_out   = i;
                comb_valid = 1;
            end
        end
        for (int i = N-1; i >= 0; i--) begin
            if ((i > k) && (data_i[i] == 1)) begin
                comb_out   = i;
                comb_valid = 1;
            end
        end
    end

    always @(posedge clk) begin
        data_o       <= comb_out;
        data_valid_o <= comb_valid;
    end

endmodule


`default_nettype wire 