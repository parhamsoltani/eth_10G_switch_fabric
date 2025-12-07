`timescale 1ns / 1ps
// `default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Company: IUST
// Engineer: Parham Soltani
//
// Create Date:  2025-11-25
// Module Name: ingress_line_qos
// Description: Enhanced ingress with QoS classification
// Extends your existing ingress_switch.sv with header parsing
//////////////////////////////////////////////////////////////////////////////////

`include "fabric_params.vh"

module ingress_line_qos #(
    parameter NUM_PORT          = `NUM_PORTS,
    parameter W_MINI            = `DATA_WIDTH,
    parameter KEEP_WIDTH        = $clog2((W_MINI/8) + 1),
    parameter PACKET_ID_WIDTH   = `PACKET_ID_WIDTH,
    parameter QOS_TAG_WIDTH     = `QOS_TAG_WIDTH,
    parameter INPUT_QUEUE_DEPTH = 16,
    parameter INPUT_QUEUE_TUSER = PACKET_ID_WIDTH + 1 + KEEP_WIDTH + QOS_TAG_WIDTH
)(
    input  wire clk,
    input  wire rst_n,

    // External RX interface
    switch_data_if.slave_mp     rx_data_if,
    switch_metadata_if.slave_mp rx_meta_if,

    // To fabric (same as your existing ingress_switch outputs)
    output wire                         rd_en_rx,
    output wire [W_MINI-1:0]           data_rx,
    output wire [KEEP_WIDTH-1:0]       keep_rx,
    output wire                         valid_rx,
    output wire                         is_bad_frame_rx,
    output wire [PACKET_ID_WIDTH-1:0]  packet_id_rx,
    output wire                         last_rx,
    output wire                         iq_fifo_almost_empty,
    output wire [NUM_PORT-1:0]         dest_mask_rx,
    output wire                         dest_mask_valid_rx,
    output wire [QOS_TAG_WIDTH-1:0]    qos_tag_rx,  // NEW

    // QoS controls
    input  wire use_vlan_pcp,
    input  wire use_ip_dscp,
    input  wire use_port_classify
);

    //========== Input Queue (reuse your axis_fifo) ==========
    wire [W_MINI-1:0]           iq_wr_tdata;
    wire [INPUT_QUEUE_TUSER-1:0] iq_wr_tuser;
    wire                         iq_wr_tvalid;
    wire                         iq_wr_tlast;
    wire                         iq_wr_tready;

    wire [W_MINI-1:0]           iq_rd_tdata;
    wire [INPUT_QUEUE_TUSER-1:0] iq_rd_tuser;
    wire                         iq_rd_tvalid;
    wire                         iq_rd_tlast;
    wire                         iq_rd_tready;
    wire                         iq_rd_almost_empty;

    //========== Header Parsing ==========
    logic [15:0] ethertype_reg;
    logic [2:0]  vlan_pcp_reg;
    logic [7:0]  ip_tos_reg;
    logic [15:0] tcp_src_port_reg;
    logic [15:0] tcp_dst_port_reg;
    logic        is_first_beat;

    always_ff @(posedge clk) begin
        if (rx_data_if.valid && rx_data_if.ready) begin
            if (is_first_beat) begin
                // Extract headers (simplified - assumes Ethernet + IPv4 + TCP)
                // Adjust bit positions based on your actual packet format
                ethertype_reg <= rx_data_if.data[111:96];  // Byte 12-13
                vlan_pcp_reg  <= rx_data_if.data[127:125]; // VLAN tag PCP
                ip_tos_reg    <= rx_data_if.data[71:64];   // IP TOS field
                tcp_src_port_reg <= rx_data_if.data[47:32];
                tcp_dst_port_reg <= rx_data_if.data[31:16];
            end

            is_first_beat <= rx_data_if.last;  // Next beat is first of new packet
        end
    end

    //========== QoS Classification ==========
    wire [QOS_TAG_WIDTH-1:0] classified_qos;

    qos_classifier #(
        .QOS_TAG_WIDTH(QOS_TAG_WIDTH),
        .DATA_WIDTH(W_MINI)
    ) classifier (
        .clk(clk),
        .rst_n(rst_n),
        .ethertype(ethertype_reg),
        .vlan_pcp(vlan_pcp_reg),
        .ip_tos(ip_tos_reg),
        .tcp_src_port(tcp_src_port_reg),
        .tcp_dst_port(tcp_dst_port_reg),
        .use_vlan_pcp(use_vlan_pcp),
        .use_ip_dscp(use_ip_dscp),
        .use_port_classify(use_port_classify),
        .qos_tag(classified_qos)
    );

    //========== Input Queue (match your axis_fifo usage) ==========
    assign iq_wr_tdata  = rx_data_if.data;
    assign iq_wr_tuser  = {classified_qos, rx_data_if.id, rx_data_if.is_bad_frame, rx_data_if.keep};
    assign iq_wr_tvalid = rx_data_if.valid;
    assign iq_wr_tlast  = rx_data_if.last;
    assign rx_data_if.ready = iq_wr_tready;

    axis_fifo #(
        .TDATA_WIDTH(W_MINI),
        .TUSER_WIDTH(INPUT_QUEUE_TUSER),
        .FIFO_DEPTH(INPUT_QUEUE_DEPTH)
    ) input_queue (
        .async_rst('0),
        .clk(clk),
        .wr_tdata(iq_wr_tdata),
        .wr_tuser(iq_wr_tuser),
        .wr_tvalid(iq_wr_tvalid),
        .wr_tlast(iq_wr_tlast),
        .wr_tready(iq_wr_tready),
        .wr_prog_full(),
        .rd_tdata(iq_rd_tdata),
        .rd_tuser(iq_rd_tuser),
        .rd_tvalid(iq_rd_tvalid),
        .rd_tlast(iq_rd_tlast),
        .rd_tready(iq_rd_tready),
        .rd_almost_empty(iq_rd_almost_empty)
    );

    //========== Output Assignments ==========
    assign data_rx            = iq_rd_tdata;
    assign keep_rx            = iq_rd_tuser[KEEP_WIDTH-1:0];
    assign is_bad_frame_rx    = iq_rd_tuser[KEEP_WIDTH];
    assign packet_id_rx       = iq_rd_tuser[KEEP_WIDTH+PACKET_ID_WIDTH:KEEP_WIDTH+1];
    assign qos_tag_rx         = iq_rd_tuser[INPUT_QUEUE_TUSER-1:KEEP_WIDTH+PACKET_ID_WIDTH+1];
    assign valid_rx           = iq_rd_tvalid;
    assign last_rx            = iq_rd_tlast;
    assign iq_fifo_almost_empty = iq_rd_almost_empty;
    assign iq_rd_tready       = rd_en_rx;

    // Metadata passthrough (your existing pattern)
    assign dest_mask_rx       = rx_meta_if.dest_port_mask;
    assign dest_mask_valid_rx = rx_meta_if.valid;
    assign rx_meta_if.ready   = 1'b1;  // Always ready for metadata

endmodule

`default_nettype wire