`timescale 1ns / 1ps

`include "fabric_params.vh"

module tb_ethernet_switch;

    //==========================================================================
    // Parameters
    //==========================================================================
    parameter NUM_PORT      = `NUM_PORTS;
    parameter DATA_WIDTH    = `DATA_WIDTH;
    parameter ID_WIDTH      = `PACKET_ID_WIDTH;
    parameter KEEP_WIDTH    = $clog2(DATA_WIDTH/8 + 1);

    parameter TX_PERIOD     = 3.2;   // 10G
    parameter SYS_PERIOD    = 1.499;

    //==========================================================================
    // Clock and Reset
    //==========================================================================
    logic sys_clk;
    logic sys_reset;

    initial begin
        sys_clk = 0;
        forever #(SYS_PERIOD) sys_clk = ~sys_clk;
    end

    initial begin
        sys_reset = 1;
        repeat (20) @(posedge sys_clk);
        sys_reset = 0;
        $display("[%0t] Reset released", $time);
    end

    //==========================================================================
    // DUT Signals (Flattened Arrays)
    //==========================================================================
    // RX Data
    logic [DATA_WIDTH-1:0]       rx_data      [NUM_PORT];
    logic [KEEP_WIDTH-1:0]       rx_keep      [NUM_PORT];
    logic                        rx_valid     [NUM_PORT];
    logic                        rx_last      [NUM_PORT];
    logic                        rx_is_bad    [NUM_PORT];
    logic                        rx_ready     [NUM_PORT];

    // RX Metadata
    logic [NUM_PORT-1:0]         rx_dest_mask [NUM_PORT];
    logic [2:0]                  rx_qos_tag   [NUM_PORT];
    logic                        rx_meta_valid[NUM_PORT];
    logic                        rx_meta_ready[NUM_PORT];

    // TX Data
    logic [DATA_WIDTH-1:0]       tx_data      [NUM_PORT];
    logic [KEEP_WIDTH-1:0]       tx_keep      [NUM_PORT];
    logic                        tx_valid     [NUM_PORT];
    logic                        tx_last      [NUM_PORT];
    logic                        tx_is_bad    [NUM_PORT];
    logic [2:0]                  tx_qos_tag   [NUM_PORT];
    logic                        tx_ready     [NUM_PORT];

    // Status
    logic [31:0]                 status_pkt_rx[NUM_PORT];
    logic [31:0]                 status_pkt_tx[NUM_PORT];
    logic [ID_WIDTH:0]           status_free_ids;

    //==========================================================================
    // DUT Instantiation
    //==========================================================================
    wrapper_switch_fabric #(
        .NUM_PORTS(NUM_PORT),
        .DATA_WIDTH(DATA_WIDTH),
        .ID_WIDTH(ID_WIDTH)
    ) u_dut (
        .clk(sys_clk),
        .reset(sys_reset),
        
        // RX Data
        .rx_data(rx_data),
        .rx_keep(rx_keep),
        .rx_valid(rx_valid),
        .rx_last(rx_last),
        .rx_is_bad_frame(rx_is_bad),
        .rx_ready(rx_ready),
        
        // RX Metadata
        .rx_dest_port_mask(rx_dest_mask),
        .rx_qos_tag(rx_qos_tag),
        .rx_meta_valid(rx_meta_valid),
        .rx_meta_ready(rx_meta_ready),
        
        // TX Data
        .tx_data(tx_data),
        .tx_keep(tx_keep),
        .tx_valid(tx_valid),
        .tx_last(tx_last),
        .tx_is_bad_frame(tx_is_bad),
        .tx_qos_tag(tx_qos_tag),
        .tx_ready(tx_ready),
        
        // Status
        .status_pkt_rx(status_pkt_rx),
        .status_pkt_tx(status_pkt_tx),
        .status_free_ids(status_free_ids)
    );

    //==========================================================================
    // Initialize TX Ready (always accept)
    //==========================================================================
    initial begin
        for (int i = 0; i < NUM_PORT; i++) begin
            tx_ready[i] = 1'b1;
        end
    end

    //==========================================================================
    // Initialize RX Signals
    //==========================================================================
    initial begin
        for (int i = 0; i < NUM_PORT; i++) begin
            rx_data[i]       = '0;
            rx_keep[i]       = '0;
            rx_valid[i]      = 1'b0;
            rx_last[i]       = 1'b0;
            rx_is_bad[i]     = 1'b0;
            rx_dest_mask[i]  = '0;
            rx_qos_tag[i]    = 3'b010;  // Medium priority default
            rx_meta_valid[i] = 1'b0;
        end
    end

    //==========================================================================
    // Test Stimulus
    //==========================================================================
    
    // Task to send a packet
    task automatic send_packet(
        input int src_port,
        input int dst_port,
        input int pkt_len,
        input logic [2:0] qos
    );
        int beats;
        beats = (pkt_len + DATA_WIDTH/8 - 1) / (DATA_WIDTH/8);
        
        // Send metadata first
        @(posedge sys_clk);
        rx_dest_mask[src_port]  = (1 << dst_port);
        rx_qos_tag[src_port]    = qos;
        rx_meta_valid[src_port] = 1'b1;
        
        @(posedge sys_clk);
        while (!rx_meta_ready[src_port]) @(posedge sys_clk);
        rx_meta_valid[src_port] = 1'b0;
        
        // Send data beats
        for (int b = 0; b < beats; b++) begin
            @(posedge sys_clk);
            rx_data[src_port]  = {$random, $random};
            rx_keep[src_port]  = (b == beats-1) ? (pkt_len % (DATA_WIDTH/8)) : (DATA_WIDTH/8);
            if (rx_keep[src_port] == 0) rx_keep[src_port] = DATA_WIDTH/8;
            rx_valid[src_port] = 1'b1;
            rx_last[src_port]  = (b == beats-1);
            rx_is_bad[src_port] = 1'b0;
            
            while (!rx_ready[src_port]) @(posedge sys_clk);
        end
        
        @(posedge sys_clk);
        rx_valid[src_port] = 1'b0;
        rx_last[src_port]  = 1'b0;
        
        $display("[%0t] Sent packet: Port %0d -> Port %0d, len=%0d, QoS=%0d", 
                 $time, src_port, dst_port, pkt_len, qos);
    endtask

    // Monitor TX
    initial begin
        forever begin
            @(posedge sys_clk);
            for (int i = 0; i < NUM_PORT; i++) begin
                if (tx_valid[i] && tx_ready[i] && tx_last[i]) begin
                    $display("[%0t] Received packet on Port %0d, QoS=%0d", 
                             $time, i, tx_qos_tag[i]);
                end
            end
        end
    end

    //==========================================================================
    // Main Test
    //==========================================================================
    initial begin
        $timeformat(-9, 2, " ns", 20);
        $display("========================================");
        $display("  Ethernet Switch QoS Testbench");
        $display("  NUM_PORTS=%0d, DATA_WIDTH=%0d", NUM_PORT, DATA_WIDTH);
        $display("========================================");
        
        // Wait for reset
        @(negedge sys_reset);
        repeat (10) @(posedge sys_clk);
        
        // Test 1: Basic unicast
        $display("\n--- Test 1: Basic Unicast ---");
        send_packet(0, 1, 64, 3'b010);
        repeat (50) @(posedge sys_clk);
        
        // Test 2: Different QoS levels
        $display("\n--- Test 2: QoS Priority ---");
        fork
            send_packet(0, 2, 128, 3'b000);  // Low priority
            send_packet(1, 2, 128, 3'b111);  // High priority
        join
        repeat (100) @(posedge sys_clk);
        
        // Test 3: Multiple ports
        $display("\n--- Test 3: Multi-port ---");
        for (int i = 0; i < NUM_PORT; i++) begin
            fork
                automatic int src = i;
                automatic int dst = (i + 1) % NUM_PORT;
                send_packet(src, dst, 256, src[2:0]);
            join_none
        end
        wait fork;
        repeat (200) @(posedge sys_clk);
        
        // Done
        $display("\n========================================");
        $display("  Test Complete");
        $display("========================================");
        
        repeat (100) @(posedge sys_clk);
        $finish;
    end

    // Timeout
    initial begin
        #1000000;
        $display("TIMEOUT!");
        $finish;
    end

endmodule