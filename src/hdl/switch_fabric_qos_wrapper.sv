`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: IUST
// Engineer: Parham Soltani
//
// Create Date:  2025-11-25
// Module Name: switch_fabric_qos_wrapper
// Description: Top-level wrapper with runtime QoS enable/disable
// FIXED: Corrected interface connections to match actual module ports
//////////////////////////////////////////////////////////////////////////////////

`include "fabric_params.vh"
`include "implement_options.vh"

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
    parameter   ENABLE_QOS              = 1
) (
    input   wire                                clk,
    input   wire                                reset,

    // Data interfaces
    switch_data_if.slave                        rx_data_if  [NUM_PORT],
    switch_metadata_if.slave                    rx_meta_if  [NUM_PORT],
    switch_data_if.master                       tx_data_if  [NUM_PORT],

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
    localparam QOS_LEVELS = `QOS_LEVELS;

    //==========================================================================
    // Internal Reset
    //==========================================================================
    wire rst_n = ~reset;

    //==========================================================================
    // Internal wires for fabric
    //==========================================================================
    // RX path to fabric
    wire [W_MINI-1:0]           fabric_data_rx      [NUM_PORT];
    wire [KEEP_WIDTH-1:0]       fabric_keep_rx      [NUM_PORT];
    wire                        fabric_valid_rx     [NUM_PORT];
    wire                        fabric_is_bad_frame_rx [NUM_PORT];
    wire [PACKET_ID_WIDTH-1:0]  fabric_packet_id_rx [NUM_PORT];
    wire                        fabric_last_rx      [NUM_PORT];
    wire                        fabric_iq_almost_empty [NUM_PORT];
    wire [NUM_PORT-1:0]         fabric_dest_mask_rx [NUM_PORT];
    wire                        fabric_dest_mask_valid_rx [NUM_PORT];
    wire                        fabric_rd_en_rx     [NUM_PORT];

    // TX path from fabric
    wire [W_MINI-1:0]           fabric_data_tx      [NUM_PORT];
    wire [KEEP_WIDTH-1:0]       fabric_keep_tx      [NUM_PORT];
    wire                        fabric_valid_tx     [NUM_PORT];
    wire                        fabric_is_bad_frame_tx [NUM_PORT];
    wire                        fabric_last_tx      [NUM_PORT];
    wire [PACKET_ID_WIDTH-1:0]  fabric_packet_id_tx [NUM_PORT];
    wire [QOS_TAG_WIDTH-1:0]    fabric_qos_tag_tx   [NUM_PORT];
    wire                        fabric_oq_prog_full [NUM_PORT];

    // QoS controls from microinterface
    wire qos_enable_rt;
    wire use_vlan_pcp_rt;
    wire use_ip_dscp_rt;
    wire use_port_classify_rt;
    wire [15:0] aging_threshold_rt;

    // Statistics for micro interface
    reg [31:0] rx_pkt_count [NUM_PORT];
    reg [31:0] tx_pkt_count [NUM_PORT];
    reg [31:0] drop_count   [NUM_PORT];
    reg [31:0] qos_stats    [NUM_PORT][QOS_LEVELS];

    //==========================================================================
    // Interface to Wire Conversion (RX Path - Input Stage)
    //==========================================================================
    generate
        for (genvar i = 0; i < NUM_PORT; i++) begin : gen_rx_interface_conv

            // Input queue FIFO for each port
            localparam IQ_TUSER_WIDTH = 1 + PACKET_ID_WIDTH + KEEP_WIDTH;
            
            wire [W_MINI-1:0]           iq_wr_tdata;
            wire [IQ_TUSER_WIDTH-1:0]   iq_wr_tuser;
            wire                        iq_wr_tvalid;
            wire                        iq_wr_tlast;
            wire                        iq_wr_tready;
            
            wire [W_MINI-1:0]           iq_rd_tdata;
            wire [IQ_TUSER_WIDTH-1:0]   iq_rd_tuser;
            wire                        iq_rd_tvalid;
            wire                        iq_rd_tlast;
            wire                        iq_rd_tready;
            wire                        iq_rd_almost_empty;

            // Connect from interface to FIFO input
            assign iq_wr_tdata  = rx_data_if[i].data;
            assign iq_wr_tuser  = {rx_data_if[i].is_bad_frame, rx_data_if[i].id[PACKET_ID_WIDTH-1:0], rx_data_if[i].keep};
            assign iq_wr_tvalid = rx_data_if[i].valid;
            assign iq_wr_tlast  = rx_data_if[i].last;
            assign rx_data_if[i].ready = iq_wr_tready;

            // Input Queue FIFO
            axis_fifo #(
                .TDATA_WIDTH(W_MINI),
                .TUSER_WIDTH(IQ_TUSER_WIDTH),
                .FIFO_DEPTH(16),
                .PROG_FULL_THRESH(12)
            ) input_queue_inst (
                .async_rst      (reset),
                .clk            (clk),
                .wr_tdata       (iq_wr_tdata),
                .wr_tuser       (iq_wr_tuser),
                .wr_tvalid      (iq_wr_tvalid),
                .wr_tlast       (iq_wr_tlast),
                .wr_tready      (iq_wr_tready),
                .wr_prog_full   (),
                .rd_tdata       (iq_rd_tdata),
                .rd_tuser       (iq_rd_tuser),
                .rd_tvalid      (iq_rd_tvalid),
                .rd_tlast       (iq_rd_tlast),
                .rd_tready      (iq_rd_tready),
                .rd_almost_empty(iq_rd_almost_empty)
            );

            // Connect FIFO output to fabric
            assign iq_rd_tready = fabric_rd_en_rx[i];
            
            assign fabric_data_rx[i]        = iq_rd_tdata;
            assign fabric_keep_rx[i]        = iq_rd_tuser[KEEP_WIDTH-1:0];
            assign fabric_packet_id_rx[i]   = iq_rd_tuser[KEEP_WIDTH +: PACKET_ID_WIDTH];
            assign fabric_is_bad_frame_rx[i]= iq_rd_tuser[IQ_TUSER_WIDTH-1];
            assign fabric_valid_rx[i]       = iq_rd_tvalid;
            assign fabric_last_rx[i]        = iq_rd_tlast;
            assign fabric_iq_almost_empty[i]= iq_rd_almost_empty;

            // Destination mask from metadata interface
            assign fabric_dest_mask_rx[i]       = rx_meta_if[i].dest_port_mask;
            assign fabric_dest_mask_valid_rx[i] = rx_meta_if[i].valid;
            assign rx_meta_if[i].ready          = 1'b1;  // Always accept metadata

        end
    endgenerate

    //==========================================================================
    // Egress Modules (TX Path - Output Stage)
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
                .NOT_READY_LIMIT(20),
                .PACKET_ID_WIDTH(PACKET_ID_WIDTH),
                .QOS_TAG_WIDTH(QOS_TAG_WIDTH)
            ) u_egress (
                .clk(clk),
                .tx_data_if(tx_data_if[i]),
                .data_tx(fabric_data_tx[i]),
                .keep_tx(fabric_keep_tx[i]),
                .valid_tx(fabric_valid_tx[i]),
                .is_bad_frame_tx(fabric_is_bad_frame_tx[i]),
                .last_tx(fabric_last_tx[i]),
                .packet_id_tx(fabric_packet_id_tx[i]),
                .qos_tag_tx(fabric_qos_tag_tx[i]),
                .oq_wr_prog_full(fabric_oq_prog_full[i])
            );

        end
    endgenerate

    //==========================================================================
    // Core Switch Fabric
    //==========================================================================
    generate
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
    // Statistics Collection
    //==========================================================================
    generate
        for (genvar i = 0; i < NUM_PORT; i++) begin : gen_stats
            // RX packet counter
            always @(posedge clk) begin
                if (reset) begin
                    rx_pkt_count[i] <= 32'h0;
                end else if (fabric_valid_rx[i] && fabric_rd_en_rx[i] && fabric_last_rx[i]) begin
                    rx_pkt_count[i] <= rx_pkt_count[i] + 1;
                end
            end

            // TX packet counter
            always @(posedge clk) begin
                if (reset) begin
                    tx_pkt_count[i] <= 32'h0;
                end else if (fabric_valid_tx[i] && fabric_last_tx[i]) begin
                    tx_pkt_count[i] <= tx_pkt_count[i] + 1;
                end
            end

            // Drop counter (placeholder - would need actual drop signal from fabric)
            always @(posedge clk) begin
                if (reset) begin
                    drop_count[i] <= 32'h0;
                end
            end

            // QoS statistics (placeholder)
            for (genvar q = 0; q < QOS_LEVELS; q++) begin : gen_qos_stats
                always @(posedge clk) begin
                    if (reset) begin
                        qos_stats[i][q] <= 32'h0;
                    end
                end
            end
        end
    endgenerate

    //==========================================================================
    // Microprocessor Interface with QoS Statistics
    //==========================================================================
    
    // AXI handshake state machine signals
    reg        axi_awready_reg;
    reg        axi_wready_reg;
    reg        axi_bvalid_reg;
    reg        axi_arready_reg;
    reg        axi_rvalid_reg;
    reg [31:0] axi_rdata_reg;

    micro_interface_qos_enhanced #(
        .NUM_PORTS(NUM_PORT),
        .ADDR_WIDTH(16),
        .DATA_WIDTH(32),
        .QOS_LEVELS(QOS_LEVELS)
    ) u_micro_if (
        .clk(clk),
        .rst_n(rst_n),

        // AXI4-Lite interface
        .s_axi_awaddr(uif_addr),
        .s_axi_awvalid(uif_wr_en),
        .s_axi_awready(),

        .s_axi_wdata(uif_wr_data),
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

        // QoS Configuration Outputs
        .qos_enable(qos_enable_rt),
        .use_vlan_pcp(use_vlan_pcp_rt),
        .use_ip_dscp(use_ip_dscp_rt),
        .use_port_classify(use_port_classify_rt),
        .aging_threshold(aging_threshold_rt),

        // Statistics Inputs
        .rx_pkt_count(rx_pkt_count),
        .tx_pkt_count(tx_pkt_count),
        .drop_count(drop_count),
        .qos_stats(qos_stats)
    );

    //==========================================================================
    // Statistics overflow detection (placeholder)
    //==========================================================================
    assign qos_stats_overflow = {NUM_PORT{1'b0}};

endmodule

`default_nettype wire