`timescale 1ns / 1ps
`default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Company: Parman
// Engineer: Alireza Abbasian
//
// Create Date:  2025-11-25
// Module Name: ingress_line_wrapper
// Description: Parametric wrapper switching between QoS-aware and standard ingress
// Maintains backward compatibility with your existing designs
//////////////////////////////////////////////////////////////////////////////////

`include "fabric_params.vh"

module ingress_line_wrapper #(
    parameter NUM_PORT          = `NUM_PORTS,
    parameter W_MINI            = `DATA_WIDTH,
    parameter KEEP_WIDTH        = $clog2((W_MINI/8) + 1),
    parameter PACKET_ID_WIDTH   = `PACKET_ID_WIDTH,
    parameter QOS_TAG_WIDTH     = `QOS_TAG_WIDTH,
    parameter INPUT_QUEUE_DEPTH = 16,
    parameter ENABLE_QOS        = 0  // 0 = standard, 1 = QoS-aware
)(
    input  wire clk,
    input  wire rst_n,

    switch_data_if.slave_mp     rx_data_if,
    switch_metadata_if.slave_mp rx_meta_if,

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
    output wire [QOS_TAG_WIDTH-1:0]    qos_tag_rx,

    // QoS controls (ignored if ENABLE_QOS=0)
    input  wire use_vlan_pcp,
    input  wire use_ip_dscp,
    input  wire use_port_classify
);

    //==========================================================================
    // Generate Selection
    //==========================================================================
    generate
        if (ENABLE_QOS) begin : gen_qos_ingress

            localparam INPUT_QUEUE_TUSER = PACKET_ID_WIDTH + 1 + KEEP_WIDTH + QOS_TAG_WIDTH;

            ingress_line_qos #(
                .NUM_PORT(NUM_PORT),
                .W_MINI(W_MINI),
                .KEEP_WIDTH(KEEP_WIDTH),
                .PACKET_ID_WIDTH(PACKET_ID_WIDTH),
                .QOS_TAG_WIDTH(QOS_TAG_WIDTH),
                .INPUT_QUEUE_DEPTH(INPUT_QUEUE_DEPTH),
                .INPUT_QUEUE_TUSER(INPUT_QUEUE_TUSER)
            ) u_ingress_qos (
                .clk(clk),
                .rst_n(rst_n),
                .rx_data_if(rx_data_if),
                .rx_meta_if(rx_meta_if),
                .rd_en_rx(rd_en_rx),
                .data_rx(data_rx),
                .keep_rx(keep_rx),
                .valid_rx(valid_rx),
                .is_bad_frame_rx(is_bad_frame_rx),
                .packet_id_rx(packet_id_rx),
                .last_rx(last_rx),
                .iq_fifo_almost_empty(iq_fifo_almost_empty),
                .dest_mask_rx(dest_mask_rx),
                .dest_mask_valid_rx(dest_mask_valid_rx),
                .qos_tag_rx(qos_tag_rx),
                .use_vlan_pcp(use_vlan_pcp),
                .use_ip_dscp(use_ip_dscp),
                .use_port_classify(use_port_classify)
            );

        end else begin : gen_standard_ingress

            localparam INPUT_QUEUE_TUSER = PACKET_ID_WIDTH + 1 + KEEP_WIDTH;

            ingress_switch #(
                .NUM_PORT(NUM_PORT),
                .W_MINI(W_MINI),
                .KEEP_WIDTH(KEEP_WIDTH),
                .PACKET_ID_WIDTH(PACKET_ID_WIDTH),
                .QOS_TAG_WIDTH(1),  // Dummy
                .INPUT_QUEUE_DEPTH(INPUT_QUEUE_DEPTH),
                .INPUT_QUEUE_TUSER(INPUT_QUEUE_TUSER)
            ) u_ingress_std (
                .clk(clk),
                .rx_data_if(rx_data_if),
                .rx_meta_if(rx_meta_if),
                .rd_en_rx(rd_en_rx),
                .data_rx(data_rx),
                .keep_rx(keep_rx),
                .valid_rx(valid_rx),
                .is_bad_frame_rx(is_bad_frame_rx),
                .packet_id_rx(packet_id_rx),
                .last_rx(last_rx),
                .iq_fifo_almost_empty(iq_fifo_almost_empty),
                .dest_mask_rx(dest_mask_rx),
                .dest_mask_valid_rx(dest_mask_valid_rx)
            );

            // Default QoS tag when QoS disabled
            assign qos_tag_rx = `PRIORITY_MEDIUM;

        end
    endgenerate

endmodule

`default_nettype wire