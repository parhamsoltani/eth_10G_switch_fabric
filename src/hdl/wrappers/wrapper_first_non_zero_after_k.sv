`timescale 1ns / 1ps
// `default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Company: IUST
// Engineer: Parham Soltani
//
// Create Date:  2025-08-13 09:33:44
// Module Name: wrapper_first_non_zero_after_k
// Project Name:
// Target Devices:
// Tool Versions: Vivado 2022.2
// Description:
// Dependencies:
//
// Additional Comments:

//////////////////////////////////////////////////////////////////////////////////



module wrapper_first_non_zero_after_k #(
    parameter N     = 120,
    parameter LOGN  = $clog2(N)
)
(
    input  wire                     clk,
    input  wire [N-1:0]              data_i,
    input  wire [LOGN-1:0]              k,
    output wire [LOGN-1:0]           data_o,
    output wire                      data_valid_o
);

    // Registered versions of inputs (except clk)
    reg [N-1:0]  data_i_reg;
    reg [LOGN-1:0] k_reg;

    // Register inputs on posedge clk
    always @(posedge clk) begin
        data_i_reg <= data_i;
        k_reg      <= k;
    end

    // Internal wires for module outputs
    wire [LOGN-1:0] data_o_int;
    wire            data_valid_o_int;

    // Instantiate main module
    first_non_zero_after_k #(
        .N(N),
        .LOGN(LOGN)
    ) u_first_non_zero_before_k (
        .clk          (clk),
        .data_i       (data_i_reg),
        .k            (k_reg),
        .data_o       (data_o_int),
        .data_valid_o (data_valid_o_int)
    );

    // Pass through outputs
    assign data_o       = data_o_int;
    assign data_valid_o = data_valid_o_int;

endmodule


`default_nettype wire