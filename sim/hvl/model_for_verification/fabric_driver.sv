`timescale 1ns / 1ps
// `default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Company: IUST
// Engineer: Parham Soltani
//
// Create Date:  2025-03-25 00:17:28
// Module Name: fabric_driver
// Project Name:
// Target Devices:
// Tool Versions: Vivado 2022.2
// Description:
// Dependencies:
//
// Additional Comments:

//////////////////////////////////////////////////////////////////////////////////

import fabric_frame_pkg::*;


module fabric_driver # (
    parameter NUM_PORT = 10,
    parameter   DATA_WIDTH              = 64
) (
    input wire clk,
    switch_data_if.master_mp          sw_data_if,
    input  mailbox          frame_mailbox,
    output event            frame_sent
);



    bit [7:0] raw_data[];
    Fabric_frame_tr frame;

    int keep_val = 0;

    initial begin


        wait (frame_mailbox!= null);

        forever begin


            frame_mailbox.get(frame);

            frame.frame_to_raw(raw_data);

            send_frame(raw_data, frame.is_bad_frame);

            -> frame_sent;


        end
    end




    task send_frame(input bit [7:0] raw_data[],
                    input bit is_bad_frame);

        automatic int num_words = (raw_data.size() + 7) / 8;

        automatic int i = 0;

        sw_data_if.is_bad_frame <= 0;
        sw_data_if.valid <= 1;
        sw_data_if.data <= 0;
        sw_data_if.keep <= 0;

        keep_val = 0;

        for (int j = 0; j < DATA_WIDTH/8; j++) begin
            if ((i * (DATA_WIDTH/8) + j) < raw_data.size()) begin
                sw_data_if.data[j * 8 +: 8] <= raw_data[i * (DATA_WIDTH/8) + j];
                keep_val += 1;
            end
        end

        sw_data_if.keep <= keep_val;
        keep_val = 0;

        if (i == num_words - 1) begin
            sw_data_if.last <= 1;

            if (is_bad_frame) begin
                sw_data_if.is_bad_frame <= 1;
            end else begin
                sw_data_if.is_bad_frame <= 0;
            end
        end else begin
            sw_data_if.last <= 0;
            sw_data_if.is_bad_frame <= 0;
        end


        for (i = 1; i < num_words; i++) begin

            @(posedge clk);

            if (sw_data_if.ready) begin
                sw_data_if.valid <= 1;
                sw_data_if.data <= 0;
                sw_data_if.keep <= 0;

                for (int j = 0; j < DATA_WIDTH/8; j++) begin
                    if ((i * (DATA_WIDTH/8) + j) < raw_data.size()) begin
                        sw_data_if.data[j * 8 +: 8] <= raw_data[i * (DATA_WIDTH/8) + j];
                        keep_val += 1;
                    end
                end

                sw_data_if.keep <= keep_val;
                keep_val = 0;

                if (i == num_words - 1) begin
                    sw_data_if.last <= 1;

                    if (is_bad_frame) begin
                        sw_data_if.is_bad_frame <= 1;
                    end else begin
                        sw_data_if.is_bad_frame <= 0;
                    end
                end else begin
                    sw_data_if.last <= 0;
                    sw_data_if.is_bad_frame <= 0;
                end

            end else begin
                i = i - 1; // Retry if not ready
            end
        end

        @(posedge clk);

        while (!sw_data_if.ready) begin
            @(posedge clk);
        end

        sw_data_if.valid <= 0;
        sw_data_if.last <= 0;
        sw_data_if.is_bad_frame <= 0;
        keep_val = 0;






    endtask
endmodule


`default_nettype wire