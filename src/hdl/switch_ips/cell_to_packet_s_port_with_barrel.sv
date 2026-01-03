`timescale 1ns / 1ps
// `default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Company: IUST
// Engineer: Parham Soltani
//
// Create Date:  2025-08-11 18:43:08
// Module Name: cell_to_packet_s_port_with_barrel
// Description: Multi-port cell to packet with barrel shifter and packet ID
//
// MODIFIED: Added PACKET_ID_WIDTH and packet_id propagation
//////////////////////////////////////////////////////////////////////////////////

module cell_to_packet_s_port_with_barrel #(
    parameter   S                       = 10,            // speed up
    parameter   W_MINI                  = 64,            // bus data width (mini cell data width)
    parameter   START_OF_CELL_DELAY     = 0,
    parameter   PACKET_ID_WIDTH         = 8,             // NEW: Packet ID width
    parameter   QOS_TAG_WIDTH           = 3,             // NEW: QoS tag width
    // DO NOT CHANGE
    parameter   KEEP_WIDTH              = $clog2((W_MINI/8) + 1),
    parameter   S_LOG                   = $clog2(S),
    // MODIFIED: Added QOS_TAG_WIDTH to metadata
    parameter   META_DATA_WIDTH         = S + KEEP_WIDTH + 1 + S_LOG + PACKET_ID_WIDTH + QOS_TAG_WIDTH
) (
    input   wire                                clk,
    input   wire                                start_of_cell_i,
    input   wire [META_DATA_WIDTH-1:0]          metadata_i, // sync with start_of_cell_i
    input   wire                                last_cell_i,// sync with start_of_cell_i
    input   wire [S_LOG-1:0]                    barrel_sel, // 1 delay respect to start_of_cell_i
    input   wire [W_MINI-1:0]                   data_i [S],  // first minicell has 1 delay respect to start_of_cell_i

    output  wire [W_MINI-1:0]                   data_tx[S],
    output  wire [KEEP_WIDTH-1:0]               keep_tx[S],
    output  wire                                valid_tx[S],
    output  wire                                is_bad_frame_tx[S],
    output  wire                                last_tx[S],
    output  wire [PACKET_ID_WIDTH-1:0]          packet_id_tx[S],  // NEW: Packet ID output array
    output  wire [QOS_TAG_WIDTH-1:0]            qos_tag_tx[S]     // NEW: QoS tag output array
);

    //==============================================================================
    // wires, regs and memories
    //==============================================================================

    // -- barrel_rd_data wires
    wire [W_MINI-1:0] barrel_rd_data_data_in [S];
    wire [W_MINI-1:0] barrel_rd_data_data_out [S];

    // === cell_to_packet wires ===
    wire                          c2p_start_of_cell_i  [S];
    wire [W_MINI-1:0]             c2p_data_i           [S];
    wire [META_DATA_WIDTH-1:0]    c2p_metadata_i       [S];
    wire                          c2p_last_cell_i      [S];

    wire [W_MINI-1:0]             c2p_data_tx          [S];
    wire [KEEP_WIDTH-1:0]         c2p_keep_tx          [S];
    wire                          c2p_valid_tx         [S];
    wire                          c2p_is_bad_frame_tx  [S];
    wire                          c2p_last_tx          [S];
    wire [PACKET_ID_WIDTH-1:0]    c2p_packet_id_tx     [S];  // NEW: Per-port packet_id
    wire [QOS_TAG_WIDTH-1:0]      c2p_qos_tag_tx       [S];  // NEW: Per-port qos_tag

    reg rr_sel [S];

    initial begin
        rr_sel[S-1] = 1'b1;
        for (int i = 0; i < S-1; i++) begin
            rr_sel[i] = 1'b0;
        end
    end

    assign barrel_rd_data_data_in = data_i;

    generate
        for (genvar i = 0; i < S; i++) begin : gen_assign_p2c
            assign c2p_start_of_cell_i[i] = start_of_cell_i && rr_sel[rr_index(i, START_OF_CELL_DELAY)];
            assign c2p_data_i[i]          = barrel_rd_data_data_out[i];
            assign c2p_metadata_i[i]      = metadata_i;
            assign c2p_last_cell_i[i]     = last_cell_i;
        end
    endgenerate

    generate
        for (genvar i = 0; i < S; i++) begin : gen_output_assign
            assign data_tx[i]         = c2p_data_tx[i];
            assign keep_tx[i]         = c2p_keep_tx[i];
            assign valid_tx[i]        = c2p_valid_tx[i];
            assign is_bad_frame_tx[i] = c2p_is_bad_frame_tx[i];
            assign last_tx[i]         = c2p_last_tx[i];
            assign packet_id_tx[i]    = c2p_packet_id_tx[i];  // NEW: Connect packet_id
            assign qos_tag_tx[i]      = c2p_qos_tag_tx[i];    // NEW: Connect qos_tag
        end
    endgenerate

    //==============================================================================
    // Main Controls
    //==============================================================================

    always @(posedge clk) begin
        for (int i = S-1; i > 0; i--) begin
            rr_sel[i] <= rr_sel[i-1];
        end
        rr_sel[0] <= rr_sel[S-1];
    end

    //==============================================================================
    // Instantiated Modules
    //==============================================================================

    generate
        for (genvar i = 0; i < S; i++) begin : gen_c2p
            cell_to_packet #(
                .S(S),
                .W_MINI(W_MINI),
                .PACKET_ID_WIDTH(PACKET_ID_WIDTH),        // NEW: Pass parameter
                .QOS_TAG_WIDTH(QOS_TAG_WIDTH)             // NEW: Pass parameter
            ) c2p (
                .clk             (clk),
                .start_of_cell_i (c2p_start_of_cell_i[i]),
                .data_i          (c2p_data_i[i]),
                .metadata_i      (c2p_metadata_i[i]),
                .last_cell_i     (c2p_last_cell_i[i]),
                .data_tx         (c2p_data_tx[i]),
                .keep_tx         (c2p_keep_tx[i]),
                .valid_tx        (c2p_valid_tx[i]),
                .is_bad_frame_tx (c2p_is_bad_frame_tx[i]),
                .last_tx         (c2p_last_tx[i]),
                .packet_id_tx    (c2p_packet_id_tx[i]),   // NEW: Connect packet_id
                .qos_tag_tx      (c2p_qos_tag_tx[i])      // NEW: Connect qos_tag
            );
        end
    endgenerate

    barrel_shifter #(
        .WIDTH(W_MINI),
        .NUM_PORT(S)
    ) barrel_rd_data (
        .clk        (clk),
        .data_in    (barrel_rd_data_data_in),
        .shift_val  (barrel_sel),
        .data_out   (barrel_rd_data_data_out)
    );

    //==============================================================================
    // Functions
    //==============================================================================

    function automatic int rr_index(input int port_index, input int delay_val);
        return (port_index + delay_val + 10*S) % S;
    endfunction

endmodule

`default_nettype wire