`timescale 1ns / 1ps
`default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Company: Parman
// Engineer: Alireza Abbasian
//
// Create Date:  2025-11-25
// Module Name: micro_interface_qos_enhanced
// Description: Enhanced micro interface with QoS statistics collection
// Extends your existing micro_interface.sv with per-QoS-level counters
//////////////////////////////////////////////////////////////////////////////////

`include "fabric_params.vh"

module micro_interface_qos_enhanced #(
    parameter NUM_PORT      = `NUM_PORTS,
    parameter QOS_LEVELS    = `QOS_LEVELS,
    parameter QOS_TAG_WIDTH = `QOS_TAG_WIDTH,
    parameter ADDR_WIDTH    = 16,
    parameter DATA_WIDTH    = 32
)(
    input  wire clk,
    input  wire rst_n,

    // AXI4-Lite interface (your pattern)
    input  wire [ADDR_WIDTH-1:0]    s_axi_awaddr,
    input  wire                     s_axi_awvalid,
    output wire                     s_axi_awready,

    input  wire [DATA_WIDTH-1:0]    s_axi_wdata,
    input  wire [DATA_WIDTH/8-1:0]  s_axi_wstrb,
    input  wire                     s_axi_wvalid,
    output wire                     s_axi_wready,

    output wire [1:0]               s_axi_bresp,
    output wire                     s_axi_bvalid,
    input  wire                     s_axi_bready,

    input  wire [ADDR_WIDTH-1:0]    s_axi_araddr,
    input  wire                     s_axi_arvalid,
    output wire                     s_axi_arready,

    output wire [DATA_WIDTH-1:0]    s_axi_rdata,
    output wire [1:0]               s_axi_rresp,
    output wire                     s_axi_rvalid,
    input  wire                     s_axi_rready,

    // Fabric monitoring signals (your pattern)
    input  wire [NUM_PORT-1:0]      port_link_up,
    input  wire [NUM_PORT-1:0]      port_rx_active,
    input  wire [NUM_PORT-1:0]      port_tx_active,

    // NEW: QoS monitoring
    input  wire [NUM_PORT-1:0]      port_rx_valid,
    input  wire [NUM_PORT-1:0]      port_tx_valid,
    input  wire [QOS_TAG_WIDTH-1:0] port_rx_qos [NUM_PORT],
    input  wire [QOS_TAG_WIDTH-1:0] port_tx_qos [NUM_PORT],

    // Control outputs
    output reg  qos_enable,
    output reg  use_vlan_pcp,
    output reg  use_ip_dscp,
    output reg  use_port_classify
);

    //==========================================================================
    // Register Map (extends your existing map)
    //==========================================================================
    localparam REG_CONTROL       = 16'h0000;  // Your existing
    localparam REG_STATUS        = 16'h0004;  // Your existing
    localparam REG_PORT_STATUS   = 16'h0008;  // Your existing

    // NEW: QoS registers (starting at 0x0100)
    localparam REG_QOS_CONTROL   = 16'h0100;
    localparam REG_QOS_STATUS    = 16'h0104;

    // Per-port, per-QoS statistics (0x0200 - 0x0FFF)
    // Format: BASE + (port * QOS_LEVELS * 8) + (qos_level * 8) + offset
    localparam REG_QOS_STATS_BASE = 16'h0200;
    localparam REG_QOS_RX_PKTS    = 0;  // +0: RX packets
    localparam REG_QOS_TX_PKTS    = 4;  // +4: TX packets

    //==========================================================================
    // Statistics Counters (per port, per QoS level)
    //==========================================================================
    reg [31:0] qos_rx_pkt_count [NUM_PORT][QOS_LEVELS];
    reg [31:0] qos_tx_pkt_count [NUM_PORT][QOS_LEVELS];
    reg [31:0] qos_rx_byte_count [NUM_PORT][QOS_LEVELS];
    reg [31:0] qos_tx_byte_count [NUM_PORT][QOS_LEVELS];

    // Port-level totals (your existing pattern)
    reg [31:0] port_rx_packets [NUM_PORT];
    reg [31:0] port_tx_packets [NUM_PORT];

    initial begin
        qos_enable = 1'b0;
        use_vlan_pcp = 1'b0;
        use_ip_dscp = 1'b0;
        use_port_classify = 1'b0;

        for (int p = 0; p < NUM_PORT; p++) begin
            port_rx_packets[p] = 0;
            port_tx_packets[p] = 0;
            for (int q = 0; q < QOS_LEVELS; q++) begin
                qos_rx_pkt_count[p][q] = 0;
                qos_tx_pkt_count[p][q] = 0;
                qos_rx_byte_count[p][q] = 0;
                qos_tx_byte_count[p][q] = 0;
            end
        end
    end

    //==========================================================================
    // Statistics Collection
    //==========================================================================
    generate
        for (genvar p = 0; p < NUM_PORT; p++) begin : gen_stats

            // RX packet counting (with QoS breakdown)
            always @(posedge clk) begin
                if (port_rx_valid[p]) begin
                    port_rx_packets[p] <= port_rx_packets[p] + 1;

                    // QoS-specific counter
                    if (qos_enable) begin
                        for (int q = 0; q < QOS_LEVELS; q++) begin
                            if (port_rx_qos[p] == q[QOS_TAG_WIDTH-1:0]) begin
                                qos_rx_pkt_count[p][q] <= qos_rx_pkt_count[p][q] + 1;
                            end
                        end
                    end
                end
            end

            // TX packet counting
            always @(posedge clk) begin
                if (port_tx_valid[p]) begin
                    port_tx_packets[p] <= port_tx_packets[p] + 1;

                    if (qos_enable) begin
                        for (int q = 0; q < QOS_LEVELS; q++) begin
                            if (port_tx_qos[p] == q[QOS_TAG_WIDTH-1:0]) begin
                                qos_tx_pkt_count[p][q] <= qos_tx_pkt_count[p][q] + 1;
                            end
                        end
                    end
                end
            end
        end
    endgenerate

    //==========================================================================
    // AXI4-Lite State Machine (your pattern)
    //==========================================================================
    typedef enum logic [2:0] {
        IDLE,
        WRITE_ADDR,
        WRITE_DATA,
        WRITE_RESP,
        READ_ADDR,
        READ_DATA
    } axi_state_t;

    axi_state_t axi_state = IDLE;

    reg [ADDR_WIDTH-1:0]  write_addr_reg;
    reg [DATA_WIDTH-1:0]  write_data_reg;
    reg [ADDR_WIDTH-1:0]  read_addr_reg;
    reg [DATA_WIDTH-1:0]  read_data_reg;
    reg                   read_valid_reg;

    assign s_axi_awready = (axi_state == IDLE) || (axi_state == WRITE_ADDR);
    assign s_axi_wready  = (axi_state == WRITE_DATA);
    assign s_axi_bvalid  = (axi_state == WRITE_RESP);
    assign s_axi_bresp   = 2'b00;  // OKAY

    assign s_axi_arready = (axi_state == IDLE) || (axi_state == READ_ADDR);
    assign s_axi_rvalid  = read_valid_reg;
    assign s_axi_rdata   = read_data_reg;
    assign s_axi_rresp   = 2'b00;  // OKAY

    //==========================================================================
    // AXI Write Channel
    //==========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            axi_state <= IDLE;
            write_addr_reg <= '0;
            write_data_reg <= '0;

        end else begin
            case (axi_state)
                IDLE: begin
                    if (s_axi_awvalid) begin
                        write_addr_reg <= s_axi_awaddr;
                        axi_state <= WRITE_DATA;
                    end else if (s_axi_arvalid) begin
                        read_addr_reg <= s_axi_araddr;
                        axi_state <= READ_DATA;
                    end
                end

                WRITE_DATA: begin
                    if (s_axi_wvalid) begin
                        write_data_reg <= s_axi_wdata;

                        // Decode write address
                        case (write_addr_reg)
                            REG_CONTROL: begin
                                // Your existing control bits
                            end

                            REG_QOS_CONTROL: begin
                                qos_enable        <= s_axi_wdata[0];
                                use_vlan_pcp      <= s_axi_wdata[1];
                                use_ip_dscp       <= s_axi_wdata[2];
                                use_port_classify <= s_axi_wdata[3];
                            end
                        endcase

                        axi_state <= WRITE_RESP;
                    end
                end

                WRITE_RESP: begin
                    if (s_axi_bready) begin
                        axi_state <= IDLE;
                    end
                end

                READ_DATA: begin
                    read_valid_reg <= 1'b1;

                    // Decode read address
                    if (read_addr_reg >= REG_QOS_STATS_BASE) begin
                        // QoS statistics read
                        logic [15:0] offset = read_addr_reg - REG_QOS_STATS_BASE;
                        int port_idx = offset / (QOS_LEVELS * 8);
                        int qos_offset = offset % (QOS_LEVELS * 8);
                        int qos_idx = qos_offset / 8;
                        int reg_type = qos_offset % 8;

                        if (port_idx < NUM_PORT && qos_idx < QOS_LEVELS) begin
                            case (reg_type)
                                REG_QOS_RX_PKTS: read_data_reg <= qos_rx_pkt_count[port_idx][qos_idx];
                                REG_QOS_TX_PKTS: read_data_reg <= qos_tx_pkt_count[port_idx][qos_idx];
                                default: read_data_reg <= 32'hDEADBEEF;
                            endcase
                        end else begin
                            read_data_reg <= 32'hBADC0FFE;
                        end

                    end else begin
                        case (read_addr_reg)
                            REG_QOS_CONTROL: begin
                                read_data_reg <= {28'b0, use_port_classify, use_ip_dscp, use_vlan_pcp, qos_enable};
                            end

                            REG_QOS_STATUS: begin
                                // Aggregate QoS stats across all ports
                                logic [31:0] total_high = 0;
                                for (int p = 0; p < NUM_PORT; p++) begin
                                    total_high += qos_rx_pkt_count[p][0];  // Assuming HIGH=0
                                end
                                read_data_reg <= total_high;
                            end

                            default: read_data_reg <= 32'h00000000;
                        endcase
                    end

                    if (s_axi_rready) begin
                        read_valid_reg <= 1'b0;
                        axi_state <= IDLE;
                    end
                end

                default: axi_state <= IDLE;
            endcase
        end
    end

    //==========================================================================
    // Diagnostics (synthesis translate_off)
    //==========================================================================
    // synthesis translate_off
    initial begin
        $display("========================================");
        $display("  Micro Interface QoS Configuration");
        $display("========================================");
        $display("NUM_PORT:      %0d", NUM_PORT);
        $display("QoS Enabled:   %0d", ENABLE_QOS);
        $display("QoS Levels:    %0d", QOS_LEVELS);
        $display("========================================");
    end

    // Monitor QoS distribution
    real qos_dist [QOS_LEVELS];
    int total_packets = 0;

    always @(posedge clk) begin
        for (int p = 0; p < NUM_PORT; p++) begin
            if (port_rx_valid[p]) begin
                total_packets++;
                for (int q = 0; q < QOS_LEVELS; q++) begin
                    if (port_rx_qos[p] == q[QOS_TAG_WIDTH-1:0]) begin
                        qos_dist[q] = (real'(qos_rx_pkt_count[p][q]) / real'(total_packets)) * 100.0;
                    end
                end
            end
        end
    end

    final begin
        $display("\n========================================");
        $display("  QoS Traffic Distribution");
        $display("========================================");
        for (int q = 0; q < QOS_LEVELS; q++) begin
            $display("QoS Level %0d: %.2f%%", q, qos_dist[q]);
        end
        $display("========================================\n");
    end
    // synthesis translate_on

endmodule

`default_nettype wire