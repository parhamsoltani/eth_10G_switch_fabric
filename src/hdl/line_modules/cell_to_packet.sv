`timescale 1ns / 1ps
// `default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Company: IUST
// Engineer: Parham Soltani
//
// Create Date:  2025-08-02 16:02:05
// Module Name: cell_to_packet
// Description: Converts cells back to packets with packet ID preservation
//
// MODIFIED: Added PACKET_ID_WIDTH parameter and packet_id output
//////////////////////////////////////////////////////////////////////////////////

module cell_to_packet #(
    parameter   S                       = 10,            // speed up
    parameter   W_MINI                  = 64,            // bus data width (mini cell data width)
    parameter   PACKET_ID_WIDTH         = 8,             // NEW: Packet ID width

    // DO NOT CHANGE
    parameter   KEEP_WIDTH              = $clog2((W_MINI/8) + 1),
    parameter   S_LOG                   = $clog2(S),
    // MODIFIED: Added PACKET_ID_WIDTH to metadata
    parameter   META_DATA_WIDTH         = S + KEEP_WIDTH + 1 + S_LOG + PACKET_ID_WIDTH
) (
    input   wire                                clk,
    input   wire                                start_of_cell_i,
    input   wire [W_MINI-1:0]                   data_i,  // has 1 clk delay related to start_of_cell_i
    input   wire [META_DATA_WIDTH-1:0]          metadata_i, // 0 delay
    input   wire                                last_cell_i,// 0 delay

    output  wire [W_MINI-1:0]                   data_tx,
    output  wire [KEEP_WIDTH-1:0]               keep_tx,
    output  wire                                valid_tx,
    output  wire                                is_bad_frame_tx,
    output  wire                                last_tx,
    output  wire [PACKET_ID_WIDTH-1:0]          packet_id_tx    // NEW: Packet ID output
);

    //==============================================================================
    // local parameters and integers
    //==============================================================================
    // Metadata bit positions (from MSB to LSB):
    // [packet_id | keep_minicell | keep_last | is_bad_frame | last_minicell_index]
    localparam PKT_ID_MSB = META_DATA_WIDTH - 1;
    localparam PKT_ID_LSB = META_DATA_WIDTH - PACKET_ID_WIDTH;
    localparam KEEP_MINI_MSB = PKT_ID_LSB - 1;
    localparam KEEP_MINI_LSB = PKT_ID_LSB - S;
    localparam KEEP_LAST_MSB = KEEP_MINI_LSB - 1;
    localparam KEEP_LAST_LSB = KEEP_MINI_LSB - KEEP_WIDTH;
    localparam BAD_FRAME_BIT = KEEP_LAST_LSB - 1;
    localparam LAST_IDX_MSB = BAD_FRAME_BIT - 1;
    localparam LAST_IDX_LSB = 0;

    //==============================================================================
    // wires, regs and memories
    //==============================================================================

    // outputs
    reg  [KEEP_WIDTH-1:0]       keep_reg_o = 0;
    reg                         valid_reg_o = 0;
    reg                         is_bad_frame_reg_o = 0;
    reg                         last_reg_o = 0;
    reg  [PACKET_ID_WIDTH-1:0]  packet_id_reg_o = 0;    // NEW: Packet ID output register

    // reg inputs
    reg                         last_cell_reg;
    reg [S-1:0]                 keep_minicell_reg;
    reg [KEEP_WIDTH-1:0]        keep_last_reg;
    reg                         is_bad_frame_reg;
    reg [S_LOG-1:0]             last_minicell_index_reg = '0;
    reg [PACKET_ID_WIDTH-1:0]   packet_id_reg = '0;     // NEW: Packet ID storage

    // temp aux variables
    reg [S_LOG:0]               cell_valid_counter = S;

    wire is_minicell_valid = keep_minicell_reg[cell_valid_counter[S_LOG-1:0]];

    assign data_tx          = data_i;
    assign keep_tx          = keep_reg_o;
    assign valid_tx         = valid_reg_o;
    assign is_bad_frame_tx  = is_bad_frame_reg_o;
    assign last_tx          = last_reg_o;
    assign packet_id_tx     = packet_id_reg_o;          // NEW: Connect packet_id output

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
            last_cell_reg           <= last_cell_i;
            // MODIFIED: Extract all fields including packet_id from metadata
            packet_id_reg           <= metadata_i[PKT_ID_MSB:PKT_ID_LSB];
            keep_minicell_reg       <= metadata_i[KEEP_MINI_MSB:KEEP_MINI_LSB];
            keep_last_reg           <= metadata_i[KEEP_LAST_MSB:KEEP_LAST_LSB];
            is_bad_frame_reg        <= metadata_i[BAD_FRAME_BIT];
            last_minicell_index_reg <= metadata_i[LAST_IDX_MSB:LAST_IDX_LSB];
        end
    end

    always @(posedge clk) begin
        if (cell_valid_counter < S && is_minicell_valid) begin
            valid_reg_o <= 1;
            packet_id_reg_o <= packet_id_reg;           // NEW: Output packet_id when valid
            if (last_minicell_index_reg == cell_valid_counter) begin
                last_reg_o <= last_cell_reg;
                is_bad_frame_reg_o <= is_bad_frame_reg;
                keep_reg_o <= keep_last_reg;
            end else begin
                last_reg_o <= 0;
                is_bad_frame_reg_o <= 0;
                keep_reg_o <= W_MINI / 8;
            end
        end else begin
            keep_reg_o <= 0;
            valid_reg_o <= 0;
            is_bad_frame_reg_o <= 0;
            last_reg_o <= 0;
            packet_id_reg_o <= '0;                      // NEW: Clear when not valid
        end
    end

endmodule

`default_nettype wire