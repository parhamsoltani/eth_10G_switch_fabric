`timescale 1ns / 1ps
// `default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Company: IUST
// Engineer: Parham Soltani
//
// Create Date:  2025-08-13 17:26:58
// Module Name: wrapper_first_none_zero_except_k
// Project Name:
// Target Devices:
// Tool Versions: Vivado 2022.2
// Description:
// Dependencies:
//
// Additional Comments:

//////////////////////////////////////////////////////////////////////////////////



module wrapper_first_none_zero_except_k #(
    parameter int N    = 120,
    // DO NOT CHANGE BELOW
    parameter int LOGN = $clog2(N)
) (
    input  wire                  clk,
    input  wire [N-1:0]          data_i,
    input  wire                  wr_en,         // update none_zero_reg when 1
    output wire [LOGN-1:0]       data_o,        // current stored index
    output wire                  data_valid_o
);

    // Registered versions of inputs (except clk)
    reg [N-1:0] data_i_reg;
    reg         wr_en_reg;

    // Sample inputs on the rising edge of clk
    always @(posedge clk) begin
        data_i_reg    <= data_i;
        wr_en_reg     <= wr_en;
    end

    // Internal wires for outputs
    wire [LOGN-1:0] data_o_int;
    wire            data_valid_o_int;

    // Instantiate the main module
    first_none_zero_except_k #(
        .N(N),
        .LOGN(LOGN)
    ) u_first_none_zero_except_k (
        .clk          (clk),
        .data_i       (data_i_reg),
        .ready_o      (wr_en_reg),
        .data_o       (data_o_int),
        .data_valid_o (data_valid_o_int)
    );

    // Pass-through outputs
    assign data_o       = data_o_int;
    assign data_valid_o = data_valid_o_int;

endmodule


`default_nettype wire