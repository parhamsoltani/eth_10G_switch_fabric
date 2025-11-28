`timescale 1ns / 1ps
`default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Company: IUST
// Engineer: Parham Soltani
// 
// Create Date:  2025-08-08 12:26:30
// Module Name: multicast_mask_to_index
// Project Name: 
// Target Devices: 
// Tool Versions: Vivado 2022.2
// Description: 
// Dependencies: 
// 
// Additional Comments: 

//////////////////////////////////////////////////////////////////////////////////



module multicast_mask_to_index #(
    parameter N                 = 10,
    parameter DATA_WIDTH        = 2,
    parameter MASK_FIFO_DEPTH   = 32,
    // DO NOT CHANGE BELOW
	parameter	LOGN	= $clog2(N)
) (
    input  wire                         clk,
    input  wire                         push_i,
    input  wire	[N-1:0] 			    mask_i,
    input  wire	[DATA_WIDTH-1:0] 		data_i,
    output wire                         push_o,
    output wire	[LOGN-1:0] 			    index_o,
    output wire	[DATA_WIDTH-1:0] 		data_o,
    output wire                         prog_full_o
);

    //==============================================================================
    // local parameters and integers
    //==============================================================================
    localparam FIFO_WIDTH = N + DATA_WIDTH;
    localparam PROG_FULL_THRESH = 10;

    //==============================================================================
    // wires, regs and memories
    //==============================================================================

    // FIFO signals
    wire                        fifo_push_i;
    wire [FIFO_WIDTH-1:0]       fifo_push_data_i;
    wire                        fifo_pop_i;
    wire [FIFO_WIDTH-1:0]       fifo_pop_data_o;
    wire                        fifo_prog_full_o;
    wire                        fifo_empty_o;


    wire [LOGN:0]               num_non_zero_mask;

    wire [LOGN-1:0]             first_non_zero_mask;

    wire none_empty_fifo = !fifo_empty_o;

    wire [N-1:0]                fifo_mask_out = fifo_pop_data_o[FIFO_WIDTH-1 : DATA_WIDTH];
    reg [N-1:0]                 fifo_mask_out_reg = 0;   

    wire [DATA_WIDTH-1:0]       fifo_data_out = fifo_pop_data_o[DATA_WIDTH-1:0];
    reg	[DATA_WIDTH-1:0] 		fifo_data_out_reg = 0;






    reg	 			            valid_multicast_reg = 0;
    reg	[LOGN-1:0] 			    index_reg = 0;
    reg                         push_o_reg = 0;
    reg [DATA_WIDTH-1:0]        data_o_reg = 0;




   


    //==============================================================================
    // Assignments for wiring
    //==============================================================================
    assign fifo_push_i = push_i;
    assign fifo_push_data_i = {mask_i, data_i};
    assign fifo_pop_i = none_empty_fifo && (((num_non_zero_mask <= 1) && valid_multicast_reg) || (!valid_multicast_reg));





    assign push_o       = push_o_reg;
    assign index_o      = index_reg;
    assign data_o       = data_o_reg;
    assign prog_full_o  = fifo_prog_full_o;


    always @(posedge clk) begin
        if (fifo_pop_i) begin
            fifo_mask_out_reg <= fifo_mask_out;
            fifo_data_out_reg <= fifo_data_out; 
        end else begin
            fifo_mask_out_reg[first_non_zero_mask] <= 0;
        end
    end


    always @(posedge clk) begin
        index_reg <= first_non_zero_mask;
        data_o_reg <= fifo_data_out_reg;
    end

     always @(posedge clk) begin

        valid_multicast_reg <= 0;
        push_o_reg <= 0;

        if (!valid_multicast_reg && none_empty_fifo) begin
            valid_multicast_reg <= 1;
            push_o_reg <= 0;
        end else if (valid_multicast_reg && num_non_zero_mask > 1) begin
            valid_multicast_reg <= 1;
            push_o_reg <= 1;
        end else if (valid_multicast_reg && num_non_zero_mask == 1) begin
            if (none_empty_fifo) begin
                valid_multicast_reg <= 1;
                push_o_reg <= 1;
            end else begin
                valid_multicast_reg <= 0;
                push_o_reg <= 1;
            end
        end else if (valid_multicast_reg && num_non_zero_mask == 0) begin
            if (none_empty_fifo) begin
                valid_multicast_reg <= 1;
                push_o_reg <= 0;
            end else begin
                valid_multicast_reg <= 0;
                push_o_reg <= 0;
            end
        end
		
    end



    always @( * ) begin


        
        

	end

 
    //==============================================================================
    // Instantiated Modules
    //==============================================================================

    simple_fifo #(
        .DATA_WIDTH        (FIFO_WIDTH),
        .FIFO_DEPTH        (MASK_FIFO_DEPTH),
        .XPM_READ_LATENCY  (0),
        .PROG_FULL_THRESH    (PROG_FULL_THRESH)
    ) u_fifo (
        .clk_i             (clk),
        .reset_i           ('0),
        .push_i            (fifo_push_i),
        .push_data_i       (fifo_push_data_i),
        .pop_i             (fifo_pop_i),
        .pop_data_o        (fifo_pop_data_o),
        .full_o            (),
        .prog_full_o       (fifo_prog_full_o),
        .empty_o           (fifo_empty_o)
    );


    


    num_non_zero_no_delay #(
        .N      (N)
    ) u_num_non_zero (
        .data_i (fifo_mask_out_reg),
        .data_o (num_non_zero_mask)
    );

    

    first_non_zero_no_delay #(
        .N      (N)
    ) u_first_non_zero (
        .data_i (fifo_mask_out_reg),
        .data_o (first_non_zero_mask)
    );



endmodule


`default_nettype wire 