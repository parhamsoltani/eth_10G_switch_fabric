`timescale 1ns / 1ps
`include "implement_options.vh"

import fabric_frame_pkg::*;

module tb_backpressure;
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
    
    int packets_sent = 0;
    int packets_received = 0;
    int backpressure_cycles = 0;
    
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
        for (int i = 0; i < NUM_PORT; i++)
            tx_mailbox[i] = new();
        
        wait(!sys_reset);
        repeat(200) @(posedge sys_clk);
        
        $display("\n╔═══════════════════════════════════════════════════════╗");
        $display("║  TEST 8: BACK-PRESSURE HANDLING                       ║");
        $display("║  Random ready deassertions on egress                   ║");
        $display("╚═══════════════════════════════════════════════════════╝\n");
        
        // Send continuous stream of packets
        fork
            begin
                for (int i = 0; i < 200; i++) begin
                    send_packet(0, 1, 64, i);
                    repeat($urandom_range(10, 50)) @(posedge sys_clk);
                end
            end
        join_none
        
        // Wait for completion
        repeat(50000) @(posedge sys_clk);
        
        print_results();
        $finish;
    end
    
    //==========================================================================
    // Random Back-Pressure Generator
    //==========================================================================
    initial begin
        wait(!sys_reset);
        
        forever begin
            @(posedge sys_clk);
            
            // Random backpressure: 30% probability
            if ($urandom_range(0, 99) < 30) begin
                tx_data_if[1].ready <= 1'b0;
                backpressure_cycles++;
            end else begin
                tx_data_if[1].ready <= 1'b1;
            end
        end
    end
    
    //==========================================================================
    // Helper Tasks
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
        packets_sent++;
        
        @frame_sent[src];
    endtask
    
    //==========================================================================
    // RX Monitor
    //==========================================================================
    initial begin
        wait(!sys_reset);
        
        forever begin
            @(posedge sys_clk);
            if (tx_data_if[1].valid && tx_data_if[1].ready && tx_data_if[1].last) begin
                packets_received++;
                if (packets_received % 20 == 0 || packets_received <= 5)
                    $display("  [RX] Packet %0d received", tx_data_if[1].id);
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
        automatic real backpressure_ratio;
        
        backpressure_ratio = 100.0 * real'(backpressure_cycles) / 50000.0;
        
        $display("\n════════════════════════════════════════════════════════");
        $display("  BACK-PRESSURE TEST RESULTS");
        $display("════════════════════════════════════════════════════════");
        $display("  Packets sent:         %0d", packets_sent);
        $display("  Packets received:     %0d", packets_received);
        $display("  Backpressure cycles:  %0d (%.1f%%)", 
                 backpressure_cycles, backpressure_ratio);
        
        if (packets_received == packets_sent) begin
            $display("\n  ✓ ALL PACKETS DELIVERED DESPITE BACKPRESSURE");
        end else begin
            $display("\n  ✗ PACKET LOSS: %0d packets missing",
                     packets_sent - packets_received);
        end
        $display("════════════════════════════════════════════════════════\n");
    endtask
    
endmodule