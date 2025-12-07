`timescale 1ns / 1ps
`include "qos_defines.vh"

module qos_classifier #(
    parameter QOS_TAG_WIDTH = `QOS_TAG_WIDTH,
    parameter DATA_WIDTH = 512
) (
    input  logic clk,
    input  logic rst_n,

    // Packet header fields
    input  logic [15:0] ethertype,
    input  logic [2:0]  vlan_pcp,
    input  logic [7:0]  ip_tos,
    input  logic [15:0] tcp_src_port,
    input  logic [15:0] tcp_dst_port,

    // Classification control
    input  logic use_vlan_pcp,
    input  logic use_ip_dscp,
    input  logic use_port_classify,

    // Output QoS tag
    output logic [QOS_TAG_WIDTH-1:0] qos_tag
);

    //═══════════════════════════════════════════════════════════════════════════
    // Internal Signals
    //═══════════════════════════════════════════════════════════════════════════

    logic [5:0] dscp;
    logic [QOS_TAG_WIDTH-1:0] vlan_qos;
    logic [QOS_TAG_WIDTH-1:0] dscp_qos;
    logic [QOS_TAG_WIDTH-1:0] port_qos;

    //═══════════════════════════════════════════════════════════════════════════
    // Extract DSCP from IP TOS field
    //═══════════════════════════════════════════════════════════════════════════

    assign dscp = ip_tos[7:2];

    //═══════════════════════════════════════════════════════════════════════════
    // VLAN PCP to QoS Mapping (802.1p)
    //═══════════════════════════════════════════════════════════════════════════

    function automatic logic [QOS_TAG_WIDTH-1:0] map_vlan_pcp(input logic [2:0] pcp);
        case (pcp)
            3'b000, 3'b001: return `PRIORITY_BACKGROUND;      // 0-1: Background/Best Effort
            3'b010:         return `PRIORITY_EXCELLENT;       // 2: Excellent Effort
            3'b011:         return `PRIORITY_CRITICAL;        // 3: Critical Applications
            3'b100:         return `PRIORITY_VIDEO;           // 4: Video
            3'b101:         return `PRIORITY_VOICE;           // 5: Voice
            3'b110:         return `PRIORITY_VOICE;           // 6: Internetwork Control
            3'b111:         return `PRIORITY_NETWORK_CONTROL; // 7: Network Control
            default:        return `PRIORITY_STANDARD;
        endcase
    endfunction

    //═══════════════════════════════════════════════════════════════════════════
    // DSCP to QoS Mapping (RFC 2474/2475)
    //═══════════════════════════════════════════════════════════════════════════

    function automatic logic [QOS_TAG_WIDTH-1:0] map_dscp(input logic [5:0] dscp_val);
        casex (dscp_val)
            // Expedited Forwarding (EF) - Highest priority for real-time traffic
            6'd46:          return `PRIORITY_VOICE;           // EF (DSCP 46)

            // Class Selector (CS) - Network/Internetwork Control
            6'd48, 6'd56:   return `PRIORITY_NETWORK_CONTROL; // CS6, CS7

            // Assured Forwarding Class 4 (AF4x) - Interactive multimedia
            6'd32, 6'd34, 6'd36: return `PRIORITY_VIDEO;      // AF41, AF42, AF43

            // Assured Forwarding Class 3 (AF3x) - Multimedia streaming
            6'd24, 6'd26, 6'd28: return `PRIORITY_CRITICAL;   // AF31, AF32, AF33

            // Assured Forwarding Class 2 (AF2x) - Transactional data
            6'd16, 6'd18, 6'd20: return `PRIORITY_EXCELLENT;  // AF21, AF22, AF23

            // Assured Forwarding Class 1 (AF1x) - Bulk data
            6'd8, 6'd10, 6'd12: return `PRIORITY_STANDARD;    // AF11, AF12, AF13

            // Class Selector 1 (CS1) - Low priority bulk
            6'd8:           return `PRIORITY_BEST_EFFORT;     // CS1

            // Default / Best Effort
            6'd0:           return `PRIORITY_BACKGROUND;      // CS0 (Best Effort)

            // Catch-all for undefined DSCP values
            default:        return `PRIORITY_STANDARD;
        endcase
    endfunction

    //═══════════════════════════════════════════════════════════════════════════
    // Port-based Classification
    //═══════════════════════════════════════════════════════════════════════════

    function automatic logic [QOS_TAG_WIDTH-1:0] map_port(input logic [15:0] src_port, input logic [15:0] dst_port);
        // Check source port first
        case (src_port)
            // Real-time protocols (highest priority)
            16'd5060, 16'd5061:         return `PRIORITY_VOICE;      // SIP
            16'd1719, 16'd1720:         return `PRIORITY_VOICE;      // H.323

            // Management/Control protocols
            16'd22:                     return `PRIORITY_CRITICAL;   // SSH
            16'd23:                     return `PRIORITY_EXCELLENT;  // Telnet
            16'd161, 16'd162:           return `PRIORITY_EXCELLENT;  // SNMP

            // Standard protocols
            16'd80, 16'd443:            return `PRIORITY_STANDARD;   // HTTP/HTTPS
            16'd25, 16'd110, 16'd143:   return `PRIORITY_STANDARD;   // Email

            default: begin
                // Check if in RTP range (16384-32767)
                if (src_port >= 16'd16384 && src_port <= 16'd32767)
                    return `PRIORITY_VOICE;  // RTP audio/video

                // Check destination port if source didn't match
                case (dst_port)
                    16'd5060, 16'd5061:         return `PRIORITY_VOICE;
                    16'd1719, 16'd1720:         return `PRIORITY_VOICE;
                    16'd22:                     return `PRIORITY_CRITICAL;
                    16'd23:                     return `PRIORITY_EXCELLENT;
                    16'd161, 16'd162:           return `PRIORITY_EXCELLENT;
                    16'd80, 16'd443:            return `PRIORITY_STANDARD;
                    16'd25, 16'd110, 16'd143:   return `PRIORITY_STANDARD;
                    default: begin
                        if (dst_port >= 16'd16384 && dst_port <= 16'd32767)
                            return `PRIORITY_VOICE;
                        else
                            return `PRIORITY_BACKGROUND;  // Unknown ports
                    end
                endcase
            end
        endcase
    endfunction

    //═══════════════════════════════════════════════════════════════════════════
    // Classification Logic
    //═══════════════════════════════════════════════════════════════════════════

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            qos_tag <= `PRIORITY_STANDARD;
        end else begin
            // Priority order: VLAN PCP > DSCP > Port-based > Default

            if (use_vlan_pcp) begin
                // VLAN PCP has highest priority
                qos_tag <= map_vlan_pcp(vlan_pcp);
            end
            else if (use_ip_dscp) begin
                // DSCP classification
                qos_tag <= map_dscp(dscp);
            end
            else if (use_port_classify) begin
                // Port-based classification
                qos_tag <= map_port(tcp_src_port, tcp_dst_port);
            end
            else begin
                // Default to standard priority
                qos_tag <= `PRIORITY_STANDARD;
            end
        end
    end

endmodule