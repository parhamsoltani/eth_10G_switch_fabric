`timescale 1ns / 1ps
`include "implement_options.vh"

import fabric_frame_pkg::*;

module tb_reset;
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
    event frame_sent [NUM_PORT];
    
    int test_phase = 0;
    int packets_before_reset = 0;
    int packets_after_reset = 0;
    
    //==========================================================================
    // DUT
    //==========================================================================
    switch_fabric #(
        .NUM_PORT(NUM_PORT),
        .S(`S),
        .W_MINI(W_MINI),
        .MAIN_MEM_DEPTH(`D),
        .XPQ_DEPTH(`X)
    ) dut (
        .clk(sys_clk),
        .reset(sys_reset),
        .rx_data_if(rx_data_if),
        .rx_meta_if(rx_meta_if),
        .tx_data_if(tx_data_if)
    );
    
    //==========================================================================
    // Clock
    //==========================================================================
    initial begin
        sys_clk = 0;
        forever #(SYS_PERIOD/2) sys_clk = ~sys_clk;
    end
    
    //==========================================================================
    // Test Sequence
    //==========================================================================
    initial begin
        for (int i = 0; i < NUM_PORT; i++)
            tx_mailbox[i] = new();
        
        // Initial reset
        sys_reset = 0;
        repeat(100) @(posedge sys_clk);
        sys_reset = 1;
        repeat(10) @(posedge sys_clk);
        sys_reset = 0;
        repeat(200) @(posedge sys_clk);
        
        $display("\n╔═══════════════════════════════════════════════════════╗");
        $display("║  TEST 10: RESET BEHAVIOR                              ║");
        $display("║  Test reset during operation and recovery             ║");
        $display("╚═══════════════════════════════════════════════════════╝\n");
        
        // Phase 1: Send packets before reset
        test_phase = 1;
        $display("\n[PHASE 1] Sending 20 packets before reset");
        for (int i = 0; i < 20; i++) begin
            send_packet(0, 1, 64, i);
            repeat(50) @(posedge sys_clk);
        end
        
        repeat(500) @(posedge sys_clk);
        $display("  → Packets received before reset: %0d", packets_before_reset);
        
        // Phase 2: Assert reset during traffic
        test_phase = 2;
        $display("\n[PHASE 2] Asserting reset during traffic");
        fork
            begin
                for (int i = 20; i < 30; i++) begin
                    send_packet(0, 1, 64, i);
                    repeat(20) @(posedge sys_clk);
                end
            end
        join_none
        
        repeat(100) @(posedge sys_clk);
        sys_reset = 1;
        $display("  → Reset asserted");
        repeat(50) @(posedge sys_clk);
        sys_reset = 0;
        $display("  → Reset deasserted");
        
        // Phase 3: Send packets after reset
        test_phase = 3;
        repeat(200) @(posedge sys_clk);
        $display("\n[PHASE 3] Sending 20 packets after reset");
        for (int i = 30; i < 50; i++) begin
            send_packet(0, 1, 64, i);
            repeat(50) @(posedge sys_clk);
        end
        
        repeat(1000) @(posedge sys_clk);
        
        print_results();
        $finish;
    end
    
    //==========================================================================
    // Helper Task
    //==========================================================================
    task send_packet(input int src, input int dst, input int size, input int id);
        automatic bit [7:0] payload[];
        automatic Fabric_frame_tr frame;
        
        payload = new[size];
        for (int i = 0; i < size; i++)
            payload[i] = (i + id) & 8'hFF;
        
        frame = Fabric_frame_tr::create_from_raw(
            .raw_data(payload),
            .dest(1 << dst),
            .ifg_clk(10),
            .is_bad_frame(0),
            .id(id)
        );
        
        tx_mailbox[src].put(frame);
        @frame_sent[src];
    endtask
    
    //==========================================================================
    // RX Monitor
    //==========================================================================
    initial begin
        tx_data_if[1].ready = 1'b1;
        
        forever begin
            @(posedge sys_clk);
            if (tx_data_if[1].valid && tx_data_if[1].ready && tx_data_if[1].last) begin
                if (test_phase == 1) begin
                    packets_before_reset++;
                    $display("  [PRE-RESET] Packet %0d received", tx_data_if[1].id);
                end else if (test_phase == 3) begin
                    packets_after_reset++;
                    $display("  [POST-RESET] Packet %0d received", tx_data_if[1].id);
                end
            end
        end
    end
    
    //==========================================================================
    // TX Driver
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
            end
        end
    endgenerate
    
    //==========================================================================
    // Results
    //==========================================================================
    task print_results();
        $display("\n════════════════════════════════════════════════════════");
        $display("  RESET BEHAVIOR TEST RESULTS");
        $display("════════════════════════════════════════════════════════");
        $display("  Packets before reset:  %0d / 20", packets_before_reset);
        $display("  Packets after reset:   %0d / 20", packets_after_reset);
        
        if (packets_after_reset == 20) begin
            $display("\n  ✓ FABRIC RECOVERED AFTER RESET");
        end else begin
            $display("\n  ✗ RECOVERY INCOMPLETE");
        end
        $display("════════════════════════════════════════════════════════\n");
    endtask
    
endmodule