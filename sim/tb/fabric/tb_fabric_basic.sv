`timescale 1ns / 1ps
`default_nettype none

import fabric_frame_pkg::*;

`include "implement_options.vh"
`include "sim_options.vh"

module tb_fabric_basic;
    // Convert macros to localparams for constant expressions
    localparam NUM_PORT = `NUM_PORT;
    localparam W_MINI = `W;
    localparam S = `S;
    localparam MAIN_MEM_DEPTH = `D;
    localparam XPQ_DEPTH = `X;
    localparam PACKET_ID_WIDTH = `PACKET_ID_WIDTH;
    localparam QOS_TAG_WIDTH = 3;
    localparam real SYS_PERIOD = 1.499;  // ~345 MHz

    // Clock & Reset
    reg sys_clk, sys_reset;

    // Interfaces
    switch_data_if #(.DATA_WIDTH(W_MINI), .ID_WIDTH(PACKET_ID_WIDTH))
        rx_data_if [NUM_PORT] ();

    switch_metadata_if #(.PORT_MASK_WIDTH(NUM_PORT), .ID_WIDTH(PACKET_ID_WIDTH), .QOS_TAG_WIDTH(QOS_TAG_WIDTH))
        rx_meta_if [NUM_PORT] ();

    switch_data_if #(.DATA_WIDTH(W_MINI), .ID_WIDTH(PACKET_ID_WIDTH))
        tx_data_if [NUM_PORT] ();

    // Mailbox arrays - Fixed size arrays (not dynamic)
    mailbox frame_tx[NUM_PORT];
    mailbox frame_rx[NUM_PORT];
    event frame_sent[NUM_PORT];

    int packets_sent = 0;
    int packets_recv = 0;

    // DUT
    switch_fabric #(
        .NUM_PORT(NUM_PORT),
        .S(S),
        .W_MINI(W_MINI),
        .MAIN_MEM_DEPTH(MAIN_MEM_DEPTH),
        .XPQ_DEPTH(XPQ_DEPTH),
        .OUTPUT_QUEUE_DEPTH(64),
        .MULTICAST_SUPPORT(0),
        .PACKET_ID_WIDTH(PACKET_ID_WIDTH),
        .QOS_TAG_WIDTH(3)
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
    initial sys_clk = 0;
    always #(SYS_PERIOD) sys_clk = ~sys_clk;

    // Reset generation
    initial begin
        sys_reset = 0;
        repeat(100) @(posedge sys_clk);
        sys_reset = 1;
        repeat(10) @(posedge sys_clk);
        sys_reset = 0;
    end

    // Initialize mailboxes
    initial begin
        for (int i = 0; i < NUM_PORT; i++) begin
            frame_tx[i] = new();
            frame_rx[i] = new();
        end
    end

    // Test stimulus
    initial begin
        wait (!sys_reset);
        repeat(200) @(posedge sys_clk);

        $display("\n════════════════════════════════════════");
        $display("  BASIC FABRIC TEST");
        $display("  NUM_PORT=%0d, S=%0d, QoS=DISABLED", NUM_PORT, S);
        $display("════════════════════════════════════════\n");

        // Test 1: Unicast (port 0 → port 1)
        send_unicast(0, 1, 256);

        // Test 2: All-to-all (sequential)
        for (int src = 0; src < NUM_PORT; src++) begin
            for (int dst = 0; dst < NUM_PORT; dst++) begin
                if (src != dst) send_unicast(src, dst, 128);
            end
        end

        // Test 3: Concurrent traffic
        fork
            repeat(50) send_unicast(0, NUM_PORT-1, 512);
            repeat(50) send_unicast(NUM_PORT-1, 0, 512);
        join

        // Wait for all packets
        repeat(5000) @(posedge sys_clk);

        $display("\n════════════════════════════════════════");
        $display("  TEST RESULTS");
        $display("════════════════════════════════════════");
        $display("  Packets Sent:     %0d", packets_sent);
        $display("  Packets Received: %0d", packets_recv);

        if (packets_sent == packets_recv) begin
            $display("\n   ✓ BASIC TEST PASSED ");
        end else begin
            $error("\n   ✗ PACKET LOSS: %0d missing ", packets_sent - packets_recv);
        end

        $display("════════════════════════════════════════\n");
        $finish;
    end

    // Packet generation task
    task send_unicast(int src, int dst, int size);
        automatic bit [NUM_PORT-1:0] dest_mask = (1 << dst);
        automatic bit [7:0] raw_data[] = new[size];
        automatic Fabric_frame_tr frame;

        for (int i = 0; i < size; i++) raw_data[i] = $urandom();

        frame = Fabric_frame_tr::create_from_raw(
            .raw_data(raw_data),
            .dest(dest_mask),
            .ifg_clk(10),
            .is_bad_frame(1'b0),
            .id(packets_sent)
        );

        frame_tx[src].put(frame.do_copy());
        packets_sent++;

        @frame_sent[src];
    endtask

    // Monitors & Drivers
    generate
        for (genvar i = 0; i < NUM_PORT; i++) begin : gen_infra
            // Create local mailbox variables for this port
            mailbox local_tx_mbox;
            mailbox local_rx_mbox;

            // Initialize local mailboxes from arrays
            initial begin
                local_tx_mbox = frame_tx[i];
                local_rx_mbox = frame_rx[i];
            end

            // Driver - drives RX data interface
            fabric_driver #(
                .NUM_PORT(NUM_PORT),
                .DATA_WIDTH(W_MINI)
            ) drv (
                .clk(sys_clk),
                .sw_data_if(rx_data_if[i].master_mp),
                .frame_mailbox(local_tx_mbox),  // Use local mailbox
                .frame_sent(frame_sent[i])
            );

            // Monitor - monitors TX data interface
            fabric_monitor #(
                .NUM_PORT(NUM_PORT),
                .DATA_WIDTH(W_MINI)
            ) mon (
                .clk(sys_clk),
                .sw_data_if(tx_data_if[i].monitor),
                .sw_meta_if(rx_meta_if[i].monitor),
                .frame_mailbox(local_rx_mbox)   // Use local mailbox
            );

            // Drive TX ready and collect received packets
            initial begin
                tx_data_if[i].ready = 1'b1;

                forever begin
                    automatic Fabric_frame_tr frame;
                    local_rx_mbox.get(frame);
                    packets_recv++;
                end
            end

            // Manual metadata driving
            initial begin
                rx_meta_if[i].valid = 0;
                rx_meta_if[i].dest_port_mask = 0;
                rx_meta_if[i].id = 0;
                rx_meta_if[i].qos_tag = 0;
                rx_meta_if[i].vlan_id = 0;

                forever begin
                    automatic Fabric_frame_tr frame;

                    // Wait for a frame in the mailbox (peek without removing)
                    wait(local_tx_mbox.num() > 0);
                    local_tx_mbox.peek(frame);

                    // Wait for data interface to start transmitting
                    @(posedge sys_clk);
                    wait(rx_data_if[i].valid && rx_data_if[i].ready);

                    // Drive metadata
                    rx_meta_if[i].valid <= 1'b1;
                    rx_meta_if[i].dest_port_mask <= frame.dest;
                    rx_meta_if[i].id <= frame.id;
                    rx_meta_if[i].qos_tag <= 3'b0;
                    rx_meta_if[i].vlan_id <= 12'b0;

                    @(posedge sys_clk);

                    // Hold metadata valid until accepted
                    while (!(rx_meta_if[i].valid && rx_meta_if[i].ready)) begin
                        @(posedge sys_clk);
                    end

                    rx_meta_if[i].valid <= 1'b0;
                end
            end
        end
    endgenerate

    // Timeout watchdog
    initial begin
        #1000000;  // 1ms timeout
        $error("TIMEOUT - test did not complete");
        $finish;
    end

endmodule

`default_nettype wire