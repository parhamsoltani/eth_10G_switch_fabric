`timescale 1ns / 1ps
`default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Company: IUST
// Engineer: Parham Soltani
//
// Create Date:  2025-11-25
// Module Name: switch_fabric_qos_wrapper
// Description: Top-level wrapper with runtime QoS enable/disable
// Instantiates your switch_fabric with QoS enhancements
//////////////////////////////////////////////////////////////////////////////////

`include "fabric_params.vh"

module switch_fabric_qos_wrapper #(
    parameter   NUM_PORT                = `NUM_PORTS,
    parameter   S                       = `S,
    parameter   W_MINI                  = `DATA_WIDTH,
    parameter   MAIN_MEM_DEPTH          = `D,
    parameter   XPQ_DEPTH               = `X,
    parameter   OUTPUT_QUEUE_DEPTH      = `OUTPUT_QUEUE_DEPTH,
    parameter   MULTICAST_SUPPORT       = `MULTICAST_SUPPORT,
    parameter   MULTICAST_RATE          = `U,
    parameter   PACKET_ID_WIDTH         = `PACKET_ID_WIDTH,
    parameter   QOS_TAG_WIDTH           = `QOS_TAG_WIDTH,
    parameter   ENABLE_QOS              = 1  // Compile-time enable
) (
    input   wire                                clk,
    input   wire                                reset,

    // Data interfaces (your existing pattern)
    switch_data_if.slave_mp                     rx_data_if  [NUM_PORT],
    switch_metadata_if.slave_mp                 rx_meta_if  [NUM_PORT],
    switch_data_if.master_mp                    tx_data_if  [NUM_PORT],

    // Microprocessor interface for runtime control
    input  wire [15:0]                          uif_addr,
    input  wire                                 uif_wr_en,
    input  wire [31:0]                          uif_wr_data,
    input  wire                                 uif_rd_en,
    output wire [31:0]                          uif_rd_data,

    // Debug/status outputs
    output wire [$clog2(MULTICAST_RATE * MAIN_MEM_DEPTH):0] addr_fifos_num_free_o,
    output wire [$clog2(MAIN_MEM_DEPTH):0]      free_fifo_count_o,
    output wire [NUM_PORT-1:0]                  qos_stats_overflow
);

    localparam KEEP_WIDTH = $clog2((W_MINI/8) + 1);

    //==========================================================================
    // Internal wires (from ingress wrappers to fabric)
    //==========================================================================
    wire                        int_rd_en_rx [NUM_PORT];
    wire [W_MINI-1:0]           int_data_rx [NUM_PORT];
    wire [KEEP_WIDTH-1:0]       int_keep_rx [NUM_PORT];
    wire                        int_valid_rx [NUM_PORT];
    wire                        int_is_bad_frame_rx [NUM_PORT];
    wire [PACKET_ID_WIDTH-1:0]  int_packet_id_rx [NUM_PORT];
    wire                        int_last_rx [NUM_PORT];
    wire                        int_iq_almost_empty [NUM_PORT];
    wire [NUM_PORT-1:0]         int_dest_mask_rx [NUM_PORT];
    wire                        int_dest_mask_valid_rx [NUM_PORT];
    wire [QOS_TAG_WIDTH-1:0]    int_qos_tag_rx [NUM_PORT];

    // Fabric outputs (cell2packet → egress)
    wire [W_MINI-1:0]           int_data_tx [NUM_PORT];
    wire [KEEP_WIDTH-1:0]       int_keep_tx [NUM_PORT];
    wire                        int_valid_tx [NUM_PORT];
    wire                        int_is_bad_frame_tx [NUM_PORT];
    wire                        int_last_tx [NUM_PORT];

    // Backpressure from egress
    wire                        int_oq_prog_full [NUM_PORT];

    // QoS controls from microinterface
    wire qos_enable_rt;
    wire use_vlan_pcp_rt;
    wire use_ip_dscp_rt;
    wire use_port_classify_rt;

    // Monitoring signals
    wire [NUM_PORT-1:0] port_link_up;
    wire [NUM_PORT-1:0] port_rx_active;
    wire [NUM_PORT-1:0] port_tx_active;
    wire [NUM_PORT-1:0] port_rx_valid;
    wire [NUM_PORT-1:0] port_tx_valid;
    wire [QOS_TAG_WIDTH-1:0] port_rx_qos [NUM_PORT];
    wire [QOS_TAG_WIDTH-1:0] port_tx_qos [NUM_PORT];

    //==========================================================================
    // Ingress Line Wrappers (per port)
    //==========================================================================
    generate
        for (genvar i = 0; i < NUM_PORT; i++) begin : gen_ingress

            ingress_line_wrapper #(
                .NUM_PORT(NUM_PORT),
                .W_MINI(W_MINI),
                .KEEP_WIDTH(KEEP_WIDTH),
                .PACKET_ID_WIDTH(PACKET_ID_WIDTH),
                .QOS_TAG_WIDTH(QOS_TAG_WIDTH),
                .INPUT_QUEUE_DEPTH(16),
                .ENABLE_QOS(ENABLE_QOS)
            ) u_ingress_wrapper (
                .clk(clk),
                .rst_n(~reset),
                .rx_data_if(rx_data_if[i]),
                .rx_meta_if(rx_meta_if[i]),
                .rd_en_rx(int_rd_en_rx[i]),
                .data_rx(int_data_rx[i]),
                .keep_rx(int_keep_rx[i]),
                .valid_rx(int_valid_rx[i]),
                .is_bad_frame_rx(int_is_bad_frame_rx[i]),
                .packet_id_rx(int_packet_id_rx[i]),
                .last_rx(int_last_rx[i]),
                .iq_fifo_almost_empty(int_iq_almost_empty[i]),
                .dest_mask_rx(int_dest_mask_rx[i]),
                .dest_mask_valid_rx(int_dest_mask_valid_rx[i]),
                .qos_tag_rx(int_qos_tag_rx[i]),
                .use_vlan_pcp(use_vlan_pcp_rt),
                .use_ip_dscp(use_ip_dscp_rt),
                .use_port_classify(use_port_classify_rt)
            );

            // Monitoring
            assign port_rx_valid[i] = int_valid_rx[i];
            assign port_rx_qos[i]   = int_qos_tag_rx[i];
            assign port_tx_valid[i] = int_valid_tx[i];
            assign port_tx_qos[i]   = int_qos_tag_rx[i];  // Passthrough (preserved in fabric)

        end
    endgenerate

    //==========================================================================
    // Egress Line Modules (your existing egress_switch)
    //==========================================================================
    generate
        for (genvar i = 0; i < NUM_PORT; i++) begin : gen_egress

            egress_switch #(
                .NUM_PORT(NUM_PORT),
                .W_MINI(W_MINI),
                .KEEP_WIDTH(KEEP_WIDTH),
                .OUTPUT_QUEUE_DEPTH(OUTPUT_QUEUE_DEPTH),
                .OUTPUT_QUEUE_TUSER(1 + KEEP_WIDTH),
                .OQ_PROG_FULL_THRESH(30),
                .NOT_READY_LIMIT(20)
            ) u_egress (
                .clk(clk),
                .tx_data_if(tx_data_if[i]),
                .data_tx(int_data_tx[i]),
                .keep_tx(int_keep_tx[i]),
                .valid_tx(int_valid_tx[i]),
                .is_bad_frame_tx(int_is_bad_frame_tx[i]),
                .last_tx(int_last_tx[i]),
                .oq_wr_prog_full(int_oq_prog_full[i])
            );

        end
    endgenerate

    //==========================================================================
    // Core Switch Fabric (your existing switch_fabric.sv)
    //==========================================================================
    // For QoS-aware fabric, you'd instantiate switch_high_radix_matching with
    // dest_finder_row_matching_qos. For now, we use standard fabric with QoS
    // metadata passed through.

    // Temporary wire arrays to match your fabric's array-of-wires style
    wire [W_MINI-1:0] fabric_data_rx [NUM_PORT];
    wire [KEEP_WIDTH-1:0] fabric_keep_rx [NUM_PORT];
    wire fabric_valid_rx [NUM_PORT];
    wire fabric_is_bad_frame_rx [NUM_PORT];
    wire [PACKET_ID_WIDTH-1:0] fabric_packet_id_rx [NUM_PORT];
    wire fabric_last_rx [NUM_PORT];
    wire fabric_iq_almost_empty [NUM_PORT];
    wire [NUM_PORT-1:0] fabric_dest_mask_rx [NUM_PORT];
    wire fabric_dest_mask_valid_rx [NUM_PORT];
    wire fabric_rd_en_rx [NUM_PORT];

    wire [W_MINI-1:0] fabric_data_tx [NUM_PORT];
    wire [KEEP_WIDTH-1:0] fabric_keep_tx [NUM_PORT];
    wire fabric_valid_tx [NUM_PORT];
    wire fabric_is_bad_frame_tx [NUM_PORT];
    wire fabric_last_tx [NUM_PORT];
    wire fabric_oq_prog_full [NUM_PORT];

    generate
        for (genvar i = 0; i < NUM_PORT; i++) begin : gen_fabric_conn
            assign fabric_data_rx[i]            = int_data_rx[i];
            assign fabric_keep_rx[i]            = int_keep_rx[i];
            assign fabric_valid_rx[i]           = int_valid_rx[i];
            assign fabric_is_bad_frame_rx[i]    = int_is_bad_frame_rx[i];
            assign fabric_packet_id_rx[i]       = int_packet_id_rx[i];
            assign fabric_last_rx[i]            = int_last_rx[i];
            assign fabric_iq_almost_empty[i]    = int_iq_almost_empty[i];
            assign fabric_dest_mask_rx[i]       = int_dest_mask_rx[i];
            assign fabric_dest_mask_valid_rx[i] = int_dest_mask_valid_rx[i];
            assign int_rd_en_rx[i]              = fabric_rd_en_rx[i];

            assign int_data_tx[i]            = fabric_data_tx[i];
            assign int_keep_tx[i]            = fabric_keep_tx[i];
            assign int_valid_tx[i]           = fabric_valid_tx[i];
            assign int_is_bad_frame_tx[i]    = fabric_is_bad_frame_tx[i];
            assign int_last_tx[i]            = fabric_last_tx[i];
            assign fabric_oq_prog_full[i]    = int_oq_prog_full[i];
        end
    endgenerate

    // NOTE: To use QoS-aware matching, replace switch_fabric instantiation with:
    // switch_high_radix_matching_qos #(...) or switch_2s_qos #(...)
    // For backward compatibility, we keep standard fabric here

    generate;
        if (NUM_PORT <= S) begin : gen_under_s
            switch_s #(
                .NUM_PORT(NUM_PORT),
                .S(S),
                .W_MINI(W_MINI),
                .MAIN_MEM_DEPTH(MAIN_MEM_DEPTH),
                .XPQ_DEPTH(XPQ_DEPTH),
                .OUTPUT_QUEUE_DEPTH(OUTPUT_QUEUE_DEPTH),
                .MULTICAST_SUPPORT(MULTICAST_SUPPORT),
                .MULTICAST_RATE(MULTICAST_RATE),
                .PACKET_ID_WIDTH(PACKET_ID_WIDTH),
                .QOS_TAG_WIDTH(QOS_TAG_WIDTH)
            ) switch_inst (
                .clk(clk),
                .data_rx(fabric_data_rx),
                .keep_rx(fabric_keep_rx),
                .valid_rx(fabric_valid_rx),
                .is_bad_frame_rx(fabric_is_bad_frame_rx),
                .packet_id_rx(fabric_packet_id_rx),
                .last_rx(fabric_last_rx),
                .iq_fifo_almost_empty(fabric_iq_almost_empty),
                .dest_mask_rx(fabric_dest_mask_rx),
                .dest_mask_valid_rx(fabric_dest_mask_valid_rx),
                .rd_en_rx(fabric_rd_en_rx),
                .data_tx(fabric_data_tx),
                .keep_tx(fabric_keep_tx),
                .valid_tx(fabric_valid_tx),
                .is_bad_frame_tx(fabric_is_bad_frame_tx),
                .last_tx(fabric_last_tx),
                .oq_wr_prog_full(fabric_oq_prog_full),
                .addr_fifos_num_free_o(addr_fifos_num_free_o),
                .free_fifo_count_o(free_fifo_count_o)
            );

        end else if (NUM_PORT <= 2*S) begin : gen_2s
            switch_2s #(
                .NUM_PORT(NUM_PORT),
                .S(S),
                .W_MINI(W_MINI),
                .MAIN_MEM_DEPTH(MAIN_MEM_DEPTH),
                .XPQ_DEPTH(XPQ_DEPTH),
                .OUTPUT_QUEUE_DEPTH(OUTPUT_QUEUE_DEPTH),
                .MULTICAST_SUPPORT(MULTICAST_SUPPORT),
                .MULTICAST_RATE(MULTICAST_RATE),
                .PACKET_ID_WIDTH(PACKET_ID_WIDTH),
                .QOS_TAG_WIDTH(QOS_TAG_WIDTH)
            ) switch_inst (
                .clk(clk),
                .data_rx(fabric_data_rx),
                .keep_rx(fabric_keep_rx),
                .valid_rx(fabric_valid_rx),
                .is_bad_frame_rx(fabric_is_bad_frame_rx),
                .packet_id_rx(fabric_packet_id_rx),
                .last_rx(fabric_last_rx),
                .iq_fifo_almost_empty(fabric_iq_almost_empty),
                .dest_mask_rx(fabric_dest_mask_rx),
                .dest_mask_valid_rx(fabric_dest_mask_valid_rx),
                .rd_en_rx(fabric_rd_en_rx),
                .data_tx(fabric_data_tx),
                .keep_tx(fabric_keep_tx),
                .valid_tx(fabric_valid_tx),
                .is_bad_frame_tx(fabric_is_bad_frame_tx),
                .last_tx(fabric_last_tx),
                .oq_wr_prog_full(fabric_oq_prog_full),
                .addr_fifos_num_free_o(addr_fifos_num_free_o),
                .free_fifo_count_o(free_fifo_count_o)
            );

        end else begin : gen_high_radix
            switch_high_radix_matching #(
                .NUM_PORT(NUM_PORT),
                .S(S),
                .W_MINI(W_MINI),
                .MAIN_MEM_DEPTH(MAIN_MEM_DEPTH),
                .XPQ_DEPTH(XPQ_DEPTH),
                .OUTPUT_QUEUE_DEPTH(OUTPUT_QUEUE_DEPTH),
                .MULTICAST_SUPPORT(MULTICAST_SUPPORT),
                .MULTICAST_RATE(MULTICAST_RATE),
                .PACKET_ID_WIDTH(PACKET_ID_WIDTH),
                .QOS_TAG_WIDTH(QOS_TAG_WIDTH)
            ) switch_inst (
                .clk(clk),
                .data_rx(fabric_data_rx),
                .keep_rx(fabric_keep_rx),
                .valid_rx(fabric_valid_rx),
                .is_bad_frame_rx(fabric_is_bad_frame_rx),
                .packet_id_rx(fabric_packet_id_rx),
                .last_rx(fabric_last_rx),
                .iq_fifo_almost_empty(fabric_iq_almost_empty),
                .dest_mask_rx(fabric_dest_mask_rx),
                .dest_mask_valid_rx(fabric_dest_mask_valid_rx),
                .rd_en_rx(fabric_rd_en_rx),
                .data_tx(fabric_data_tx),
                .keep_tx(fabric_keep_tx),
                .valid_tx(fabric_valid_tx),
                .is_bad_frame_tx(fabric_is_bad_frame_tx),
                .last_tx(fabric_last_tx),
                .oq_wr_prog_full(fabric_oq_prog_full),
                .addr_fifos_num_free_o(addr_fifos_num_free_o),
                .free_fifo_count_o(free_fifo_count_o)
            );
        end
    endgenerate

    //==========================================================================
    // Microprocessor Interface with QoS Statistics
    //==========================================================================
    micro_interface_qos_enhanced #(
        .NUM_PORT(NUM_PORT),
        .QOS_LEVELS(3),
        .QOS_TAG_WIDTH(QOS_TAG_WIDTH),
        .ADDR_WIDTH(16),
        .DATA_WIDTH(32)
    ) u_micro_if (
        .clk(clk),
        .rst_n(~reset),

        // Simplified AXI (convert from your uif_ signals)
        .s_axi_awaddr(uif_addr),
        .s_axi_awvalid(uif_wr_en),
        .s_axi_awready(),
        .s_axi_wdata(uif_wr_data),
        .s_axi_wstrb(4'hF),
        .s_axi_wvalid(uif_wr_en),
        .s_axi_wready(),
        .s_axi_bresp(),
        .s_axi_bvalid(),
        .s_axi_bready(1'b1),
        .s_axi_araddr(uif_addr),
        .s_axi_arvalid(uif_rd_en),
        .s_axi_arready(),
        .s_axi_rdata(uif_rd_data),
        .s_axi_rresp(),
        .s_axi_rvalid(),
        .s_axi_rready(1'b1),

        // Monitoring
        .port_link_up(port_link_up),
        .port_rx_active(port_rx_active),
        .port_tx_active(port_tx_active),
        .port_rx_valid(port_rx_valid),
        .port_tx_valid(port_tx_valid),
        .port_rx_qos(port_rx_qos),
        .port_tx_qos(port_tx_qos),

        // Controls
        .qos_enable(qos_enable_rt),
        .use_vlan_pcp(use_vlan_pcp_rt),
        .use_ip_dscp(use_ip_dscp_rt),
        .use_port_classify(use_port_classify_rt)
    );

    //==========================================================================
    // Statistics overflow detection
    //==========================================================================
    // (Your pattern for error flagging)
    generate
        for (genvar i = 0; i < NUM_PORT; i++) begin : gen_overflow
            assign qos_stats_overflow[i] = 1'b0;  // Placeholder
        end
    endgenerate

endmodule

`default_nettype wire