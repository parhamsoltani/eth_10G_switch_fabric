`timescale 1ns / 1ps
// `default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Company: IUST
// Engineer: Parham Soltani
//
// Create Date:  2025-11-25
// Module Name: ingress_line_wrapper
// Description: Parametric wrapper switching between QoS-aware and standard ingress
// Maintains backward compatibility with your existing designs
//////////////////////////////////////////////////////////////////////////////////

`include "fabric_params.vh"

module ingress_line_wrapper #(
    parameter DATA_WIDTH    = `DATA_WIDTH,
    parameter NUM_PORTS     = `NUM_PORTS,
    parameter ID_WIDTH      = `PACKET_ID_WIDTH,
    parameter ENABLE_QOS    = `ENABLE_QOS
)(
    input  logic clk,
    input  logic rst_n,

    // From line modules
    switch_data_if.slave        rx_data_if,
    switch_metadata_if.slave    rx_meta_if,

    // To VOQ stage
    output logic                    voq_wr_valid [NUM_PORTS],
    output logic [DATA_WIDTH-1:0]   voq_wr_data,
    output logic [DATA_WIDTH/8-1:0] voq_wr_keep,
    output logic                    voq_wr_last,
    output logic [ID_WIDTH-1:0]     voq_wr_id,
    output logic                    voq_wr_is_bad,
    output logic [2:0]              voq_wr_qos,
    input  logic                    voq_wr_ready [NUM_PORTS],

    // Packet ID Manager interface
    output logic                    id_alloc_req,
    input  logic                    id_alloc_grant,
    input  logic [ID_WIDTH-1:0]     allocated_id,

    // QoS Configuration (from microprocessor)
    input  logic                    qos_enable,
    input  logic                    use_vlan_pcp,
    input  logic                    use_ip_dscp,
    input  logic                    use_port_classify
);

    generate
        if (ENABLE_QOS) begin : gen_qos_ingress
            //═══════════════════════════════════════════════════════════════
            // QoS-AWARE INGRESS
            //═══════════════════════════════════════════════════════════════

            ingress_line_qos #(
                .DATA_WIDTH(DATA_WIDTH),
                .NUM_PORTS(NUM_PORTS),
                .ID_WIDTH(ID_WIDTH)
            ) ingress_qos (
                .clk(clk),
                .rst_n(rst_n),
                .rx_data_if(rx_data_if),
                .rx_meta_if(rx_meta_if),
                .voq_wr_valid(voq_wr_valid),
                .voq_wr_data(voq_wr_data),
                .voq_wr_keep(voq_wr_keep),
                .voq_wr_last(voq_wr_last),
                .voq_wr_id(voq_wr_id),
                .voq_wr_is_bad(voq_wr_is_bad),
                .voq_wr_qos(voq_wr_qos),
                .voq_wr_ready(voq_wr_ready),
                .id_alloc_req(id_alloc_req),
                .id_alloc_grant(id_alloc_grant),
                .allocated_id(allocated_id),
                .qos_enable(qos_enable),
                .use_vlan_pcp(use_vlan_pcp),
                .use_ip_dscp(use_ip_dscp),
                .use_port_classify(use_port_classify)
            );

        end else begin : gen_standard_ingress
            //═══════════════════════════════════════════════════════════════
            // STANDARD INGRESS (No QoS)
            //═══════════════════════════════════════════════════════════════

            ingress_switch #(
                .DATA_WIDTH(DATA_WIDTH),
                .NUM_PORTS(NUM_PORTS),
                .ID_WIDTH(ID_WIDTH)
            ) ingress_std (
                .clk(clk),
                .rst_n(rst_n),
                .rx_data_if(rx_data_if),
                .rx_meta_if(rx_meta_if),
                .voq_wr_valid(voq_wr_valid),
                .voq_wr_data(voq_wr_data),
                .voq_wr_keep(voq_wr_keep),
                .voq_wr_last(voq_wr_last),
                .voq_wr_id(voq_wr_id),
                .voq_wr_is_bad(voq_wr_is_bad),
                .voq_wr_qos(voq_wr_qos),
                .voq_wr_ready(voq_wr_ready),
                .id_alloc_req(id_alloc_req),
                .id_alloc_grant(id_alloc_grant),
                .allocated_id(allocated_id)
            );

        end
    endgenerate

endmodule

`default_nettype wire
