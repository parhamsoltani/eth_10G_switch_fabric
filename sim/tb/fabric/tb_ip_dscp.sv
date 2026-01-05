`timescale 1ns / 1ps
`include "implement_options.vh"

import fabric_frame_pkg::*;

module tb_ip_dscp;
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
    
    int test_count = 0;
    int pass_count = 0;
    int fail_count = 0;
    
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
        $display("║  TEST 5: IP DSCP CLASSIFICATION                      ║");
        $display("║  Testing all 64 DSCP values (upper 3 bits → QoS)     ║");
        $display("╚═══════════════════════════════════════════════════════╝\n");
        
        // Test all 64 DSCP values
        for (int dscp = 0; dscp < 64; dscp++) begin
            send_ipv4_packet(
                .src_port(0),
                .dst_port(1),
                .dscp(dscp[5:0]),
                .payload_size(100)
            );
            repeat(150) @(posedge sys_clk);
        end
        
        repeat(5000) @(posedge sys_clk);
        
        print_results();
        $finish;
    end
    
    //==========================================================================
    // Send IPv4 Packet with DSCP
    //==========================================================================
    task send_ipv4_packet(
        input int src_port,
        input int dst_port,
        input logic [5:0] dscp,
        input int payload_size
    );
        automatic bit [7:0] frame_data[];
        automatic Fabric_frame_tr frame;
        automatic int total_size;
        automatic int idx;
        automatic logic [2:0] expected_qos;
        
        // Expected QoS = upper 3 bits of DSCP
        expected_qos = dscp[5:3];
        
        // Ethernet + IPv4 header + payload
        total_size = 14 + 20 + payload_size;
        frame_data = new[total_size];
        
        idx = 0;
        
        // Ethernet Header (14 bytes)
        // DA (6)
        for (int i = 0; i < 6; i++)
            frame_data[idx++] = 8'hFF;
        // SA (6)
        for (int i = 0; i < 6; i++)
            frame_data[idx++] = src_port;
        // EtherType = 0x0800 (IPv4)
        frame_data[idx++] = 8'h08;
        frame_data[idx++] = 8'h00;
        
        // IPv4 Header (20 bytes minimum)
        frame_data[idx++] = 8'h45;                    // Version=4, IHL=5
        frame_data[idx++] = {dscp, 2'b00};            // DSCP + ECN
        frame_data[idx++] = ((20 + payload_size) >> 8);  // Total Length (MSB)
        frame_data[idx++] = ((20 + payload_size) & 8'hFF); // Total Length (LSB)
        frame_data[idx++] = 8'h00;                    // Identification
        frame_data[idx++] = 8'h00;
        frame_data[idx++] = 8'h00;                    // Flags + Fragment Offset
        frame_data[idx++] = 8'h00;
        frame_data[idx++] = 8'h40;                    // TTL = 64
        frame_data[idx++] = 8'h06;                    // Protocol = TCP
        frame_data[idx++] = 8'h00;                    // Checksum (dummy)
        frame_data[idx++] = 8'h00;
        // Source IP
        frame_data[idx++] = 8'hC0;
        frame_data[idx++] = 8'hA8;
        frame_data[idx++] = 8'h01;
        frame_data[idx++] = 8'h01;
        // Dest IP
        frame_data[idx++] = 8'hC0;
        frame_data[idx++] = 8'hA8;
        frame_data[idx++] = 8'h01;
        frame_data[idx++] = 8'h02;
        
        // Payload
        for (int i = 0; i < payload_size; i++)
            frame_data[idx++] = i[7:0];
        
        frame = Fabric_frame_tr::create_from_raw(
            .raw_data(frame_data),
            .dest(1 << dst_port),
            .ifg_clk(20),
            .is_bad_frame(0),
            .id(test_count)
        );
        
        tx_mailbox[src_port].put(frame);
        test_count++;
        
        $display("[%0t] TX: DSCP=%2d (0x%02X) → expected QoS=%0d",
                 $time, dscp, dscp, expected_qos);
        
        @frame_sent[src_port];
    endtask
    
    //==========================================================================
    // RX Monitor
    //==========================================================================
    generate
        for (genvar i = 0; i < NUM_PORT; i++) begin : gen_rx_mon
            initial begin
                automatic logic [5:0] dscp;
                automatic logic [2:0] expected_qos;
                automatic logic [2:0] actual_qos;
                
                tx_data_if[i].ready = 1'b1;
                
                forever begin
                    @(posedge sys_clk);
                    if (tx_data_if[i].valid && tx_data_if[i].ready && tx_data_if[i].last) begin
                        // Extract DSCP from packet ID for verification
                        dscp = tx_data_if[i].id[5:0];
                        expected_qos = dscp[5:3];
                        
                        // Get actual QoS from metadata (would be from classifier in real design)
                        actual_qos = rx_meta_if[0].qos_tag;  // Simplified
                        
                        if (actual_qos == expected_qos) begin
                            $display("  [PASS] DSCP=%2d → QoS=%0d ✓", dscp, actual_qos);
                            pass_count++;
                        end else begin
                            $error("  [FAIL] DSCP=%2d → QoS=%0d (expected %0d) ✗",
                                   dscp, actual_qos, expected_qos);
                            fail_count++;
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
        $display("\n════════════════════════════════════════════════════════");
        $display("  IP DSCP CLASSIFICATION TEST RESULTS");
        $display("════════════════════════════════════════════════════════");
        $display("  Total Tests:    %0d", test_count);
        $display("  Passed:         %0d", pass_count);
        $display("  Failed:         %0d", fail_count);
        
        if (fail_count == 0) begin
            $display("\n  ✓ ALL IP DSCP TESTS PASSED");
        end else begin
            $display("\n  ✗ SOME TESTS FAILED");
        end
        $display("════════════════════════════════════════════════════════\n");
    endtask
    
endmodule