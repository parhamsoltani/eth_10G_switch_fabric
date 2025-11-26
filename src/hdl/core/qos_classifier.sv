`timescale 1ns / 1ps
`default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Company: Parman
// Engineer: Alireza Abbasian
//
// Create Date:  2025-11-25
// Module Name: qos_classifier
// Project Name:
// Target Devices:
// Tool Versions: Vivado 2022.2
// Description: Multi-field QoS classification for ingress packets
// Dependencies:
//
// Additional Comments:
// Classifies packets based on VLAN PCP, IP DSCP, or port-based policies
//////////////////////////////////////////////////////////////////////////////////

`include "fabric_params.vh"

module qos_classifier #(
    parameter QOS_TAG_WIDTH = `QOS_TAG_WIDTH,
    parameter DATA_WIDTH    = `DATA_WIDTH
)(
    input  wire clk,
    input  wire rst_n,

    // Packet header fields (extracted from first beat)
    input  wire [15:0] ethertype,
    input  wire [2:0]  vlan_pcp,
    input  wire [7:0]  ip_tos,
    input  wire [15:0] tcp_src_port,
    input  wire [15:0] tcp_dst_port,

    // Classification controls
    input  wire use_vlan_pcp,
    input  wire use_ip_dscp,
    input  wire use_port_classify,

    // Output QoS tag
    output logic [QOS_TAG_WIDTH-1:0] qos_tag
);

    // VLAN PCP to QoS mapping (802.1p)
    function automatic logic [QOS_TAG_WIDTH-1:0] pcp_to_qos(input logic [2:0] pcp);
        case (pcp)
            3'b000, 3'b001: return `PRIORITY_LOW;     // Best Effort
            3'b010, 3'b011: return `PRIORITY_MEDIUM;  // Excellent Effort
            3'b100, 3'b101,
            3'b110, 3'b111: return `PRIORITY_HIGH;    // Network Control
            default: return `PRIORITY_MEDIUM;
        endcase
    endfunction

    // IP DSCP to QoS mapping (RFC 2474)
    function automatic logic [QOS_TAG_WIDTH-1:0] dscp_to_qos(input logic [5:0] dscp);
        if (dscp >= 6'h30)      // CS6, CS7, EF
            return `PRIORITY_HIGH;
        else if (dscp >= 6'h18) // AF3x, AF4x
            return `PRIORITY_MEDIUM;
        else
            return `PRIORITY_LOW;
    endfunction

    // Port-based classification (well-known ports)
    function automatic logic [QOS_TAG_WIDTH-1:0] port_to_qos(
        input logic [15:0] src, input logic [15:0] dst
    );
        // Voice/video: high priority
        if (src == 5060 || dst == 5060)  // SIP
            return `PRIORITY_HIGH;
        if (src >= 16384 && src <= 32767)  // RTP dynamic range
            return `PRIORITY_HIGH;

        // Interactive: medium priority
        if (src == 22 || dst == 22)  // SSH
            return `PRIORITY_MEDIUM;
        if (src == 23 || dst == 23)  // Telnet
            return `PRIORITY_MEDIUM;

        // Bulk: low priority
        return `PRIORITY_LOW;
    endfunction

    logic [QOS_TAG_WIDTH-1:0] qos_vlan;
    logic [QOS_TAG_WIDTH-1:0] qos_dscp;
    logic [QOS_TAG_WIDTH-1:0] qos_port;

    logic [5:0] dscp;
    assign dscp = ip_tos[7:2];  // DSCP = TOS[7:2]

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            qos_tag <= `PRIORITY_MEDIUM;
        end else begin
            qos_vlan <= pcp_to_qos(vlan_pcp);
            qos_dscp <= dscp_to_qos(dscp);
            qos_port <= port_to_qos(tcp_src_port, tcp_dst_port);

            // Priority: VLAN > DSCP > Port-based
            if (use_vlan_pcp)
                qos_tag <= qos_vlan;
            else if (use_ip_dscp)
                qos_tag <= qos_dscp;
            else if (use_port_classify)
                qos_tag <= qos_port;
            else
                qos_tag <= `PRIORITY_MEDIUM;  // Default
        end
    end

endmodule

`default_nettype wire