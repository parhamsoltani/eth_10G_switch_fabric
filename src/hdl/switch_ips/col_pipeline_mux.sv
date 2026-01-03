`timescale 1ns / 1ps
// `default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Company: IUST
// Engineer: Parham Soltani
//
// Create Date:  2025-08-15 11:15:04
// Module Name: col_pipeline_mux
// Project Name:
// Target Devices:
// Tool Versions: Vivado 2022.2
// Description:
// Dependencies:
// 
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module col_pipeline_mux #(
    parameter META_DATA_WIDTH   = 19,
    parameter W_MINI            = 112,
    parameter NUM_XPQ_ROW       = 6,
    parameter S                 = 10,
    parameter MUX_MAX_SIZE      = 4,
    // DO NOT CHANGE
    parameter NUM_XPQ_ROW_LOG   = (NUM_XPQ_ROW <= 1) ? 1 : $clog2(NUM_XPQ_ROW)  // Minimum 1 bit to avoid [-1:0]
) (
    input  wire                             clk,
    input  wire [NUM_XPQ_ROW-1:0]           select_one_hot,

    input  wire [META_DATA_WIDTH-1:0]       xpq_pop_metadata_in   [NUM_XPQ_ROW],
    input  wire                             xpq_pop_last_cell_in  [NUM_XPQ_ROW],
    input  wire [W_MINI-1:0]                xpq_pop_data_in       [NUM_XPQ_ROW][S],

    output wire [META_DATA_WIDTH-1:0]       xpq_pop_metadata_out,
    output wire                             xpq_pop_last_cell_out,
    output wire [W_MINI-1:0]                xpq_pop_data_out      [S]
);

    // -------------------------------------------------------------------------
    // 1) One-hot -> binary select
    // -------------------------------------------------------------------------
    generate
        if (NUM_XPQ_ROW == 1) begin : gen_single_row
            // No mux needed - direct passthrough
            // sel_mux_r not used in this case
            
            // -------------------------------------------------------------------------
            // 2) Metadata - direct passthrough
            // -------------------------------------------------------------------------
            assign xpq_pop_metadata_out = xpq_pop_metadata_in[0];
            
            // -------------------------------------------------------------------------
            // 3) Last cell - direct passthrough
            // -------------------------------------------------------------------------
            assign xpq_pop_last_cell_out = xpq_pop_last_cell_in[0];
            
            // -------------------------------------------------------------------------
            // 4) Per-lane data - direct passthrough
            // -------------------------------------------------------------------------
            for (genvar i = 0; i < S; i = i + 1) begin : g_lane_passthrough
                assign xpq_pop_data_out[i] = xpq_pop_data_in[0][i];
            end
            
        end else begin : gen_multi_row
            // Multiple rows - need mux logic
            
            reg [NUM_XPQ_ROW_LOG-1:0] sel_mux_r;

            always @(posedge clk) begin
                for (int i = 0; i < NUM_XPQ_ROW; ++i) begin
                    if (select_one_hot[i]) begin
                        sel_mux_r <= i[NUM_XPQ_ROW_LOG-1:0];
                    end
                end
            end

            // -------------------------------------------------------------------------
            // 2) Metadata mux
            // -------------------------------------------------------------------------
            pipeline_mux #(
                .N (NUM_XPQ_ROW),
                .K (MUX_MAX_SIZE),
                .W (META_DATA_WIDTH)
            ) u_meta_mux (
                .clk (clk),
                .in  (xpq_pop_metadata_in),
                .sel (sel_mux_r),
                .out (xpq_pop_metadata_out)
            );

            // -------------------------------------------------------------------------
            // 3) Last cell mux
            // -------------------------------------------------------------------------
            pipeline_mux #(
                .N (NUM_XPQ_ROW),
                .K (MUX_MAX_SIZE),
                .W (1)
            ) u_last_mux (
                .clk (clk),
                .in  (xpq_pop_last_cell_in),
                .sel (sel_mux_r),
                .out (xpq_pop_last_cell_out)
            );

            // -------------------------------------------------------------------------
            // 4) Delay select for each lane
            // -------------------------------------------------------------------------
            wire [NUM_XPQ_ROW_LOG-1:0] sel_mux_D [0:S];

            delayed_regs #(
                .WIDTH     (NUM_XPQ_ROW_LOG),
                .NUM_DELAY (S)
            ) u_sel_data_delay (
                .clk            (clk),
                .signal_in      (sel_mux_r),
                .delayed_signal (sel_mux_D)
            );

            // -------------------------------------------------------------------------
            // 5) Per-lane data muxes
            // -------------------------------------------------------------------------
            for (genvar i = 0; i < S; i = i + 1) begin : g_lane_mux
                // Temporary wire for this lane: collects data from all rows
                wire [W_MINI-1:0] lane_data [NUM_XPQ_ROW];
                for (genvar r = 0; r < NUM_XPQ_ROW; r = r + 1) begin : g_lane_row
                    assign lane_data[r] = xpq_pop_data_in[r][i];
                end

                pipeline_mux #(
                    .N (NUM_XPQ_ROW),
                    .K (MUX_MAX_SIZE),
                    .W (W_MINI)
                ) u_data_mux (
                    .clk (clk),
                    .in  (lane_data),
                    .sel (sel_mux_D[i+1]),
                    .out (xpq_pop_data_out[i])
                );
            end
        end
    endgenerate

endmodule

`default_nettype wire