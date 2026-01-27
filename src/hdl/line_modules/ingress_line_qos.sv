`timescale 1ns / 1ps

`include "fabric_params.vh"

module ingress_line_qos #(
    parameter NUM_PORT          = 10,
    parameter W_MINI            = 64,
    parameter KEEP_WIDTH        = $clog2((W_MINI/8) + 1),
    parameter PACKET_ID_WIDTH   = 8,
    parameter QOS_TAG_WIDTH     = 3,
    parameter INPUT_QUEUE_DEPTH = 32,
    parameter INPUT_QUEUE_TUSER = PACKET_ID_WIDTH + 1 + KEEP_WIDTH + QOS_TAG_WIDTH
)(
    input  wire clk,
    input  wire rst_n,

    // External RX interface (from MAC/PHY)
    switch_data_if.slave_mp     rx_data_if,
    switch_metadata_if.slave_mp rx_meta_if,

    // To fabric core (original interface for switch_fabric.sv)
    input  wire                         rd_en_rx,
    output wire [W_MINI-1:0]            data_rx,
    output wire [KEEP_WIDTH-1:0]        keep_rx,
    output wire                         valid_rx,
    output wire                         is_bad_frame_rx,
    output wire [PACKET_ID_WIDTH-1:0]   packet_id_rx,
    output wire                         last_rx,
    output wire                         iq_fifo_almost_empty,
    output wire [NUM_PORT-1:0]          dest_mask_rx,
    output wire                         dest_mask_valid_rx,
    output wire [QOS_TAG_WIDTH-1:0]     qos_tag_rx,

    // QoS classification controls
    input  wire use_vlan_pcp,
    input  wire use_ip_dscp,
    input  wire use_port_classify
);

    //==========================================================================
    // Internal Signals
    //==========================================================================
    wire [W_MINI-1:0]            iq_wr_tdata;
    wire [INPUT_QUEUE_TUSER-1:0] iq_wr_tuser;
    wire                         iq_wr_tvalid;
    wire                         iq_wr_tlast;
    wire                         iq_wr_tready;

    wire [W_MINI-1:0]            iq_rd_tdata;
    wire [INPUT_QUEUE_TUSER-1:0] iq_rd_tuser;
    wire                         iq_rd_tvalid;
    wire                         iq_rd_tlast;
    wire                         iq_rd_tready;
    wire                         iq_rd_almost_empty;

    //==========================================================================
    // Header Parsing for QoS Classification
    //==========================================================================
    reg [15:0] ethertype_reg;
    reg [2:0]  vlan_pcp_reg;
    reg [7:0]  ip_tos_reg;
    reg [15:0] tcp_src_port_reg;
    reg [15:0] tcp_dst_port_reg;
    reg        is_first_beat;
    reg [3:0]  beat_count;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ethertype_reg    <= 16'h0800;
            vlan_pcp_reg     <= 3'b010;
            ip_tos_reg       <= 8'h00;
            tcp_src_port_reg <= 16'h0000;
            tcp_dst_port_reg <= 16'h0000;
            is_first_beat    <= 1'b1;
            beat_count       <= 4'd0;
        end else begin
            if (rx_data_if.valid && rx_data_if.ready) begin
                if (is_first_beat) begin
                    beat_count <= 4'd1;
                    is_first_beat <= 1'b0;
                end else begin
                    beat_count <= beat_count + 1;
                end

                // Parse headers based on data width
                if (W_MINI >= 64) begin
                    case (beat_count)
                        4'd1: begin
                            // Bytes [8:13] contain end of src MAC + EtherType
                            ethertype_reg <= {rx_data_if.data[39:32], rx_data_if.data[47:40]};
                            if ({rx_data_if.data[39:32], rx_data_if.data[47:40]} == 16'h8100) begin
                                vlan_pcp_reg <= rx_data_if.data[55:53];
                            end
                        end
                        4'd2: begin
                            if (ethertype_reg == 16'h8100) begin
                                // VLAN tagged: real EtherType at bytes [16:17], ToS at byte [19]
                                ethertype_reg <= {rx_data_if.data[7:0], rx_data_if.data[15:8]};
                                ip_tos_reg <= rx_data_if.data[23:16];
                            end else if (ethertype_reg == 16'h0800) begin
                                // IP header starts, ToS at byte [15]
                                ip_tos_reg <= rx_data_if.data[15:8];
                            end
                        end
                        4'd3: begin
                            // TCP/UDP ports (assuming IP header, no options)
                            tcp_src_port_reg <= {rx_data_if.data[7:0], rx_data_if.data[15:8]};
                            tcp_dst_port_reg <= {rx_data_if.data[23:16], rx_data_if.data[31:24]};
                        end
                        default: ;
                    endcase
                end else begin
                    // 32-bit data width parsing
                    case (beat_count)
                        4'd3: ethertype_reg <= {rx_data_if.data[7:0], rx_data_if.data[15:8]};
                        4'd4: if (ethertype_reg == 16'h8100) vlan_pcp_reg <= rx_data_if.data[7:5];
                        4'd5: if (ethertype_reg == 16'h0800) ip_tos_reg <= rx_data_if.data[15:8];
                        4'd8: begin
                            tcp_src_port_reg <= {rx_data_if.data[7:0], rx_data_if.data[15:8]};
                            tcp_dst_port_reg <= {rx_data_if.data[23:16], rx_data_if.data[31:24]};
                        end
                        default: ;
                    endcase
                end

                if (rx_data_if.last) begin
                    is_first_beat <= 1'b1;
                    beat_count <= 4'd0;
                end
            end
        end
    end

    //==========================================================================
    // QoS Classification
    //==========================================================================
    wire [QOS_TAG_WIDTH-1:0] classified_qos;
    wire [QOS_TAG_WIDTH-1:0] final_qos;
    wire classifier_active;

    assign classifier_active = use_vlan_pcp || use_ip_dscp || use_port_classify;

    qos_classifier #(
        .QOS_TAG_WIDTH(QOS_TAG_WIDTH),
        .DATA_WIDTH(W_MINI)
    ) u_classifier (
        .clk(clk),
        .rst_n(rst_n),
        .ethertype(ethertype_reg),
        .vlan_pcp(vlan_pcp_reg),
        .ip_tos(ip_tos_reg),
        .tcp_src_port(tcp_src_port_reg),
        .tcp_dst_port(tcp_dst_port_reg),
        .use_vlan_pcp(use_vlan_pcp),
        .use_ip_dscp(use_ip_dscp),
        .use_port_classify(use_port_classify),
        .qos_tag(classified_qos)
    );

    // Use classified QoS when classifier is active, otherwise pass through metadata QoS
    assign final_qos = classifier_active ? classified_qos : rx_meta_if.qos_tag;

    //==========================================================================
    // Input Queue
    //==========================================================================
    assign iq_wr_tdata  = rx_data_if.data;
    assign iq_wr_tuser  = {final_qos, rx_data_if.id, rx_data_if.is_bad_frame, rx_data_if.keep};
    assign iq_wr_tvalid = rx_data_if.valid;
    assign iq_wr_tlast  = rx_data_if.last;
    assign rx_data_if.ready = iq_wr_tready;

    axis_fifo #(
        .TDATA_WIDTH(W_MINI),
        .TUSER_WIDTH(INPUT_QUEUE_TUSER),
        .FIFO_DEPTH(INPUT_QUEUE_DEPTH)
    ) u_input_queue (
        .async_rst(~rst_n),
        .clk(clk),
        .wr_tdata(iq_wr_tdata),
        .wr_tuser(iq_wr_tuser),
        .wr_tvalid(iq_wr_tvalid),
        .wr_tlast(iq_wr_tlast),
        .wr_tready(iq_wr_tready),
        .wr_prog_full(),
        .rd_tdata(iq_rd_tdata),
        .rd_tuser(iq_rd_tuser),
        .rd_tvalid(iq_rd_tvalid),
        .rd_tlast(iq_rd_tlast),
        .rd_tready(iq_rd_tready),
        .rd_almost_empty(iq_rd_almost_empty)
    );

    //==========================================================================
    // Output to Fabric Core
    //==========================================================================
    assign iq_rd_tready       = rd_en_rx;
    assign data_rx            = iq_rd_tdata;
    assign keep_rx            = iq_rd_tuser[KEEP_WIDTH-1:0];
    assign is_bad_frame_rx    = iq_rd_tuser[KEEP_WIDTH];
    assign packet_id_rx       = iq_rd_tuser[KEEP_WIDTH+PACKET_ID_WIDTH:KEEP_WIDTH+1];
    assign qos_tag_rx         = iq_rd_tuser[INPUT_QUEUE_TUSER-1:INPUT_QUEUE_TUSER-QOS_TAG_WIDTH];
    assign valid_rx           = iq_rd_tvalid;
    assign last_rx            = iq_rd_tlast;
    assign iq_fifo_almost_empty = iq_rd_almost_empty;

    //==========================================================================
    // Metadata Handling - Destination Mask
    // MODIFIED: Registered ready output to fix setup timing violations
    //==========================================================================
    reg [NUM_PORT-1:0] dest_mask_latched;
    reg                dest_mask_valid_latched;
    reg                rx_meta_ready_reg;       // ADDED: Registered ready signal
    reg                rx_meta_ready_reg_d1;    // ADDED: Pipeline stage for timing

    // Combinational next-state logic for ready
    wire rx_meta_ready_next;
    wire packet_complete;
    
    // Detect when current packet is complete
    assign packet_complete = iq_rd_tvalid && rd_en_rx && iq_rd_tlast;
    
    // Ready when no valid destination mask is held, or when packet completes
    assign rx_meta_ready_next = !dest_mask_valid_latched || packet_complete;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dest_mask_latched       <= '0;
            dest_mask_valid_latched <= 1'b0;
            rx_meta_ready_reg       <= 1'b1;    // Ready by default after reset
            rx_meta_ready_reg_d1    <= 1'b1;    // Pipeline stage
        end else begin
            // Pipeline the ready signal for better timing
            rx_meta_ready_reg_d1 <= rx_meta_ready_next;
            rx_meta_ready_reg    <= rx_meta_ready_reg_d1;
            
            // Capture metadata when valid handshake occurs
            if (rx_meta_if.valid && rx_meta_ready_reg) begin
                dest_mask_latched       <= rx_meta_if.dest_port_mask;
                dest_mask_valid_latched <= 1'b1;
            end
            
            // Clear valid flag after last beat is read
            if (packet_complete) begin
                dest_mask_valid_latched <= 1'b0;
            end
        end
    end

    assign dest_mask_rx       = dest_mask_latched;
    assign dest_mask_valid_rx = dest_mask_valid_latched;
    
    // MODIFIED: Use registered ready signal (breaks combinational path to output)
    assign rx_meta_if.ready   = rx_meta_ready_reg;

endmodule

`default_nettype wire