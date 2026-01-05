`timescale 1ns / 1ps
`include "implement_options.vh"

import fabric_frame_pkg::*;

module tb_wfq;
    parameter NUM_PORT = `NUM_PORT;
    parameter W_MINI = `W;
    parameter SYS_PERIOD = 1.499;
    parameter NUM_PACKETS = 500;
    
    reg sys_clk, sys_reset;
    
    switch_data_if #(.DATA_WIDTH(W_MINI), .ID_WIDTH(8))
        rx_data_if [NUM_PORT] ();
    
    switch_metadata_if #(.PORT_MASK_WIDTH(NUM_PORT), .ID_WIDTH(8), .QOS_TAG_WIDTH(3))
        rx_meta_if [NUM_PORT] ();
    
    switch_data_if #(.DATA_WIDTH(W_MINI), .ID_WIDTH(8))
        tx_data_if [NUM_PORT] ();
    
    mailbox #(Fabric_frame_tr) tx_mailbox [NUM_PORT];
    event frame_sent [NUM_PORT];
    
    int packets_sent_p0 = 0;
    int packets_sent_p7 = 0;
    int packets_recv_p0 = 0;
    int packets_recv_p7 = 0;
    time start_time_p0, end_time_p0;
    time start_time_p7, end_time_p7;
    
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
        $display("║  TEST 9: WEIGHTED FAIR QUEUING                        ║");
        $display("║  Send equal P7 & P0 traffic, measure bandwidth        ║");
        $display("╚═══════════════════════════════════════════════════════╝\n");
        
        // Send streams simultaneously
        fork
            begin
                start_time_p7 = $time;
                for (int i = 0; i < NUM_PACKETS; i++) begin
                    send_packet(0, 1, 64, 7, i);  // Priority 7
                    repeat(10) @(posedge sys_clk);
                end
            end
            
            begin
                start_time_p0 = $time;
                for (int i = 0; i < NUM_PACKETS; i++) begin
                    send_packet(0, 1, 64, 0, i + 1000);  // Priority 0
                    repeat(10) @(posedge sys_clk);
                end
            end
        join
        
        // Wait for all packets
        repeat(20000) @(posedge sys_clk);
        
        print_results();
        $finish;
    end
    
    //==========================================================================
    // Send Packet with QoS
    //==========================================================================
    task send_packet(
        input int src,
        input int dst,
        input int size,
        input int qos,
        input int id
    );
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
        
        if (qos == 7)
            packets_sent_p7++;
        else
            packets_sent_p0++;
        
        @frame_sent[src];
    endtask
    
    //==========================================================================
    // RX Monitor
    //==========================================================================
    initial begin
        wait(!sys_reset);
        tx_data_if[1].ready = 1'b1;
        
        forever begin
            @(posedge sys_clk);
            if (tx_data_if[1].valid && tx_data_if[1].ready && tx_data_if[1].last) begin
                if (tx_data_if[1].id < 1000) begin
                    // Priority 7 packet
                    packets_recv_p7++;
                    if (packets_recv_p7 == 1)
                        $display("  First P7 packet received at %0t", $time);
                    if (packets_recv_p7 == NUM_PACKETS) begin
                        end_time_p7 = $time;
                        $display("  Last P7 packet received at %0t", $time);
                    end
                end else begin
                    // Priority 0 packet
                    packets_recv_p0++;
                    if (packets_recv_p0 == 1)
                        $display("  First P0 packet received at %0t", $time);
                    if (packets_recv_p0 == NUM_PACKETS) begin
                        end_time_p0 = $time;
                        $display("  Last P0 packet received at %0t", $time);
                    end
                end
            end
        end
    end
    
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
        automatic real throughput_p7;
        automatic real throughput_p0;
        automatic real ratio;
        automatic real duration_p7_us;
        automatic real duration_p0_us;
        
        duration_p7_us = (end_time_p7 - start_time_p7) / 1000.0;
        duration_p0_us = (end_time_p0 - start_time_p0) / 1000.0;
        
        throughput_p7 = (duration_p7_us > 0) ? 
                        (packets_recv_p7 * 64 * 8) / duration_p7_us : 0;
        throughput_p0 = (duration_p0_us > 0) ? 
                        (packets_recv_p0 * 64 * 8) / duration_p0_us : 0;
        
        ratio = (throughput_p0 > 0) ? throughput_p7 / throughput_p0 : 0;
        
        $display("\n════════════════════════════════════════════════════════");
        $display("  WEIGHTED FAIR QUEUING TEST RESULTS");
        $display("════════════════════════════════════════════════════════");
        $display("  Priority 7 (High):");
        $display("    Sent:        %0d packets", packets_sent_p7);
        $display("    Received:    %0d packets", packets_recv_p7);
        $display("    Duration:    %.2f µs", duration_p7_us);
        $display("    Throughput:  %.2f Mbps", throughput_p7);
        
        $display("\n  Priority 0 (Low):");
        $display("    Sent:        %0d packets", packets_sent_p0);
        $display("    Received:    %0d packets", packets_recv_p0);
        $display("    Duration:    %.2f µs", duration_p0_us);
        $display("    Throughput:  %.2f Mbps", throughput_p0);
        
        $display("\n  Bandwidth Ratio (P7/P0):  %.2f:1", ratio);
        
        if (ratio > 5.0 && ratio < 200.0) begin
            $display("\n  ✓ WEIGHTED FAIR QUEUING WORKING");
        end else begin
            $display("\n  ⚠ WARNING: Ratio outside expected range (5-200)");
        end
        $display("════════════════════════════════════════════════════════\n");
    endtask
    
endmodule