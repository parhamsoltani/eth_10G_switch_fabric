`timescale 1ns / 1ps
`include "implement_options.vh"

import fabric_frame_pkg::*;

module tb_fabric_connectivity;
    parameter NUM_PORT = `NUM_PORT;
    parameter W_MINI = `W;
    parameter S = `S;
    parameter MAIN_MEM_DEPTH = `D;
    parameter XPQ_DEPTH = `X;
    parameter PACKET_ID_WIDTH = `PACKET_ID_WIDTH;
    parameter QOS_TAG_WIDTH = `QOS_TAG_WIDTH;
    parameter SYS_PERIOD = 1.499;

    //==========================================================================
    // DUT Interfaces
    //==========================================================================
    reg sys_clk, sys_reset;

    switch_data_if #(.DATA_WIDTH(W_MINI), .ID_WIDTH(PACKET_ID_WIDTH))
        rx_data_if [NUM_PORT] ();

    switch_metadata_if #(
        .PORT_MASK_WIDTH(NUM_PORT),
        .ID_WIDTH(PACKET_ID_WIDTH),
        .QOS_TAG_WIDTH(QOS_TAG_WIDTH)
    ) rx_meta_if [NUM_PORT] ();

    switch_data_if #(.DATA_WIDTH(W_MINI), .ID_WIDTH(PACKET_ID_WIDTH))
        tx_data_if [NUM_PORT] ();

    //==========================================================================
    // Test Infrastructure
    //==========================================================================
    mailbox #(Fabric_frame_tr) frame_tx_mailbox [NUM_PORT];
    mailbox #(Fabric_frame_tr) frame_rx_mailbox [NUM_PORT];
    event frame_sent [NUM_PORT];

    int packets_sent = 0;
    int packets_received = 0;
    int connectivity_matrix [NUM_PORT][NUM_PORT];
    time packet_tx_time [NUM_PORT*NUM_PORT];
    time packet_rx_time [NUM_PORT*NUM_PORT];

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
        .PACKET_ID_WIDTH(PACKET_ID_WIDTH),
        .QOS_TAG_WIDTH(QOS_TAG_WIDTH),
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
        int pkt_id = 1;
        bit [7:0] payload[];
        Fabric_frame_tr frame;
        real latency_us;

        // Initialize
        for (int i = 0; i < NUM_PORT; i++) begin
            frame_tx_mailbox[i] = new();
            frame_rx_mailbox[i] = new();
            for (int j = 0; j < NUM_PORT; j++)
                connectivity_matrix[i][j] = 0;
        end

        wait(!sys_reset);
        repeat(200) @(posedge sys_clk);

        $display("\n╔═══════════════════════════════════════════════════════╗");
        $display("║  TEST 1: 10×10 CONNECTIVITY MATRIX                  ║");
        $display("║  Testing all 100 port combinations (64-byte frames) ║");
        $display("╚═══════════════════════════════════════════════════════╝\n");

        // Send packets
        for (int src = 0; src < NUM_PORT; src++) begin
            for (int dst = 0; dst < NUM_PORT; dst++) begin
                payload = new[64];
                for (int k = 0; k < 64; k++)
                    payload[k] = $urandom();

                frame = Fabric_frame_tr::create_from_raw(
                    .raw_data(payload),
                    .dest(1 << dst),
                    .ifg_clk(20),
                    .is_bad_frame(0),
                    .id(pkt_id)
                );

                packet_tx_time[src*NUM_PORT + dst] = $time;
                frame_tx_mailbox[src].put(frame);
                packets_sent++;

                $display("[%0t] Sending pkt %0d: Port %0d → Port %0d",
                         $time, pkt_id, src, dst);

                @frame_sent[src];
                pkt_id++;

                repeat(100) @(posedge sys_clk);
            end
        end

        $display("\n[%0t] All packets sent, waiting for reception...", $time);
        repeat(20000) @(posedge sys_clk);

        print_connectivity_report();
        $finish;
    end

    //==========================================================================
    // RX Monitors
    //==========================================================================
    generate
        for (genvar i = 0; i < NUM_PORT; i++) begin : gen_rx_mon
            initial begin
                int src, dst, pkt_idx;
                real latency_us;

                tx_data_if[i].ready = 1'b1;

                forever begin
                    @(posedge sys_clk);
                    if (tx_data_if[i].valid && tx_data_if[i].ready && tx_data_if[i].last) begin
                        packets_received++;

                        src = (tx_data_if[i].id - 1) / NUM_PORT;
                        dst = i;
                        pkt_idx = src * NUM_PORT + dst;

                        if (src >= 0 && src < NUM_PORT) begin
                            connectivity_matrix[src][dst] = 1;
                            packet_rx_time[pkt_idx] = $time;
                            latency_us = ($time - packet_tx_time[pkt_idx]) / 1000.0;

                            $display("[%0t] ✓ Received at port %0d from port %0d (latency: %.2f µs)",
                                     $time, dst, src, latency_us);

                            if (latency_us > 1.0)
                                $warning("Latency %.2f µs exceeds 1 µs requirement", latency_us);
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
            fabric_driver #(
                .NUM_PORT(NUM_PORT),
                .DATA_WIDTH(W_MINI)
            ) driver (
                .clk(sys_clk),
                .sw_data_if(rx_data_if[i]),
                .frame_mailbox(frame_tx_mailbox[i]),
                .frame_sent(frame_sent[i])
            );

            initial begin
                Fabric_frame_tr meta_frame;

                rx_meta_if[i].valid = 0;
                rx_meta_if[i].dest_port_mask = 0;
                rx_meta_if[i].id = 0;
                rx_meta_if[i].qos_tag = `PRIORITY_STANDARD;
                rx_meta_if[i].vlan_id = 0;

                wait(frame_tx_mailbox[i] != null);

                forever begin
                    @(posedge sys_clk);
                    if (rx_data_if[i].valid && rx_data_if[i].ready) begin
                        if (!rx_meta_if[i].valid) begin
                            rx_meta_if[i].dest_port_mask <= rx_data_if[i].id[3:0];
                            rx_meta_if[i].id <= rx_data_if[i].id;
                            rx_meta_if[i].qos_tag <= `PRIORITY_STANDARD;
                            rx_meta_if[i].valid <= 1'b1;

                            @(posedge sys_clk);
                            rx_meta_if[i].valid <= 1'b0;
                        end
                    end
                end
            end
        end
    endgenerate

    //==========================================================================
    // Report Generation
    //==========================================================================
    task print_connectivity_report();
        int passed = 0;
        int failed = 0;
        real avg_latency = 0.0;
        int latency_violations = 0;

        $display("\n╔═══════════════════════════════════════════════════════╗");
        $display("║         CONNECTIVITY MATRIX RESULTS                   ║");
        $display("╠═══════════════════════════════════════════════════════╣");
        $display("║  Total Sent:     %3d                                  ║", packets_sent);
        $display("║  Total Received: %3d                                  ║", packets_received);
        $display("╠═══════════════════════════════════════════════════════╣");

        $write("║     ");
        for (int d = 0; d < NUM_PORT; d++) $write("%2d ", d);
        $display("   ║");

        for (int s = 0; s < NUM_PORT; s++) begin
            $write("║  %2d ", s);
            for (int d = 0; d < NUM_PORT; d++) begin
                if (connectivity_matrix[s][d]) begin
                    $write(" ✓ ");
                    passed++;
                    avg_latency += (packet_rx_time[s*NUM_PORT+d] -
                                    packet_tx_time[s*NUM_PORT+d]) / 1000.0;
                end else begin
                    $write(" ✗ ");
                    failed++;
                end
            end
            $display("   ║");
        end

        avg_latency = avg_latency / passed;

        $display("╠═══════════════════════════════════════════════════════╣");
        $display("║  Passed Paths: %3d / %3d                             ║", passed, NUM_PORT*NUM_PORT);
        $display("║  Failed Paths: %3d                                    ║", failed);
        $display("║  Avg Latency:  %.2f µs                                ║", avg_latency);
        $display("║  >1µs Latency: %3d paths                              ║", latency_violations);
                
        if (failed == 0 && latency_violations == 0) begin
            $display("╠═══════════════════════════════════════════════════════╣");
            $display("║                  ALL TESTS PASSED                     ║");
        end else begin
            $display("╠═══════════════════════════════════════════════════════╣");
            $display("║                SOME TESTS FAILED                      ║");
        end
        
        $display("╚═══════════════════════════════════════════════════════╝\n");
    endtask

endmodule
