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
    localparam real SYS_PERIOD = 1.499;  // ~667 MHz

    // Clock & Reset
    reg sys_clk, sys_reset;
    bit reset_done;
    bit mailboxes_ready;

    // Interfaces
    switch_data_if #(.DATA_WIDTH(W_MINI), .ID_WIDTH(PACKET_ID_WIDTH))
        rx_data_if [NUM_PORT] ();

    switch_metadata_if #(.PORT_MASK_WIDTH(NUM_PORT), .ID_WIDTH(PACKET_ID_WIDTH), .QOS_TAG_WIDTH(QOS_TAG_WIDTH))
        rx_meta_if [NUM_PORT] ();

    switch_data_if #(.DATA_WIDTH(W_MINI), .ID_WIDTH(PACKET_ID_WIDTH))
        tx_data_if [NUM_PORT] ();

    // Mailbox arrays - Using two separate mailboxes for synchronization
    mailbox #(Fabric_frame_tr) frame_tx_data[NUM_PORT];
    mailbox #(Fabric_frame_tr) frame_tx_meta[NUM_PORT];
    mailbox #(Fabric_frame_tr) frame_rx[NUM_PORT];
    event frame_sent[NUM_PORT];

    int packets_sent = 0;
    int packets_recv = 0;

    // Initialize mailboxes at time 0
    initial begin
        mailboxes_ready = 0;
        for (int i = 0; i < NUM_PORT; i++) begin
            frame_tx_data[i] = new();
            frame_tx_meta[i] = new();
            frame_rx[i] = new();
        end
        mailboxes_ready = 1;
        $display("[%0t] Mailboxes initialized", $time);
    end

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
    always #(SYS_PERIOD/2.0) sys_clk = ~sys_clk;

    // Reset generation
    initial begin
        reset_done = 0;
        sys_reset = 0;
        repeat(100) @(posedge sys_clk);
        sys_reset = 1;
        repeat(10) @(posedge sys_clk);
        sys_reset = 0;
        reset_done = 1;
        $display("[%0t] Reset complete", $time);
    end

    // Test stimulus
    initial begin
        wait (reset_done);
        repeat(200) @(posedge sys_clk);

        $display("\n════════════════════════════════════════");
        $display("  BASIC FABRIC TEST");
        $display("  NUM_PORT=%0d, S=%0d, QoS=DISABLED", NUM_PORT, S);
        $display("════════════════════════════════════════\n");

        // Test 1: Unicast (port 0 → port 1)
        $display("[TEST 1] Unicast: Port 0 → Port 1");
        send_unicast(0, 1, 256);
        repeat(100) @(posedge sys_clk);

        // Test 2: All-to-all (sequential)
        $display("[TEST 2] All-to-all sequential");
        for (int src = 0; src < NUM_PORT; src++) begin
            for (int dst = 0; dst < NUM_PORT; dst++) begin
                if (src != dst) begin
                    $display("  Sending: Port %0d → Port %0d", src, dst);
                    send_unicast(src, dst, 128);
                end
            end
        end
        repeat(500) @(posedge sys_clk);

        // Test 3: Concurrent traffic
        $display("[TEST 3] Concurrent traffic");
        fork
            repeat(50) send_unicast(0, NUM_PORT-1, 512);
            repeat(50) send_unicast(NUM_PORT-1, 0, 512);
        join

        // Wait for all packets
        repeat(10000) @(posedge sys_clk);

        $display("\n════════════════════════════════════════");
        $display("  TEST RESULTS");
        $display("════════════════════════════════════════");
        $display("  Packets Sent:     %0d", packets_sent);
        $display("  Packets Received: %0d", packets_recv);

        if (packets_sent == packets_recv) begin
            $display("\n    BASIC TEST PASSED ");
        end else begin
            $error("\n    PACKET LOSS: %0d missing ", packets_sent - packets_recv);
        end

        $display("════════════════════════════════════════\n");
        $finish;
    end

    // Packet generation task - Modified to send to both mailboxes
    task send_unicast(int src, int dst, int size);
        automatic bit [NUM_PORT-1:0] dest_mask = (1 << dst);
        automatic bit [7:0] raw_data[] = new[size];
        automatic Fabric_frame_tr frame_data, frame_meta;

        for (int i = 0; i < size; i++) raw_data[i] = $urandom();

        frame_data = Fabric_frame_tr::create_from_raw(
            .raw_data(raw_data),
            .dest(dest_mask),
            .ifg_clk(10),
            .is_bad_frame(1'b0),
            .id(packets_sent)
        );

        frame_meta = frame_data.do_copy();

        // Send to both mailboxes for synchronization
        frame_tx_data[src].put(frame_data);
        frame_tx_meta[src].put(frame_meta);
        packets_sent++;

        @frame_sent[src];
    endtask

    // Generate drivers and monitors for each port
    generate
        for (genvar gi = 0; gi < NUM_PORT; gi++) begin : gen_infra
            
            // ===== TX Data Interface Driver =====
            initial begin
                automatic Fabric_frame_tr frame;
                automatic bit [7:0] raw_data[];
                automatic int num_words, keep_val, j;

                // Initialize interface signals
                rx_data_if[gi].valid = 0;
                rx_data_if[gi].data = 0;
                rx_data_if[gi].keep = 0;
                rx_data_if[gi].last = 0;
                rx_data_if[gi].id = 0;
                rx_data_if[gi].is_bad_frame = 0;

                wait(mailboxes_ready);
                wait(reset_done);

                forever begin
                    frame_tx_data[gi].get(frame);
                    frame.frame_to_raw(raw_data);
                    num_words = (raw_data.size() + (W_MINI/8) - 1) / (W_MINI/8);

                    for (int beat = 0; beat < num_words; beat++) begin
                        rx_data_if[gi].valid <= 1'b1;
                        rx_data_if[gi].data <= '0;
                        rx_data_if[gi].id <= frame.id;
                        rx_data_if[gi].is_bad_frame <= (beat == num_words - 1) ? frame.is_bad_frame : 1'b0;
                        rx_data_if[gi].last <= (beat == num_words - 1);

                        keep_val = 0;
                        for (j = 0; j < W_MINI/8; j++) begin
                            if ((beat * (W_MINI/8) + j) < raw_data.size()) begin
                                rx_data_if[gi].data[j*8 +: 8] <= raw_data[beat * (W_MINI/8) + j];
                                keep_val++;
                            end
                        end
                        rx_data_if[gi].keep <= keep_val[W_MINI/8-1:0];

                        @(posedge sys_clk);
                        while (!rx_data_if[gi].ready) @(posedge sys_clk);
                    end

                    rx_data_if[gi].valid <= 1'b0;
                    rx_data_if[gi].last <= 1'b0;
                    rx_data_if[gi].is_bad_frame <= 1'b0;

                    repeat(frame.ifg_clk) @(posedge sys_clk);

                    ->frame_sent[gi];
                end
            end

            // ===== Metadata Interface Driver - CORRECTED =====
            initial begin
                automatic Fabric_frame_tr frame;

                rx_meta_if[gi].valid = 0;
                rx_meta_if[gi].dest_port_mask = 0;
                rx_meta_if[gi].id = 0;
                rx_meta_if[gi].qos_tag = 0;
                rx_meta_if[gi].vlan_id = 0;

                wait(mailboxes_ready);
                wait(reset_done);

                forever begin
                    // Get frame from metadata mailbox
                    frame_tx_meta[gi].get(frame);

                    // Debug: Print what we're sending
                    //$display("[%0t] Port %0d META: id=%0d, dest_mask=%b", 
                    //         $time, gi, frame.id, frame.dest);

                    // Wait for first data beat to be valid
                    @(posedge sys_clk);
                    while (!(rx_data_if[gi].valid && rx_data_if[gi].ready)) 
                        @(posedge sys_clk);

                    // Drive metadata synchronized with data
                    rx_meta_if[gi].valid <= 1'b1;
                    rx_meta_if[gi].dest_port_mask <= frame.dest;
                    rx_meta_if[gi].id <= frame.id;
                    rx_meta_if[gi].qos_tag <= 3'b0;
                    rx_meta_if[gi].vlan_id <= 12'b0;

                    @(posedge sys_clk);

                    while (!(rx_meta_if[gi].valid && rx_meta_if[gi].ready)) begin
                        @(posedge sys_clk);
                    end

                    rx_meta_if[gi].valid <= 1'b0;
                end
            end

            // ===== RX Data Interface Monitor =====
            initial begin
                automatic bit [7:0] raw_data[$];
                automatic bit frame_started = 0;
                automatic int ifg_clk = 0;
                automatic time start_time, end_time;
                automatic int data_id;
                automatic Fabric_frame_tr frame;
                automatic bit is_bad;

                tx_data_if[gi].ready = 1'b0;

                wait(mailboxes_ready);
                wait(reset_done);

                tx_data_if[gi].ready = 1'b1;

                forever begin
                    @(posedge sys_clk);
                    if (tx_data_if[gi].valid && tx_data_if[gi].ready) begin
                        if (!frame_started) begin
                            start_time = $time;
                            data_id = tx_data_if[gi].id;
                            frame_started = 1;
                        end

                        for (int byte_idx = 0; byte_idx < W_MINI/8; byte_idx++) begin
                            if (byte_idx < tx_data_if[gi].keep) begin
                                raw_data.push_back(tx_data_if[gi].data[byte_idx*8 +: 8]);
                            end
                        end

                        is_bad = tx_data_if[gi].is_bad_frame;

                        if (tx_data_if[gi].last) begin
                            end_time = $time;
                            frame = Fabric_frame_tr::create_from_raw(
                                .raw_data(raw_data),
                                .dest('0),
                                .ifg_clk(ifg_clk),
                                .is_bad_frame(is_bad),
                                .id(data_id)
                            );
                            frame.start_time = start_time;
                            frame.end_time = end_time;

                            frame_rx[gi].put(frame);
                            packets_recv++;
                            $display("[%0t] Received packet on port %0d, id=%0d, size=%0d bytes", 
                                     $time, gi, data_id, raw_data.size());

                            raw_data = {};
                            ifg_clk = 0;
                            frame_started = 0;
                        end
                    end else if (frame_started) begin
                        ifg_clk++;
                    end
                end
            end

        end
    endgenerate

    // Timeout watchdog
    initial begin
        #2000000;  // 2ms timeout
        $error("TIMEOUT - test did not complete");
        $display("  Packets Sent:     %0d", packets_sent);
        $display("  Packets Received: %0d", packets_recv);
        $finish;
    end

endmodule

`default_nettype wire