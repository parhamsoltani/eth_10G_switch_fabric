`timescale 1ns / 1ps
// `default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Company: IUST
// Engineer: Parham Soltani
//
// Create Date:  2025-08-16 19:26:48
// Module Name: row_mux
// Project Name:
// Target Devices:
// Tool Versions: Vivado 2022.2
// Description:
// Dependencies:
//
// Additional Comments:

//////////////////////////////////////////////////////////////////////////////////



module row_mux #(
    parameter META_DATA_WIDTH   = 19,
    parameter NUM_XPQ_COL_LOG   = 6,
    parameter S_LOG             = 4,
    parameter S                 = 7,
    parameter W_MINI            = 100,
    parameter XPQ_INDEX         = 2
) (
    input wire                               clk,
    input wire                               voq_cell_valid_1         ,
    input wire [META_DATA_WIDTH-1:0]         voq_cell_metadata_1      ,
    input wire                               voq_last_cell_1          ,
    input wire [NUM_XPQ_COL_LOG-1:0]         voq_xpq_index_1          ,
    input wire [S_LOG-1:0]                   voq_dest_s_index_1       ,
    input wire [W_MINI-1:0]                  voq_main_mem_rd_data_1   [S],

    input wire                               voq_cell_valid_2         ,
    input wire [META_DATA_WIDTH-1:0]         voq_cell_metadata_2      ,
    input wire                               voq_last_cell_2          ,
    input wire [NUM_XPQ_COL_LOG-1:0]         voq_xpq_index_2          ,
    input wire [S_LOG-1:0]                   voq_dest_s_index_2       ,
    input wire [W_MINI-1:0]                  voq_main_mem_rd_data_2   [S],

    output reg                              xpq_push_o         ,
    output reg [META_DATA_WIDTH-1:0]        voq_cell_metadata_o      ,
    output reg                              voq_last_cell_o          ,
    output reg [S_LOG-1:0]                  voq_dest_s_index_o       ,
    output reg [W_MINI-1:0]                 voq_main_mem_rd_data_o   [S]

);

    // -------------------------------------------------------------------------
    // 1) Build select (0 -> take stream 1, 1 -> take stream 2)
    // -------------------------------------------------------------------------
    wire match_1 = voq_cell_valid_1 && (voq_xpq_index_1 == XPQ_INDEX);
    wire match_2 = voq_cell_valid_2 && (voq_xpq_index_2 == XPQ_INDEX);

    always @(posedge clk) begin

        xpq_push_o <= match_1 | match_2;
    end

    // -------------------------------------------------------------------------
    // 2) Immediate (non-delayed) muxing for metadata/flags
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        voq_cell_metadata_o <= match_1 ? voq_cell_metadata_1 : voq_cell_metadata_2;
        voq_last_cell_o     <= match_1 ? voq_last_cell_1     : voq_last_cell_2;
        voq_dest_s_index_o  <= match_1 ? voq_dest_s_index_1  : voq_dest_s_index_2;
    end

    // -------------------------------------------------------------------------
    // 3) Delay the select for each lane (like your col mux)
    //    sel_D[0] is immediate; use sel_D[i+1] for lane i
    // -------------------------------------------------------------------------
    wire [0:0] sel_D [0:S];  // WIDTH=1 -> [0:0]
    delayed_regs #(
        .WIDTH     (1),
        .NUM_DELAY (S)
    ) u_sel_delay (
        .clk            (clk),
        .signal_in      (match_1),
        .delayed_signal (sel_D)
    );

    // -------------------------------------------------------------------------
    // 4) Per-lane data muxing with mux_tile (K=2, W=W_MINI)
    // -------------------------------------------------------------------------
    generate
        for (genvar i = 0; i < S; i++) begin : g_lane
            wire [W_MINI-1:0] in_lane [2];
            assign in_lane[1] = voq_main_mem_rd_data_1[i];
            assign in_lane[0] = voq_main_mem_rd_data_2[i];

            mux_tile #(
                .K (2),
                .W (W_MINI)
            ) u_lane_mux (
                .clk (clk),
                .in  (in_lane),
                .sel (sel_D[i+1]),   // 1-bit select, delayed per lane
                .out (voq_main_mem_rd_data_o[i])
            );
        end
    endgenerate

endmodule


`default_nettype wire