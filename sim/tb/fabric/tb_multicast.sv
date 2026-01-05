`timescale 1ns / 1ps
`include "implement_options.vh"

import fabric_frame_pkg::*;

module tb_multicast;
    parameter NUM_PORT = `NUM_PORT;
    parameter W_MINI = `W;
    parameter SYS_PERIOD = 1.499;
    
    reg sys_clk, sys_reset;
    
    switch_data_if #(.DATA_WIDTH(W_MINI), .ID_WIDTH(8))
        rx_data_if [NUM_PORT] ();
    
    switch_metadata_if #(.PORT_MASK_WIDTH(NUM_PORT), .ID_WIDTH(8), .QOS_TAG_WIDTH(3))
        rx_meta_if [NUM_PORT] ();
    
    switch_data_if #(.DATA_WIDTH(W_MINI), .ID_WIDTH(8))
        tx_data_if [NUM_PORT] ();
    
    mailbox #(Fabric_frame_tr) tx_mailbox [NUM_PORT];
    mailbox #(Fabric_frame_tr) rx_mailbox [NUM_PORT];
    event frame_sent [NUM_PORT];
    
    int packets_sent = 0;
    int packets_received [NUM_PORT];
    
    //==========================================================================
    // DUT
    //==========================================================================
    switch_fabric #(
        .NUM_PORT(NUM_PORT),
        .S(`S),
        .W_MINI(W_MINI),
        .MAIN_MEM_DEPTH(`D),
        .XPQ_DEPTH(`X),
        .MULTICAST_SUPPORT(1),
        .PACKET_ID_WIDTH(8),
        .QOS_TAG_WIDTH(3)
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
        for (int i = 0; i < NUM_PORT; i++) begin
            tx_mailbox[i] = new();
            rx_mailbox[i] = new();
            packets_received[i] = 0;
        end
        
        wait(!sys_reset);
        repeat(200) @(posedge sys_clk);
        
        $display("\n╔═══════════════════════════════════════════════════════╗");
        $display("║  TEST 7: MULTICAST TRAFFIC                            ║");
        $display("║  Port 0 → Multiple destination ports                  ║");
        $display("╚═══════════════════════════════════════════════════════╝\n");
        
        // Test 1: Unicast (baseline)
        $display("\n[TEST 1] Unicast: Port 0 → Port 1");
        send_multicast_packet(
            .src_port(0),
            .dest_mask(10'b0000000010),  // Only port 1
            .payload_size(64),
            .pkt_id(packets_sent++)
        );
        repeat(500) @(posedge sys_clk);
        verify_multicast(1, 10'b0000000010);
        
        // Test 2: Multicast to 2 ports
        $display("\n[TEST 2] Multicast: Port 0 → Ports 1,2");
        send_multicast_packet(
            .src_port(0),
            .dest_mask(10'b0000000110),  // Ports 1,2
            .payload_size(64),
            .pkt_id(packets_sent++)
        );
        repeat(500) @(posedge sys_clk);
        verify_multicast(2, 10'b0000000110);
        
        // Test 3: Multicast to 4 ports
        $display("\n[TEST 3] Multicast: Port 0 → Ports 1,2,3,4");
        send_multicast_packet(
            .src_port(0),
            .dest_mask(10'b0000011110),  // Ports 1,2,3,4
            .payload_size(128),
            .pkt_id(packets_sent++)
        );
        repeat(1000) @(posedge sys_clk);
        verify_multicast(3, 10'b0000011110);
        
        // Test 4: Broadcast to all ports
        $display("\n[TEST 4] Broadcast: Port 0 → All ports (except 0)");
        send_multicast_packet(
            .src_port(0),
            .dest_mask(10'b1111111110),  // All except source
            .payload_size(64),
            .pkt_id(packets_sent++)
        );
        repeat(2000) @(posedge sys_clk);
        verify_multicast(4, 10'b1111111110);
        
        // Test 5: Multiple multicast packets
        $display("\n[TEST 5] Sending 10 multicast packets");
        for (int i = 0; i < 10; i++) begin
            send_multicast_packet(
                .src_port(0),
                .dest_mask(10'b0000001110),  // Ports 1,2,3
                .payload_size(64),
                .pkt_id(packets_sent++)
            );
            repeat(100) @(posedge sys_clk);
        end
        repeat(3000) @(posedge sys_clk);
        
        print_results();
        $finish;
    end
    
    //==========================================================================
    // Send Multicast Packet
    //==========================================================================
    task send_multicast_packet(
        input int src_port,
        input logic [NUM_PORT-1:0] dest_mask,
        input int payload_size,
        input int pkt_id
    );
        automatic bit [7:0] payload[];
        automatic Fabric_frame_tr frame;
        
        payload = new[payload_size];
        for (int i = 0; i < payload_size; i++)
            payload[i] = (i + pkt_id) & 8'hFF;
        
        frame = Fabric_frame_tr::create_from_raw(
            .raw_data(payload),
            .dest(dest_mask),
            .ifg_clk(20),
            .is_bad_frame(0),
            .id(pkt_id)
        );
        
        tx_mailbox[src_port].put(frame);
        
        $display("  TX: Packet ID=%0d, dest_mask=%10b", pkt_id, dest_mask);
        
        @frame_sent[src_port];
    endtask
    
    //==========================================================================
    // Verify Multicast Reception
    //==========================================================================
    task verify_multicast(input int test_num, input logic [NUM_PORT-1:0] expected_mask);
        automatic int expected_count;
        automatic int actual_count;
        automatic bit test_pass;
        
        expected_count = $countones(expected_mask);
        actual_count = 0;
        test_pass = 1'b1;
        
        for (int p = 0; p < NUM_PORT; p++) begin
            if (expected_mask[p]) begin
                if (packets_received[p] > 0) begin
                    actual_count++;
                    packets_received[p] = 0;  // Reset for next test
                end else begin
                    $error("  [FAIL] Port %0d did not receive packet", p);
                    test_pass = 1'b0;
                end
            end else begin
                if (packets_received[p] > 0) begin
                    $error("  [FAIL] Port %0d received unexpected packet", p);
                    test_pass = 1'b0;
                    packets_received[p] = 0;
                end
            end
        end
        
        if (test_pass && actual_count == expected_count) begin
            $display("  [PASS] Test %0d: %0d/%0d ports received ✓", 
                     test_num, actual_count, expected_count);
        end else begin
            $display("  [FAIL] Test %0d: %0d/%0d ports received ✗",
                     test_num, actual_count, expected_count);
        end
    endtask
    
    //==========================================================================
    // RX Monitors
    //==========================================================================
    generate
        for (genvar i = 0; i < NUM_PORT; i++) begin : gen_rx_mon
            initial begin
                automatic Fabric_frame_tr frame;
                
                tx_data_if[i].ready = 1'b1;
                
                forever begin
                    @(posedge sys_clk);
                    if (tx_data_if[i].valid && tx_data_if[i].ready && tx_data_if[i].last) begin
                        packets_received[i]++;
                        $display("    Port %0d RX: ID=%0d (count=%0d)",
                                 i, tx_data_if[i].id, packets_received[i]);
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
            
            initial begin
                rx_meta_if[i].valid = 0;
                rx_meta_if[i].dest_port_mask = 0;
                rx_meta_if[i].qos_tag = 0;
                rx_meta_if[i].id = 0;
                
                wait(tx_mailbox[i] != null);
                
                forever begin
                    automatic Fabric_frame_tr frame;
                    tx_mailbox[i].peek(frame);
                    
                    @(posedge sys_clk);
                    if (rx_data_if[i].valid && rx_data_if[i].ready) begin
                        rx_meta_if[i].valid <= 1'b1;
                        rx_meta_if[i].dest_port_mask <= frame.dest[NUM_PORT-1:0];
                        rx_meta_if[i].qos_tag <= 3'b000;
                        rx_meta_if[i].id <= frame.id[7:0];
                    end else begin
                        rx_meta_if[i].valid <= 1'b0;
                    end
                end
            end
        end
    endgenerate
    
    //==========================================================================
    // Results
    //==========================================================================
    task print_results();
        automatic int total_rx;
        
        total_rx = 0;
        for (int i = 0; i < NUM_PORT; i++)
            total_rx += packets_received[i];
        
        $display("\n════════════════════════════════════════════════════════");
        $display("  MULTICAST TEST RESULTS");
        $display("════════════════════════════════════════════════════════");
        $display("  Packets sent:      %0d", packets_sent);
        $display("  Total receptions:  %0d", total_rx);
        
        $display("\n  Per-port reception:");
        for (int i = 0; i < NUM_PORT; i++) begin
            if (packets_received[i] > 0)
                $display("    Port %0d: %0d packets", i, packets_received[i]);
        end
        
        $display("\n  ✓ MULTICAST TESTS COMPLETED");
        $display("════════════════════════════════════════════════════════\n");
    endtask
    
endmodule