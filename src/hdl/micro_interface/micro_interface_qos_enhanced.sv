`timescale 1ns / 1ps
// `default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Company: IUST
// Engineer: Parham Soltani
//
// Create Date:  2025-11-25
// Module Name: micro_interface_qos_enhanced
// Description: Enhanced micro interface with QoS statistics collection
// Extends your existing micro_interface.sv with per-QoS-level counters
//////////////////////////////////////////////////////////////////////////////////

`include "fabric_params.vh"
`include "qos_defines.vh"

module micro_interface_qos_enhanced #(
    parameter NUM_PORTS     = `NUM_PORTS,
    parameter ADDR_WIDTH    = 16,
    parameter DATA_WIDTH    = 32,
    parameter QOS_LEVELS    = `QOS_LEVELS
)(
    input  wire                         clk,
    input  wire                         rst_n,

    // AXI4-Lite Slave Interface
    input  wire [ADDR_WIDTH-1:0]        s_axi_awaddr,
    input  wire                         s_axi_awvalid,
    output reg                          s_axi_awready,

    input  wire [DATA_WIDTH-1:0]        s_axi_wdata,
    input  wire                         s_axi_wvalid,
    output reg                          s_axi_wready,

    output reg  [1:0]                   s_axi_bresp,
    output reg                          s_axi_bvalid,
    input  wire                         s_axi_bready,

    input  wire [ADDR_WIDTH-1:0]        s_axi_araddr,
    input  wire                         s_axi_arvalid,
    output reg                          s_axi_arready,

    output reg  [DATA_WIDTH-1:0]        s_axi_rdata,
    output reg  [1:0]                   s_axi_rresp,
    output reg                          s_axi_rvalid,
    input  wire                         s_axi_rready,

    // QoS Configuration Outputs
    output reg                          qos_enable,
    output reg                          use_vlan_pcp,
    output reg                          use_ip_dscp,
    output reg                          use_port_classify,
    output reg  [15:0]                  aging_threshold,

    // Statistics Inputs (from fabric)
    input  wire [31:0]                  rx_pkt_count [NUM_PORTS],
    input  wire [31:0]                  tx_pkt_count [NUM_PORTS],
    input  wire [31:0]                  drop_count [NUM_PORTS],
    input  wire [31:0]                  qos_stats [NUM_PORTS][QOS_LEVELS]
);

    //═══════════════════════════════════════════════════════════════════════════
    // Register Map (COMPLETE IMPLEMENTATION)
    //═══════════════════════════════════════════════════════════════════════════

    localparam REG_FABRIC_ID         = 16'h0000;  // RO: Device ID
    localparam REG_FABRIC_VERSION    = 16'h0004;  // RO: Version
    localparam REG_CONTROL           = 16'h0008;  // RW: Soft reset
    localparam REG_STATUS            = 16'h000C;  // RO: Fabric status

    localparam REG_QOS_CONTROL       = 16'h0100;  // RW: QoS enable bits
    localparam REG_QOS_AGE_THRESH    = 16'h0104;  // RW: Aging threshold

    // Per-port statistics (0x0200 + port*0x20)
    localparam REG_PORT_RX_BASE      = 16'h0200;
    localparam REG_PORT_TX_BASE      = 16'h0204;
    localparam REG_PORT_DROP_BASE    = 16'h0208;

    // Per-port, per-QoS statistics (0x1000 + port*0x100 + qos*0x10)
    localparam REG_QOS_STATS_BASE    = 16'h1000;

    //═══════════════════════════════════════════════════════════════════════════
    // Internal Registers
    //═══════════════════════════════════════════════════════════════════════════

    localparam FABRIC_ID      = 32'h50415245;  // "PARE" (Parman)
    localparam FABRIC_VERSION = 32'h00010000;  // v1.0.0

    reg [ADDR_WIDTH-1:0] wr_addr_latched;
    reg [ADDR_WIDTH-1:0] rd_addr_latched;
    reg soft_reset;

    typedef enum logic [2:0] {
        WR_IDLE,
        WR_ADDR,
        WR_DATA,
        WR_RESP
    } wr_state_t;

    typedef enum logic [1:0] {
        RD_IDLE,
        RD_ADDR,
        RD_DATA
    } rd_state_t;

    wr_state_t wr_state;
    rd_state_t rd_state;

    //═══════════════════════════════════════════════════════════════════════════
    // Write State Machine (COMPLETE)
    //═══════════════════════════════════════════════════════════════════════════

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_state <= WR_IDLE;
            s_axi_awready <= 1'b0;
            s_axi_wready <= 1'b0;
            s_axi_bvalid <= 1'b0;
            s_axi_bresp <= 2'b00;

            qos_enable <= 1'b1;  // Default: QoS enabled
            use_vlan_pcp <= 1'b1;
            use_ip_dscp <= 1'b1;
            use_port_classify <= 1'b0;
            aging_threshold <= `SCHEDULER_AGING_THRESHOLD;
            soft_reset <= 1'b0;

        end else begin
            case (wr_state)
                WR_IDLE: begin
                    s_axi_awready <= 1'b1;
                    s_axi_wready <= 1'b0;
                    s_axi_bvalid <= 1'b0;

                    if (s_axi_awvalid && s_axi_awready) begin
                        wr_addr_latched <= s_axi_awaddr;
                        s_axi_awready <= 1'b0;
                        wr_state <= WR_DATA;
                    end
                end

                WR_DATA: begin
                    s_axi_wready <= 1'b1;

                    if (s_axi_wvalid && s_axi_wready) begin
                        s_axi_wready <= 1'b0;

                        // Write to registers
                        case (wr_addr_latched)
                            REG_CONTROL: begin
                                soft_reset <= s_axi_wdata[0];
                            end

                            REG_QOS_CONTROL: begin
                                qos_enable        <= s_axi_wdata[0];
                                use_vlan_pcp      <= s_axi_wdata[1];
                                use_ip_dscp       <= s_axi_wdata[2];
                                use_port_classify <= s_axi_wdata[3];
                            end

                            REG_QOS_AGE_THRESH: begin
                                aging_threshold <= s_axi_wdata[15:0];
                            end

                            default: begin
                                // Invalid write (read-only or out of range)
                                s_axi_bresp <= 2'b10;  // SLVERR
                            end
                        endcase

                        wr_state <= WR_RESP;
                    end
                end

                WR_RESP: begin
                    s_axi_bvalid <= 1'b1;
                    s_axi_bresp <= 2'b00;  // OKAY

                    if (s_axi_bvalid && s_axi_bready) begin
                        s_axi_bvalid <= 1'b0;
                        wr_state <= WR_IDLE;
                    end
                end
            endcase

            // Auto-clear soft reset
            if (soft_reset) soft_reset <= 1'b0;
        end
    end

    //═══════════════════════════════════════════════════════════════════════════
    // Read State Machine (COMPLETE)
    //═══════════════════════════════════════════════════════════════════════════

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_state <= RD_IDLE;
            s_axi_arready <= 1'b0;
            s_axi_rvalid <= 1'b0;
            s_axi_rdata <= 32'h0;
            s_axi_rresp <= 2'b00;

        end else begin
            case (rd_state)
                RD_IDLE: begin
                    s_axi_arready <= 1'b1;
                    s_axi_rvalid <= 1'b0;

                    if (s_axi_arvalid && s_axi_arready) begin
                        rd_addr_latched <= s_axi_araddr;
                        s_axi_arready <= 1'b0;
                        rd_state <= RD_DATA;
                    end
                end

                RD_DATA: begin
                    s_axi_rvalid <= 1'b1;
                    s_axi_rresp <= 2'b00;  // Default OKAY

                    // Read register values
                    case (rd_addr_latched)
                        REG_FABRIC_ID: begin
                            s_axi_rdata <= FABRIC_ID;
                        end

                        REG_FABRIC_VERSION: begin
                            s_axi_rdata <= FABRIC_VERSION;
                        end

                        REG_CONTROL: begin
                            s_axi_rdata <= {31'b0, soft_reset};
                        end

                        REG_STATUS: begin
                            s_axi_rdata <= {28'b0, use_port_classify, use_ip_dscp, use_vlan_pcp, qos_enable};
                        end

                        REG_QOS_CONTROL: begin
                            s_axi_rdata <= {28'b0, use_port_classify, use_ip_dscp, use_vlan_pcp, qos_enable};
                        end

                        REG_QOS_AGE_THRESH: begin
                            s_axi_rdata <= {16'b0, aging_threshold};
                        end

                        default: begin
                            // Check if port statistics
                            if (rd_addr_latched >= REG_PORT_RX_BASE && rd_addr_latched < REG_QOS_STATS_BASE) begin
                                automatic int port_idx = (rd_addr_latched - REG_PORT_RX_BASE) / 32'h20;
                                automatic int reg_offset = (rd_addr_latched - REG_PORT_RX_BASE) % 32'h20;

                                if (port_idx < NUM_PORTS) begin
                                    case (reg_offset)
                                        0: s_axi_rdata <= rx_pkt_count[port_idx];
                                        4: s_axi_rdata <= tx_pkt_count[port_idx];
                                        8: s_axi_rdata <= drop_count[port_idx];
                                        default: s_axi_rdata <= 32'h0;
                                    endcase
                                end else begin
                                    s_axi_rresp <= 2'b10;  // SLVERR
                                end

                            // Check if QoS statistics
                            end else if (rd_addr_latched >= REG_QOS_STATS_BASE) begin
                                automatic int port_idx = (rd_addr_latched - REG_QOS_STATS_BASE) / 32'h100;
                                automatic int qos_idx = ((rd_addr_latched - REG_QOS_STATS_BASE) % 32'h100) / 32'h10;

                                if (port_idx < NUM_PORTS && qos_idx < QOS_LEVELS) begin
                                    s_axi_rdata <= qos_stats[port_idx][qos_idx];
                                end else begin
                                    s_axi_rresp <= 2'b10;  // SLVERR
                                end

                            end else begin
                                s_axi_rdata <= 32'h0;
                                s_axi_rresp <= 2'b10;  // SLVERR
                            end
                        end
                    endcase

                    if (s_axi_rvalid && s_axi_rready) begin
                        s_axi_rvalid <= 1'b0;
                        rd_state <= RD_IDLE;
                    end
                end
            endcase
        end
    end

endmodule

`default_nettype wire
