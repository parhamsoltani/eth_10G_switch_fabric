`timescale 1ns / 1ps
`default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Company: IUST
// Engineer: Parham Soltani
// 
// Create Date:  2025-08-02 16:02:05
// Module Name: cell_to_packet
// Project Name: 
// Target Devices: 
// Tool Versions: Vivado 2022.2
// Description: 
// Dependencies: 
// 
// Additional Comments: 

//////////////////////////////////////////////////////////////////////////////////



module cell_to_packet #(
    parameter   S                       = 10,            // speed up
    parameter   W_MINI                  = 64,            // bus data width (mini cell data width)

    // DO NOT CHANGE
    parameter   KEEP_WIDTH              = $clog2((W_MINI/8) + 1),
    parameter   S_LOG                   = $clog2(S),
    parameter   META_DATA_WIDTH         = S + KEEP_WIDTH + 1 + S_LOG // minicells_keep, last_minicell_keep, is_bad_frame
) (
    input   wire                                clk,
    input   wire                                start_of_cell_i,
    input   wire [W_MINI-1:0]                   data_i,  // has 1 clk delay related to start_of_cell_i
    input   wire [META_DATA_WIDTH-1:0]          metadata_i, // 0 delay
    input   wire                                last_cell_i,// 0 delay


    output  wire [W_MINI-1:0]                   data_tx ,
    output  wire [KEEP_WIDTH-1:0]               keep_tx ,
    output  wire                                valid_tx ,
    output  wire                                is_bad_frame_tx ,
    output  wire                                last_tx
);

    //==============================================================================
    // local parameters and integers
    //==============================================================================

    //==============================================================================
    // wires, regs and memories
    //==============================================================================

    // outputs
    reg  [KEEP_WIDTH-1:0]   keep_reg_o = 0;
    reg                     valid_reg_o = 0;
    reg                     is_bad_frame_reg_o = 0;
    reg                     last_reg_o = 0;

    // reg inputs
    reg                     last_cell_reg;
    reg [S-1:0]             keep_minicell_reg;
    reg [KEEP_WIDTH-1:0]    keep_last_reg; 
    reg                     is_bad_frame_reg;
    reg [S_LOG-1:0]         last_minicell_index_reg = '0;   

    // temp aux variables

    reg [S_LOG:0]           cell_valid_counter = S;

    wire is_minicell_valid =  keep_minicell_reg[cell_valid_counter[S_LOG-1:0]];

    assign data_tx = data_i;
    assign keep_tx          = keep_reg_o;
    assign valid_tx         = valid_reg_o;
    assign is_bad_frame_tx  = is_bad_frame_reg_o ;       
    assign last_tx          = last_reg_o;


    //==============================================================================
    // Main Controls
    //==============================================================================

    always @(posedge clk) begin
        if (start_of_cell_i) begin
            cell_valid_counter <= 0;
        end else if (cell_valid_counter < S) begin
            cell_valid_counter <= cell_valid_counter + 1;
        end
    end

    always @(posedge clk) begin
        if (start_of_cell_i) begin
            last_cell_reg   <= last_cell_i;
            {keep_minicell_reg, keep_last_reg, is_bad_frame_reg, last_minicell_index_reg} <= metadata_i;
        end
    end

    always @(posedge clk) begin
        if (cell_valid_counter < S && is_minicell_valid) begin
            valid_reg_o <= 1;
            if (last_minicell_index_reg == cell_valid_counter) begin
                last_reg_o <= last_cell_reg;
                is_bad_frame_reg_o <= is_bad_frame_reg;
                keep_reg_o <= keep_last_reg;
            end else begin
                last_reg_o <= 0;
                is_bad_frame_reg_o <= 0;
                keep_reg_o <= W_MINI/8;
            end
        end else begin  
            keep_reg_o <= 0;
            valid_reg_o <= 0;
            is_bad_frame_reg_o <= 0;
            last_reg_o <= 0;
        end
    end




    //==============================================================================
    // Instantiated Modules
    //==============================================================================

    //==============================================================================
    // Functions
    //==============================================================================

endmodule

`default_nettype wire 