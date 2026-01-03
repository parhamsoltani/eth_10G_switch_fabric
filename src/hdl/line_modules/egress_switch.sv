`timescale 1ns / 1ps
// `default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Company: IUST
// Engineer: Parham Soltani
//
// Create Date:  2025-08-02 16:01:13
// Module Name: egress_switch
// Description: Egress stage with packet ID preservation
//
// MODIFIED: Added packet_id_tx input and proper propagation to output
//////////////////////////////////////////////////////////////////////////////////

module egress_switch #(
    parameter   NUM_PORT                = 10,            // number of ports
    parameter   W_MINI                  = 64,            // bus data width (mini cell data width)
    parameter   KEEP_WIDTH              = 10,
    parameter   OUTPUT_QUEUE_DEPTH      = 16,
    parameter   OUTPUT_QUEUE_TUSER      = 1,             // Legacy parameter (not used directly now)
    parameter   OQ_PROG_FULL_THRESH     = 30,
    parameter   NOT_READY_LIMIT         = 20,
    parameter   PACKET_ID_WIDTH         = 8,             // NEW: Packet ID width
    parameter   QOS_TAG_WIDTH           = 3              // NEW: QoS tag width
) (
    input   wire                                clk,
    switch_data_if.master_mp                    tx_data_if,
    input   wire [W_MINI-1:0]                   data_tx,
    input   wire [KEEP_WIDTH-1:0]               keep_tx,
    input   wire                                valid_tx,
    input   wire                                is_bad_frame_tx,
    input   wire                                last_tx,
    input   wire [PACKET_ID_WIDTH-1:0]          packet_id_tx,    // NEW: Packet ID input
    input   wire [QOS_TAG_WIDTH-1:0]            qos_tag_tx,      // NEW: QoS tag input
    output  wire                                oq_wr_prog_full
);

    //==============================================================================
    // local parameters and integers
    //==============================================================================
    // MODIFIED: Updated tuser width to include packet_id and qos_tag
    localparam OUTPUT_QUEUE_TUSER_ACTUAL = PACKET_ID_WIDTH + QOS_TAG_WIDTH + 1 + KEEP_WIDTH;

    //==============================================================================
    // wires, regs and memories
    //==============================================================================

    wire [W_MINI-1:0] output_queue_wr_tdata;
    wire [OUTPUT_QUEUE_TUSER_ACTUAL-1:0] output_queue_wr_tuser;
    wire output_queue_wr_tvalid;
    wire output_queue_wr_tlast;
    wire output_queue_wr_tready;
    wire output_queue_wr_prog_full;

    wire [W_MINI-1:0] output_queue_rd_tdata;
    wire [OUTPUT_QUEUE_TUSER_ACTUAL-1:0] output_queue_rd_tuser;
    wire output_queue_rd_tvalid;
    wire output_queue_rd_tlast;
    wire output_queue_rd_tready;
    wire output_queue_rd_almost_empty;

    reg [$clog2(NOT_READY_LIMIT)-1:0] not_ready_counter = NOT_READY_LIMIT;
    reg oq_ready_int = 0;

    always @(posedge clk) begin
        if (tx_data_if.ready) begin
            not_ready_counter <= NOT_READY_LIMIT;
        end else if (not_ready_counter > 0) begin
            not_ready_counter <= not_ready_counter - 1;
        end
    end

    always @(posedge clk) begin
        if (not_ready_counter == 0) begin
            oq_ready_int <= 1;
        end else begin
            oq_ready_int <= 0;
        end
    end

    assign output_queue_rd_tready = oq_ready_int || tx_data_if.ready;

    // MODIFIED: Pack packet_id and qos_tag into tuser
    assign output_queue_wr_tdata  = data_tx;
    assign output_queue_wr_tuser  = {packet_id_tx, qos_tag_tx, is_bad_frame_tx, keep_tx};
    assign output_queue_wr_tvalid = valid_tx;
    assign output_queue_wr_tlast  = last_tx;

    assign oq_wr_prog_full = output_queue_wr_prog_full;

    // MODIFIED: Unpack packet_id and qos_tag from tuser and connect to tx_data_if
    assign tx_data_if.data         = output_queue_rd_tdata;
    assign tx_data_if.id           = output_queue_rd_tuser[OUTPUT_QUEUE_TUSER_ACTUAL-1 -: PACKET_ID_WIDTH];
    assign tx_data_if.qos_tag      = output_queue_rd_tuser[OUTPUT_QUEUE_TUSER_ACTUAL-1 - PACKET_ID_WIDTH -: QOS_TAG_WIDTH];
    assign tx_data_if.is_bad_frame = output_queue_rd_tuser[KEEP_WIDTH + QOS_TAG_WIDTH];
    assign tx_data_if.keep         = output_queue_rd_tuser[KEEP_WIDTH-1:0];
    assign tx_data_if.valid        = output_queue_rd_tvalid;
    assign tx_data_if.last         = output_queue_rd_tlast;

    //==============================================================================
    // Instantiated Modules
    //==============================================================================

    axis_fifo #(
        .TDATA_WIDTH(W_MINI),
        .TUSER_WIDTH(OUTPUT_QUEUE_TUSER_ACTUAL),         // MODIFIED: Use actual width
        .FIFO_DEPTH(OUTPUT_QUEUE_DEPTH),
        .PROG_FULL_THRESH(OQ_PROG_FULL_THRESH)
    ) output_queue_inst (
        .async_rst      ('0),
        .clk            (clk),
        .wr_tdata       (output_queue_wr_tdata),
        .wr_tuser       (output_queue_wr_tuser),
        .wr_tvalid      (output_queue_wr_tvalid),
        .wr_tlast       (output_queue_wr_tlast),
        .wr_tready      (output_queue_wr_tready),
        .wr_prog_full   (output_queue_wr_prog_full),
        .rd_tdata       (output_queue_rd_tdata),
        .rd_tuser       (output_queue_rd_tuser),
        .rd_tvalid      (output_queue_rd_tvalid),
        .rd_tlast       (output_queue_rd_tlast),
        .rd_tready      (output_queue_rd_tready),
        .rd_almost_empty(output_queue_rd_almost_empty)
    );

endmodule

`default_nettype wire