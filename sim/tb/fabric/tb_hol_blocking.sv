`timescale 1ns / 1ps
`include "implement_options.vh"

import fabric_frame_pkg::*;

module tb_hol_blocking;
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
    
    int port1_count = 0;
    int port2_count = 0;
    time port2_start_time;
    time port2_end_time;
    
    //==========================================================================
    // DUT
    //==========================================================================
    switch_fabric #(
        .NUM_PORT(NUM_PORT),
        .S(`S),
        .W_MINI(W_MINI),
        .MAIN_MEM_DEPTH(`D),
        .XPQ_DEPTH(`X),
        .ENABLE_QOS(1)
    ) dut (
        .clk(sys_clk),
        .reset(sys_reset),
        .rx_data_if(rx_data_if),
        .rx_meta_if(rx_meta_if),
        .tx_data_if(tx_data_if)
    );
    
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
        for (int i = 0; i < NUM_PORT; i++)
            tx_mailbox[i] = new();
        
        wait(!sys_reset);
        repeat(200) @(posedge sys_clk);
        
        $display("\n╔═══════════════════════════════════════════════════════╗");
        $display("║  TEST 6: HEAD-OF-LINE BLOCKING PREVENTION            ║");
        $display("║  Port 0 → Port 1 (blocked) and Port 2 (free)         ║");
        $display("╚═══════════════════════════════════════════════════════╝\n");
        
        // Phase 1: Block Port 1
        $display("\n[PHASE 1] Blocking egress Port 1");
        force_port_blocked(1, 1);
        repeat(100) @(posedge sys_clk);
        
        // Phase 2: Send traffic to both ports
        $display("[PHASE 2] Sending 100 packets to Port 1 (will queue in VOQ)");
        fork
            begin
                for (int i = 0; i < 100; i++) begin
                    send_packet(0, 1, 64, i);
                    repeat(20) @(posedge sys_clk);
                end
            end
        join_none
        
        repeat(500) @(posedge sys_clk);
        
        $display("[PHASE 3] Sending 100 packets to Port 2 (should flow freely)");
        port2_start_time = $time;
        fork
            begin
                for (int i = 100; i < 200; i++) begin
                    send_packet(0, 2, 64, i);
                    repeat(20) @(posedge sys_clk);
                end
            end
        join_none
        
        // Wait for Port 2 traffic to complete
        wait(port2_count >= 100);
        port2_end_time = $time;
        
        $display("[PHASE 4] Unblocking Port 1");
        force_port_blocked(1, 0);
        
        // Wait for Port 1 to drain
        repeat(10000) @(posedge sys_clk);
        
        print_results();
        $finish;
    end
    
    //==========================================================================
    // Helper Tasks
    //==========================================================================
    task send_packet(input int src, input int dst, input int size, input int id);
        automatic bit [7:0] payload[];
        automatic Fabric_frame_tr frame;
        
        payload = new[size];
        for (int i = 0; i < size; i++)
            payload[i] = i[7:0];
        
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
    
    task force_port_blocked(input int port, input bit blocked);
        if (blocked) begin
            force tx_data_if[port].ready = 1'b0;
            $display("  → Port %0d BLOCKED", port);
        end else begin
            release tx_data_if[port].ready;
            $display("  → Port %0d UNBLOCKED", port);
        end
    endtask
    
    //==========================================================================
    // RX Monitors
    //==========================================================================
    generate
        for (genvar i = 0; i < NUM_PORT; i++) begin : gen_rx_mon
            initial begin
                if (i == 1 || i == 2) begin  // Only monitor port 1 and 2
                    tx_data_if[i].ready = 1'b1;
                    
                    forever begin
                        @(posedge sys_clk);
                        if (tx_data_if[i].valid && tx_data_if[i].ready && tx_data_if[i].last) begin
                            if (i == 1) begin
                                port1_count++;
                                $display("  [Port 1] Received packet %0d (total=%0d)", 
                                         tx_data_if[i].id, port1_count);
                            end else if (i == 2) begin
                                port2_count++;
                                if (port2_count <= 5 || port2_count >= 95)
                                    $display("  [Port 2] Received packet %0d (total=%0d)",
                                             tx_data_if[i].id, port2_count);
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
        end
    endgenerate
    
    //==========================================================================
    // Results
    //==========================================================================
    task print_results();
        automatic real port2_latency_us;
        
        port2_latency_us = (port2_end_time - port2_start_time) / 1000.0;
        
        $display("\n════════════════════════════════════════════════════════");
        $display("  HEAD-OF-LINE BLOCKING TEST RESULTS");
        $display("════════════════════════════════════════════════════════");
        $display("  Port 1 (blocked) received:   %0d packets", port1_count);
        $display("  Port 2 (free) received:      %0d packets", port2_count);
        $display("  Port 2 completion time:      %.2f µs", port2_latency_us);
        
        if (port2_count == 100 && port1_count > 0) begin
            $display("\n  ✓ HOL BLOCKING PREVENTED");
            $display("    Port 2 traffic completed despite Port 1 blockage");
        end else if (port2_count < 100) begin
            $display("\n  ✗ TEST FAILED: Port 2 affected by Port 1 blockage");
        end else if (port1_count == 0) begin
            $display("\n  ⚠ WARNING: Port 1 never unblocked");
        end
        $display("════════════════════════════════════════════════════════\n");
    endtask
    
endmodule