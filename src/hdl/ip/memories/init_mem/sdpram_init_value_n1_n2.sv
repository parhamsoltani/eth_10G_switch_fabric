// ========================================================
// Description   :  
// Start project : 2024-09-15
// Author        : Alireza Abbasian 
// ========================================================





`timescale 1ns / 1ns
`default_nettype none


module sdpram_init_value_n1_n2
#(
	// User Configurable Parameters
	parameter	WIDTH		        = 72,
    parameter   DEPTH               = 512,
    parameter   N1                  = 64,
    parameter   N2                  = 128,
	parameter	MEMORY_PRIMITIVE	= "distributed",			// "auto", "block", "distributed", "ultra"
	parameter	XPM_READ_LATENCY    = 1,		    // 
	// DO NOT change following parameters
	parameter	DEPTH_LOG		    = $clog2(DEPTH)
)
(
	input	wire						clk,

	input	wire						wr_en_i,
	input	wire	[DEPTH_LOG-1:0]	    wr_addr_i,
	input	wire	[WIDTH-1:0]	        wr_data_i,

	input	wire						rd_en_i,
	input	wire	[DEPTH_LOG-1:0]	    rd_addr_i,
	output	wire	[WIDTH-1:0]	        rd_data_o
);
    
    `ifdef SIM
        localparam string INIT_FILE_NAME    = $sformatf("../src/inc/mem_init/mem_init_%0d_%0d.mem", N1, N2);
    `else
        localparam string INIT_FILE_NAME    = $sformatf("mem_init_%0d_%0d.mem", N1, N2);
    `endif

    localparam WRITE_MODE_B      = "READ_FIRST";

    sdpram_init_value #(
        .WIDTH             (WIDTH),
        .DEPTH             (DEPTH),
        .INIT_FILE_NAME    (INIT_FILE_NAME),
        .MEMORY_PRIMITIVE  (MEMORY_PRIMITIVE),
        .WRITE_MODE_B      (WRITE_MODE_B),
        .XPM_READ_LATENCY  (XPM_READ_LATENCY)
    ) mem_inst (
        .clk        (clk),
        .wr_en_i    (wr_en_i),
        .wr_addr_i  (wr_addr_i),
        .wr_data_i  (wr_data_i),
        .rd_en_i    (rd_en_i),
        .rd_addr_i  (rd_addr_i),
        .rd_data_o  (rd_data_o)
    );

    
		

endmodule 


`default_nettype wire 