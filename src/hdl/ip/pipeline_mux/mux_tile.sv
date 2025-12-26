`timescale 1ns / 1ps
// `default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Company: IUST
// Engineer: Parham Soltani
//
// Create Date:  2025-08-09
// Module Name: mux_tile
// Project Name:
// Target Devices:
// Tool Versions: Vivado 2022.2
// Description:
// Dependencies:
//
// Additional Comments:

//////////////////////////////////////////////////////////////////////////////////
module mux_tile #(
  	parameter int K = 4,      // power-of-two maximum ports
  	parameter int W = 1,      // data width
	parameter int SB = $clog2(K)
)(
	input  wire        		clk,
	input  wire [ W-1:0]	in 		[K],
	input  wire [SB-1:0]	sel,
	output reg  [ W-1:0]	out
);

	always @(posedge clk) begin
		out <= in[sel];
	end

endmodule

`default_nettype wire
