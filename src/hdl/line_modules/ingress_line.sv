`timescale 1ns / 1ps
// `default_nettype none

`include "fabric_params.vh"

module ingress_line #(
    parameter NUM_PORTS     = `NUM_PORTS,
    parameter DATA_WIDTH    = `DATA_WIDTH,
    parameter ID_WIDTH      = `PACKET_ID_WIDTH,
    parameter INPUT_Q_DEPTH = 128
)(
    input  logic clk,
    input  logic rst_n,

    // External RX interface (AXI-Stream like)
    switch_data_if.slave        external_rx,
    switch_metadata_if.slave    external_meta,

    // Internal fabric interface
    switch_data_if.master       fabric_rx_data,
    switch_metadata_if.master   fabric_rx_meta,

    // QoS classifier controls
    input  logic use_vlan_pcp,
    input  logic use_ip_dscp,
    input  logic use_port_classify
);

    // Input queue to absorb bursts
    logic [DATA_WIDTH-1:0]      iq_wr_data;
    logic [DATA_WIDTH/8-1:0]    iq_wr_keep;
    logic                       iq_wr_valid;
    logic                       iq_wr_last;
    logic                       iq_wr_is_bad;
    logic                       iq_wr_ready;

    logic [DATA_WIDTH-1:0]      iq_rd_data;
    logic [DATA_WIDTH/8-1:0]    iq_rd_keep;
    logic                       iq_rd_valid;
    logic                       iq_rd_last;
    logic                       iq_rd_is_bad;
    logic                       iq_rd_ready;

    // QoS classification
    logic [15:0] ethertype;
    logic [2:0]  vlan_pcp;
    logic [7:0]  ip_tos;
    logic [15:0] tcp_src_port;
    logic [15:0] tcp_dst_port;
    logic [2:0]  classified_qos;

    // Extract header fields (simplified - assumes Ethernet + IPv4)
    // In real implementation, parse packet headers properly
    assign ethertype = iq_rd_data[31:16];
    assign vlan_pcp = iq_rd_data[15:13];
    assign ip_tos = iq_rd_data[23:16];
    assign tcp_src_port = iq_rd_data[31:16];
    assign tcp_dst_port = iq_rd_data[15:0];

    // QoS Classifier
    qos_classifier classifier (
        .clk(clk),
        .rst_n(rst_n),
        .ethertype(ethertype),
        .vlan_pcp(vlan_pcp),
        .ip_tos(ip_tos),
        .src_port(tcp_src_port),
        .dst_port(tcp_dst_port),
        .use_vlan_pcp(use_vlan_pcp),
        .use_ip_dscp(use_ip_dscp),
        .use_port_classify(use_port_classify),
        .qos_tag(classified_qos)
    );

    // Input Queue (simple FIFO)
    typedef struct packed {
        logic [DATA_WIDTH-1:0]      data;
        logic [DATA_WIDTH/8-1:0]    keep;
        logic                       last;
        logic                       is_bad;
    } iq_entry_t;

    iq_entry_t iq_fifo[$];

    assign iq_wr_data = external_rx.data;
    assign iq_wr_keep = external_rx.keep;
    assign iq_wr_valid = external_rx.valid;
    assign iq_wr_last = external_rx.last;
    assign iq_wr_is_bad = external_rx.is_bad_frame;
    assign external_rx.ready = iq_wr_ready;

    assign iq_wr_ready = (iq_fifo.size() < INPUT_Q_DEPTH);

    // Write to input queue
    always @(posedge clk) begin
        if (iq_wr_valid && iq_wr_ready) begin
            iq_entry_t entry;
            entry.data = iq_wr_data;
            entry.keep = iq_wr_keep;
            entry.last = iq_wr_last;
            entry.is_bad = iq_wr_is_bad;
            iq_fifo.push_back(entry);
        end
    end

    // Read from input queue
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            iq_rd_valid <= 1'b0;
        end else begin
            iq_rd_valid <= 1'b0;

            if (iq_rd_ready && iq_fifo.size() > 0) begin
                automatic iq_entry_t entry;
                entry = iq_fifo.pop_front();
                iq_rd_data <= entry.data;
                iq_rd_keep <= entry.keep;
                iq_rd_last <= entry.last;
                iq_rd_is_bad <= entry.is_bad;
                iq_rd_valid <= 1'b1;
            end
        end
    end

    // Pass to fabric
    assign fabric_rx_data.data = iq_rd_data;
    assign fabric_rx_data.keep = iq_rd_keep;
    assign fabric_rx_data.valid = iq_rd_valid;
    assign fabric_rx_data.last = iq_rd_last;
    assign fabric_rx_data.is_bad_frame = iq_rd_is_bad;
    assign fabric_rx_data.qos_tag = classified_qos;
    assign iq_rd_ready = fabric_rx_data.ready;

    // Metadata passthrough
    assign fabric_rx_meta.dest_port_mask = external_meta.dest_port_mask;
    assign fabric_rx_meta.id = external_meta.id;
    assign fabric_rx_meta.qos_tag = classified_qos;  // Override with classified
    assign fabric_rx_meta.valid = external_meta.valid;
    assign external_meta.ready = fabric_rx_meta.ready;

endmodule

`default_nettype wire