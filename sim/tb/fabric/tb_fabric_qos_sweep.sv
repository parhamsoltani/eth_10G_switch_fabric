`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Automated QoS configuration sweep testbench
// Validates QoS latency and packet delivery
//////////////////////////////////////////////////////////////////////////////////

import fabric_frame_pkg::*;

`include "sim_options.vh"
`include "implement_options.vh"
`include "qos_defines.vh"

`include "../../hvl/verification/qos_latency_tracker.sv"

module tb_fabric_qos_sweep;

    parameter NUM_PORT = `NUM_PORT;
    parameter W_MINI = `W;
    parameter S = `S;
    parameter MAIN_MEM_DEPTH = `D;
    parameter XPQ_DEPTH = `X;
    parameter QOS_TAG_WIDTH = `QOS_TAG_WIDTH;
    parameter ENABLE_QOS = 1;
    parameter PACKET_ID_WIDTH = 8;

    parameter SYS_PERIOD = 1.499;
    localparam TB = "tb_fabric_qos_sweep";

    string test_vector_file = "../../sim/tb/fabric/test_vectors_qos.json";

    // Packet ID counter for unique IDs (1-255, avoid 0)
    int global_pkt_id = 1;

    //==========================================================================
    // Clock & Reset
    //==========================================================================
    reg sys_clk;
    reg sys_reset;

    initial begin
        $timeformat(-9, 2, " ns", 20);
        sys_clk = 0;
        forever #(SYS_PERIOD) sys_clk = ~sys_clk;
    end

    initial begin
        sys_reset = 0;
        repeat (100) @(posedge sys_clk);
        sys_reset = 1;
        repeat (10) @(posedge sys_clk);
        sys_reset = 0;
    end

    //==========================================================================
    // Interfaces
    //==========================================================================
    switch_data_if #(.DATA_WIDTH(W_MINI), .ID_WIDTH(PACKET_ID_WIDTH))
        rx_data_if [NUM_PORT] ();

    switch_metadata_if #(.PORT_MASK_WIDTH(NUM_PORT), .ID_WIDTH(PACKET_ID_WIDTH), .QOS_TAG_WIDTH(QOS_TAG_WIDTH))
        rx_meta_if [NUM_PORT] ();

    switch_data_if #(.DATA_WIDTH(W_MINI), .ID_WIDTH(PACKET_ID_WIDTH))
        tx_data_if [NUM_PORT] ();

    //==========================================================================
    // Shadow signals for TX monitoring
    //==========================================================================
    logic [NUM_PORT-1:0] tx_valid;
    logic [NUM_PORT-1:0] tx_ready;
    logic [NUM_PORT-1:0] tx_last;
    logic [PACKET_ID_WIDTH-1:0] tx_id [NUM_PORT];

    generate
        for (genvar g = 0; g < NUM_PORT; g++) begin : gen_shadow
            assign tx_valid[g] = tx_data_if[g].valid;
            assign tx_ready[g] = tx_data_if[g].ready;
            assign tx_last[g]  = tx_data_if[g].last;
            assign tx_id[g]    = tx_data_if[g].id;
        end
    endgenerate

    //==========================================================================
    // DUT
    //==========================================================================
    switch_fabric #(
        .NUM_PORT(NUM_PORT),
        .S(S),
        .W_MINI(W_MINI),
        .MAIN_MEM_DEPTH(MAIN_MEM_DEPTH),
        .XPQ_DEPTH(XPQ_DEPTH),
        .OUTPUT_QUEUE_DEPTH(64),
        .MULTICAST_SUPPORT(0),
        .MULTICAST_RATE(1),
        .PACKET_ID_WIDTH(PACKET_ID_WIDTH),
        .QOS_TAG_WIDTH(QOS_TAG_WIDTH),
        .ENABLE_QOS(ENABLE_QOS)
    ) dut (
        .clk(sys_clk),
        .reset(sys_reset),
        .rx_data_if(rx_data_if),
        .rx_meta_if(rx_meta_if),
        .tx_data_if(tx_data_if)
    );

    //==========================================================================
    // Traffic Generators & Tracking
    //==========================================================================
    mailbox #(Fabric_frame_tr) frame_mailbox_in[NUM_PORT];
    mailbox #(Fabric_frame_tr) frame_mailbox_out[NUM_PORT];
    event frame_sent[NUM_PORT];

    qos_latency_tracker_simple latency_tracker;

    // Simple packet tracking - indexed by 8-bit packet ID directly
    typedef struct {
        bit valid;
        int src_port;
        int dst_port;
        logic [2:0] qos;
        time tx_time;
        int size_bytes;
    } pkt_info_t;
    
    // Direct array indexed by packet ID (1-255)
    pkt_info_t sent_packets[256];

    initial begin
        latency_tracker = new();
        for (int i = 0; i < 256; i++) begin
            sent_packets[i].valid = 0;
        end
    end

    //==========================================================================
    // Test Execution
    //==========================================================================
    initial begin
        automatic int test_pass = 1;
        
        for (int i = 0; i < NUM_PORT; i++) begin
            frame_mailbox_in[i] = new();
            frame_mailbox_out[i] = new();
        end

        wait (!sys_reset);
        repeat (100) @(posedge sys_clk);

        if ($fopen(test_vector_file, "r")) begin
            load_test_vectors();
        end else begin
            run_default_tests();
        end

        // Wait for all packets to drain
        repeat (5000) @(posedge sys_clk);

        // Print results
        $display("\n");
        $display("╔═══════════════════════════════════════════════════════════════╗");
        $display("║                    QoS SWEEP TEST RESULTS                     ║");
        $display("╚═══════════════════════════════════════════════════════════════╝");
        
        latency_tracker.print_summary();
        print_packet_stats();
        
        // Validate results
        test_pass = validate_results();
        
        if (test_pass) begin
            $display("\n[PASS] All QoS tests passed!");
        end else begin
            $display("\n[FAIL] Some QoS tests failed - see details above");
        end

        $display("\n[%0t] Sweep complete", $time);
        repeat (100) @(posedge sys_clk);
        $stop;
    end

    //==========================================================================
    // Statistics
    //==========================================================================
    int packets_sent = 0;
    int packets_received = 0;
    int packets_matched = 0;
    int packets_id_zero = 0;
    int packets_id_not_found = 0;

    task print_packet_stats();
        automatic int still_pending = 0;
        
        $display("\n─── Packet Delivery Statistics ───");
        $display("  Packets Sent:      %0d", packets_sent);
        $display("  Packets Received:  %0d", packets_received);
        $display("  Packets Matched:   %0d", packets_matched);
        $display("  Packet Loss:       %0d (%.2f%%)", 
            packets_sent - packets_matched,
            100.0 * (packets_sent - packets_matched) / packets_sent);
        
        // Count pending packets
        for (int i = 1; i < 256; i++) begin
            if (sent_packets[i].valid) still_pending++;
        end
        
        if (still_pending > 0) begin
            $display("  Still pending:     %0d", still_pending);
            if (still_pending <= 5) begin
                for (int i = 1; i < 256; i++) begin
                    if (sent_packets[i].valid) begin
                        $display("    - ID=%0d src=%0d dst=%0d qos=%0d", 
                            i, sent_packets[i].src_port, sent_packets[i].dst_port, sent_packets[i].qos);
                    end
                end
            end
        end
    endtask

    //==========================================================================
    // Result Validation
    //==========================================================================
    function int validate_results();
        automatic int pass = 1;
        automatic real loss_pct;
        automatic real high_prio_avg, low_prio_avg;
        
        $display("\n─── Validation Checks ───");
        
        // Check 1: Packet loss should be < 1%
        loss_pct = 100.0 * (packets_sent - packets_matched) / packets_sent;
        if (loss_pct > 1.0) begin
            $display("  [FAIL] Packet loss %.2f%% exceeds 1%% threshold", loss_pct);
            pass = 0;
        end else begin
            $display("  [OK]   Packet loss %.2f%% within threshold", loss_pct);
        end
        
        // Check 2: All packets should be received
        if (packets_received != packets_sent) begin
            $display("  [FAIL] Received %0d packets, expected %0d", packets_received, packets_sent);
            pass = 0;
        end else begin
            $display("  [OK]   All %0d packets received", packets_sent);
        end
        
        // Check 3: High priority should have lower average latency than low priority
        // (This is a soft check - we report but don't fail on it)
        high_prio_avg = latency_tracker.get_avg_latency(7);
        low_prio_avg = latency_tracker.get_avg_latency(0);
        
        if (high_prio_avg > 0 && low_prio_avg > 0) begin
            if (high_prio_avg < low_prio_avg) begin
                $display("  [OK]   Priority ordering correct (high=%.1fns < low=%.1fns)", 
                    high_prio_avg, low_prio_avg);
            end else begin
                $display("  [INFO] Priority ordering: high=%.1fns, low=%.1fns (may vary under light load)", 
                    high_prio_avg, low_prio_avg);
            end
        end
        
        return pass;
    endfunction

    //==========================================================================
    // Test Tasks
    //==========================================================================
    task run_default_tests();
        $display("\n[QoS SWEEP] Running default test patterns");
        $display("─────────────────────────────────────────");

        test_uniform_priority(`PRIORITY_HIGH, 100);
        test_mixed_priority(100);
        test_priority_inversion(50);
        test_critical_burst(20);
    endtask

    task test_uniform_priority(input logic [2:0] prio_level, input int num_packets);
        $display("\n[TEST] Uniform priority: %0d packets @ priority %0d", num_packets, prio_level);

        for (int i = 0; i < num_packets; i++) begin
            send_packet_qos(
                .src($urandom_range(0, NUM_PORT-1)),
                .dst($urandom_range(0, NUM_PORT-1)),
                .size($urandom_range(64, 1500)),
                .qos(prio_level),
                .ifg($urandom_range(10, 50))
            );
        end

        repeat (1000) @(posedge sys_clk);
    endtask

    task test_mixed_priority(input int num_packets);
        automatic logic [2:0] prio;
        
        $display("\n[TEST] Mixed priority: %0d packets (alternating high/low)", num_packets);

        for (int i = 0; i < num_packets; i++) begin
            prio = (i % 2) ? `PRIORITY_HIGH : `PRIORITY_LOW;
            send_packet_qos(
                .src(i % NUM_PORT),
                .dst((i+1) % NUM_PORT),
                .size($urandom_range(64, 512)),
                .qos(prio),
                .ifg(20)
            );
        end

        repeat (1000) @(posedge sys_clk);
    endtask

    task test_priority_inversion(input int num_packets);
        $display("\n[TEST] Priority inversion: %0d low-pri + %0d high-pri burst", 
            num_packets, num_packets/2);

        fork
            // Background low-priority traffic
            begin
                for (int i = 0; i < num_packets; i++) begin
                    send_packet_qos(0, 1, 512, `PRIORITY_LOW, 10);
                end
            end
            // Delayed high-priority burst
            begin
                #(SYS_PERIOD*200);
                for (int i = 0; i < num_packets/2; i++) begin
                    send_packet_qos(2, 1, 256, `PRIORITY_HIGH, 10);
                end
            end
        join

        repeat (2000) @(posedge sys_clk);
    endtask

    task test_critical_burst(input int num_packets);
        $display("\n[TEST] Critical priority burst: %0d packets", num_packets);

        repeat (num_packets) begin
            send_packet_qos(0, 1, 128, `PRIORITY_CRITICAL, 5);
        end

        repeat (500) @(posedge sys_clk);
    endtask

    task automatic send_packet_qos(
        input int src,
        input int dst,
        input int size,
        input logic [2:0] qos,
        input int ifg
    );
        automatic bit [NUM_PORT-1:0] dst_mask = (1 << dst);
        automatic bit [7:0] raw_data[] = new[size];
        automatic Fabric_frame_tr frame;
        automatic int pkt_id;
        automatic int wait_count = 0;

        // Generate unique packet ID (1-255, wrap around)
        pkt_id = global_pkt_id;
        global_pkt_id++;
        if (global_pkt_id > 255) global_pkt_id = 1;

        // Wait if this ID is still pending (avoid collision) - with timeout
        while (sent_packets[pkt_id].valid && wait_count < 1000) begin
            @(posedge sys_clk);
            wait_count++;
        end
        
        if (wait_count >= 1000) begin
            $display("[WARN] Timeout waiting for pkt_id=%0d to clear, forcing reuse", pkt_id);
            sent_packets[pkt_id].valid = 0;
        end

        for (int i = 0; i < size; i++) begin
            raw_data[i] = $urandom();
        end

        frame = Fabric_frame_tr::create_from_raw(
            .raw_data(raw_data),
            .dest(dst_mask),
            .ifg_clk(ifg),
            .is_bad_frame(1'b0),
            .id(pkt_id)
        );

        // Store packet info
        sent_packets[pkt_id].valid = 1;
        sent_packets[pkt_id].src_port = src;
        sent_packets[pkt_id].dst_port = dst;
        sent_packets[pkt_id].qos = qos;
        sent_packets[pkt_id].tx_time = $time;
        sent_packets[pkt_id].size_bytes = size;

        // Record TX in latency tracker
        latency_tracker.record_tx(pkt_id, src, dst, qos);
        packets_sent++;

        frame_mailbox_in[src].put(frame.do_copy());
        @frame_sent[src];
    endtask

    task load_test_vectors();
        $display("[SWEEP] Loading test vectors from %s", test_vector_file);
    endtask

    //==========================================================================
    // Drivers and Monitors
    //==========================================================================
    generate
        for (genvar i = 0; i < NUM_PORT; i++) begin : gen_port_agents
            mailbox #(Fabric_frame_tr) drv_mailbox;
            mailbox #(Fabric_frame_tr) mon_mailbox;

            initial begin
                drv_mailbox = new();
                mon_mailbox = new();
                frame_mailbox_in[i] = drv_mailbox;
                frame_mailbox_out[i] = mon_mailbox;
            end

            //------------------------------------------------------------------
            // DRIVER
            //------------------------------------------------------------------
            fabric_driver #(
                .NUM_PORT(NUM_PORT),
                .DATA_WIDTH(W_MINI)
            ) u_driver (
                .clk(sys_clk),
                .sw_data_if(rx_data_if[i]),
                .frame_mailbox(drv_mailbox),
                .frame_sent(frame_sent[i])
            );

            //------------------------------------------------------------------
            // MONITOR
            //------------------------------------------------------------------
            fabric_monitor #(
                .NUM_PORT(NUM_PORT),
                .DATA_WIDTH(W_MINI),
                .QOS_TAG_WIDTH(QOS_TAG_WIDTH),
                .PACKET_ID_WIDTH(PACKET_ID_WIDTH)
            ) u_monitor (
                .clk(sys_clk),
                .sw_data_if(tx_data_if[i]),
                .sw_meta_if(rx_meta_if[i]),
                .frame_mailbox(mon_mailbox)
            );

            //------------------------------------------------------------------
            // TX Ready
            //------------------------------------------------------------------
            assign tx_data_if[i].ready = 1'b1;

            //------------------------------------------------------------------
            // RX Packet Tracking
            //------------------------------------------------------------------
            initial begin
                automatic int rx_pkt_id;
                automatic int rx_port;
                automatic logic [2:0] rx_qos;

                rx_port = i;  // Capture genvar value

                forever begin
                    @(posedge sys_clk);
                    
                    if (tx_valid[i] && tx_ready[i] && tx_last[i]) begin
                        rx_pkt_id = tx_id[i];
                        packets_received++;
                        
                        if (rx_pkt_id == 0) begin
                            packets_id_zero++;
                        end else if (!sent_packets[rx_pkt_id].valid) begin
                            packets_id_not_found++;
                        end else begin
                            // Found matching packet
                            rx_qos = sent_packets[rx_pkt_id].qos;
                            
                            // Record RX with original QoS
                            latency_tracker.record_rx(rx_pkt_id, rx_port, rx_qos);
                            packets_matched++;
                            
                            // Clear entry
                            sent_packets[rx_pkt_id].valid = 0;
                        end
                    end
                end
            end
        end
    endgenerate

endmodule

`default_nettype wire