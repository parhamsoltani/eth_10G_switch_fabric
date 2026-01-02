`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// QoS Diagnostic Test - Handle packet fragmentation in cell-based fabric
//////////////////////////////////////////////////////////////////////////////////

import fabric_frame_pkg::*;

`include "sim_options.vh"
`include "implement_options.vh"

module tb_fabric_qos_stress;

    parameter NUM_PORT = `NUM_PORT;
    parameter W_MINI = `W;
    parameter S = `S;
    parameter MAIN_MEM_DEPTH = `D;
    parameter XPQ_DEPTH = `X;
    parameter QOS_TAG_WIDTH = `QOS_TAG_WIDTH;
    parameter ENABLE_QOS = 1;
    parameter NUM_QOS_LEVELS = 8;

    parameter SYS_PERIOD = 1.499;

    localparam int BYTES_PER_BEAT = W_MINI / 8;
    localparam int KEEP_WIDTH = $clog2(BYTES_PER_BEAT + 1);

    // Priority level definitions (0 = highest priority, 7 = lowest)
    localparam logic [2:0] PRIO_0_CRITICAL   = 3'd0;
    localparam logic [2:0] PRIO_7_BESTEFFORT = 3'd7;

    //==========================================================================
    // DUT Infrastructure
    //==========================================================================

    reg sys_clk, sys_reset;

    switch_data_if #(.DATA_WIDTH(W_MINI), .ID_WIDTH(8))
        rx_data_if [NUM_PORT] ();

    switch_metadata_if #(.PORT_MASK_WIDTH(NUM_PORT), .ID_WIDTH(8), .QOS_TAG_WIDTH(QOS_TAG_WIDTH))
        rx_meta_if [NUM_PORT] ();

    switch_data_if #(.DATA_WIDTH(W_MINI), .ID_WIDTH(8))
        tx_data_if [NUM_PORT] ();

    switch_fabric #(
        .NUM_PORT(NUM_PORT),
        .S(S),
        .W_MINI(W_MINI),
        .MAIN_MEM_DEPTH(MAIN_MEM_DEPTH),
        .XPQ_DEPTH(XPQ_DEPTH),
        .OUTPUT_QUEUE_DEPTH(64),
        .MULTICAST_SUPPORT(0),
        .MULTICAST_RATE(1),
        .PACKET_ID_WIDTH(8),
        .QOS_TAG_WIDTH(QOS_TAG_WIDTH)
    ) dut (
        .clk(sys_clk),
        .reset(sys_reset),
        .rx_data_if(rx_data_if),
        .rx_meta_if(rx_meta_if),
        .tx_data_if(tx_data_if)
    );

    // Clock generation
    initial begin
        sys_clk = 0;
        forever #(SYS_PERIOD) sys_clk = ~sys_clk;
    end

    // Reset
    initial begin
        sys_reset = 0;
        repeat (100) @(posedge sys_clk);
        sys_reset = 1;
        repeat (10) @(posedge sys_clk);
        sys_reset = 0;
    end

    //==========================================================================
    // Tracking Infrastructure
    //==========================================================================

    typedef struct {
        realtime    tx_time;
        int         src_port;
        int         dst_port;
        logic [2:0] qos;
        int         size;
        bit         received;
    } pkt_info_t;

    pkt_info_t pkt_tracker[int];

    int port_seq_num[NUM_PORT];
    int total_packets_sent;
    int total_packets_received;
    int total_packets_misrouted;
    int total_fragments;

    int       pkt_count[NUM_QOS_LEVELS];
    real      latency_sum[NUM_QOS_LEVELS];
    real      latency_min[NUM_QOS_LEVELS];
    real      latency_max[NUM_QOS_LEVELS];

    // Backpressure monitoring
    int total_ready_cycles[NUM_PORT];
    int not_ready_cycles[NUM_PORT];

    semaphore port_sem[NUM_PORT];

    //==========================================================================
    // Per-port drive request structure
    //==========================================================================

    typedef struct {
        bit [NUM_PORT-1:0] dst_mask;
        bit [7:0] pkt_id;
        logic [2:0] qos;
        int size;
        bit [7:0] data[2048];
        bit valid;
        bit done;
    } drive_req_t;

    drive_req_t drive_request[NUM_PORT];

    //==========================================================================
    // Initialization
    //==========================================================================

    initial begin
        for (int i = 0; i < NUM_QOS_LEVELS; i++) begin
            pkt_count[i] = 0;
            latency_sum[i] = 0.0;
            latency_min[i] = 1e9;
            latency_max[i] = 0.0;
        end

        for (int p = 0; p < NUM_PORT; p++) begin
            port_seq_num[p] = 0;
            total_ready_cycles[p] = 0;
            not_ready_cycles[p] = 0;
            drive_request[p].valid = 0;
            drive_request[p].done = 0;
        end

        for (int i = 0; i < NUM_PORT; i++) begin
            port_sem[i] = new(1);
        end

        total_packets_sent = 0;
        total_packets_received = 0;
        total_packets_misrouted = 0;
        total_fragments = 0;
    end

    //==========================================================================
    // Helper function
    //==========================================================================
    
    function automatic int make_tracker_key(int src_port, int seq_num);
        return (src_port << 16) | (seq_num & 16'hFFFF);
    endfunction

    //==========================================================================
    // Main Test Sequence
    //==========================================================================

    initial begin
        wait (!sys_reset);
        repeat (500) @(posedge sys_clk);

        $display("\n================================================================");
        $display("            DIAGNOSTIC TEST SUITE                              ");
        $display("   BYTES_PER_BEAT = %0d, KEEP_WIDTH = %0d", BYTES_PER_BEAT, KEEP_WIDTH);
        $display("================================================================\n");

        // Test 1: Single packet, no congestion
        $display("[TEST 1] Single packet from port 0 to port 1");
        send_single_packet(0, 1, 64, PRIO_0_CRITICAL);
        repeat (2000) @(posedge sys_clk);
        $display("  Sent: %0d, Received: %0d, Fragments: %0d", 
                 total_packets_sent, total_packets_received, total_fragments);

        // Test 2: One packet per port, different destinations
        $display("\n[TEST 2] One packet from each port to next port (round robin)");
        for (int i = 0; i < NUM_PORT; i++) begin
            send_single_packet(i, (i+1) % NUM_PORT, 64, PRIO_0_CRITICAL);
            repeat (100) @(posedge sys_clk);
        end
        repeat (5000) @(posedge sys_clk);
        $display("  Sent: %0d, Received: %0d, Fragments: %0d", 
                 total_packets_sent, total_packets_received, total_fragments);

        // Test 3: Multiple packets with spacing
        $display("\n[TEST 3] 10 packets from port 0 to port 1 with 500 cycle gaps");
        for (int i = 0; i < 10; i++) begin
            send_single_packet(0, 1, 128, PRIO_0_CRITICAL);
            repeat (500) @(posedge sys_clk);
        end
        repeat (10000) @(posedge sys_clk);
        $display("  Sent: %0d, Received: %0d, Fragments: %0d", 
                 total_packets_sent, total_packets_received, total_fragments);

        // Test 4: Concurrent traffic from all ports
        $display("\n[TEST 4] Concurrent: 5 packets from each port to port 0");
        fork
            begin
                for (int p = 0; p < NUM_PORT; p++) begin
                    automatic int port_idx = p;
                    fork
                        begin
                            for (int i = 0; i < 5; i++) begin
                                send_single_packet(port_idx, 0, 64, PRIO_0_CRITICAL);
                                repeat (200) @(posedge sys_clk);
                            end
                        end
                    join_none
                end
            end
        join
        wait fork;
        repeat (50000) @(posedge sys_clk);
        $display("  Sent: %0d, Received: %0d, Fragments: %0d", 
                 total_packets_sent, total_packets_received, total_fragments);

        // Test 5: Heavy concurrent traffic
        $display("\n[TEST 5] Heavy: 20 packets from each port to random destinations");
        fork
            begin
                for (int p = 0; p < NUM_PORT; p++) begin
                    automatic int port_idx = p;
                    fork
                        begin
                            for (int i = 0; i < 20; i++) begin
                                automatic int dst = $urandom_range(0, NUM_PORT-1);
                                if (dst == port_idx) dst = (dst + 1) % NUM_PORT;
                                send_single_packet(port_idx, dst, $urandom_range(64, 256), 
                                                  $urandom_range(0, 7));
                                repeat ($urandom_range(50, 200)) @(posedge sys_clk);
                            end
                        end
                    join_none
                end
            end
        join
        wait fork;
        
        $display("  After sending: Sent: %0d, Received: %0d, Fragments: %0d", 
                 total_packets_sent, total_packets_received, total_fragments);
        
        // Extended drain
        $display("\n[DRAIN] Waiting for remaining packets...");
        drain_and_report(200000);

        // Print backpressure statistics
        print_backpressure_stats();

        // Print latency summary
        print_latency_summary();

        // Print final summary
        print_final_summary();

        $display("\n[%0t] Test complete", $time);
        $stop;
    end

    //==========================================================================
    // Send single packet task - uses handshake with per-port driver
    //==========================================================================

    task automatic send_single_packet(
        input int src,
        input int dst,
        input int size,
        input logic [2:0] qos
    );
        automatic bit [NUM_PORT-1:0] dst_mask = (1 << dst);
        automatic int seq_num;
        automatic int tracker_key;
        automatic bit [7:0] pkt_id;

        port_sem[src].get(1);

        seq_num = port_seq_num[src];
        port_seq_num[src] = port_seq_num[src] + 1;
        tracker_key = make_tracker_key(src, seq_num);
        pkt_id = seq_num[7:0];

        // Record tracking info
        pkt_tracker[tracker_key].tx_time = $realtime;
        pkt_tracker[tracker_key].src_port = src;
        pkt_tracker[tracker_key].dst_port = dst;
        pkt_tracker[tracker_key].qos = qos;
        pkt_tracker[tracker_key].size = size;
        pkt_tracker[tracker_key].received = 0;

        // Build payload with tracking info embedded at start
        // Use unique pattern that's easy to find
        drive_request[src].data[0] = 8'hDE;  // Magic header byte 1
        drive_request[src].data[1] = 8'hAD;  // Magic header byte 2
        drive_request[src].data[2] = 8'hBE;  // Magic header byte 3
        drive_request[src].data[3] = 8'hEF;  // Magic header byte 4
        drive_request[src].data[4] = src[7:0];
        drive_request[src].data[5] = dst[7:0];
        drive_request[src].data[6] = seq_num[7:0];
        drive_request[src].data[7] = seq_num[15:8];
        drive_request[src].data[8] = {5'b0, qos};
        drive_request[src].data[9] = size[7:0];
        drive_request[src].data[10] = size[15:8];
        drive_request[src].data[11] = 8'hA5;  // End of header marker
        for (int i = 12; i < size; i++) begin
            drive_request[src].data[i] = i[7:0];
        end

        // Set up request
        drive_request[src].dst_mask = dst_mask;
        drive_request[src].pkt_id = pkt_id;
        drive_request[src].qos = qos;
        drive_request[src].size = size;
        drive_request[src].valid = 1;

        // Wait for driver to complete
        wait(drive_request[src].done);
        drive_request[src].valid = 0;
        @(posedge sys_clk);

        total_packets_sent++;

        port_sem[src].put(1);
    endtask

    //==========================================================================
    // Drain task with progress reporting
    //==========================================================================

    task drain_and_report(input int max_cycles);
        int cycles;
        int last_received;
        int idle_count;
        
        cycles = 0;
        last_received = 0;
        idle_count = 0;

        while (cycles < max_cycles) begin
            repeat (5000) @(posedge sys_clk);
            cycles = cycles + 5000;

            if (total_packets_received == total_packets_sent) begin
                $display("  All %0d packets received after %0d cycles", 
                        total_packets_received, cycles);
                return;
            end

            if (total_packets_received == last_received) begin
                idle_count = idle_count + 1;
                if (idle_count >= 10) begin
                    $display("  Stalled at %0d/%0d packets after %0d cycles",
                            total_packets_received, total_packets_sent, cycles);
                    return;
                end
            end else begin
                $display("  Progress: %0d/%0d packets received (fragments: %0d)",
                        total_packets_received, total_packets_sent, total_fragments);
                idle_count = 0;
            end
            last_received = total_packets_received;
        end

        $display("  Timeout: %0d/%0d packets received", 
                total_packets_received, total_packets_sent);
    endtask

    //==========================================================================
    // Port interface drivers and monitors (generate block)
    //==========================================================================

    generate
        for (genvar i = 0; i < NUM_PORT; i++) begin : gen_port

            // Initialize interfaces
            initial begin
                rx_data_if[i].valid = 1'b0;
                rx_data_if[i].data = '0;
                rx_data_if[i].last = 1'b0;
                rx_data_if[i].id = '0;
                rx_data_if[i].keep = '0;
                rx_data_if[i].is_bad_frame = 1'b0;
                rx_data_if[i].qos_tag = '0;

                rx_meta_if[i].dest_port_mask = '0;
                rx_meta_if[i].qos_tag = '0;
                rx_meta_if[i].id = '0;
                rx_meta_if[i].valid = 1'b0;
                rx_meta_if[i].vlan_id = '0;

                tx_data_if[i].ready = 1'b1;
            end

            // Per-port packet driver
            initial begin
                forever begin
                    @(posedge sys_clk);
                    if (drive_request[i].valid && !drive_request[i].done) begin
                        automatic int bytes_sent = 0;
                        automatic int total_bytes = drive_request[i].size;

                        // Send metadata
                        rx_meta_if[i].dest_port_mask <= drive_request[i].dst_mask;
                        rx_meta_if[i].qos_tag <= drive_request[i].qos;
                        rx_meta_if[i].id <= drive_request[i].pkt_id;
                        rx_meta_if[i].valid <= 1'b1;

                        // Send data beats
                        while (bytes_sent < total_bytes) begin
                            automatic int bytes_this_beat;
                            automatic bit [W_MINI-1:0] beat_data = '0;
                            automatic bit [KEEP_WIDTH-1:0] beat_keep;
                            automatic bit is_last_beat;

                            bytes_this_beat = (total_bytes - bytes_sent > BYTES_PER_BEAT) ?
                                              BYTES_PER_BEAT : (total_bytes - bytes_sent);
                            is_last_beat = (bytes_sent + bytes_this_beat >= total_bytes);

                            for (int b = 0; b < bytes_this_beat; b++) begin
                                beat_data[b*8 +: 8] = drive_request[i].data[bytes_sent + b];
                            end
                            beat_keep = bytes_this_beat[KEEP_WIDTH-1:0];

                            rx_data_if[i].data <= beat_data;
                            rx_data_if[i].keep <= beat_keep;
                            rx_data_if[i].last <= is_last_beat;
                            rx_data_if[i].id <= drive_request[i].pkt_id;
                            rx_data_if[i].qos_tag <= drive_request[i].qos;
                            rx_data_if[i].is_bad_frame <= 1'b0;
                            rx_data_if[i].valid <= 1'b1;

                            do begin
                                @(posedge sys_clk);
                            end while (!rx_data_if[i].ready);

                            bytes_sent = bytes_sent + bytes_this_beat;
                        end

                        rx_data_if[i].valid <= 1'b0;
                        rx_meta_if[i].valid <= 1'b0;

                        drive_request[i].done <= 1'b1;
                        @(posedge sys_clk);
                        drive_request[i].done <= 1'b0;
                    end
                end
            end

            // Monitor backpressure on input
            always @(posedge sys_clk) begin
                if (!sys_reset) begin
                    if (rx_data_if[i].valid) begin
                        total_ready_cycles[i] <= total_ready_cycles[i] + 1;
                        if (!rx_data_if[i].ready) begin
                            not_ready_cycles[i] <= not_ready_cycles[i] + 1;
                        end
                    end
                end
            end

            // RX monitor - Use packet ID to match packets
            initial begin
                bit [7:0] rx_payload[4096];
                int rx_byte_count;
                int packets_on_port;
                bit [7:0] current_pkt_id;
                
                rx_byte_count = 0;
                packets_on_port = 0;

                forever begin
                    @(posedge sys_clk);
                    if (tx_data_if[i].valid && tx_data_if[i].ready) begin
                        // Capture packet ID from interface
                        current_pkt_id = tx_data_if[i].id;
                        
                        // Extract all bytes from the data bus
                        for (int b = 0; b < BYTES_PER_BEAT && rx_byte_count < 4096; b++) begin
                            rx_payload[rx_byte_count] = tx_data_if[i].data[b*8 +: 8];
                            rx_byte_count = rx_byte_count + 1;
                        end

                        if (tx_data_if[i].last) begin
                            packets_on_port++;
                            
                            // Debug first few packets per port
                            if (packets_on_port <= 3) begin
                                $display("[DEBUG] Port %0d pkt %0d: id=%0d, %0d bytes, first 24:", 
                                        i, packets_on_port, current_pkt_id, rx_byte_count);
                                for (int b = 0; b < 24 && b < rx_byte_count; b++) begin
                                    $write(" %02X", rx_payload[b]);
                                end
                                $display("");
                            end
                            
                            // Process based on whether it has DEADBEEF header
                            process_received_packet(i, rx_payload, rx_byte_count, current_pkt_id);
                            
                            rx_byte_count = 0;
                        end
                    end
                end
            end

        end
    endgenerate

    //==========================================================================
    // Process received packet - handle both complete packets and fragments
    //==========================================================================

    task automatic process_received_packet(
        input int port,
        input bit [7:0] payload[4096],
        input int byte_count,
        input bit [7:0] pkt_id
    );
        int found_offset;
        int embedded_src;
        int embedded_dst;
        int embedded_seq;
        logic [2:0] embedded_qos;
        int embedded_size;
        int tracker_key;
        realtime rx_time;
        real latency_ns;
        
        found_offset = -1;
        rx_time = $realtime;

        // Search for DEADBEEF magic pattern
        for (int offset = 0; offset <= byte_count - 12; offset++) begin
            if (payload[offset] == 8'hDE && 
                payload[offset+1] == 8'hAD && 
                payload[offset+2] == 8'hBE && 
                payload[offset+3] == 8'hEF) begin
                found_offset = offset;
                break;
            end
        end

        if (found_offset < 0) begin
            // This is a fragment without header - count it but don't process
            total_fragments++;
            return;
        end

        // Extract header fields
        embedded_src = payload[found_offset + 4];
        embedded_dst = payload[found_offset + 5];
        embedded_seq = {payload[found_offset + 7], payload[found_offset + 6]};
        embedded_qos = payload[found_offset + 8][2:0];
        embedded_size = {payload[found_offset + 10], payload[found_offset + 9]};

        if (embedded_src >= NUM_PORT) begin
            $display("[WARN] Port %0d: Invalid src port %0d at offset %0d", 
                    port, embedded_src, found_offset);
            total_fragments++;
            return;
        end

        tracker_key = make_tracker_key(embedded_src, embedded_seq);

        if (!pkt_tracker.exists(tracker_key)) begin
            $display("[WARN] Port %0d: Unknown packet src=%0d seq=%0d", 
                    port, embedded_src, embedded_seq);
            total_fragments++;
            return;
        end

        if (pkt_tracker[tracker_key].received) begin
            // Already received - this is a duplicate, count as fragment
            total_fragments++;
            return;
        end

        latency_ns = (rx_time - pkt_tracker[tracker_key].tx_time) / 1000.0;

        if (pkt_tracker[tracker_key].dst_port != port) begin
            total_packets_misrouted++;
            $display("[ERROR] Packet misrouted: expected port %0d, got port %0d (src=%0d seq=%0d)",
                    pkt_tracker[tracker_key].dst_port, port, embedded_src, embedded_seq);
        end

        // Use original QoS from tracker for statistics
        embedded_qos = pkt_tracker[tracker_key].qos;

        if (embedded_qos < NUM_QOS_LEVELS) begin
            pkt_count[embedded_qos]++;
            latency_sum[embedded_qos] = latency_sum[embedded_qos] + latency_ns;
            if (latency_ns < latency_min[embedded_qos])
                latency_min[embedded_qos] = latency_ns;
            if (latency_ns > latency_max[embedded_qos])
                latency_max[embedded_qos] = latency_ns;
        end

        pkt_tracker[tracker_key].received = 1;
        total_packets_received++;
    endtask

    //==========================================================================
    // Reporting Tasks
    //==========================================================================

    task print_backpressure_stats();
        $display("\n=== Backpressure Statistics ===");
        for (int p = 0; p < NUM_PORT; p++) begin
            if (total_ready_cycles[p] > 0) begin
                automatic real pct = 100.0 * not_ready_cycles[p] / total_ready_cycles[p];
                $display("  Port %0d: %0d/%0d cycles not ready (%.1f%%)",
                        p, not_ready_cycles[p], total_ready_cycles[p], pct);
            end else begin
                $display("  Port %0d: No traffic", p);
            end
        end
    endtask

    task print_latency_summary();
        $display("\n=== QoS Latency Summary ===");
        for (int p = 0; p < NUM_QOS_LEVELS; p++) begin
            if (pkt_count[p] > 0) begin
                automatic real avg = latency_sum[p] / pkt_count[p];
                $display("  Priority %0d: %5d pkts, avg=%8.1fns, min=%8.1fns, max=%8.1fns",
                    p, pkt_count[p], avg, latency_min[p], latency_max[p]);
            end
        end
    endtask

    task print_final_summary();
        int lost;
        real loss_pct;
        int total_outputs;

        $display("\n================================================================");
        $display("                    FINAL SUMMARY                              ");
        $display("================================================================");

        total_outputs = total_packets_received + total_fragments;
        
        $display("\nPacket Statistics:");
        $display("  Total Sent:        %0d", total_packets_sent);
        $display("  Total Received:    %0d (complete packets with header)", total_packets_received);
        $display("  Total Fragments:   %0d (data without header - likely split packets)", total_fragments);
        $display("  Total Outputs:     %0d", total_outputs);

        lost = total_packets_sent - total_packets_received;
        if (total_packets_sent > 0) begin
            loss_pct = 100.0 * lost / total_packets_sent;
        end else begin
            loss_pct = 0.0;
        end

        if (lost > 0) begin
            $display("  Lost Packets:      %0d (%.1f%%)", lost, loss_pct);
        end else begin
            $display("  Lost Packets:      0 [PASS]");
        end

        $display("  Misrouted:         %0d", total_packets_misrouted);

        // Analysis of fragments
        if (total_fragments > 0) begin
            $display("\n  NOTE: %0d fragments detected. This suggests the fabric may be", total_fragments);
            $display("        splitting packets into multiple output bursts.");
            $display("        Packets sent: %0d, Complete+Fragments: %0d", 
                    total_packets_sent, total_outputs);
            if (total_outputs > total_packets_sent) begin
                $display("        Ratio: %.2f outputs per input (packet splitting)", 
                        real'(total_outputs) / real'(total_packets_sent));
            end
        end

        if (lost == 0 && total_packets_misrouted == 0) begin
            $display("\n  *** ALL TESTS PASSED ***");
        end else begin
            $display("\n  *** FAILURES DETECTED ***");
            
            // List which packets were lost (up to 30)
            if (lost > 0 && lost <= 30) begin
                $display("\n  Lost packet details:");
                foreach (pkt_tracker[key]) begin
                    if (!pkt_tracker[key].received) begin
                        $display("    src=%0d dst=%0d seq=%0d qos=%0d size=%0d",
                                pkt_tracker[key].src_port,
                                pkt_tracker[key].dst_port,
                                key & 16'hFFFF,
                                pkt_tracker[key].qos,
                                pkt_tracker[key].size);
                    end
                end
            end else if (lost > 30) begin
                $display("\n  Too many lost packets to list (%0d total)", lost);
            end
        end
    endtask

endmodule

`default_nettype wire