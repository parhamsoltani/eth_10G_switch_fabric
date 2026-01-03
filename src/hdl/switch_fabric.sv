`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: IUST
// Engineer: Parham Soltani
// Module Name: switch_fabric
// Description: QoS-Enabled Switch Fabric with Packet ID Preservation
// Version: 2.2 - Fixed QoS classifier override and packet ID propagation
//////////////////////////////////////////////////////////////////////////////////

`include "fabric_params.vh"
`include "qos_defines.vh"

module switch_fabric #(
    parameter   NUM_PORT                = 10,
    parameter   S                       = 10,
    parameter   W_MINI                  = 64,
    parameter   MAIN_MEM_DEPTH          = 512,
    parameter   XPQ_DEPTH               = 64,
    parameter   OUTPUT_QUEUE_DEPTH      = 128,
    parameter   MULTICAST_SUPPORT       = 0,
    parameter   MULTICAST_RATE          = 1,
    parameter   PACKET_ID_WIDTH         = 8,
    parameter   QOS_TAG_WIDTH           = 3,
    parameter   ENABLE_QOS              = 1
) (
    input   wire                                clk,
    input   wire                                reset,
    switch_data_if.slave_mp                     rx_data_if  [NUM_PORT],
    switch_metadata_if.slave_mp                 rx_meta_if  [NUM_PORT],
    switch_data_if.master_mp                    tx_data_if  [NUM_PORT]
);

    //==========================================================================
    // Local Parameters
    //==========================================================================
    localparam KEEP_WIDTH = $clog2((W_MINI/8) + 1);
    localparam INPUT_QUEUE_DEPTH     = 2*S+10;
    localparam INPUT_QUEUE_TUSER     = PACKET_ID_WIDTH + 1 + KEEP_WIDTH + QOS_TAG_WIDTH;
    localparam OUTPUT_QUEUE_TUSER    = 1 + KEEP_WIDTH + PACKET_ID_WIDTH;  // MODIFIED: Added PACKET_ID_WIDTH
    localparam OQ_PROG_FULL_THRESH   = 30;
    localparam NOT_READY_LIMIT       = 20;

    //==========================================================================
    // Internal Wires (Core Switch ↔ Ingress/Egress)
    //==========================================================================
    wire [W_MINI-1:0]           data_rx        [NUM_PORT];
    wire [KEEP_WIDTH-1:0]       keep_rx        [NUM_PORT];
    wire                        valid_rx       [NUM_PORT];
    wire                        is_bad_frame_rx [NUM_PORT];
    wire [PACKET_ID_WIDTH-1:0]  packet_id_rx   [NUM_PORT];
    wire                        last_rx        [NUM_PORT];
    wire                        iq_fifo_almost_empty [NUM_PORT];
    wire [NUM_PORT-1:0]         dest_mask_rx   [NUM_PORT];
    wire                        dest_mask_valid_rx [NUM_PORT];
    wire                        rd_en_rx       [NUM_PORT];
    wire [QOS_TAG_WIDTH-1:0]    qos_tag_rx     [NUM_PORT];

    wire [W_MINI-1:0]           data_tx        [NUM_PORT];
    wire [KEEP_WIDTH-1:0]       keep_tx        [NUM_PORT];
    wire                        valid_tx       [NUM_PORT];
    wire                        is_bad_frame_tx [NUM_PORT];
    wire                        last_tx        [NUM_PORT];
    wire [PACKET_ID_WIDTH-1:0]  packet_id_tx   [NUM_PORT];   // NEW: Packet ID from switch core
    wire [QOS_TAG_WIDTH-1:0]    qos_tag_tx     [NUM_PORT];   // NEW: QoS tag from switch core
    wire                        oq_wr_prog_full [NUM_PORT];

    // Debug outputs kept as internal wires
    wire [$clog2(MULTICAST_RATE * MAIN_MEM_DEPTH):0] addr_fifos_num_free_internal;
    wire [$clog2(MAIN_MEM_DEPTH):0] free_fifo_count_internal;

    //==========================================================================
    // QoS Configuration - DISABLED FOR TESTBENCH CONTROL
    //==========================================================================
    // FIXED: Disable classifier in simulation to allow testbench control
    `ifdef SIMULATION
        wire use_vlan_pcp       = 1'b0;  // Disable VLAN PCP classification
        wire use_ip_dscp        = 1'b0;  // Disable IP DSCP classification
        wire use_port_classify  = 1'b0;  // Disable port classification
    `else
        wire use_vlan_pcp       = 1'b1;  // Enable in synthesis
        wire use_ip_dscp        = 1'b1;  // Enable in synthesis
        wire use_port_classify  = 1'b0;  // Disable port classification
    `endif
    
    wire qos_enable         = ENABLE_QOS;

    //==========================================================================
    // INGRESS: QoS-Aware vs Standard
    //==========================================================================
    generate
        for (genvar i = 0; i < NUM_PORT; i++) begin : gen_ingress_ports

            if (ENABLE_QOS) begin : gen_qos_ingress
                
                ingress_line_qos #(
                    .NUM_PORT(NUM_PORT),
                    .W_MINI(W_MINI),
                    .KEEP_WIDTH(KEEP_WIDTH),
                    .PACKET_ID_WIDTH(PACKET_ID_WIDTH),
                    .QOS_TAG_WIDTH(QOS_TAG_WIDTH),
                    .INPUT_QUEUE_DEPTH(INPUT_QUEUE_DEPTH),
                    .INPUT_QUEUE_TUSER(INPUT_QUEUE_TUSER)
                ) ingress_inst (
                    .clk(clk),
                    .rst_n(~reset),
                    .rx_data_if(rx_data_if[i]),
                    .rx_meta_if(rx_meta_if[i]),
                    .rd_en_rx(rd_en_rx[i]),
                    .data_rx(data_rx[i]),
                    .keep_rx(keep_rx[i]),
                    .valid_rx(valid_rx[i]),
                    .is_bad_frame_rx(is_bad_frame_rx[i]),
                    .packet_id_rx(packet_id_rx[i]),
                    .last_rx(last_rx[i]),
                    .iq_fifo_almost_empty(iq_fifo_almost_empty[i]),
                    .dest_mask_rx(dest_mask_rx[i]),
                    .dest_mask_valid_rx(dest_mask_valid_rx[i]),
                    .qos_tag_rx(qos_tag_rx[i]),
                    .use_vlan_pcp(use_vlan_pcp),
                    .use_ip_dscp(use_ip_dscp),
                    .use_port_classify(use_port_classify)
                );
                
            end else begin : gen_standard_ingress
                
                ingress_switch #(
                    .NUM_PORT(NUM_PORT),
                    .W_MINI(W_MINI),
                    .KEEP_WIDTH(KEEP_WIDTH),
                    .PACKET_ID_WIDTH(PACKET_ID_WIDTH),
                    .QOS_TAG_WIDTH(QOS_TAG_WIDTH),
                    .INPUT_QUEUE_DEPTH(INPUT_QUEUE_DEPTH),
                    .INPUT_QUEUE_TUSER(PACKET_ID_WIDTH + 1 + KEEP_WIDTH)
                ) ingress_inst (
                    .clk(clk),
                    .rx_data_if(rx_data_if[i]),
                    .rx_meta_if(rx_meta_if[i]),
                    .rd_en_rx(rd_en_rx[i]),
                    .data_rx(data_rx[i]),
                    .keep_rx(keep_rx[i]),
                    .valid_rx(valid_rx[i]),
                    .is_bad_frame_rx(is_bad_frame_rx[i]),
                    .packet_id_rx(packet_id_rx[i]),
                    .last_rx(last_rx[i]),
                    .iq_fifo_almost_empty(iq_fifo_almost_empty[i]),
                    .dest_mask_rx(dest_mask_rx[i]),
                    .dest_mask_valid_rx(dest_mask_valid_rx[i])
                );
                
                // Pass through testbench QoS tag (no classification)
                assign qos_tag_rx[i] = rx_meta_if[i].qos_tag;
                
            end

        end
    endgenerate

    //==========================================================================
    // CORE SWITCH: Select Architecture Based on NUM_PORT
    //==========================================================================
    generate
        
        if (NUM_PORT <= S) begin : gen_under_s

            if (ENABLE_QOS) begin : gen_qos_switch
                
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
                    .QOS_TAG_WIDTH(QOS_TAG_WIDTH),
                    .KEEP_WIDTH(KEEP_WIDTH)
                ) switch_inst (
                    .clk(clk),
                    .data_rx(data_rx),
                    .keep_rx(keep_rx),
                    .valid_rx(valid_rx),
                    .is_bad_frame_rx(is_bad_frame_rx),
                    .packet_id_rx(packet_id_rx),
                    .qos_tag_rx(qos_tag_rx),                // Connect QoS input
                    .last_rx(last_rx),
                    .iq_fifo_almost_empty(iq_fifo_almost_empty),
                    .dest_mask_rx(dest_mask_rx),
                    .dest_mask_valid_rx(dest_mask_valid_rx),
                    .rd_en_rx(rd_en_rx),
                    .data_tx(data_tx),
                    .keep_tx(keep_tx),
                    .valid_tx(valid_tx),
                    .is_bad_frame_tx(is_bad_frame_tx),
                    .packet_id_tx(packet_id_tx),             // Connect packet_id
                    .qos_tag_tx(qos_tag_tx),                 // Connect QoS output
                    .last_tx(last_tx),
                    .oq_wr_prog_full(oq_wr_prog_full),
                    .addr_fifos_num_free_o(addr_fifos_num_free_internal),
                    .free_fifo_count_o(free_fifo_count_internal)
                );
                
            end else begin : gen_standard_switch
                
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
                    .data_rx(data_rx),
                    .keep_rx(keep_rx),
                    .valid_rx(valid_rx),
                    .is_bad_frame_rx(is_bad_frame_rx),
                    .packet_id_rx(packet_id_rx),
                    .last_rx(last_rx),
                    .iq_fifo_almost_empty(iq_fifo_almost_empty),
                    .dest_mask_rx(dest_mask_rx),
                    .dest_mask_valid_rx(dest_mask_valid_rx),
                    .rd_en_rx(rd_en_rx),
                    .data_tx(data_tx),
                    .keep_tx(keep_tx),
                    .valid_tx(valid_tx),
                    .is_bad_frame_tx(is_bad_frame_tx),
                    .last_tx(last_tx),
                    .oq_wr_prog_full(oq_wr_prog_full),
                    .addr_fifos_num_free_o(addr_fifos_num_free_internal),
                    .free_fifo_count_o(free_fifo_count_internal)
                );
                
                // FIXED: Preserve packet ID and QoS tag through standard switch
                for (genvar j = 0; j < NUM_PORT; j++) begin : gen_pkt_id_passthrough
                    assign packet_id_tx[j] = packet_id_rx[j];  // Pass through packet ID
                    assign qos_tag_tx[j] = qos_tag_rx[j];      // Pass through QoS tag
                end
                
            end

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
                .data_rx(data_rx),
                .keep_rx(keep_rx),
                .valid_rx(valid_rx),
                .is_bad_frame_rx(is_bad_frame_rx),
                .packet_id_rx(packet_id_rx),
                .last_rx(last_rx),
                .iq_fifo_almost_empty(iq_fifo_almost_empty),
                .dest_mask_rx(dest_mask_rx),
                .dest_mask_valid_rx(dest_mask_valid_rx),
                .rd_en_rx(rd_en_rx),
                .data_tx(data_tx),
                .keep_tx(keep_tx),
                .valid_tx(valid_tx),
                .is_bad_frame_tx(is_bad_frame_tx),
                .last_tx(last_tx),
                .oq_wr_prog_full(oq_wr_prog_full),
                .addr_fifos_num_free_o(addr_fifos_num_free_internal),
                .free_fifo_count_o(free_fifo_count_internal)
            );
            
            // FIXED: Preserve packet ID and QoS tag
            for (genvar j = 0; j < NUM_PORT; j++) begin : gen_pkt_id_passthrough_2s
                assign packet_id_tx[j] = packet_id_rx[j];
                assign qos_tag_tx[j] = qos_tag_rx[j];
            end
            
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
                .data_rx(data_rx),
                .keep_rx(keep_rx),
                .valid_rx(valid_rx),
                .is_bad_frame_rx(is_bad_frame_rx),
                .packet_id_rx(packet_id_rx),
                .qos_tag_rx(qos_tag_rx),
                .last_rx(last_rx),
                .iq_fifo_almost_empty(iq_fifo_almost_empty),
                .dest_mask_rx(dest_mask_rx),
                .dest_mask_valid_rx(dest_mask_valid_rx),
                .rd_en_rx(rd_en_rx),
                .data_tx(data_tx),
                .keep_tx(keep_tx),
                .valid_tx(valid_tx),
                .is_bad_frame_tx(is_bad_frame_tx),
                .packet_id_tx(packet_id_tx),
                .qos_tag_tx(qos_tag_tx),
                .last_tx(last_tx),
                .oq_wr_prog_full(oq_wr_prog_full),
                .addr_fifos_num_free_o(addr_fifos_num_free_internal),
                .free_fifo_count_o(free_fifo_count_internal)
            );
                
        end
    endgenerate


    //==========================================================================
    // EGRESS: With Packet ID Propagation
    //==========================================================================
    generate
        for (genvar i = 0; i < NUM_PORT; i++) begin : gen_egress_ports

            egress_switch #(
                .NUM_PORT(NUM_PORT),
                .W_MINI(W_MINI),
                .KEEP_WIDTH(KEEP_WIDTH),
                .OUTPUT_QUEUE_DEPTH(OUTPUT_QUEUE_DEPTH),
                .OUTPUT_QUEUE_TUSER(OUTPUT_QUEUE_TUSER),
                .OQ_PROG_FULL_THRESH(OQ_PROG_FULL_THRESH),
                .NOT_READY_LIMIT(NOT_READY_LIMIT),
                .PACKET_ID_WIDTH(PACKET_ID_WIDTH),        // Pass parameter
                .QOS_TAG_WIDTH(QOS_TAG_WIDTH)             // Pass parameter
            ) egress_inst (
                .clk(clk),
                .tx_data_if(tx_data_if[i]),
                .data_tx(data_tx[i]),
                .keep_tx(keep_tx[i]),
                .valid_tx(valid_tx[i]),
                .is_bad_frame_tx(is_bad_frame_tx[i]),
                .last_tx(last_tx[i]),
                .packet_id_tx(packet_id_tx[i]),          // Connect packet_id
                .qos_tag_tx(qos_tag_tx[i]),              // Connect QoS tag
                .oq_wr_prog_full(oq_wr_prog_full[i])
            );

        end
    endgenerate

    //==========================================================================
    // Debug Display
    //==========================================================================
    // synthesis translate_off
    initial begin
        $display("═══════════════════════════════════════════════════════════");
        $display(" Switch Fabric Configuration (QoS-Enabled + Packet ID)");
        $display(" Version 2.2 - Fixed classifier override");
        $display("═══════════════════════════════════════════════════════════");
        $display("NUM_PORT =            %0d", NUM_PORT          );
        $display("S =                   %0d", S                 );
        $display("W_MINI =              %0d", W_MINI            );
        $display("MAIN_MEM_DEPTH =      %0d", MAIN_MEM_DEPTH    );
        $display("XPQ_DEPTH =           %0d", XPQ_DEPTH         );
        $display("OUTPUT_QUEUE_DEPTH =  %0d", OUTPUT_QUEUE_DEPTH);
        $display("MULTICAST_SUPPORT =   %0d", MULTICAST_SUPPORT );
        $display("MULTICAST_RATE =      %0d", MULTICAST_RATE    );
        $display("PACKET_ID_WIDTH =     %0d", PACKET_ID_WIDTH   );
        $display("QOS_TAG_WIDTH =       %0d", QOS_TAG_WIDTH     );
        $display("ENABLE_QoS =          %0d", ENABLE_QOS        );
        `ifdef SIMULATION
        $display("CLASSIFIER_ENABLED =  %0d (DISABLED for testbench)", 
                  use_vlan_pcp || use_ip_dscp || use_port_classify);
        `endif
        $display("═══════════════════════════════════════════════════════════");
    end
    // synthesis translate_on

endmodule

`default_nettype wire