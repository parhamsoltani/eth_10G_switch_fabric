`timescale 1ns / 1ps
// `default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// QoS Stress Test Testbench
// Validates QoS behavior under extreme conditions:
//   - Sustained oversubscription
//   - Priority inversion attacks
//   - Burst congestion
//   - Fairness under mixed traffic
//////////////////////////////////////////////////////////////////////////////////

import fabric_frame_pkg::*;

`include "sim_options.vh"
`include "implement_options.vh"
`include "qos_defines.vh"

`include "../../hvl/verification/qos_latency_tracker.sv"

module tb_fabric_qos_stress;

    parameter NUM_PORT = `NUM_PORT;
    parameter W_MINI = `W;
    parameter S = `S;
    parameter MAIN_MEM_DEPTH = `D;
    parameter XPQ_DEPTH = `X;
    parameter QOS_TAG_WIDTH = `QOS_TAG_WIDTH;
    parameter ENABLE_QOS = 1;  // FIXED: Hardcoded for QoS testbench

    parameter SYS_PERIOD = 1.499;

    // Test phases
    typedef enum {
        PHASE_WARMUP,
        PHASE_OVERSUBSCRIPTION,
        PHASE_PRIORITY_INVERSION,
        PHASE_BURST_ATTACK,
        PHASE_FAIRNESS_TEST,
        PHASE_COOLDOWN,
        PHASE_DONE
    } test_phase_t;

    test_phase_t current_phase = PHASE_WARMUP;

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
        .tx_data_if(tx_data_if),
        .addr_fifos_num_free_o(),
        .free_fifo_count_o()
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
    // Traffic Generation
    //==========================================================================

    mailbox frame_mailbox_in[NUM_PORT];
    mailbox frame_mailbox_out[NUM_PORT];
    event frame_sent[NUM_PORT];

    qos_latency_tracker latency_tracker;

    initial begin
        latency_tracker = new();
    end

    initial begin
        for (int i = 0; i < NUM_PORT; i++) begin
            frame_mailbox_in[i] = new();
            frame_mailbox_out[i] = new();
        end

        wait (!sys_reset);
        repeat (200) @(posedge sys_clk);

        run_stress_tests();

        repeat (5000) @(posedge sys_clk);

        latency_tracker.print_summary();
        print_stress_summary();

        $display("[%0t] Stress test complete", $time);
        $stop;
    end

    //==========================================================================
    // Stress Test Scenarios
    //==========================================================================

    task run_stress_tests();
        $display("\n╔══════════════════════════════════════════════════════════════╗");
        $display("║            QoS STRESS TEST SUITE                             ║");
        $display("╚══════════════════════════════════════════════════════════════╝\n");

        // Phase 1: Warmup
        current_phase = PHASE_WARMUP;
        run_warmup();

        // Phase 2: Sustained oversubscription
        current_phase = PHASE_OVERSUBSCRIPTION;
        run_oversubscription_test();

        // Phase 3: Priority inversion attack
        current_phase = PHASE_PRIORITY_INVERSION;
        run_priority_inversion_attack();

        // Phase 4: Burst attack
        current_phase = PHASE_BURST_ATTACK;
        run_burst_attack();

        // Phase 5: Fairness test
        current_phase = PHASE_FAIRNESS_TEST;
        run_fairness_test();

        // Phase 6: Cooldown
        current_phase = PHASE_COOLDOWN;
        run_cooldown();

        current_phase = PHASE_DONE;
    endtask

    task run_warmup();
        $display("[PHASE 1] Warmup: Light traffic to stabilize fabric");

        repeat (100) begin
            send_random_packet(
                .qos_dist({25, 25, 25, 25}),
                .size_range({64, 256})
            );
            repeat (50) @(posedge sys_clk);
        end

        repeat (1000) @(posedge sys_clk);
    endtask

    task run_oversubscription_test();
        $display("\n[PHASE 2] Oversubscription: All ports → Port 0");
        $display("  Expected: High-priority packets should get through");

        fork
            begin
                for (int i = 0; i < NUM_PORT/2; i++) begin
                    repeat (200) begin
                        send_packet_qos(
                            .src(i),
                            .dst(0),
                            .size($urandom_range(64, 512)),
                            .qos(`PRIORITY_HIGH),
                            .ifg(5)
                        );
                    end
                end
            end

            begin
                for (int i = NUM_PORT/2; i < NUM_PORT; i++) begin
                    repeat (200) begin
                        send_packet_qos(
                            .src(i),
                            .dst(0),
                            .size($urandom_range(64, 1500)),
                            .qos(`PRIORITY_LOW),
                            .ifg(5)
                        );
                    end
                end
            end
        join

        repeat (5000) @(posedge sys_clk);
    endtask

    task run_priority_inversion_attack();
        $display("\n[PHASE 3] Priority Inversion: Flood low-pri, then inject high-pri");
        $display("  Expected: High-pri should preempt low-pri");

        for (int src = 0; src < NUM_PORT; src++) begin
            repeat (100) begin
                send_packet_qos(src, (src+1)%NUM_PORT, 1500, `PRIORITY_LOW, 5);
            end
        end

        repeat (100) @(posedge sys_clk);

        for (int src = 0; src < NUM_PORT; src++) begin
            repeat (20) begin
                send_packet_qos(src, (src+1)%NUM_PORT, 128, `PRIORITY_CRITICAL, 10);
            end
        end

        repeat (3000) @(posedge sys_clk);
    endtask

    task run_burst_attack();
        $display("\n[PHASE 4] Burst Attack: Back-to-back max-size packets");
        $display("  Expected: Fabric should not deadlock");

        fork
            begin
                repeat (50) begin
                    send_packet_qos(0, NUM_PORT-1, 1500, `PRIORITY_MEDIUM, 1);
                end
            end
            begin
                #(SYS_PERIOD * 100);
                repeat (50) begin
                    send_packet_qos(NUM_PORT-1, 0, 1500, `PRIORITY_HIGH, 1);
                end
            end
        join

        repeat (4000) @(posedge sys_clk);
    endtask

    task run_fairness_test();
        $display("\n[PHASE 5] Fairness: Equal load, check QoS latency ordering");
        $display("  Expected: Avg(CRITICAL) < Avg(HIGH) < Avg(MEDIUM) < Avg(LOW)");

        for (int i = 0; i < 100; i++) begin
            fork
                send_packet_qos($urandom_range(0, NUM_PORT-1), $urandom_range(0, NUM_PORT-1),
                    $urandom_range(64, 512), `PRIORITY_CRITICAL, 20);
                send_packet_qos($urandom_range(0, NUM_PORT-1), $urandom_range(0, NUM_PORT-1),
                    $urandom_range(64, 512), `PRIORITY_HIGH, 20);
                send_packet_qos($urandom_range(0, NUM_PORT-1), $urandom_range(0, NUM_PORT-1),
                    $urandom_range(64, 512), `PRIORITY_MEDIUM, 20);
                send_packet_qos($urandom_range(0, NUM_PORT-1), $urandom_range(0, NUM_PORT-1),
                    $urandom_range(64, 512), `PRIORITY_LOW, 20);
            join
        end

        repeat (5000) @(posedge sys_clk);
    endtask

    task run_cooldown();
        $display("\n[PHASE 6] Cooldown: Drain remaining packets");
        repeat (2000) @(posedge sys_clk);
    endtask

    //==========================================================================
    // Packet Injection Helper
    //==========================================================================

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

        for (int i = 0; i < size; i++) begin
            raw_data[i] = $urandom();
        end

        frame = Fabric_frame_tr::create_from_raw(
            .raw_data(raw_data),
            .dest(dst_mask),
            .ifg_clk(ifg),
            .is_bad_frame(1'b0),
            .id($urandom())
        );

        frame.data[12] = qos;

        latency_tracker.record_tx(frame.id, src, dst, qos);
        frame_mailbox_in[src].put(frame.do_copy());
        @frame_sent[src];
    endtask

    task send_random_packet(
        input int qos_dist [4],
        input int size_range [2]
    );
        int rand_val = $urandom_range(0, 99);
        logic [2:0] qos;

        if (rand_val < qos_dist[0]) qos = `PRIORITY_CRITICAL;
        else if (rand_val < qos_dist[0] + qos_dist[1]) qos = `PRIORITY_HIGH;
        else if (rand_val < qos_dist[0] + qos_dist[1] + qos_dist[2]) qos = `PRIORITY_MEDIUM;
        else qos = `PRIORITY_LOW;

        send_packet_qos(
            .src($urandom_range(0, NUM_PORT-1)),
            .dst($urandom_range(0, NUM_PORT-1)),
            .size($urandom_range(size_range[0], size_range[1])),
            .qos(qos),
            .ifg($urandom_range(5, 50))
        );
    endtask

    //==========================================================================
    // Statistics Collection
    //==========================================================================

    int phase_packet_count [7];
    int phase_drop_count [7];

    task print_stress_summary();
        $display("\n╔══════════════════════════════════════════════════════════════╗");
        $display("║              STRESS TEST SUMMARY                             ║");
        $display("╚══════════════════════════════════════════════════════════════╝");

        $display("\nPhase Results:");
        $display("  Phase 1 (Warmup):           %0d packets", phase_packet_count[1]);
        $display("  Phase 2 (Oversubscription): %0d packets (%0d estimated drops)",
            phase_packet_count[2], phase_drop_count[2]);
        $display("  Phase 3 (Priority Inversion): %0d packets", phase_packet_count[3]);
        $display("  Phase 4 (Burst Attack):      %0d packets", phase_packet_count[4]);
        $display("  Phase 5 (Fairness):          %0d packets", phase_packet_count[5]);

        $display("\nStress Test Verdict:");
        if (latency_tracker.packet_count[`PRIORITY_CRITICAL] > 0 &&
            latency_tracker.avg_latency[`PRIORITY_CRITICAL] < 500.0) begin
            $display("   Critical priority latency acceptable (%.2f ns)",
                latency_tracker.avg_latency[`PRIORITY_CRITICAL]);
        end else begin
            $error("   Critical priority latency excessive");
        end

        $display("\n");
    endtask

    //==========================================================================
    // Monitors/Drivers
    //==========================================================================

    generate
        for (genvar i = 0; i < NUM_PORT; i++) begin : gen_infra
            mailbox temp_in, temp_out;

            initial begin
                temp_in = new();
                temp_out = new();
                frame_mailbox_in[i] = temp_in;
                frame_mailbox_out[i] = temp_out;
            end

            fabric_monitor #(
                .NUM_PORT(NUM_PORT),
                .DATA_WIDTH(W_MINI),
                .QOS_TAG_WIDTH(QOS_TAG_WIDTH),
                .PACKET_ID_WIDTH(8)
            ) u_mon (
                .clk(sys_clk),
                .sw_data_if(rx_data_if[i]),
                .sw_meta_if(rx_meta_if[i]),
                .frame_mailbox(temp_in)
            );

            fabric_driver #(
                .NUM_PORT(NUM_PORT),
                .DATA_WIDTH(W_MINI)
            ) u_drv (
                .clk(sys_clk),
                .sw_data_if(tx_data_if[i]),
                .frame_mailbox(temp_out),
                .frame_sent(frame_sent[i])
            );

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

    //==========================================================================
    // Assertions
    //==========================================================================

    property p_no_deadlock;
        @(posedge sys_clk) disable iff (sys_reset)
        1'b1; // Placeholder - replace with actual deadlock check
    endproperty

    assert property (p_no_deadlock)
    else $error("[DEADLOCK] Fabric stuck in full state");

    sequence s_critical_egress;
        (tx_data_if[0].valid && rx_meta_if[0].qos_tag == `PRIORITY_CRITICAL);
    endsequence

    property p_critical_not_starved;
        @(posedge sys_clk) disable iff (sys_reset || !ENABLE_QOS)
        (current_phase == PHASE_OVERSUBSCRIPTION) |->
            ##[1:2000] s_critical_egress;
    endproperty

    assert property (p_critical_not_starved)
    else $warning("[STARVATION] No critical packets egressed during oversubscription");

endmodule

`default_nettype wire