`timescale 1ns / 1ps
// `default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Company: IUST
// Engineer: Parham Soltani
//
// Create Date:  2025-03-26 12:26:18
// Module Name: switch_fabric_model
// Project Name:
// Target Devices:
// Tool Versions: Vivado 2022.2
// Description:
// Dependencies:
//
// Additional Comments:

//////////////////////////////////////////////////////////////////////////////////

import fabric_frame_pkg::*;

module switch_fabric #(
    parameter   NUM_PORT                = 10,            // number of ports
    parameter   S                       = 10,            // speed up
    parameter   W_MINI                  = 64,            // bus data width (mini cell data width)
    parameter   MAIN_MEM_DEPTH          = 512,           // main mem depth
    parameter   XPQ_DEPTH               = 64,
    parameter   OUTPUT_QUEUE_DEPTH      = 128,
    parameter   MULTICAST_SUPPORT       = 0,
    parameter   MULTICAST_RATE          = 1,        // Address fifos depth = MULTICAST_RATE* MAIN_MEM_DEPTH
    parameter   PACKET_ID_WIDTH         = 8,
    parameter   QOS_TAG_WIDTH           = 1
) (
    input   wire                                clk,
    input   wire                                reset,
    switch_data_if.slave_mp                     rx_data_if  [NUM_PORT],
    switch_metadata_if.slave_mp                 rx_meta_if  [NUM_PORT],
    switch_data_if.master_mp                    tx_data_if  [NUM_PORT]
);

    mailbox     frame_mailbox_in     [NUM_PORT];
    mailbox     frame_mailbox_out    [NUM_PORT];

    Fabric_frame_tr frame_in[NUM_PORT];
    Fabric_frame_tr frame_out[NUM_PORT];

    event       frame_sent              [NUM_PORT];

    generate
    for (genvar i = 0; i < NUM_PORT; ++i) begin

        mailbox temp_frame_mailbox;
        initial begin
            wait (temp_frame_mailbox != null);
            frame_mailbox_in[i] = temp_frame_mailbox;
        end

        fabric_monitor #(
            .NUM_PORT(NUM_PORT),
            .DATA_WIDTH(W_MINI),
            .QOS_TAG_WIDTH       (QOS_TAG_WIDTH),
            .PACKET_ID_WIDTH     (PACKET_ID_WIDTH)
        ) u_fabric_monitor (
            .clk(clk),
            .sw_data_if(rx_data_if[i]),
            .sw_meta_if(rx_meta_if[i]),
            .frame_mailbox(temp_frame_mailbox)
        );

    end
    endgenerate

    generate
        for (genvar g = 0; g < NUM_PORT; ++g) begin

            mailbox     gen_to_driver_mailbox_temp;

            initial begin
                wait (frame_mailbox_out[g] != null);

                gen_to_driver_mailbox_temp = frame_mailbox_out[g];
            end

            fabric_driver #(.NUM_PORT(NUM_PORT), .DATA_WIDTH(W_MINI)) u_fabric_driver (
                .clk(clk),
                .sw_data_if(tx_data_if[g]),
                .frame_mailbox(gen_to_driver_mailbox_temp),
                .frame_sent(frame_sent[g])
            );
        end
    endgenerate


    task forward_frame(int src_port, Fabric_frame_tr frame);
        for (int i = 0; i < NUM_PORT; i++) begin
            if (frame.dest[i]) begin // If bit i in dest_mac is set, forward to port i
                frame_mailbox_out[i].put(frame.do_copy());
            end
        end
    endtask

    generate
    for (genvar i = 0; i < NUM_PORT; i++) begin
        initial begin
            frame_mailbox_out[i] = new();
            wait (frame_mailbox_in[i] != null);

            forever begin
                frame_mailbox_in[i].get(frame_in[i]);
                forward_frame(i, frame_in[i]);
            end
        end
    end
    endgenerate

endmodule


`default_nettype wire