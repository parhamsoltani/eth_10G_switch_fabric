// ========================================================
// Description   :
// Start project : 2024-09-15
// Author        : Parham Soltani
// ========================================================





`timescale 1ns / 1ns
// `default_nettype none


module sdpram_init_value
#(
	// User Configurable Parameters
	parameter	WIDTH		        = 71,
    parameter   DEPTH               = 32,
    parameter   INIT_FILE_NAME      = "none",
	parameter	MEMORY_PRIMITIVE	= "distributed",			// "auto", "block", "distributed", "ultra"
	parameter	WRITE_MODE_B        = "READ_FIRST",		        // WRITE_FIRST | READ_FIRST | NO_CHANGE
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
    localparam	int MEMORY_SIZE	= WIDTH*DEPTH;
    localparam  int CASCADE_HEIGHT = MEMORY_PRIMITIVE == "ultra" ? DEPTH/4000: 0;




    xpm_memory_sdpram #(
        // Common module parameters
        .ADDR_WIDTH_A		(DEPTH_LOG),
        .ADDR_WIDTH_B		(DEPTH_LOG),
        .AUTO_SLEEP_TIME	(0),
        .BYTE_WRITE_WIDTH_A	(WIDTH),		//integer; 8, 9, or WRITE_DATA_WIDTH_A value
        .CASCADE_HEIGHT(CASCADE_HEIGHT),                  // if uram
        .CLOCKING_MODE		("common_clock"),
        .ECC_MODE			("no_ecc"),
        .MEMORY_INIT_FILE	(INIT_FILE_NAME),
        .MEMORY_INIT_PARAM	(""),
        .MEMORY_OPTIMIZATION("true"),
        .MEMORY_PRIMITIVE	(MEMORY_PRIMITIVE),
        .MEMORY_SIZE		(MEMORY_SIZE),
        .MESSAGE_CONTROL	(0),
        .READ_DATA_WIDTH_B	(WIDTH),
        .READ_LATENCY_B		(XPM_READ_LATENCY),
        .READ_RESET_VALUE_B	("0"),
        .USE_EMBEDDED_CONSTRAINT(0),
        .USE_MEM_INIT		(1),
        .WAKEUP_TIME		("disable_sleep"),
        .WRITE_DATA_WIDTH_A	(WIDTH),
        .WRITE_MODE_B		(WRITE_MODE_B)
    )
    xpm_mem
    (
        .sleep			(1'b0),
        .clka			(clk),
        .ena			(1'b1),
        .wea			(wr_en_i),
        .addra			(wr_addr_i),
        .dina			(wr_data_i),
        .injectsbiterra	(1'b0),
        .injectdbiterra	(1'b0),

        // Port B module ports
        .clkb			(clk),
        .rstb			(1'b0),
        .enb			(rd_en_i),		// rd_en for READ_LATENCY_B == 1
        .regceb			(1'b1),
        .addrb			(rd_addr_i),
        .doutb			(rd_data_o),
        .sbiterrb		(),
        .dbiterrb		()
    );



endmodule



`default_nettype wire