`timescale 1ns / 1ps
// `default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Company: IUST
// Engineer: Parham Soltani
//
// Create Date:  2025-08-03 10:32:42
// Module Name: pipeline_mem_with_inout_barrel
// Project Name:
// Target Devices:
// Tool Versions: Vivado 2022.2
// Description:
// Dependencies:
//
// Additional Comments:

//////////////////////////////////////////////////////////////////////////////////

module pipeline_mem_with_inout_barrel
#(
	// User Configurable Parameters
	parameter	WIDTH		        = 136,
    parameter   DEPTH               = 8,
    parameter   NUM_MEM             = 8,
    parameter	XPM_READ_LATENCY    = 1,
	// DO NOT change following parameters
	parameter	DEPTH_LOG		    = $clog2(DEPTH),
	parameter   NUM_MEM_LOG = $clog2(NUM_MEM)
)
(
	input	wire						clk,

    input   wire    [NUM_MEM_LOG-1:0]   wr_sel_i,
	input	wire						wr_en_i [NUM_MEM],
	input	wire	[DEPTH_LOG-1:0]	    wr_addr_i[NUM_MEM],
	input	wire	[WIDTH-1:0]	        wr_data_i [NUM_MEM],

    input   wire    [NUM_MEM_LOG-1:0]   rd_sel_i,
	input	wire						rd_en_i,
	input	wire	[DEPTH_LOG-1:0]	    rd_addr_i,
	output	wire	[WIDTH-1:0]	        rd_data_o [NUM_MEM]
);


    //=========================
    // Wire Declarations
    //=========================

    // -- barrel_wr_en wires
    wire barrel_wr_en_data_out [NUM_MEM];


    // -- barrel_wr_data wires
    wire [WIDTH-1:0] barrel_wr_data_data_out [NUM_MEM];

    // -- barrel_rd_data wires
    wire [WIDTH-1:0] barrel_rd_data_data_in [NUM_MEM];
    wire [WIDTH-1:0] barrel_rd_data_data_out [NUM_MEM];

    // -- raw_mem wires
    wire                         raw_mem_wr_en_i [NUM_MEM];
    reg  [DEPTH_LOG-1:0]         raw_mem_wr_addr_i;
    wire [WIDTH-1:0]             raw_mem_wr_data_i [NUM_MEM];
    wire                         raw_mem_rd_en_i;
    wire [DEPTH_LOG-1:0]         raw_mem_rd_addr_i;
    wire [WIDTH-1:0]             raw_mem_rd_data_o [NUM_MEM];


    //=========================
    // Assign Connections
    //=========================



    assign raw_mem_rd_en_i   = rd_en_i;
    assign raw_mem_rd_addr_i = rd_addr_i;

    assign raw_mem_wr_en_i      = barrel_wr_en_data_out;
    assign raw_mem_wr_data_i      = barrel_wr_data_data_out;

    assign barrel_rd_data_data_in = raw_mem_rd_data_o;
    assign rd_data_o              = barrel_rd_data_data_out;


    //=========================
    // Reg Logic
    //=========================

    always @(posedge clk) begin
        raw_mem_wr_addr_i <= wr_addr_i[wr_sel_i];
    end



    //=========================
    // Module Instances
    //=========================

    // 1. barrel_shifter for wr_en_i
    barrel_shifter #(
        .WIDTH(1),
        .NUM_PORT(NUM_MEM)
    ) barrel_wr_en (
        .clk        (clk),
        .data_in    (wr_en_i),
        .shift_val  (wr_sel_i),
        .data_out   (barrel_wr_en_data_out)
    );

    // 2. barrel_shifter for wr_data_i
    barrel_shifter #(
        .WIDTH(WIDTH),
        .NUM_PORT(NUM_MEM)
    ) barrel_wr_data (
        .clk        (clk),
        .data_in    (wr_data_i),
        .shift_val  (wr_sel_i),
        .data_out   (barrel_wr_data_data_out)
    );

    // 3. barrel_shifter for rd_data_o
    barrel_shifter #(
        .WIDTH(WIDTH),
        .NUM_PORT(NUM_MEM)
    ) barrel_rd_data (
        .clk        (clk),
        .data_in    (barrel_rd_data_data_in),
        .shift_val  (rd_sel_i),
        .data_out   (barrel_rd_data_data_out)
    );

    // 4. raw_mem instance
    pipeline_mem #(
        .WIDTH(WIDTH),
        .DEPTH(DEPTH),
        .NUM_MEM(NUM_MEM),
        .XPM_READ_LATENCY(XPM_READ_LATENCY)
    ) raw_mem (
        .clk        (clk),
        .wr_en_i    (raw_mem_wr_en_i),
        .wr_addr_i  (raw_mem_wr_addr_i),
        .wr_data_i  (raw_mem_wr_data_i),
        .rd_en_i    (raw_mem_rd_en_i),
        .rd_addr_i  (raw_mem_rd_addr_i),
        .rd_data_o  (raw_mem_rd_data_o)
    );




endmodule


`default_nettype wire