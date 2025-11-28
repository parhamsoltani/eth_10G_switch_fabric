`timescale 1ns / 1ps
`default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Company: IUST
// Engineer: Parham Soltani
// 
// Create Date:  2025-07-31 23:39:11
// Module Name: first_non_zero_no_delay
// Project Name: 
// Target Devices: 
// Tool Versions: Vivado 2022.2
// Description: 
// Dependencies: 
// 
// Additional Comments: 

//////////////////////////////////////////////////////////////////////////////////



module first_non_zero_no_delay #(
    parameter	N		= 64,
    // DO NOT CHANGE BELOW
	parameter	LOGN	= $clog2(N)
)
(
	input	wire	[N-1:0] 			data_i,
	output	wire 	[LOGN-1:0]			data_o
);
	
	reg [LOGN-1:0] comb_out;

	always @( * ) begin
		comb_out = 0;
		for (int i=0; i<N; ++i) begin
			if (data_i[i] == 1) begin
				comb_out = i;
			end
		end
	end

	assign data_o = comb_out;


	

endmodule

`default_nettype wire 