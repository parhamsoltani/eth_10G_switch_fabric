`timescale 1ns / 1ps
`default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Company: Parman
// Engineer: Alireza Abbasian
//
// Create Date:  2025-03-26 12:10:03
// Module Name: generator_frame
// Project Name: switch
// Target Devices: ku3p
// Tool Versions: Vivado 2022.2
// Description:
// Dependencies:
//
// Additional Comments:

//////////////////////////////////////////////////////////////////////////////////

//import class_pkg::*;

`include "sim_options.vh"

module generator_frame #(
    parameter   NUM_PORT = 10,
    parameter MICRO_DATA_WIDTH = 16,
    parameter MICRO_ADDR_WIDTH = 16
) (
    input   wire        sys_clk,
    input   wire        sys_reset,
    axis_if.master_mp      axis      [NUM_PORT],
    output  bit         end_of_sim,
    micro_if.master_mp  m_if
);



    `ifdef SIM_SPEED_UP
        localparam NUM_FRAME_PER_PORT = 100;
    `else
        localparam NUM_FRAME_PER_PORT = 2000;
    `endif




    mailbox     gen_to_driver_mailbox   [NUM_PORT];

    Micro_driver #(.MICRO_DATA_WIDTH(MICRO_DATA_WIDTH), .MICRO_ADDR_WIDTH(MICRO_ADDR_WIDTH)) m_if_driver;

    event       frame_sent              [NUM_PORT];

    Ethernet_frame frame [NUM_PORT];
    int seq_number [NUM_PORT];
    int total_num_frames = 0;

    bit [47:0] src_mac;
    bit [47:0] dest_mac;

    bit [NUM_PORT-1:0] src_mac_mask;
    bit [NUM_PORT-1:0] dest_mac_mask;

    logic [15:0] m_if_data_out;


    int j;














    initial begin
        end_of_sim = 0;

        for (int i = 0; i < NUM_PORT; ++i) begin
            gen_to_driver_mailbox[i] = new();
            seq_number[i] = 0;
        end

        m_if_driver = new(m_if);





        repeat (600) @(posedge sys_clk); // wait for stability

        repeat (10) $display(" ");
        $display("driving starts ....\n");
        repeat (2) $display(" ");



        // config micro interface ==========================

        m_if_driver.read_reg(16'hf000,m_if_data_out, "Line rate");

        m_if_driver.read_reg(16'h0000,m_if_data_out, "Num ports");

        m_if_driver.write_reg(16'h0001,1'b1, "save switch state");
        m_if_driver.write_reg(16'h0001,1'b0, "save switch state");
        m_if_driver.read_reg(16'h0002,m_if_data_out, "addr_fifos_num_free_reg");
        m_if_driver.read_reg(16'h0003,m_if_data_out, "free_fifo_count_reg");


        repeat (600) @(posedge sys_clk); // wait for stability
        // ===========================================







        for (int thread_i = 0; thread_i < NUM_PORT; ++thread_i) begin
            automatic int i = thread_i;
            fork begin


                repeat (NUM_FRAME_PER_PORT) begin

                    // macs are byte byte form left to right indexing from 0 -> 5
                    src_mac = reverse_mac(48'h00_80_16_00_00_00);

                    dest_mac = reverse_mac(48'h00_80_16_00_00_00);
                    // dest_mac = reverse_mac(48'h01_80_16_00_00_00, 3); // multicast
                    // dest_mac = reverse_mac(48'hff_ff_ff_ff_ff_ff); // broadcast

                    src_mac_mask = generate_mask_for_port(i);
                    // dest_mac_mask = generate_mask_for_port(0);
                    // dest_mac_mask = generate_mask_for_port(i);
                    dest_mac_mask = generate_mask_for_port($urandom_range(0,NUM_PORT-1));
                    // dest_mac_mask = generate_random_mask_port();
                    // dest_mac_mask = generate_multicast_mask(10);

                    frame[i] = Ethernet_frame::create(
                        .dest_mac(dest_mac),
                        .src_mac(src_mac),
                        .src_port(src_mac_mask),
                        .dest_port(dest_mac_mask),
                        .length($urandom_range(60, 72)), // -crc(4)
                        .seq_number(seq_number[i]),
                        .ifg_clk($urandom_range(20, 40)),  // per clock
                        .bad_frame_prob(0) // real number between 0,1
                    );

                    // for debug ================================
                    // frame[i].do_print(
                    //     .name("generator frame"),
                    //     .include_data(0)
                    // );
                    // =========================================

                    gen_to_driver_mailbox[i].put(frame[i]);


                    seq_number[i]++;
                    total_num_frames++;
                    @frame_sent[i];
                end
            end join_none
        end
        wait fork;

        for (int i = 0; i < 10000; ++i) @(posedge sys_clk);

        m_if_driver.write_reg(16'h0001,1'b1, "save switch state");
        m_if_driver.write_reg(16'h0001,1'b0, "save switch state");
        m_if_driver.read_reg(16'h0002,m_if_data_out, "addr_fifos_num_free_reg");
        m_if_driver.read_reg(16'h0003,m_if_data_out, "free_fifo_count_reg");

        for (int i = 0; i < 1000; ++i) @(posedge sys_clk);

        end_of_sim = 1;

        $display("========================================");
        $display("total number of generated frames = %d", total_num_frames);
        $display("========================================\n");
    end










    generate
        for (genvar g = 0; g < NUM_PORT; ++g) begin

            mailbox     gen_to_driver_mailbox_temp;

            initial begin
                wait (gen_to_driver_mailbox[g] != null);

                gen_to_driver_mailbox_temp = gen_to_driver_mailbox[g];
            end

            axi_driver u_axi_driver (
                .axis(axis[g]),
                .frame_mailbox(gen_to_driver_mailbox_temp),
                .frame_sent(frame_sent[g])
            );
        end
    endgenerate



















    function bit [47:0] reverse_mac(bit [47:0] base_mac);
        base_mac = {<<8{base_mac}};
        return base_mac;
    endfunction




    function bit [NUM_PORT-1:0] generate_mask_for_port(int port);
        automatic bit [NUM_PORT-1:0] port_mask = 1 << port;  // Set only the 'port' bit
        return port_mask;
    endfunction

    function bit [NUM_PORT-1:0] generate_random_mask_port();
        automatic int rand_port = $urandom_range(0, NUM_PORT-1);
        return generate_mask_for_port(rand_port);
    endfunction

    function bit [NUM_PORT-1:0] generate_multicast_mask(int num_multicast);
        automatic bit [NUM_PORT-1:0] multicast_mask = 0;
        automatic int count = 0;
        automatic int rand_bit = 0;

        // Randomly set 'num_multicast' bits in multicast_mask
        while (count < num_multicast) begin
            rand_bit = $urandom_range(0, NUM_PORT-1);
            if (!multicast_mask[rand_bit]) begin
                multicast_mask[rand_bit] = 1;
                count++;
            end
        end

        return multicast_mask;
    endfunction







endmodule



`default_nettype wire