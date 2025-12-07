`timescale 1ns / 1ps
// `default_nettype none

`include "fabric_params.vh"

module tb_fabric_qos;

    parameter NUM_PORTS = 10;
    parameter DATA_WIDTH = 32;
    parameter ID_WIDTH = 10;
    parameter CLK_PERIOD = 4.0;  // 250 MHz

    logic clk;
    logic rst_n;

    // Interfaces
    switch_data_if #(.DATA_WIDTH(DATA_WIDTH), .ID_WIDTH(ID_WIDTH))
        rx_data_if [NUM_PORTS] ();

    switch_metadata_if #(.PORT_MASK_WIDTH(NUM_PORTS), .ID_WIDTH(ID_WIDTH))
        rx_meta_if [NUM_PORTS] ();

    switch_data_if #(.DATA_WIDTH(DATA_WIDTH), .ID_WIDTH(ID_WIDTH))
        tx_data_if [NUM_PORTS] ();

    // Scoreboard and QoS checker
    fabric_scoreboard #(
        .NUM_PORTS(NUM_PORTS),
        .DATA_WIDTH(DATA_WIDTH),
        .ID_WIDTH(ID_WIDTH)
    ) scoreboard ();

    qos_checker #(
        .NUM_PORTS(NUM_PORTS),
        .ID_WIDTH(ID_WIDTH)
    ) qos_check ();

    // DUT
    switch_fabric #(
        .NUM_PORTS(NUM_PORTS),
        .DATA_WIDTH(DATA_WIDTH),
        .ID_WIDTH(ID_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .rx_data_if(rx_data_if),
        .rx_meta_if(rx_meta_if),
        .tx_data_if(tx_data_if),
        .pkt_count_rx(),
        .pkt_count_tx(),
        .pkt_drop_count(),
        .free_ids()
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Reset
    initial begin
        rst_n = 0;
        repeat (10) @(posedge clk);
        rst_n = 1;
        $display("[%0t] Reset released", $time);
    end

    // Packet ID counter
    int next_pkt_id = 0;

    // Test stimulus
    initial begin
        $timeformat(-9, 2, " ns", 10);

        wait (rst_n);
        repeat (20) @(posedge clk);

        $display("\n========================================");
        $display("  FABRIC QoS TEST SEQUENCE");
        $display("========================================\n");

        // Test 1: Priority ordering
        $display("[%0t] TEST 1: Priority Ordering", $time);
        fork
            send_packet(.src(0), .dst(1), .size(64), .qos(3'b010));   // Low
            #(CLK_PERIOD*5);
            send_packet(.src(2), .dst(1), .size(64), .qos(3'b000));   // High
            #(CLK_PERIOD*5);
            send_packet(.src(3), .dst(1), .size(64), .qos(3'b001));   // Medium
        join

        repeat (200) @(posedge clk);

        // Test 2: Multicast high priority
        $display("[%0t] TEST 2: Multicast High Priority", $time);
        send_multicast(.src(0), .dst_mask(10'b0000001111), .size(128), .qos(3'b000));

        repeat (300) @(posedge clk);

        // Test 3: Sustained mixed load
        $display("[%0t] TEST 3: Sustained Mixed Traffic", $time);
        fork
            repeat (10) begin
                send_packet(.src(0), .dst($urandom_range(1,NUM_PORTS-1)), .size(64), .qos(3'b000));
                #(CLK_PERIOD*10);
            end
            repeat (20) begin
                send_packet(.src(1), .dst($urandom_range(0,NUM_PORTS-1)), .size(128), .qos(3'b001));
                #(CLK_PERIOD*8);
            end
            repeat (30) begin
                send_packet(.src(2), .dst($urandom_range(0,NUM_PORTS-1)), .size(256), .qos(3'b010));
                #(CLK_PERIOD*6);
            end
        join

        repeat (1000) @(posedge clk);

        // Test 4: Congestion scenario
        $display("[%0t] TEST 4: Congestion (all→port 5)", $time);
        fork
            for (int s = 0; s < NUM_PORTS; s++) begin
                if (s != 5) begin
                    automatic int src = s;
                    fork
                        repeat (5) begin
                            send_packet(.src(src), .dst(5), .size(512), .qos(3'b001));
                            #(CLK_PERIOD*20);
                        end
                    join_none
                end
            end
        join

        repeat (2000) @(posedge clk);

        // Print reports
        scoreboard.print_report();
        qos_check.print_report();

        $display("[%0t] All tests complete", $time);
        $finish;
    end

    // Task to send packet
    task automatic send_packet(
        input int src,
        input int dst,
        input int size,
        input logic [2:0] qos
    );
        automatic int num_beats = (size + (DATA_WIDTH/8) - 1) / (DATA_WIDTH/8);
        automatic int pkt_id = next_pkt_id++;

        // Send metadata first
        @(posedge clk);
        rx_meta_if[src].dest_port_mask <= (1 << dst);
        rx_meta_if[src].qos_tag <= qos;
        rx_meta_if[src].id <= pkt_id[ID_WIDTH-1:0];
        rx_meta_if[src].valid <= 1'b1;

        wait (rx_meta_if[src].ready);
        @(posedge clk);
        rx_meta_if[src].valid <= 1'b0;

        // Record in scoreboard
        scoreboard.record_tx(pkt_id[ID_WIDTH-1:0], src, dst, qos, size, 1'b0);

        // Send data
        for (int beat = 0; beat < num_beats; beat++) begin
            @(posedge clk);
            rx_data_if[src].data <= $random;
            rx_data_if[src].keep <= (beat == num_beats-1) ? size % (DATA_WIDTH/8) : (DATA_WIDTH/8);
            rx_data_if[src].valid <= 1'b1;
            rx_data_if[src].last <= (beat == num_beats-1);
            rx_data_if[src].is_bad_frame <= 1'b0;
            rx_data_if[src].id <= pkt_id[ID_WIDTH-1:0];
            rx_data_if[src].qos_tag <= qos;

            wait (rx_data_if[src].ready);
        end

        @(posedge clk);
        rx_data_if[src].valid <= 1'b0;

    endtask

    task automatic send_multicast(
        input int src,
        input logic [NUM_PORTS-1:0] dst_mask,
        input int size,
        input logic [2:0] qos
    );
        automatic int num_beats = (size + (DATA_WIDTH/8) - 1) / (DATA_WIDTH/8);
        automatic int pkt_id = next_pkt_id++;

        @(posedge clk);
        rx_meta_if[src].dest_port_mask <= dst_mask;
        rx_meta_if[src].qos_tag <= qos;
        rx_meta_if[src].id <= pkt_id[ID_WIDTH-1:0];
        rx_meta_if[src].valid <= 1'b1;

        wait (rx_meta_if[src].ready);
        @(posedge clk);
        rx_meta_if[src].valid <= 1'b0;

        // Record multicast (to each destination)
        for (int dst = 0; dst < NUM_PORTS; dst++) begin
            if (dst_mask[dst]) begin
                scoreboard.record_tx(pkt_id[ID_WIDTH-1:0], src, dst, qos, size, 1'b0);
            end
        end

        for (int beat = 0; beat < num_beats; beat++) begin
            @(posedge clk);
            rx_data_if[src].data <= $random;
            rx_data_if[src].keep <= (beat == num_beats-1) ? size % (DATA_WIDTH/8) : (DATA_WIDTH/8);
            rx_data_if[src].valid <= 1'b1;
            rx_data_if[src].last <= (beat == num_beats-1);
            rx_data_if[src].is_bad_frame <= 1'b0;
            rx_data_if[src].id <= pkt_id[ID_WIDTH-1:0];
            rx_data_if[src].qos_tag <= qos;

            wait (rx_data_if[src].ready);
        end

        @(posedge clk);
        rx_data_if[src].valid <= 1'b0;
    endtask

    // RX monitors
    genvar g;
    generate
        for (g = 0; g < NUM_PORTS; g++) begin : gen_rx_monitor

            int beat_count = 0;
            logic [ID_WIDTH-1:0] current_id;
            logic [2:0] current_qos;
            int current_size;

            initial begin
                tx_data_if[g].ready = 1'b1;

                forever begin
                    @(posedge clk);
                    if (tx_data_if[g].valid && tx_data_if[g].ready) begin
                        if (beat_count == 0) begin
                            current_id = tx_data_if[g].id;
                            current_qos = tx_data_if[g].qos_tag;
                            current_size = 0;
                        end

                        current_size += tx_data_if[g].keep;
                        beat_count++;

                        // Check QoS ordering
                        qos_check.check_priority_order(current_id, current_qos, $time);
                        qos_check.check_starvation(current_qos, $time);

                        if (tx_data_if[g].last) begin
                            scoreboard.record_rx(
                                current_id,
                                g,
                                current_qos,
                                current_size,
                                tx_data_if[g].is_bad_frame
                            );
                            beat_count = 0;
                        end
                    end
                end
            end
        end
    endgenerate

endmodule

`default_nettype wire