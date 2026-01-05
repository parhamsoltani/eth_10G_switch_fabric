`timescale 1ns / 1ps
`include "implement_options.vh"

import fabric_frame_pkg::*;

module tb_vlan_pcp;
    parameter NUM_PORT = `NUM_PORT;
    parameter W_MINI = `W;
    parameter SYS_PERIOD = 1.499;
    
    //==========================================================================
    // DUT Signals
    //==========================================================================
    reg sys_clk, sys_reset;
    
    switch_data_if #(.DATA_WIDTH(W_MINI), .ID_WIDTH(8))
        rx_data_if [NUM_PORT] ();
    
    switch_metadata_if #(.PORT_MASK_WIDTH(NUM_PORT), .ID_WIDTH(8), .QOS_TAG_WIDTH(3))
        rx_meta_if [NUM_PORT] ();
    
    switch_data_if #(.DATA_WIDTH(W_MINI), .ID_WIDTH(8))
        tx_data_if [NUM_PORT] ();
    
    //==========================================================================
    // Test Infrastructure
    //==========================================================================
    mailbox #(Fabric_frame_tr) tx_mailbox [NUM_PORT];
    event frame_sent [NUM_PORT];
    
    int test_vectors_sent = 0;
    int test_vectors_passed = 0;
    int test_vectors_failed = 0;
    
    // PCP to QoS mapping table
    logic [2:0] expected_qos [8];
    
    //==========================================================================
    // DUT Instantiation
    //==========================================================================
    switch_fabric #(
        .NUM_PORT(NUM_PORT),
        .S(`S),
        .W_MINI(W_MINI),
        .MAIN_MEM_DEPTH(`D),
        .XPQ_DEPTH(`X),
        .PACKET_ID_WIDTH(8),
        .QOS_TAG_WIDTH(3),
        .ENABLE_QOS(1)
    ) dut (
        .clk(sys_clk),
        .reset(sys_reset),
        .rx_data_if(rx_data_if),
        .rx_meta_if(rx_meta_if),
        .tx_data_if(tx_data_if)
    );
    
    //==========================================================================
    // Clock & Reset
    //==========================================================================
    initial begin
        sys_clk = 0;
        forever #(SYS_PERIOD/2) sys_clk = ~sys_clk;
    end
    
    initial begin
        sys_reset = 0;
        repeat(100) @(posedge sys_clk);
        sys_reset = 1;
        repeat(10) @(posedge sys_clk);
        sys_reset = 0;
    end
    
    //==========================================================================
    // Test Sequence
    //==========================================================================
    initial begin
        // Initialize PCP to QoS mapping (standard 802.1p)
        expected_qos[0] = 3'd1;  // Best Effort
        expected_qos[1] = 3'd0;  // Background
        expected_qos[2] = 3'd2;  // Excellent Effort
        expected_qos[3] = 3'd3;  // Critical Applications
        expected_qos[4] = 3'd4;  // Video
        expected_qos[5] = 3'd5;  // Voice
        expected_qos[6] = 3'd6;  // Internetwork Control
        expected_qos[7] = 3'd7;  // Network Control
        
        // Initialize mailboxes
        for (int i = 0; i < NUM_PORT; i++)
            tx_mailbox[i] = new();
        
        wait(!sys_reset);
        repeat(200) @(posedge sys_clk);
        
        $display("\n╔═══════════════════════════════════════════════════════╗");
        $display("║  TEST 4: VLAN PCP CLASSIFICATION                     ║");
        $display("║  Testing 802.1Q Priority Code Point mapping          ║");
        $display("╚═══════════════════════════════════════════════════════╝\n");
        
        // Test all 8 PCP values
        for (int pcp = 0; pcp < 8; pcp++) begin
            send_vlan_tagged_frame(
                .src_port(0),
                .dst_port(1),
                .pcp(pcp),
                .dei(0),
                .vlan_id(100),
                .payload_size(64)
            );
            repeat(200) @(posedge sys_clk);
        end
        
        // Test non-VLAN frames (should default to priority 1)
        $display("\n[TEST] Sending non-VLAN frame (should default to QoS=1)");
        send_untagged_frame(
            .src_port(0),
            .dst_port(1),
            .payload_size(64)
        );
        repeat(200) @(posedge sys_clk);
        
        // Wait for all packets
        repeat(5000) @(posedge sys_clk);
        
        print_results();
        $finish;
    end
    
    //==========================================================================
    // Send VLAN Tagged Frame
    //==========================================================================
    task send_vlan_tagged_frame(
        input int src_port,
        input int dst_port,
        input logic [2:0] pcp,
        input logic dei,
        input logic [11:0] vlan_id,
        input int payload_size
    );
        automatic bit [7:0] frame_data[];
        automatic Fabric_frame_tr frame;
        automatic int total_size;
        automatic int idx;
        
        // Frame: DA(6) + SA(6) + TPID(2) + TCI(2) + Type(2) + Payload + FCS(4)
        total_size = 6 + 6 + 2 + 2 + 2 + payload_size + 4;
        frame_data = new[total_size];
        
        idx = 0;
        
        // Destination MAC (6 bytes)
        for (int i = 0; i < 6; i++)
            frame_data[idx++] = 8'hFF;
        
        // Source MAC (6 bytes)
        for (int i = 0; i < 6; i++)
            frame_data[idx++] = src_port;
        
        // TPID = 0x8100 (2 bytes)
        frame_data[idx++] = 8'h81;
        frame_data[idx++] = 8'h00;
        
        // TCI (2 bytes): PCP(3) | DEI(1) | VID(12)
        frame_data[idx++] = {pcp, dei, vlan_id[11:8]};
        frame_data[idx++] = vlan_id[7:0];
        
        // EtherType (2 bytes)
        frame_data[idx++] = 8'h08;
        frame_data[idx++] = 8'h00;
        
        // Payload
        for (int i = 0; i < payload_size; i++)
            frame_data[idx++] = i[7:0];
        
        // FCS (4 bytes) - dummy
        for (int i = 0; i < 4; i++)
            frame_data[idx++] = 8'h00;
        
        frame = Fabric_frame_tr::create_from_raw(
            .raw_data(frame_data),
            .dest(1 << dst_port),
            .ifg_clk(20),
            .is_bad_frame(0),
            .id(test_vectors_sent)
        );
        
        tx_mailbox[src_port].put(frame);
        test_vectors_sent++;
        
        $display("[%0t] TX: VLAN frame PCP=%0d → expected QoS=%0d (VLAN_ID=%0d)",
                 $time, pcp, expected_qos[pcp], vlan_id);
        
        @frame_sent[src_port];
    endtask
    
    //==========================================================================
    // Send Untagged Frame
    //==========================================================================
    task send_untagged_frame(
        input int src_port,
        input int dst_port,
        input int payload_size
    );
        automatic bit [7:0] frame_data[];
        automatic Fabric_frame_tr frame;
        automatic int total_size;
        automatic int idx;
        
        // Frame: DA(6) + SA(6) + Type(2) + Payload + FCS(4)
        total_size = 6 + 6 + 2 + payload_size + 4;
        frame_data = new[total_size];
        
        idx = 0;
        
        // Destination MAC
        for (int i = 0; i < 6; i++)
            frame_data[idx++] = 8'hFF;
        
        // Source MAC
        for (int i = 0; i < 6; i++)
            frame_data[idx++] = src_port;
        
        // EtherType
        frame_data[idx++] = 8'h08;
        frame_data[idx++] = 8'h00;
        
        // Payload
        for (int i = 0; i < payload_size; i++)
            frame_data[idx++] = i[7:0];
        
        // FCS
        for (int i = 0; i < 4; i++)
            frame_data[idx++] = 8'h00;
        
        frame = Fabric_frame_tr::create_from_raw(
            .raw_data(frame_data),
            .dest(1 << dst_port),
            .ifg_clk(20),
            .is_bad_frame(0),
            .id(test_vectors_sent)
        );
        
        tx_mailbox[src_port].put(frame);
        test_vectors_sent++;
        
        @frame_sent[src_port];
    endtask
    
    //==========================================================================
    // RX Monitors
    //==========================================================================
    generate
        for (genvar i = 0; i < NUM_PORT; i++) begin : gen_rx_mon
            initial begin
                automatic logic [2:0] rx_qos;
                automatic int pkt_id;
                
                tx_data_if[i].ready = 1'b1;
                
                forever begin
                    @(posedge clk);
                    if (tx_data_if[i].valid && tx_data_if[i].ready && tx_data_if[i].last) begin
                        // QoS tag should be on metadata interface
                        // For this test, we check if classifier mapped PCP correctly
                        pkt_id = tx_data_if[i].id;
                        
                        // In real implementation, check rx_meta_if[i].qos_tag
                        // For now, we assume ID encodes the PCP value
                        if (pkt_id < 8) begin
                            // VLAN frame test
                            if (rx_meta_if[i].qos_tag == expected_qos[pkt_id]) begin
                                $display("  [PASS] PCP=%0d → QoS=%0d ✓", 
                                         pkt_id, rx_meta_if[i].qos_tag);
                                test_vectors_passed++;
                            end else begin
                                $error("  [FAIL] PCP=%0d → QoS=%0d (expected %0d) ✗",
                                       pkt_id, rx_meta_if[i].qos_tag, expected_qos[pkt_id]);
                                test_vectors_failed++;
                            end
                        end else begin
                            // Non-VLAN frame test
                            if (rx_meta_if[i].qos_tag == 3'd1) begin
                                $display("  [PASS] Non-VLAN → QoS=1 ✓");
                                test_vectors_passed++;
                            end else begin
                                $error("  [FAIL] Non-VLAN → QoS=%0d (expected 1) ✗",
                                       rx_meta_if[i].qos_tag);
                                test_vectors_failed++;
                            end
                        end
                    end
                end
            end
        end
    endgenerate
    
    //==========================================================================
    // TX Drivers
    //==========================================================================
    generate
        for (genvar i = 0; i < NUM_PORT; i++) begin : gen_tx_drv
            fabric_driver #(.NUM_PORT(NUM_PORT), .DATA_WIDTH(W_MINI))
            driver (
                .clk(sys_clk),
                .sw_data_if(rx_data_if[i]),
                .frame_mailbox(tx_mailbox[i]),
                .frame_sent(frame_sent[i])
            );
            
            // Metadata driver (simplified - would need VLAN parser in real design)
            initial begin
                rx_meta_if[i].valid = 0;
                rx_meta_if[i].dest_port_mask = 0;
                rx_meta_if[i].qos_tag = 0;
                rx_meta_if[i].vlan_id = 0;
            end
        end
    endgenerate
    
    //==========================================================================
    // Results
    //==========================================================================
    task print_results();
        $display("\n════════════════════════════════════════════════════════");
        $display("  VLAN PCP CLASSIFICATION TEST RESULTS");
        $display("════════════════════════════════════════════════════════");
        $display("  Total Tests:    %0d", test_vectors_sent);
        $display("  Passed:         %0d", test_vectors_passed);
        $display("  Failed:         %0d", test_vectors_failed);
        
        if (test_vectors_failed == 0) begin
            $display("\n  ✓ ALL VLAN PCP TESTS PASSED");
        end else begin
            $display("\n  ✗ SOME TESTS FAILED");
        end
        $display("════════════════════════════════════════════════════════\n");
    endtask
    
endmodule