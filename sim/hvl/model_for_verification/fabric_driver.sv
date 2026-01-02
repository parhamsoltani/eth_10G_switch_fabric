`timescale 1ns / 1ps
// `default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Company: IUST
// Engineer: Parham Soltani
//
// Create Date:  2025-03-25 00:17:28
// Module Name: fabric_driver
// Description: Drives packets into the switch fabric DUT
//
// FIXED: Proper packet ID handling throughout frame transmission
//////////////////////////////////////////////////////////////////////////////////

import fabric_frame_pkg::*;

module fabric_driver # (
    parameter NUM_PORT = 10,
    parameter DATA_WIDTH = 64
) (
    input wire clk,
    switch_data_if.master_mp          sw_data_if,
    ref mailbox #(Fabric_frame_tr)    frame_mailbox,
    output event                      frame_sent
);

    bit [7:0] raw_data[];
    Fabric_frame_tr frame;
    int keep_val = 0;

    initial begin
        // Initialize outputs
        sw_data_if.valid <= 0;
        sw_data_if.data <= 0;
        sw_data_if.keep <= 0;
        sw_data_if.last <= 0;
        sw_data_if.is_bad_frame <= 0;
        sw_data_if.id <= 0;
        sw_data_if.qos_tag <= 0;

        wait (frame_mailbox != null);

        forever begin
            frame_mailbox.get(frame);
            frame.frame_to_raw(raw_data);
            
            // Debug: Show packet being sent
            // $display("[DRV] Sending frame id=%0d size=%0d", frame.id, raw_data.size());
            
            send_frame(raw_data, frame.is_bad_frame, frame.id);
            -> frame_sent;
        end
    end

    task send_frame(
        input bit [7:0] raw_data[],
        input bit is_bad_frame,
        input int pkt_id
    );
        automatic int num_words = (raw_data.size() + (DATA_WIDTH/8) - 1) / (DATA_WIDTH/8);
        automatic int bytes_per_word = DATA_WIDTH / 8;
        automatic int i;
        automatic int byte_idx;
        automatic logic [7:0] pkt_id_8bit;
        
        // Ensure packet ID fits in 8 bits
        pkt_id_8bit = pkt_id[7:0];
        
        if (num_words == 0) begin
            $warning("[DRV] Empty frame, skipping");
            return;
        end

        // First word
        i = 0;
        sw_data_if.valid <= 1;
        sw_data_if.data <= '0;
        sw_data_if.keep <= 0;
        sw_data_if.id <= pkt_id_8bit;  // Set packet ID on first beat
        sw_data_if.is_bad_frame <= 0;
        sw_data_if.last <= 0;

        keep_val = 0;
        for (int j = 0; j < bytes_per_word; j++) begin
            byte_idx = i * bytes_per_word + j;
            if (byte_idx < raw_data.size()) begin
                sw_data_if.data[j * 8 +: 8] <= raw_data[byte_idx];
                keep_val++;
            end
        end
        sw_data_if.keep <= keep_val;

        // Check if this is also the last word
        if (num_words == 1) begin
            sw_data_if.last <= 1;
            sw_data_if.is_bad_frame <= is_bad_frame;
        end

        // Wait for ready and send remaining words
        for (i = 1; i < num_words; i++) begin
            @(posedge clk);

            // Wait for ready
            while (!sw_data_if.ready) begin
                @(posedge clk);
            end

            // Send next word
            sw_data_if.valid <= 1;
            sw_data_if.data <= '0;
            sw_data_if.keep <= 0;
            sw_data_if.id <= pkt_id_8bit;  // Keep ID consistent through frame

            keep_val = 0;
            for (int j = 0; j < bytes_per_word; j++) begin
                byte_idx = i * bytes_per_word + j;
                if (byte_idx < raw_data.size()) begin
                    sw_data_if.data[j * 8 +: 8] <= raw_data[byte_idx];
                    keep_val++;
                end
            end
            sw_data_if.keep <= keep_val;

            // Set last and bad frame on final word
            if (i == num_words - 1) begin
                sw_data_if.last <= 1;
                sw_data_if.is_bad_frame <= is_bad_frame;
            end else begin
                sw_data_if.last <= 0;
                sw_data_if.is_bad_frame <= 0;
            end
        end

        // Wait for final word to be accepted
        @(posedge clk);
        while (!sw_data_if.ready) begin
            @(posedge clk);
        end

        // Deassert valid
        sw_data_if.valid <= 0;
        sw_data_if.last <= 0;
        sw_data_if.is_bad_frame <= 0;
        sw_data_if.data <= '0;
        sw_data_if.keep <= 0;
    endtask

endmodule

`default_nettype wire