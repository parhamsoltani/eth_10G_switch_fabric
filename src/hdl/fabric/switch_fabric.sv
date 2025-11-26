`timescale 1ns / 1ps
`default_nettype none

`include "fabric_params.vh"

module switch_fabric #(
    parameter NUM_PORTS         = `NUM_PORTS,
    parameter DATA_WIDTH        = `DATA_WIDTH,
    parameter ID_WIDTH          = `PACKET_ID_WIDTH,
    parameter VOQ_DEPTH         = `VOQ_DEPTH_PER_QOS,
    parameter XPQ_DEPTH         = `XPQ_DEPTH,
    parameter PACKET_BUF_DEPTH  = `PACKET_BUFFER_DEPTH
)(
    input  logic clk,
    input  logic rst_n,

    // External interfaces
    switch_data_if.slave        rx_data_if [NUM_PORTS],
    switch_metadata_if.slave    rx_meta_if [NUM_PORTS],
    switch_data_if.master       tx_data_if [NUM_PORTS],

    // AXI4-Lite microprocessor interface (NEW)
    input  wire [15:0]          uif_awaddr,
    input  wire                 uif_awvalid,
    output wire                 uif_awready,
    input  wire [31:0]          uif_wdata,
    input  wire                 uif_wvalid,
    output wire                 uif_wready,
    output wire [1:0]           uif_bresp,
    output wire                 uif_bvalid,
    input  wire                 uif_bready,
    input  wire [15:0]          uif_araddr,
    input  wire                 uif_arvalid,
    output wire                 uif_arready,
    output wire [31:0]          uif_rdata,
    output wire [1:0]           uif_rresp,
    output wire                 uif_rvalid,
    input  wire                 uif_rready,

    // Statistics/debug
    output logic [31:0]         pkt_count_rx [NUM_PORTS],
    output logic [31:0]         pkt_count_tx [NUM_PORTS],
    output logic [31:0]         pkt_drop_count [NUM_PORTS],
    output logic [ID_WIDTH:0]   free_ids
);

    // =========================================================================
    // Internal Wiring
    // =========================================================================

    // Packet ID Manager
    logic [NUM_PORTS-1:0]   id_alloc_req;
    logic [NUM_PORTS-1:0]   id_alloc_grant;
    logic [ID_WIDTH-1:0]    allocated_id [NUM_PORTS];
    logic [NUM_PORTS-1:0]   id_release_req;
    logic [ID_WIDTH-1:0]    release_id [NUM_PORTS];

    // VOQ stage
    logic                   voq_wr_valid [NUM_PORTS][NUM_PORTS];
    logic [DATA_WIDTH-1:0]  voq_wr_data [NUM_PORTS];
    logic [DATA_WIDTH/8-1:0] voq_wr_keep [NUM_PORTS];
    logic                   voq_wr_last [NUM_PORTS];
    logic [ID_WIDTH-1:0]    voq_wr_id [NUM_PORTS];
    logic                   voq_wr_is_bad [NUM_PORTS];
    logic [2:0]             voq_wr_qos [NUM_PORTS];
    logic                   voq_wr_ready [NUM_PORTS][NUM_PORTS];

    logic                   voq_rd_valid [NUM_PORTS][NUM_PORTS];
    logic [DATA_WIDTH-1:0]  voq_rd_data [NUM_PORTS][NUM_PORTS];
    logic [DATA_WIDTH/8-1:0] voq_rd_keep [NUM_PORTS][NUM_PORTS];
    logic                   voq_rd_last [NUM_PORTS][NUM_PORTS];
    logic [ID_WIDTH-1:0]    voq_rd_id [NUM_PORTS][NUM_PORTS];
    logic                   voq_rd_is_bad [NUM_PORTS][NUM_PORTS];
    logic [2:0]             voq_rd_qos [NUM_PORTS][NUM_PORTS];
    logic                   voq_rd_ready [NUM_PORTS][NUM_PORTS];

    // XPQ stage
    logic                   xpq_wr_valid [NUM_PORTS][NUM_PORTS];
    logic [DATA_WIDTH-1:0]  xpq_wr_data [NUM_PORTS][NUM_PORTS];
    logic [DATA_WIDTH/8-1:0] xpq_wr_keep [NUM_PORTS][NUM_PORTS];
    logic                   xpq_wr_last [NUM_PORTS][NUM_PORTS];
    logic [ID_WIDTH-1:0]    xpq_wr_id [NUM_PORTS][NUM_PORTS];
    logic                   xpq_wr_is_bad [NUM_PORTS][NUM_PORTS];
    logic [2:0]             xpq_wr_qos [NUM_PORTS][NUM_PORTS];
    logic                   xpq_wr_ready [NUM_PORTS][NUM_PORTS];

    logic                   xpq_rd_valid [NUM_PORTS][NUM_PORTS];
    logic [DATA_WIDTH-1:0]  xpq_rd_data [NUM_PORTS][NUM_PORTS];
    logic [DATA_WIDTH/8-1:0] xpq_rd_keep [NUM_PORTS][NUM_PORTS];
    logic                   xpq_rd_last [NUM_PORTS][NUM_PORTS];
    logic [ID_WIDTH-1:0]    xpq_rd_id [NUM_PORTS][NUM_PORTS];
    logic                   xpq_rd_is_bad [NUM_PORTS][NUM_PORTS];
    logic [2:0]             xpq_rd_qos [NUM_PORTS][NUM_PORTS];
    logic                   xpq_rd_ready [NUM_PORTS][NUM_PORTS];

    // QoS configuration signals (from microprocessor)
    logic qos_enable_micro;
    logic use_vlan_pcp_micro;
    logic use_ip_dscp_micro;
    logic use_port_classify_micro;
    logic [15:0] aging_threshold;

    // =========================================================================
    // Packet ID Manager
    // =========================================================================

    packet_id_manager #(
        .ID_WIDTH(ID_WIDTH),
        .MAX_PORTS(NUM_PORTS)
    ) id_manager (
        .clk(clk),
        .rst_n(rst_n),
        .alloc_req(id_alloc_req),
        .alloc_grant(id_alloc_grant),
        .allocated_id(allocated_id),
        .release_req(id_release_req),
        .release_id(release_id),
        .free_id_count(free_ids)
    );

    //═══════════════════════════════════════════════════════════════════════════
    // Fabric Ingress (WITH QoS INTEGRATION)
    //═══════════════════════════════════════════════════════════════════════════

    generate
        for (genvar i = 0; i < NUM_PORTS; i++) begin : gen_ingress_port
            
            ingress_line_wrapper #(
                .DATA_WIDTH(DATA_WIDTH),
                .NUM_PORTS(NUM_PORTS),
                .ID_WIDTH(ID_WIDTH),
                .ENABLE_QOS(`ENABLE_QOS)  // CHANGED: Now uses wrapper
            ) ingress_inst (
                .clk(clk),
                .rst_n(rst_n),
                .rx_data_if(rx_data_if[i]),
                .rx_meta_if(rx_meta_if[i]),
                .voq_wr_valid(voq_wr_valid[i]),
                .voq_wr_data(voq_wr_data[i]),
                .voq_wr_keep(voq_wr_keep[i]),
                .voq_wr_last(voq_wr_last[i]),
                .voq_wr_id(voq_wr_id[i]),
                .voq_wr_is_bad(voq_wr_is_bad[i]),
                .voq_wr_qos(voq_wr_qos[i]),
                .voq_wr_ready(voq_wr_ready[i]),
                .id_alloc_req(id_alloc_req[i]),
                .id_alloc_grant(id_alloc_grant[i]),
                .allocated_id(allocated_id[i]),
                .qos_enable(qos_enable_micro),
                .use_vlan_pcp(use_vlan_pcp_micro),
                .use_ip_dscp(use_ip_dscp_micro),
                .use_port_classify(use_port_classify_micro)
            );

        end
    endgenerate

    // =========================================================================
    // VOQ Array (NUM_PORTS × NUM_PORTS)
    // =========================================================================

    genvar src, dst;
    generate
        for (src = 0; src < NUM_PORTS; src++) begin : gen_voq_src
            for (dst = 0; dst < NUM_PORTS; dst++) begin : gen_voq_dst

                voq_buffer #(
                    .DATA_WIDTH(DATA_WIDTH),
                    .ID_WIDTH(ID_WIDTH),
                    .DEPTH_PER_QOS(VOQ_DEPTH),
                    .NUM_QOS_LEVELS(`QOS_LEVELS)
                ) voq (
                    .clk(clk),
                    .rst_n(rst_n),

                    .wr_valid(voq_wr_valid[src][dst]),
                    .wr_data(voq_wr_data[src]),
                    .wr_keep(voq_wr_keep[src]),
                    .wr_last(voq_wr_last[src]),
                    .wr_id(voq_wr_id[src]),
                    .wr_is_bad(voq_wr_is_bad[src]),
                    .wr_qos(voq_wr_qos[src]),
                    .wr_ready(voq_wr_ready[src][dst]),

                    .rd_valid(voq_rd_valid[src][dst]),
                    .rd_data(voq_rd_data[src][dst]),
                    .rd_keep(voq_rd_keep[src][dst]),
                    .rd_last(voq_rd_last[src][dst]),
                    .rd_id(voq_rd_id[src][dst]),
                    .rd_is_bad(voq_rd_is_bad[src][dst]),
                    .rd_qos(voq_rd_qos[src][dst]),
                    .rd_ready(voq_rd_ready[src][dst]),

                    .occupancy(),
                    .empty(),
                    .almost_full()
                );

            end
        end
    endgenerate

    // =========================================================================
    // Crosspoint (Arbitration)
    // =========================================================================

    fabric_crosspoint #(
        .NUM_PORTS(NUM_PORTS),
        .DATA_WIDTH(DATA_WIDTH),
        .ID_WIDTH(ID_WIDTH)
    ) crosspoint (
        .clk(clk),
        .rst_n(rst_n),
        .voq_rd_valid(voq_rd_valid),
        .voq_rd_data(voq_rd_data),
        .voq_rd_keep(voq_rd_keep),
        .voq_rd_last(voq_rd_last),
        .voq_rd_id(voq_rd_id),
        .voq_rd_is_bad(voq_rd_is_bad),
        .voq_rd_qos(voq_rd_qos),
        .voq_rd_ready(voq_rd_ready),
        .xpq_wr_valid(xpq_wr_valid),
        .xpq_wr_data(xpq_wr_data),
        .xpq_wr_keep(xpq_wr_keep),
        .xpq_wr_last(xpq_wr_last),
        .xpq_wr_id(xpq_wr_id),
        .xpq_wr_is_bad(xpq_wr_is_bad),
        .xpq_wr_qos(xpq_wr_qos),
        .xpq_wr_ready(xpq_wr_ready)
    );

    // =========================================================================
    // XPQ Array (NUM_PORTS × NUM_PORTS)
    // =========================================================================

    generate
        for (src = 0; src < NUM_PORTS; src++) begin : gen_xpq_src
            for (dst = 0; dst < NUM_PORTS; dst++) begin : gen_xpq_dst

                packet_buffer #(
                    .DATA_WIDTH(DATA_WIDTH),
                    .MAX_PACKET_SIZE(512),
                    .BUFFER_DEPTH(XPQ_DEPTH),
                    .ID_WIDTH(ID_WIDTH)
                ) xpq (
                    .clk(clk),
                    .rst_n(rst_n),

                    .wr_valid(xpq_wr_valid[src][dst]),
                    .wr_data(xpq_wr_data[src][dst]),
                    .wr_keep(xpq_wr_keep[src][dst]),
                    .wr_last(xpq_wr_last[src][dst]),
                    .wr_id(xpq_wr_id[src][dst]),
                    .wr_is_bad(xpq_wr_is_bad[src][dst]),
                    .wr_ready(xpq_wr_ready[src][dst]),

                    .rd_valid(xpq_rd_valid[src][dst]),
                    .rd_data(xpq_rd_data[src][dst]),
                    .rd_keep(xpq_rd_keep[src][dst]),
                    .rd_last(xpq_rd_last[src][dst]),
                    .rd_id(xpq_rd_id[src][dst]),
                    .rd_is_bad(xpq_rd_is_bad[src][dst]),
                    .rd_ready(xpq_rd_ready[src][dst]),

                    .packet_count(),
                    .word_count()
                );

            end
        end
    endgenerate

    // =========================================================================
    // Fabric Egress
    // =========================================================================

    fabric_egress #(
        .NUM_PORTS(NUM_PORTS),
        .DATA_WIDTH(DATA_WIDTH),
        .ID_WIDTH(ID_WIDTH)
    ) egress_stage (
        .clk(clk),
        .rst_n(rst_n),
        .xpq_rd_valid(xpq_rd_valid),
        .xpq_rd_data(xpq_rd_data),
        .xpq_rd_keep(xpq_rd_keep),
        .xpq_rd_last(xpq_rd_last),
        .xpq_rd_id(xpq_rd_id),
        .xpq_rd_is_bad(xpq_rd_is_bad),
        .xpq_rd_qos(xpq_rd_qos),
        .xpq_rd_ready(xpq_rd_ready),
        .tx_data_if(tx_data_if),
        .id_release_req(id_release_req),
        .release_id(release_id)
    );

    //═══════════════════════════════════════════════════════════════════════════
    // Microprocessor Interface (NEW)
    //═══════════════════════════════════════════════════════════════════════════

    micro_interface_qos_enhanced #(
        .NUM_PORTS(NUM_PORTS),
        .QOS_LEVELS(`QOS_LEVELS)
    ) u_micro_if (
        .clk(clk),
        .rst_n(rst_n),
        
        // AXI4-Lite
        .s_axi_awaddr(uif_awaddr),
        .s_axi_awvalid(uif_awvalid),
        .s_axi_awready(uif_awready),
        .s_axi_wdata(uif_wdata),
        .s_axi_wvalid(uif_wvalid),
        .s_axi_wready(uif_wready),
        .s_axi_bresp(uif_bresp),
        .s_axi_bvalid(uif_bvalid),
        .s_axi_bready(uif_bready),
        .s_axi_araddr(uif_araddr),
        .s_axi_arvalid(uif_arvalid),
        .s_axi_arready(uif_arready),
        .s_axi_rdata(uif_rdata),
        .s_axi_rresp(uif_rresp),
        .s_axi_rvalid(uif_rvalid),
        .s_axi_rready(uif_rready),

        // QoS configuration
        .qos_enable(qos_enable_micro),
        .use_vlan_pcp(use_vlan_pcp_micro),
        .use_ip_dscp(use_ip_dscp_micro),
        .use_port_classify(use_port_classify_micro),
        .aging_threshold(aging_threshold),

        // Statistics
        .rx_pkt_count(pkt_count_rx),
        .tx_pkt_count(pkt_count_tx),
        .drop_count(pkt_drop_count),
        .qos_stats()  // TODO: Connect per-QoS statistics from VOQs
    );

    // =========================================================================
    // Statistics Counters
    // =========================================================================

    genvar p;
    generate
        for (p = 0; p < NUM_PORTS; p++) begin : gen_stats

            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    pkt_count_rx[p] <= 0;
                    pkt_count_tx[p] <= 0;
                    pkt_drop_count[p] <= 0;
                end else begin
                    // RX packet count
                    if (rx_data_if[p].valid && rx_data_if[p].ready && rx_data_if[p].last)
                        pkt_count_rx[p] <= pkt_count_rx[p] + 1;

                    // TX packet count
                    if (tx_data_if[p].valid && tx_data_if[p].ready && tx_data_if[p].last)
                        pkt_count_tx[p] <= pkt_count_tx[p] + 1;

                    // Drop count (when VOQ full)
                    if (rx_data_if[p].valid && !rx_data_if[p].ready)
                        pkt_drop_count[p] <= pkt_drop_count[p] + 1;
                end
            end

        end
    endgenerate

endmodule

`default_nettype wire
