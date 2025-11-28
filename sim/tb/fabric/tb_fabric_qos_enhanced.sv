`timescale 1ns / 1ps
`default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Company: IUST
// Engineer: Parham Soltani
//
// Create Date:  2025-11-25
// Module Name: tb_fabric_qos_enhanced
// Description: QoS-aware testbench extending your tb_ethernet_switch pattern
//////////////////////////////////////////////////////////////////////////////////

import fabric_frame_pkg::*;

`include "sim_options.vh"
`include "implement_options.vh"

module tb_fabric_qos_enhanced;

    parameter NUM_PORT = `NUM_PORT;
    parameter W_MINI = `W;
    parameter S = `S;
    parameter MAIN_MEM_DEPTH = `D;
    parameter XPQ_DEPTH = `X;
    parameter OUTPUT_QUEUE_DEPTH = `OUTPUT_QUEUE_DEPTH;
    parameter MULTICAST_SUPPORT = `MULTICAST_SUPPORT;
    parameter MULTICAST_RATE = `U;
    parameter PACKET_ID_WIDTH = 8;
    parameter QOS_TAG_WIDTH = 3;

    parameter SYS_PERIOD = 1.499;  // Match your timing.xdc

    //==========================================================================
    // Clock & Reset (your exact pattern)
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
    // Interfaces (your switch_data_if/switch_metadata_if)
    //==========================================================================
    switch_data_if #(.DATA_WIDTH(W_MINI), .ID_WIDTH(PACKET_ID_WIDTH))
        rx_data_if [NUM_PORT] ();

    switch_metadata_if #(.PORT_MASK_WIDTH(NUM_PORT), .ID_WIDTH(PACKET_ID_WIDTH), .QOS_TAG_WIDTH(QOS_TAG_WIDTH))
        rx_meta_if [NUM_PORT] ();

    switch_data_if #(.DATA_WIDTH(W_MINI), .ID_WIDTH(PACKET_ID_WIDTH))
        tx_data_if [NUM_PORT] ();

    //==========================================================================
    // Verification Components (your mailbox pattern)
    //==========================================================================
    mailbox frame_mailbox_in[NUM_PORT];
    mailbox frame_mailbox_out[NUM_PORT];

    Fabric_frame_tr frame_in[NUM_PORT];
    Fabric_frame_tr frame_out[NUM_PORT];

    event frame_sent[NUM_PORT];

    qos_checker_enhanced #(
        .NUM_PORTS(NUM_PORT),
        .ID_WIDTH(PACKET_ID_WIDTH),
        .QOS_LEVELS(3)
    ) qos_check();

    //==========================================================================
    // DUT (your switch_fabric)
    //==========================================================================
    switch_fabric #(
        .NUM_PORT(NUM_PORT),
        .S(S),
        .W_MINI(W_MINI),
        .MAIN_MEM_DEPTH(MAIN_MEM_DEPTH),
        .XPQ_DEPTH(XPQ_DEPTH),
        .OUTPUT_QUEUE_DEPTH(OUTPUT_QUEUE_DEPTH),
        .MULTICAST_SUPPORT(MULTICAST_SUPPORT),
        .MULTICAST_RATE(MULTICAST_RATE),
        .PACKET_ID_WIDTH(PACKET_ID_WIDTH),
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
    // Monitors (your fabric_monitor pattern)
    //==========================================================================
    generate
        for (genvar i = 0; i < NUM_PORT; i++) begin : gen_monitors
            mailbox temp_mailbox;

            initial begin
                wait (temp_mailbox != null);
                frame_mailbox_in[i] = temp_mailbox;
            end

            fabric_monitor #(
                .NUM_PORT(NUM_PORT),
                .DATA_WIDTH(W_MINI),
                .QOS_TAG_WIDTH(QOS_TAG_WIDTH),
                .PACKET_ID_WIDTH(PACKET_ID_WIDTH)
            ) u_monitor (
                .clk(sys_clk),
                .sw_data_if(rx_data_if[i]),
                .sw_meta_if(rx_meta_if[i]),
                .frame_mailbox(temp_mailbox)
            );
        end
    endgenerate

    //==========================================================================
    // Drivers (your fabric_driver pattern)
    //==========================================================================
    generate
        for (genvar g = 0; g < NUM_PORT; g++) begin : gen_drivers
            mailbox gen_to_driver_mailbox_temp;

            initial begin
                wait (frame_mailbox_out[g] != null);
                gen_to_driver_mailbox_temp = frame_mailbox_out[g];
            end

            fabric_driver #(
                .NUM_PORT(NUM_PORT),
                .DATA_WIDTH(W_MINI)
            ) u_driver (
                .clk(sys_clk),
                .sw_data_if(tx_data_if[g]),
                .frame_mailbox(gen_to_driver_mailbox_temp),
                .frame_sent(frame_sent[g])
            );
        end
    endgenerate

    //==========================================================================
    // Test Stimulus (follows your generator_frame.sv pattern)
    //==========================================================================
    int next_pkt_id = 0;
    bit end_of_sim = 0;

    initial begin
        for (int i = 0; i < NUM_PORT; i++) begin
            frame_mailbox_out[i] = new();
        end

        wait (!sys_reset);
        repeat (100) @(posedge sys_clk);

        $display("\n========== QoS-AWARE FABRIC TEST ==========\n");

        // Test 1: Priority ordering
        $display("[%0t] TEST 1: Strict Priority", $time);
        fork
            send_qos_burst(0, 1, 10, 3'b010);  // Low priority
            #(SYS_PERIOD*50);
            send_qos_burst(2, 1, 10, 3'b000);  // High priority
            #(SYS_PERIOD*50);
            send_qos_burst(3, 1, 10, 3'b001);  // Medium priority
        join

        repeat (500) @(posedge sys_clk);

        // Test 2: Multicast with mixed QoS
        $display("[%0t] TEST 2: Multicast QoS", $time);
        send_multicast_qos(0, 10'b0000001111, 20, 3'b000);

        repeat (500) @(posedge sys_clk);

        // Test 3: Congestion (matches your generator_frame all-to-one pattern)
        $display("[%0t] TEST 3: Congestion Scenario", $time);
        fork
            for (int s = 0; s < NUM_PORT; s++) begin
                if (s != 5) begin
                    automatic int src = s;
                    fork
                        repeat (10) begin
                            send_packet_qos(src, 5, 512, 3'b001, $urandom_range(20,40));
                        end
                    join_none
                end
            end
        join

        repeat (2000) @(posedge sys_clk);

        qos_check.print_report();

        $display("[%0t] Test complete", $time);
        end_of_sim = 1;
        repeat (100) @(posedge sys_clk);
        $stop;
    end

    //==========================================================================
    // Tasks (match your generator_frame.sv style)
    //==========================================================================
    task automatic send_packet_qos(
        input int src,
        input int dst,
        input int size,
        input logic [2:0] qos,
        input int ifg_clk
    );
        automatic int pkt_id = next_pkt_id++;
        automatic bit [47:0] src_mac = reverse_mac(48'h00_80_16_00_00_00);
        automatic bit [47:0] dst_mac = reverse_mac(48'h00_80_16_00_00_00);
        automatic bit [NUM_PORT-1:0] dst_mask = (1 << dst);

        Fabric_frame_tr frame = Fabric_frame_tr::create_from_raw(
            .raw_data(new[size]),
            .dest(dst_mask),
            .ifg_clk(ifg_clk),
            .is_bad_frame(1'b0),
            .id(pkt_id)
        );

        // Randomize payload
        for (int b = 0; b < size; b++)
            frame.data[b] = $random;

        qos_check.record_tx(pkt_id[ID_WIDTH-1:0], src, dst, qos);
        frame_mailbox_in[src].put(frame.do_copy());

        @frame_sent[src];
    endtask

    task automatic send_qos_burst(
        input int src,
        input int dst,
        input int num_packets,
        input logic [2:0] qos
    );
        repeat (num_packets) begin
            send_packet_qos(src, dst, $urandom_range(60,1500), qos, $urandom_range(20,40));
        end
    endtask

    task automatic send_multicast_qos(
        input int src,
        input logic [NUM_PORT-1:0] dst_mask,
        input int num_packets,
        input logic [2:0] qos
    );
        repeat (num_packets) begin
            for (int d = 0; d < NUM_PORT; d++) begin
                if (dst_mask[d]) begin
                    send_packet_qos(src, d, $urandom_range(64,512), qos, 20);
                end
            end
        end
    endtask

    //==========================================================================
    // RX Monitors (your pattern with QoS tracking)
    //==========================================================================
    generate
        for (genvar i = 0; i < NUM_PORT; i++) begin : gen_rx_mon
            initial begin
                tx_data_if[i].ready = 1'b1;

                forever begin
                    @(posedge sys_clk);
                    if (tx_data_if[i].valid && tx_data_if[i].ready && tx_data_if[i].last) begin
                        qos_check.record_rx(
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
    // Functions (your exact implementations)
    //==========================================================================
    function bit [47:0] reverse_mac(bit [47:0] base_mac);
        return {<<8{base_mac}};
    endfunction

endmodule

`default_nettype wire