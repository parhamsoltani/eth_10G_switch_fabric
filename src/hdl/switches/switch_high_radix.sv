`timescale 1ns / 1ps
`default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Company: Parman
// Engineer: Alireza Abbasian
// 
// Create Date:  2025-08-02 16:33:51
// Module Name: switch_high_radix
// Project Name: 
// Target Devices: 
// Tool Versions: Vivado 2022.2
// Description: 
// Dependencies: 
// 
// Additional Comments: 

//////////////////////////////////////////////////////////////////////////////////



module switch_high_radix #(
    parameter   NUM_PORT                = 10,            // number of ports     
    parameter   S                       = 10,            // speed up
    parameter   W_MINI                  = 64,            // bus data width (mini cell data width)
    parameter   MAIN_MEM_DEPTH          = 512,           // main mem depth
    parameter   XPQ_DEPTH               = 64,
    parameter   OUTPUT_QUEUE_DEPTH      = 128,
    parameter   MULTICAST_SUPPORT       = 0,
    parameter   MULTICAST_RATE          = 1,
    parameter   PACKET_ID_WIDTH         = 8,
    parameter   QOS_TAG_WIDTH           = 1,
    parameter   KEEP_WIDTH              = $clog2((W_MINI/8) + 1),
    // DO NOT CHANGE!
    parameter MAIN_MEM_DEPTH_LOG            = $clog2(MAIN_MEM_DEPTH)
) (
    input   wire                                clk,

    input   wire [W_MINI-1:0]                   data_rx [NUM_PORT],
    input   wire [KEEP_WIDTH-1:0]               keep_rx [NUM_PORT],
    input   wire                                valid_rx [NUM_PORT],
    input   wire                                is_bad_frame_rx [NUM_PORT],
    input   wire [PACKET_ID_WIDTH-1:0]          packet_id_rx [NUM_PORT],
    input   wire                                last_rx [NUM_PORT],
    input   wire                                iq_fifo_almost_empty [NUM_PORT],
    input   wire [NUM_PORT-1:0]                 dest_mask_rx [NUM_PORT],
    input   wire                                dest_mask_valid_rx [NUM_PORT],
    output  wire                                rd_en_rx [NUM_PORT],

    output  wire [W_MINI-1:0]                   data_tx [NUM_PORT],
    output  wire [KEEP_WIDTH-1:0]               keep_tx [NUM_PORT],
    output  wire                                valid_tx [NUM_PORT],
    output  wire                                is_bad_frame_tx [NUM_PORT],
    output  wire                                last_tx [NUM_PORT],
    input   wire                                oq_wr_prog_full [NUM_PORT],

    output  wire [$clog2(MULTICAST_RATE * MAIN_MEM_DEPTH):0] addr_fifos_num_free_o,
    output  wire [MAIN_MEM_DEPTH_LOG:0]         free_fifo_count_o
);


    

    //==============================================================================
    // local parameters and integers
    //==============================================================================
    localparam S_LOG = $clog2(S);
    localparam NUM_PORT_LOG = $clog2(NUM_PORT);
    
    // localparam MAIN_MEM_READ_LATENCY        = 2;

    localparam META_DATA_WIDTH = S + KEEP_WIDTH + 1 + S_LOG; // valids+last minicell keep+is_bad_frame+last_minicell_index
    localparam DFIFO_READY_THRESHOLD = 2*S+20;


    localparam READ_OFFSET = 0;

    localparam FULL_WAIT_DURATION = 50;



    localparam COL_DEST_FINDER_LATENCY = 4;
    localparam ROW_DEST_FINDER_LATENCY = 1;
    localparam XPQ_READ_LATENCY = 2;
    localparam XPQ_EXTRA_READ_LATENCY = 1;

    
    localparam NUM_XPQ_COL = (NUM_PORT+S-1)/S; // hint: ceil(a/b) = (a+b-1)/b
    localparam NUM_XPQ_ROW = (NUM_PORT+S-1)/S; // hint: ceil(a/b) = (a+b-1)/b
    localparam NUM_VOQ = (NUM_PORT+S-1)/S; // hint: ceil(a/b) = (a+b-1)/b

    localparam NUM_XPQ_COL_LOG               = NUM_XPQ_COL == 1 ? 1 : $clog2(NUM_XPQ_COL);
    localparam NUM_XPQ_ROW_LOG               = NUM_XPQ_ROW == 1 ? 1 : $clog2(NUM_XPQ_ROW);

    localparam MUX_MAX_SIZE = 2;

    localparam MUX_LATENCY = layers_needed(NUM_XPQ_ROW, MUX_MAX_SIZE);

    localparam COL_READ_LATENCY         = XPQ_READ_LATENCY + MUX_LATENCY; // xpq read + mux delay
    localparam C2P_START_OF_CELL_DELAY  = COL_DEST_FINDER_LATENCY + COL_READ_LATENCY;
    localparam ROW_RTT_DELAY            = 5 + ROW_DEST_FINDER_LATENCY;


    localparam int ROW_MAX_FANOUT = 2;



    //==============================================================================
    // wires
    //==============================================================================

    wire                                cell2pkt_start_of_cell[NUM_XPQ_COL];
    wire [META_DATA_WIDTH-1:0]          cell2pkt_metadata[NUM_XPQ_COL];
    wire                                cell2pkt_last_cell[NUM_XPQ_COL];
    wire [S_LOG-1:0]                    cell2pkt_barrel_sel[NUM_XPQ_COL];
    wire [W_MINI-1:0]                   cell2pkt_data[NUM_XPQ_COL][S];

    wire [W_MINI-1:0]                   cell2pkt_data_tx [NUM_XPQ_COL][S];
    wire [KEEP_WIDTH-1:0]               cell2pkt_keep_tx [NUM_XPQ_COL][S];
    wire                                cell2pkt_valid_tx [NUM_XPQ_COL][S];
    wire                                cell2pkt_is_bad_frame_tx [NUM_XPQ_COL][S];
    wire                                cell2pkt_last_tx [NUM_XPQ_COL][S];


    // === col_dest_finder_s wires ===
    wire [S-1:0]                col_dest_finder_none_mepty_ports    [NUM_XPQ_COL][NUM_XPQ_ROW];
    wire [S-1:0]                col_dest_finder_block_ports         [NUM_XPQ_COL];
    wire                        col_dest_finder_chosen_xpq_valid    [NUM_XPQ_COL];
    wire [NUM_XPQ_ROW-1:0]      col_dest_finder_chosen_xpq          [NUM_XPQ_COL];
    wire                        col_dest_finder_last                [NUM_XPQ_COL];
    wire [S_LOG-1:0]            col_dest_finder_last_port_index     [NUM_XPQ_COL];
    wire [S_LOG-1:0]            col_dest_finder_cell2pkt_barrel_sel [NUM_XPQ_COL];
    wire [S_LOG-1:0]            col_dest_finder_xpq_pop_id          [NUM_XPQ_COL];



    wire [NUM_PORT-1:0]         row_dest_finder_none_mepty_ports        [NUM_XPQ_ROW];
    wire [NUM_PORT-1:0]         row_dest_finder_block_ports             [NUM_XPQ_ROW];
    wire                        row_dest_finder_dfifo_last              [NUM_XPQ_ROW];
    wire                        row_dest_finder_dest_valid              [NUM_XPQ_ROW];
    wire [NUM_PORT_LOG-1:0]     row_dest_finder_dest_o              [NUM_XPQ_ROW];


    // -------------------------
    // Wires for shared_voq: voq
    // -------------------------
    wire [W_MINI-1:0]                  voq_data_rx              [NUM_VOQ][S];
    wire [KEEP_WIDTH-1:0]              voq_keep_rx              [NUM_VOQ][S];
    wire                               voq_valid_rx             [NUM_VOQ][S];
    wire                               voq_is_bad_frame_rx      [NUM_VOQ][S];
    wire [PACKET_ID_WIDTH-1:0]         voq_packet_id_rx         [NUM_VOQ][S];
    wire                               voq_last_rx              [NUM_VOQ][S];
    wire                               voq_iq_fifo_almost_empty [NUM_VOQ][S];
    wire [NUM_PORT-1:0]                voq_dest_mask_rx         [NUM_VOQ][S];
    wire                               voq_dest_mask_valid_rx   [NUM_VOQ][S];
    wire                               voq_rd_en_rx             [NUM_VOQ][S];
    wire [NUM_PORT_LOG-1:0]            voq_pop_index            [NUM_VOQ];
    wire                               voq_pop                  [NUM_VOQ];
    wire                               voq_cell_valid           [NUM_VOQ];
    wire [META_DATA_WIDTH-1:0]         voq_cell_metadata        [NUM_VOQ];
    wire                               voq_last_cell            [NUM_VOQ];
    wire [NUM_XPQ_COL_LOG-1:0]         voq_xpq_index            [NUM_VOQ];
    wire [S_LOG-1:0]                   voq_dest_s_index         [NUM_VOQ];
    wire [W_MINI-1:0]                  voq_main_mem_rd_data     [NUM_VOQ][S]; // ready one clk after voq_cell_valid
    wire [NUM_PORT-1:0]                voq_none_mepty_fifos     [NUM_VOQ];

    // wire [$clog2(MULTICAST_RATE*MAIN_MEM_DEPTH):0] voq_addr_fifos_num_free;
    // wire [MAIN_MEM_DEPTH_LOG:0]        voq_free_fifo_count;


    wire                              xpq_push              [NUM_XPQ_ROW][NUM_XPQ_COL];
    wire                              xpq_push_last_cell    [NUM_XPQ_ROW][NUM_XPQ_COL];
    wire [W_MINI-1:0]                 xpq_push_data         [NUM_XPQ_ROW][NUM_XPQ_COL][S];
    wire [META_DATA_WIDTH-1:0]        xpq_push_metadata     [NUM_XPQ_ROW][NUM_XPQ_COL];
    wire [S_LOG-1:0]                  xpq_push_id           [NUM_XPQ_ROW][NUM_XPQ_COL];
    wire                              xpq_pop               [NUM_XPQ_ROW][NUM_XPQ_COL];
    wire [S_LOG-1:0]                  xpq_pop_id            [NUM_XPQ_ROW][NUM_XPQ_COL];
    wire                              xpq_pop_last_cell     [NUM_XPQ_ROW][NUM_XPQ_COL];
    wire [W_MINI-1:0]                 xpq_pop_data          [NUM_XPQ_ROW][NUM_XPQ_COL][S];
    wire [META_DATA_WIDTH-1:0]        xpq_pop_metadata      [NUM_XPQ_ROW][NUM_XPQ_COL];
    wire [S-1:0]                      xpq_none_mepty_fifos  [NUM_XPQ_ROW][NUM_XPQ_COL];
    wire [S-1:0]                      xpq_blocked_ports     [NUM_XPQ_ROW][NUM_XPQ_COL];
    // wire [FREE_FIFO_DEPTH_LOG:0]      xpq_num_free;



    // Outputs from col_pipeline_mux, per column
    wire [META_DATA_WIDTH-1:0] mux_pop_metadata    [NUM_XPQ_COL];
    wire                       mux_pop_last_cell  [NUM_XPQ_COL];
    wire [W_MINI-1:0]          mux_pop_data       [NUM_XPQ_COL][S];

    
    // -----------------------------------------------------------------------------
    // Replicated VOQ→XPQ signals: [row][col]
    // -----------------------------------------------------------------------------
    wire                            rep_push        [NUM_VOQ][NUM_XPQ_COL];
    wire                            rep_last_cell   [NUM_VOQ][NUM_XPQ_COL];
    wire [META_DATA_WIDTH-1:0]      rep_metadata    [NUM_VOQ][NUM_XPQ_COL];
    wire [S_LOG-1:0]                rep_push_id     [NUM_VOQ][NUM_XPQ_COL];
    wire [W_MINI-1:0]               rep_data        [NUM_VOQ][S][NUM_XPQ_COL];
    wire [NUM_XPQ_COL_LOG-1:0]      rep_xpq_index   [NUM_VOQ][NUM_XPQ_COL];

    wire col_dest_finder_chosen_xpq_valid_D[NUM_XPQ_COL][0:COL_READ_LATENCY];


    //==============================================================================
    // regs
    //==============================================================================


    
    //==============================================================================
    // assignments
    //==============================================================================

    generate
        for (genvar c = 0; c < NUM_XPQ_COL; c++) begin
            
            assign cell2pkt_start_of_cell[c] = col_dest_finder_chosen_xpq_valid_D[c][COL_READ_LATENCY];
            assign cell2pkt_metadata     [c] = mux_pop_metadata[c];
            assign cell2pkt_last_cell    [c] = mux_pop_last_cell[c];
            assign cell2pkt_barrel_sel   [c] = col_dest_finder_cell2pkt_barrel_sel[c]; 
            assign cell2pkt_data         [c] = mux_pop_data[c];







    

            for (genvar r = 0; r < NUM_XPQ_ROW; r++) begin
                assign col_dest_finder_none_mepty_ports[c][r] = xpq_none_mepty_fifos[r][c];
            end
            for (genvar j = 0; j < S; j++) begin 
                if (c*S+j >= NUM_PORT) begin
                    assign col_dest_finder_block_ports[c][j] = 0;
                end else begin
                    assign col_dest_finder_block_ports[c][j] = oq_wr_prog_full[c*S+j];
                end
            end
            assign col_dest_finder_last[c] = xpq_pop_last_cell[0][c];

        end
    endgenerate


    generate
        for (genvar r = 0; r < NUM_XPQ_ROW; r++) begin
            
            assign row_dest_finder_none_mepty_ports[r]       = voq_none_mepty_fifos[r];

                for (genvar c = 0; c < NUM_XPQ_COL; c++) begin
                    for (genvar j=0; j<S; ++j) begin
                        if (c*S+j < NUM_PORT) begin
                            assign row_dest_finder_block_ports[r][c*S+j] = xpq_blocked_ports[r][c][j];
                        end
                    end
                end
            assign row_dest_finder_dfifo_last[r]              = voq_last_cell[r];
        end
    endgenerate



    // Map flat NUM_PORT arrays into NUM_VOQ × S structure
    generate
        for (genvar r = 0; r < NUM_VOQ; r++) begin : g_voq_rx_map
            for (genvar i = 0; i < S; i++) begin
                if (r*S + i < NUM_PORT) begin
                    assign voq_data_rx             [r][i] = data_rx            [r*S + i];
                    assign voq_keep_rx             [r][i] = keep_rx            [r*S + i];
                    assign voq_valid_rx            [r][i] = valid_rx           [r*S + i];
                    assign voq_is_bad_frame_rx     [r][i] = is_bad_frame_rx    [r*S + i];
                    assign voq_packet_id_rx        [r][i] = packet_id_rx       [r*S + i];
                    assign voq_last_rx             [r][i] = last_rx            [r*S + i];
                    assign voq_iq_fifo_almost_empty[r][i] = iq_fifo_almost_empty[r*S + i];
                    assign voq_dest_mask_rx        [r][i] = dest_mask_rx       [r*S + i];
                    assign voq_dest_mask_valid_rx  [r][i] = dest_mask_valid_rx [r*S + i];
                end
                else begin
                    // Unused lanes get default zeros
                    assign voq_data_rx             [r][i] = '0;
                    assign voq_keep_rx             [r][i] = '0;
                    assign voq_valid_rx            [r][i] = 1'b0;
                    assign voq_is_bad_frame_rx     [r][i] = 1'b0;
                    assign voq_packet_id_rx        [r][i] = '0;
                    assign voq_last_rx             [r][i] = 1'b0;
                    assign voq_iq_fifo_almost_empty[r][i] = 1'b1;
                    assign voq_dest_mask_rx        [r][i] = '0;
                    assign voq_dest_mask_valid_rx  [r][i] = 1'b0;
                end
            end


            assign voq_pop_index [r]           = row_dest_finder_dest_o[r]; 
            assign voq_pop [r]                 = row_dest_finder_dest_valid[r];


        end
    endgenerate


    // --- XPQ matrix: one XPQ per (row, col) ---
    generate
        for (genvar r = 0; r < NUM_XPQ_ROW; r++) begin : g_xpq_r
            for (genvar c = 0; c < NUM_XPQ_COL; c++) begin : g_xpq_c
                (* keep_hierarchy = "yes" *)
                shared_xpq #(
                    .W_MINI               (W_MINI),
                    .MAIN_MEM_DEPTH       (XPQ_DEPTH),
                    .S                    (S),
                    .META_DATA_WIDTH      (META_DATA_WIDTH),
                    .EXTRA_READ_LATENCY   (XPQ_EXTRA_READ_LATENCY),
                    .INLCUDE_PROTECTION   (0)
                ) xpq_i (
                    .clk                  (clk),

                    // push from VOQ row r to all columns c
                    .push                 (xpq_push[r][c]),
                    .push_last_cell       (xpq_push_last_cell[r][c]),
                    .push_data            (xpq_push_data[r][c]),
                    .push_metadata        (xpq_push_metadata[r][c]),
                    .push_id              (xpq_push_id[r][c]),

                    // pop controlled per column; only row 0 pops to cell2pkt for now
                    .pop                  (xpq_pop[r][c]),
                    .pop_id               (xpq_pop_id[r][c]),
                    .pop_last_cell        (xpq_pop_last_cell[r][c]),
                    .pop_data             (xpq_pop_data[r][c]),
                    .pop_metadata         (xpq_pop_metadata[r][c]),

                    .num_free             (),
                    .none_mepty_fifos     (xpq_none_mepty_fifos[r][c]),
                    .blocked_ports        (xpq_blocked_ports[r][c])
                );

                // VOQ(row r) -> XPQ(row r, col c) via replicated signals
                assign xpq_push           [r][c] = rep_push      [r][c] && (rep_xpq_index[r][c] == c);
                assign xpq_push_last_cell [r][c] = rep_last_cell [r][c];
                assign xpq_push_metadata  [r][c] = rep_metadata  [r][c];
                assign xpq_push_id        [r][c] = rep_push_id   [r][c];

                // Data lanes
                for (genvar i = 0; i < S; i++) begin : g_wire_lanes
                    assign xpq_push_data[r][c][i] = rep_data[r][i][c];
                end


                assign xpq_pop             [r][c]   = col_dest_finder_chosen_xpq[c][r];
                assign xpq_pop_id          [r][c]   = col_dest_finder_xpq_pop_id[c];  
            end
        end
    endgenerate


    


    //==========================
    // assign outputs
    //==========================

    generate
        for (genvar c = 0; c < NUM_XPQ_COL; c++) begin : g_tx_flatten_col
            for (genvar i = 0; i < S; i++) begin : g_tx_flatten_lane
                if (c*S + i < NUM_PORT) begin
                    assign data_tx        [c*S + i] = cell2pkt_data_tx      [c][i];
                    assign keep_tx        [c*S + i] = cell2pkt_keep_tx      [c][i];
                    assign valid_tx       [c*S + i] = cell2pkt_valid_tx     [c][i];
                    assign is_bad_frame_tx[c*S + i] = cell2pkt_is_bad_frame_tx[c][i];
                    assign last_tx        [c*S + i] = cell2pkt_last_tx      [c][i];
                end 
            end
        end
    endgenerate

    generate
        for (genvar r = 0; r < NUM_VOQ; r++) begin : g_rd_en_flatten_row
            for (genvar i = 0; i < S; i++) begin : g_rd_en_flatten_lane
                if ( r*S + i < NUM_PORT) begin
                    assign rd_en_rx[ r*S + i] = voq_rd_en_rx[r][i];
                end 
            end
        end
    endgenerate




    // // loop back!
    // generate
    //     for (genvar i = 0; i < NUM_PORT; i++) begin
    //         assign data_tx[i]           = data_rx[i];
    //         assign keep_tx[i]           = keep_rx[i];
    //         assign valid_tx[i]          = valid_rx[i];
    //         assign is_bad_frame_tx[i]   = is_bad_frame_rx[i];
    //         assign last_tx[i]           = last_rx[i];
    //         assign rd_en_rx[i]          = ~oq_wr_prog_full[i];
    //     end
    // endgenerate



    //==============================================================================
    // Main Controls
    //==============================================================================

    

    
    //==============================================================================
    // Instantiated Modules
    //==============================================================================



    // --- one col_dest_finder per column ---
    generate
        for (genvar c = 0; c < NUM_XPQ_COL; c++) begin : g_col_df
            // For now we drive the column DF from ROW 0 XPQs only (since only row 0 pops to cell2pkt)
            (* keep_hierarchy = "yes" *)
            dest_finder_col #(
                .S(S),
                .NUM_XPQ(NUM_XPQ_ROW),
                .COL_READ_LATENCY(COL_READ_LATENCY),
                .XPQ_EXTRA_READ_LATENCY(XPQ_EXTRA_READ_LATENCY)
            ) col_dest_finder_inst (
                .clk                      (clk),
                .none_mepty_ports         (col_dest_finder_none_mepty_ports[c]), 
                .block_ports              (col_dest_finder_block_ports[c]),
                .dfifo_last               (col_dest_finder_last[c]),    
                .chosen_xpq_valid_o       (col_dest_finder_chosen_xpq_valid[c]),
                .chosen_xpq_o             (col_dest_finder_chosen_xpq[c]),
                .cell2pkt_barrel_sel      (col_dest_finder_cell2pkt_barrel_sel[c]),
                .xpq_pop_id(col_dest_finder_xpq_pop_id[c])
            );
        end
    endgenerate


    // --- one row_dest_finder per row ---
    generate
        for (genvar r = 0; r < NUM_XPQ_ROW; r++) begin : g_row_df
            (* keep_hierarchy = "yes" *)
            dest_finder_row #(
                .S(S),
                .NUM_PORT(NUM_PORT),
                .ROW_RTT_DELAY(ROW_RTT_DELAY)
            ) row_dest_finder_inst (
                .clk                      (clk),
                .none_mepty_ports         (row_dest_finder_none_mepty_ports[r]),   // == voq_none_mepty_fifos[r]
                .block_ports              (row_dest_finder_block_ports[r]),
                .dfifo_last               (row_dest_finder_dfifo_last[r]),
                .dest_valid_o             (row_dest_finder_dest_valid[r]),
                .dest_o                   (row_dest_finder_dest_o[r])
            );
        end
    endgenerate


    
    // One cell_to_packet per XPQ column
    generate
        for (genvar c = 0; c < NUM_XPQ_COL; c++) begin : g_cell2pkt_col
            (* keep_hierarchy = "yes" *)
            cell_to_packet_s_port_with_barrel #(
                .S                    (S),
                .W_MINI               (W_MINI),
                .START_OF_CELL_DELAY  (C2P_START_OF_CELL_DELAY)
            ) u_cell2pkt_c (
                .clk               (clk),
                .start_of_cell_i   (cell2pkt_start_of_cell[c]),
                .metadata_i        (cell2pkt_metadata[c]),
                .last_cell_i       (cell2pkt_last_cell[c]),
                .barrel_sel        (cell2pkt_barrel_sel[c]),
                .data_i            (cell2pkt_data[c]),

                .data_tx           (cell2pkt_data_tx[c]),
                .keep_tx           (cell2pkt_keep_tx[c]),
                .valid_tx          (cell2pkt_valid_tx[c]),
                .is_bad_frame_tx   (cell2pkt_is_bad_frame_tx[c]),
                .last_tx           (cell2pkt_last_tx[c])
            );
        end
    endgenerate



    

    // --- one VOQ per row ---
    generate
        for (genvar r = 0; r < NUM_VOQ; r++) begin : g_voq
            (* keep_hierarchy = "yes" *)
            shared_voq #(
                .NUM_PORT               (NUM_PORT),
                .S                      (S),
                // .NUM_IN                 (NUM_PORT), // TODO NUM_IN last = NUM_PORT%S
                .W_MINI                 (W_MINI),
                .MAIN_MEM_DEPTH         (MAIN_MEM_DEPTH),
                .XPQ_DEPTH              (XPQ_DEPTH),
                .OUTPUT_QUEUE_DEPTH     (OUTPUT_QUEUE_DEPTH),
                .MULTICAST_SUPPORT      (MULTICAST_SUPPORT),
                .MULTICAST_RATE         (MULTICAST_RATE),
                .PACKET_ID_WIDTH        (PACKET_ID_WIDTH),
                .QOS_TAG_WIDTH          (QOS_TAG_WIDTH),
                .KEEP_WIDTH             (KEEP_WIDTH),
                .MAIN_MEM_DEPTH_LOG     (MAIN_MEM_DEPTH_LOG),
                .DFIFO_META_DATA_WIDTH  (META_DATA_WIDTH)
            ) voq_i (
                .clk                    (clk),

                .data_rx                (voq_data_rx[r]),
                .keep_rx                (voq_keep_rx[r]),
                .valid_rx               (voq_valid_rx[r]),
                .is_bad_frame_rx        (voq_is_bad_frame_rx[r]),
                .packet_id_rx           (voq_packet_id_rx[r]),
                .last_rx                (voq_last_rx[r]),
                .iq_fifo_almost_empty   (voq_iq_fifo_almost_empty[r]),
                .dest_mask_rx           (voq_dest_mask_rx[r]),
                .dest_mask_valid_rx     (voq_dest_mask_valid_rx[r]),
                .rd_en_rx               (voq_rd_en_rx[r]),

                .pop_index_i            (voq_pop_index[r]),        
                .pop_i                  (voq_pop[r]),              
                .cell_valid_o           (voq_cell_valid[r]),
                .cell_metadata_o        (voq_cell_metadata[r]),
                .last_cell_o            (voq_last_cell[r]),
                .xpq_index_o            (voq_xpq_index[r]),
                .dest_s_index_o         (voq_dest_s_index[r]),
                .main_mem_rd_data_o     (voq_main_mem_rd_data[r]),
                .none_mepty_fifos_o     (voq_none_mepty_fifos[r]),

                .addr_fifos_num_free_o  (),
                .free_fifo_count_o      ()
                );
        end
    endgenerate

 
    // -----------------------------------------------------------------------------
    // Build the replication trees (fanout-limited) for each VOQ row
    // -----------------------------------------------------------------------------
    generate
    for (genvar r = 0; r < NUM_VOQ; r++) begin : g_voq_rep

        // push (1 bit)
        delayed_regs #(
            .WIDTH      (1),
            .NUM_DELAY  (S-1)
        ) u_del_push_r (
            .clk            (clk),
            .signal_in      ( voq_cell_valid[r] ),
            .delayed_signal ( rep_push[r] )        // rep_push[r][0..S-1]
        );

        // last_cell (1 bit)
        delayed_regs #(
            .WIDTH      (1),
            .NUM_DELAY  (S-1)
        ) u_del_last_cell_r (
            .clk            (clk),
            .signal_in      ( voq_last_cell[r] ),
            .delayed_signal ( rep_last_cell[r] )   // rep_last_cell[r][0..S-1]
        );

        // metadata
        delayed_regs #(
            .WIDTH      (META_DATA_WIDTH),
            .NUM_DELAY  (S-1)
        ) u_del_metadata_r (
            .clk            (clk),
            .signal_in      ( voq_cell_metadata[r] ),
            .delayed_signal ( rep_metadata[r] )     // rep_metadata[r][0..S-1]
        );

        // push_id (dest_s_index)
        delayed_regs #(
            .WIDTH      (S_LOG),
            .NUM_DELAY  (S-1)
        ) u_del_push_id_r (
            .clk            (clk),
            .signal_in      ( voq_dest_s_index[r] ),
            .delayed_signal ( rep_push_id[r] )      // rep_push_id[r][0..S-1]
        );

        // voq_xpq_index
        delayed_regs #(
            .WIDTH      (NUM_XPQ_COL_LOG),
            .NUM_DELAY  (S-1)
        ) u_del_xpq_index_r (
            .clk            (clk),
            .signal_in      ( voq_xpq_index[r] ),
            .delayed_signal ( rep_xpq_index[r] )    // rep_xpq_index[r][0..S-1]
        );

        // data lanes — delay each lane across S taps
        for (genvar i = 0; i < S; i++) begin : g_rep_lane
            delayed_regs #(
                .WIDTH      (W_MINI),
                .NUM_DELAY  (S-1)
            ) u_del_data_ri (
                .clk            (clk),
                .signal_in      ( voq_main_mem_rd_data[r][i] ),
                .delayed_signal ( rep_data[r][i] )           // rep_data[r][i][0..S-1]
            );
        end

    end
    endgenerate


    generate
        for (genvar c = 0; c < NUM_XPQ_COL; c++) begin : g_col_mux
            // ---------------------------------------------------------------------
            // Temporary wires for this column's inputs to col_pipeline_mux
            // ---------------------------------------------------------------------
            wire [META_DATA_WIDTH-1:0] col_metadata_in   [NUM_XPQ_ROW];
            wire                       col_last_cell_in  [NUM_XPQ_ROW];
            wire [W_MINI-1:0]          col_data_in       [NUM_XPQ_ROW][S];

            // Map xpq_pop_*[row][col] into column-local arrays
            for (genvar r = 0; r < NUM_XPQ_ROW; r++) begin : g_map_rows
                assign col_metadata_in[r]  = xpq_pop_metadata[r][c];
                assign col_last_cell_in[r] = xpq_pop_last_cell[r][c];
                for (genvar i = 0; i < S; i++) begin : g_map_lanes
                    assign col_data_in[r][i] = xpq_pop_data[r][c][i];
                end
            end

            // ---------------------------------------------------------------------
            // Instance of col_pipeline_mux for this column
            // ---------------------------------------------------------------------
            col_pipeline_mux #(
                .META_DATA_WIDTH (META_DATA_WIDTH),
                .W_MINI          (W_MINI),
                .NUM_XPQ_ROW     (NUM_XPQ_ROW),
                .S               (S),
                .MUX_MAX_SIZE    (MUX_MAX_SIZE)
            ) u_col_pipeline_mux (
                .clk                   (clk),
                .select_one_hot        (col_dest_finder_chosen_xpq[c]),

                .xpq_pop_metadata_in   (col_metadata_in),
                .xpq_pop_last_cell_in  (col_last_cell_in),
                .xpq_pop_data_in       (col_data_in),

                .xpq_pop_metadata_out  (mux_pop_metadata[c]),
                .xpq_pop_last_cell_out (mux_pop_last_cell[c]),
                .xpq_pop_data_out      (mux_pop_data[c])
            );

        end
    endgenerate


    

    generate
        for (genvar c = 0; c < NUM_XPQ_COL; c++) begin : g_col_valid_delay

            delayed_regs #(
                .WIDTH     (1),
                .NUM_DELAY (COL_READ_LATENCY)
            ) u_col_dest_valid_delay (
                .clk            (clk),
                .signal_in      (col_dest_finder_chosen_xpq_valid[c]),
                .delayed_signal (col_dest_finder_chosen_xpq_valid_D[c])
            );


        end
    endgenerate


    //==============================================================================
    // Functions
    //==============================================================================


    function automatic int rr_index(input int port_index, input int delay_val);
        return (port_index + delay_val + 10*S) % S;
    endfunction

    function automatic int ceil_div(input int a, input int b);
        return (a + b - 1) / b;
    endfunction
    function automatic int layers_needed(input int n, input int k);
        int l = 0, x = n;
        while (x > 1) begin
            x = ceil_div(x, k);
            l++;
        end
        return l;
    endfunction
    

endmodule

`default_nettype wire 