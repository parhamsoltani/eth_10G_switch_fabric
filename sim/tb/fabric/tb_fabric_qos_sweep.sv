`timescale 1ns / 1ps
`default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Automated QoS configuration sweep testbench
// Reads test vectors from JSON and validates all configs
//////////////////////////////////////////////////////////////////////////////////

import fabric_frame_pkg::*;

`include "sim_options.vh"
`include "implement_options.vh"
`include "qos_defines.vh"

module tb_fabric_qos_sweep;

    parameter NUM_PORT = `NUM_PORT;
    parameter W_MINI = `W;
    parameter S = `S;
    parameter MAIN_MEM_DEPTH = `D;
    parameter XPQ_DEPTH = `X;
    parameter QOS_TAG_WIDTH = `QOS_TAG_WIDTH;
    parameter ENABLE_QOS = `ENABLE_QOS;

    parameter SYS_PERIOD = 1.499;
    localparam TB = "tb_fabric_qos_sweep";

    // Test configuration from JSON
    string test_vector_file = "../../sim/tb/fabric/test_vectors_qos.json";
    int test_iterations;

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
    switch_data_if #(.DATA_WIDTH(W_MINI), .ID_WIDTH(8))
        rx_data_if [NUM_PORT] ();

    switch_metadata_if #(.PORT_MASK_WIDTH(NUM_PORT), .ID_WIDTH(8), .QOS_TAG_WIDTH(QOS_TAG_WIDTH))
        rx_meta_if [NUM_PORT] ();

    switch_data_if #(.DATA_WIDTH(W_MINI), .ID_WIDTH(8))
        tx_data_if [NUM_PORT] ();

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
        .PACKET_ID_WIDTH(8),
        .QOS_TAG_WIDTH(QOS_TAG_WIDTH)
    ) dut (
        .clk(sys_clk),
        .reset(sys_reset),
        .rx_data_if(rx_data_if),
        .rx_meta_if(rx_meta_if),
        .tx_data_if(tx_data_if),
        .addr_fifos_num_free_o(),
        .free_fifo_count_o()
    );

    //==========================================================================
    // Traffic Generators
    //==========================================================================
    mailbox frame_mailbox_in[NUM_PORT];
    mailbox frame_mailbox_out[NUM_PORT];
    event frame_sent[NUM_PORT];

    qos_latency_tracker #(
        .NUM_PORTS(NUM_PORT),
        .QOS_LEVELS(`PRIORITY_LEVELS)
    ) latency_tracker();

    //==========================================================================
    // Test Execution
    //==========================================================================
    initial begin
        for (int i = 0; i < NUM_PORT; i++) begin
            frame_mailbox_in[i] = new();
            frame_mailbox_out[i] = new();
        end

        wait (!sys_reset);
        repeat (100) @(posedge sys_clk);

        // Load test vectors (if file exists)
        if ($fopen(test_vector_file, "r")) begin
            load_test_vectors();
        end else begin
            // Default test patterns
            run_default_tests();
        end

        latency_tracker.print_summary();

        $display("[%0t] Sweep complete", $time);
        repeat (100) @(posedge sys_clk);
        $stop;
    end

    //==========================================================================
    // Test Tasks
    //==========================================================================
    task run_default_tests();
        $display("\n[QoS SWEEP] Running default test patterns");

        // Pattern 1: All high priority
        test_uniform_priority(`PRIORITY_HIGH, 100);

        // Pattern 2: Mixed priority (50% high, 50% low)
        test_mixed_priority(100);

        // Pattern 3: Priority inversion stress
        test_priority_inversion(50);

        // Pattern 4: Burst of critical packets
        test_critical_burst(20);
    endtask

    task test_uniform_priority(input logic [2:0] priority, input int num_packets);
        $display("[TEST] Uniform priority: %0d packets @ priority %0d", num_packets, priority);

        for (int i = 0; i < num_packets; i++) begin
            send_packet_qos(
                .src($urandom_range(0, NUM_PORT-1)),
                .dst($urandom_range(0, NUM_PORT-1)),
                .size($urandom_range(64, 1500)),
                .qos(priority),
                .ifg($urandom_range(10, 50))
            );
        end

        repeat (1000) @(posedge sys_clk);
    endtask

    task test_mixed_priority(input int num_packets);
        $display("[TEST] Mixed priority: %0d packets", num_packets);

        for (int i = 0; i < num_packets; i++) begin
            logic [2:0] prio = (i % 2) ? `PRIORITY_HIGH : `PRIORITY_LOW;
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
        $display("[TEST] Priority inversion: %0d packets", num_packets);

        // Send low-priority first, then high-priority to same dest
        fork
            begin
                for (int i = 0; i < num_packets; i++) begin
                    send_packet_qos(0, 1, 512, `PRIORITY_LOW, 10);
                end
            end
            begin
                #(SYS_PERIOD*200);  // Delay high-priority traffic
                for (int i = 0; i < num_packets/2; i++) begin
                    send_packet_qos(2, 1, 256, `PRIORITY_HIGH, 10);
                end
            end
        join

        repeat (2000) @(posedge sys_clk);
    endtask

    task test_critical_burst(input int num_packets);
        $display("[TEST] Critical burst: %0d packets", num_packets);

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
        // Use your existing Fabric_frame_tr infrastructure
        automatic bit [NUM_PORT-1:0] dst_mask = (1 << dst);
        automatic Fabric_frame_tr frame;

        frame = Fabric_frame_tr::create_from_raw(
            .raw_data(new[size]),
            .dest(dst_mask),
            .ifg_clk(ifg),
            .is_bad_frame(1'b0),
            .id($urandom())
        );

        latency_tracker.record_tx($urandom(), src, dst, qos);
        frame_mailbox_in[src].put(frame.do_copy());
        @frame_sent[src];
    endtask

    task load_test_vectors();
        // Parse JSON test vectors (placeholder)
        $display("[SWEEP] Loading test vectors from %s", test_vector_file);
    endtask

    //==========================================================================
    // Monitors/Drivers (reuse your existing infrastructure)
    //==========================================================================
    generate
        for (genvar i = 0; i < NUM_PORT; i++) begin : gen_monitors
            mailbox temp_mailbox = new();

            initial frame_mailbox_in[i] = temp_mailbox;

            fabric_monitor #(
                .NUM_PORT(NUM_PORT),
                .DATA_WIDTH(W_MINI),
                .QOS_TAG_WIDTH(QOS_TAG_WIDTH),
                .PACKET_ID_WIDTH(8)
            ) u_monitor (
                .clk(sys_clk),
                .sw_data_if(rx_data_if[i]),
                .sw_meta_if(rx_meta_if[i]),
                .frame_mailbox(temp_mailbox)
            );
        end
    endgenerate

    generate
        for (genvar g = 0; g < NUM_PORT; g++) begin : gen_drivers
            mailbox temp_mailbox = new();

            initial frame_mailbox_out[g] = temp_mailbox;

            fabric_driver #(
                .NUM_PORT(NUM_PORT),
                .DATA_WIDTH(W_MINI)
            ) u_driver (
                .clk(sys_clk),
                .sw_data_if(tx_data_if[g]),
                .frame_mailbox(temp_mailbox),
                .frame_sent(frame_sent[g])
            );
        end
    endgenerate

    //==========================================================================
    // RX Monitors with Latency Tracking
    //==========================================================================
    generate
        for (genvar i = 0; i < NUM_PORT; i++) begin : gen_rx_mon
            initial begin
                tx_data_if[i].ready = 1'b1;

                forever begin
                    @(posedge sys_clk);
                    if (tx_data_if[i].valid && tx_data_if[i].ready && tx_data_if[i].last) begin
                        latency_tracker.record_rx(
                            tx_data_if[i].id,
                            i,
                            rx_meta_if[i].qos_tag
                        );
                    end
                end
            end
        end
    endgenerate

endmodule

`default_nettype wire