`timescale 1ns / 1ps

`include "fabric_params.vh"

module ingress_line_voq #(
    parameter NUM_PORT          = `NUM_PORTS,
    parameter DATA_WIDTH        = `DATA_WIDTH,
    parameter NUM_PORTS         = `NUM_PORTS,
    parameter ID_WIDTH          = `PACKET_ID_WIDTH,
    parameter W_MINI            = DATA_WIDTH,
    parameter KEEP_WIDTH        = $clog2((W_MINI/8) + 1),
    parameter PACKET_ID_WIDTH   = ID_WIDTH,
    parameter QOS_TAG_WIDTH     = 3,
    parameter INPUT_QUEUE_DEPTH = 16,
    parameter INPUT_QUEUE_TUSER = PACKET_ID_WIDTH + 1 + KEEP_WIDTH + QOS_TAG_WIDTH
)(
    input  wire clk,
    input  wire rst_n,

    // External RX interface
    switch_data_if.slave     rx_data_if,
    switch_metadata_if.slave rx_meta_if,

    // To VOQ stage (matches VOQ architecture expectations)
    output logic                        voq_wr_valid [NUM_PORTS],
    output logic [DATA_WIDTH-1:0]       voq_wr_data,
    output logic [KEEP_WIDTH-1:0]       voq_wr_keep,
    output logic                        voq_wr_last,
    output logic [ID_WIDTH-1:0]         voq_wr_id,
    output logic                        voq_wr_is_bad,
    output logic [QOS_TAG_WIDTH-1:0]    voq_wr_qos,
    input  logic                        voq_wr_ready [NUM_PORTS],

    // Packet ID Manager interface
    output logic                        id_alloc_req,
    input  logic                        id_alloc_grant,
    input  logic [ID_WIDTH-1:0]         allocated_id,

    // QoS Configuration
    input  logic                        qos_enable,
    input  logic                        use_vlan_pcp,
    input  logic                        use_ip_dscp,
    input  logic                        use_port_classify
);

    //==========================================================================
    // Internal Signals
    //==========================================================================
    logic [W_MINI-1:0]            iq_wr_tdata;
    logic [INPUT_QUEUE_TUSER-1:0] iq_wr_tuser;
    logic                         iq_wr_tvalid;
    logic                         iq_wr_tlast;
    logic                         iq_wr_tready;

    logic [W_MINI-1:0]            iq_rd_tdata;
    logic [INPUT_QUEUE_TUSER-1:0] iq_rd_tuser;
    logic                         iq_rd_tvalid;
    logic                         iq_rd_tlast;
    logic                         iq_rd_tready;

    logic [NUM_PORTS-1:0]         dest_mask_latched;
    logic                         dest_mask_valid;


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

    generate
    if (W_MINI >= 64) begin : gen_parse_64bit

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

                    case (beat_count)
                        4'd1: begin
                            ethertype_reg <= {rx_data_if.data[39:32], rx_data_if.data[47:40]};
                            if ({rx_data_if.data[39:32], rx_data_if.data[47:40]} == 16'h8100) begin
                                vlan_pcp_reg <= rx_data_if.data[55:53];
                            end
                        end
                        4'd2: begin
                            if (ethertype_reg == 16'h8100) begin
                                ethertype_reg <= {rx_data_if.data[7:0], rx_data_if.data[15:8]};
                                ip_tos_reg <= rx_data_if.data[23:16];
                            end else if (ethertype_reg == 16'h0800) begin
                                ip_tos_reg <= rx_data_if.data[15:8];
                            end
                        end
                        4'd3: begin
                            tcp_src_port_reg <= {rx_data_if.data[7:0], rx_data_if.data[15:8]};
                            tcp_dst_port_reg <= {rx_data_if.data[23:16], rx_data_if.data[31:24]};
                        end
                        default: ;
                    endcase

                    if (rx_data_if.last) begin
                        is_first_beat <= 1'b1;
                        beat_count <= 4'd0;
                    end
                end
            end
        end

    end else begin : gen_parse_32bit

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

                    if (rx_data_if.last) begin
                        is_first_beat <= 1'b1;
                        beat_count <= 4'd0;
                    end
                end
            end
        end

    end
    endgenerate

    //==========================================================================
    // QoS Classification
    //==========================================================================
    logic [QOS_TAG_WIDTH-1:0] classified_qos;
    logic [QOS_TAG_WIDTH-1:0] final_qos;

    qos_classifier #(
        .QOS_TAG_WIDTH(QOS_TAG_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
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

    // Use classified QoS or pass through from metadata
    assign final_qos = qos_enable ? classified_qos : rx_meta_if.qos_tag;

    //==========================================================================
    // Packet ID Allocation
    //==========================================================================
    logic [ID_WIDTH-1:0] current_pkt_id;
    logic                pkt_id_valid;

    // Request ID at start of packet
    assign id_alloc_req = rx_data_if.valid && is_first_beat && !pkt_id_valid;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_pkt_id <= '0;
            pkt_id_valid   <= 1'b0;
        end else begin
            if (id_alloc_grant) begin
                current_pkt_id <= allocated_id;
                pkt_id_valid   <= 1'b1;
            end
            if (rx_data_if.valid && rx_data_if.ready && rx_data_if.last) begin
                pkt_id_valid <= 1'b0;
            end
        end
    end

    //==========================================================================
    // Input Queue
    //==========================================================================
    assign iq_wr_tdata  = rx_data_if.data;
    assign iq_wr_tuser  = {final_qos, current_pkt_id, rx_data_if.is_bad_frame, rx_data_if.keep};
    assign iq_wr_tvalid = rx_data_if.valid && pkt_id_valid;
    assign iq_wr_tlast  = rx_data_if.last;
    assign rx_data_if.ready = iq_wr_tready && pkt_id_valid;

    axis_fifo #(
        .TDATA_WIDTH(W_MINI),
        .TUSER_WIDTH(INPUT_QUEUE_TUSER),
        .FIFO_DEPTH(INPUT_QUEUE_DEPTH)
    ) u_input_queue (
        .async_rst(1'b0),
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
        .rd_almost_empty()
    );

    //==========================================================================
    // Destination Mask Handling
    //==========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dest_mask_latched <= '0;
            dest_mask_valid   <= 1'b0;
        end else begin
            if (rx_meta_if.valid && rx_meta_if.ready) begin
                dest_mask_latched <= rx_meta_if.dest_port_mask;
                dest_mask_valid   <= 1'b1;
            end
            if (iq_rd_tvalid && iq_rd_tready && iq_rd_tlast) begin
                dest_mask_valid <= 1'b0;
            end
        end
    end

    assign rx_meta_if.ready = !dest_mask_valid || (iq_rd_tvalid && iq_rd_tready && iq_rd_tlast);

    //==========================================================================
    // VOQ Write Interface
    //==========================================================================
    // Decode destination mask to per-port valid signals
    logic any_voq_ready;
    
    always_comb begin
        any_voq_ready = 1'b0;
        for (int i = 0; i < NUM_PORTS; i++) begin
            voq_wr_valid[i] = iq_rd_tvalid && dest_mask_valid && dest_mask_latched[i];
            if (dest_mask_latched[i] && voq_wr_ready[i])
                any_voq_ready = 1'b1;
        end
    end

    assign iq_rd_tready = any_voq_ready && dest_mask_valid;

    // Data outputs - extract from tuser
    assign voq_wr_data   = iq_rd_tdata;
    assign voq_wr_keep   = iq_rd_tuser[KEEP_WIDTH-1:0];
    assign voq_wr_is_bad = iq_rd_tuser[KEEP_WIDTH];
    assign voq_wr_id     = iq_rd_tuser[KEEP_WIDTH+PACKET_ID_WIDTH:KEEP_WIDTH+1];
    assign voq_wr_qos    = iq_rd_tuser[INPUT_QUEUE_TUSER-1:INPUT_QUEUE_TUSER-QOS_TAG_WIDTH];
    assign voq_wr_last   = iq_rd_tlast;

endmodule

`default_nettype wire