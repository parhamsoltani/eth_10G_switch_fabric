`timescale 1ns / 1ps
`include "implement_options.vh"

import fabric_frame_pkg::*;

module tb_jumbo_frames;
    parameter NUM_PORT = `NUM_PORT;
    parameter W_MINI = `W;
    parameter JUMBO_SIZE = 9000;
    parameter NUM_JUMBO_FRAMES = 100;
    parameter SYS_PERIOD = 1.499;
    
    // DUT signals
    reg sys_clk, sys_reset;
    
    switch_data_if #(.DATA_WIDTH(W_MINI), .ID_WIDTH(8))
        rx_data_if [NUM_PORT] ();
    
    switch_metadata_if #(.PORT_MASK_WIDTH(NUM_PORT), .ID_WIDTH(8), .QOS_TAG_WIDTH(3))
        rx_meta_if [NUM_PORT] ();
    
    switch_data_if #(.DATA_WIDTH(W_MINI), .ID_WIDTH(8))
        tx_data_if [NUM_PORT] ();
    
    // Test infrastructure
    mailbox #(Fabric_frame_tr) tx_mailbox [NUM_PORT];
    mailbox #(Fabric_frame_tr) rx_mailbox [NUM_PORT];
    event frame_sent [NUM_PORT];
    
    int jumbo_sent = 0;
    int jumbo_recv = 0;
    int cell_count_tx = 0;
    int cell_count_rx = 0;
    int corruption_errors = 0;
    
    // DUT
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
    
    // Clock & reset
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
    
    // Test sequence
    initial begin
        automatic Fabric_frame_tr frame;
        automatic bit [7:0] payload[];
        automatic int src, dst;
        automatic logic [2:0] qos;
        
        for (int i = 0; i < NUM_PORT; i++) begin
            tx_mailbox[i] = new();
            rx_mailbox[i] = new();
        end
        
        wait(!sys_reset);
        repeat(200) @(posedge sys_clk);
        
        $display("\n╔═══════════════════════════════════════════════════════╗");
        $display("║  TEST 7: JUMBO FRAME HANDLING (9000 bytes)          ║");
        $display("║  Testing cell segmentation and reassembly            ║");
        $display("╚═══════════════════════════════════════════════════════╝\n");
        
        // Send jumbo frames with random src/dst/qos
        for (int i = 0; i < NUM_JUMBO_FRAMES; i++) begin
            src = $urandom_range(0, NUM_PORT-1);
            dst = $urandom_range(0, NUM_PORT-1);
            qos = $urandom_range(0, 7);
            
            payload = new[JUMBO_SIZE];
            for (int k = 0; k < JUMBO_SIZE; k++) 
                payload[k] = k[7:0];  // Predictable pattern for corruption detection
            
            frame = Fabric_frame_tr::create_from_raw(
                .raw_data(payload),
                .dest(1 << dst),
                .ifg_clk(50),
                .is_bad_frame(0),
                .id(i)
            );
            
            tx_mailbox[src].put(frame);
            jumbo_sent++;
            
            $display("[%0t] Sending jumbo %0d: Port %0d → Port %0d (9KB, qos=%0d)", 
                     $time, i, src, dst, qos);
            
            @frame_sent[src];
            repeat(200) @(posedge sys_clk);
        end
        
        // Wait for all frames
        $display("\n[%0t] Waiting for reassembly...", $time);
        repeat(100000) @(posedge sys_clk);
        
        // Results
        print_results();
        
        $finish;
    end
    
    // RX monitors - verify reassembly
    generate
        for (genvar i = 0; i < NUM_PORT; i++) begin : gen_rx_mon
            initial begin
                automatic bit [7:0] rx_data_bytes[];
                automatic int byte_count;
                automatic int pkt_id;
                automatic bit corruption;
                
                tx_data_if[i].ready = 1'b1;
                byte_count = 0;
                
                forever begin
                    @(posedge sys_clk);
                    if (tx_data_if[i].valid && tx_data_if[i].ready) begin
                        if (byte_count == 0) begin
                            pkt_id = tx_data_if[i].id;
                            $display("  [Port %0d] Receiving jumbo frame ID=%0d", i, pkt_id);
                        end
                        
                        // Collect bytes
                        for (int b = 0; b < W_MINI/8; b++) begin
                            if (b < tx_data_if[i].keep) begin
                                rx_data_bytes = new[byte_count + 1](rx_data_bytes);
                                rx_data_bytes[byte_count] = tx_data_if[i].data[b*8 +: 8];
                                byte_count++;
                            end
                        end
                        
                        cell_count_rx++;
                        
                        if (tx_data_if[i].last) begin
                            jumbo_recv++;
                            
                            // Verify size
                            if (byte_count != JUMBO_SIZE) begin
                                $error("  Size mismatch: expected %0d, got %0d", JUMBO_SIZE, byte_count);
                                corruption_errors++;
                            end else begin
                                // Verify payload integrity
                                corruption = 0;
                                for (int k = 0; k < byte_count; k++) begin
                                    if (rx_data_bytes[k] != k[7:0]) begin
                                        if (!corruption) begin
                                            $error("  Corruption at byte %0d: expected %02X, got %02X",
                                                   k, k[7:0], rx_data_bytes[k]);
                                            corruption_errors++;
                                        end
                                        corruption = 1;
                                    end
                                end
                                
                                if (!corruption) begin
                                    $display("  ✓ Jumbo frame %0d verified (%0d bytes, %0d cells)",
                                             pkt_id, byte_count, cell_count_rx);
                                end
                            end
                            
                            byte_count = 0;
                            rx_data_bytes = new[0];
                        end
                    end
                end
            end
        end
    endgenerate
    
    // TX drivers
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
    
    task print_results();
        $display("\n════════════════════════════════════════════════════════");
        $display("  JUMBO FRAME TEST RESULTS");
        $display("════════════════════════════════════════════════════════");
        $display("  Jumbo Sent:          %0d", jumbo_sent);
        $display("  Jumbo Received:      %0d", jumbo_recv);
        $display("  Cells Transmitted:   %0d", cell_count_tx);
        $display("  Cells Reassembled:   %0d", cell_count_rx);
        $display("  Corruption Errors:   %0d", corruption_errors);
        
        if (jumbo_sent == jumbo_recv && corruption_errors == 0) begin
            $display("\n  ✓ JUMBO FRAME TEST PASSED");
            $display("    All 9KB frames correctly segmented and reassembled");
        end else begin
            $display("\n  ✗ JUMBO FRAME TEST FAILED");
        end
        $display("════════════════════════════════════════════════════════\n");
    endtask
    
endmodule