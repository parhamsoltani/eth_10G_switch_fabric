`timescale 1ns / 1ps

import fabric_frame_pkg::*;

//////////////////////////////////////////////////////////////////////////////////
// Fabric Monitor - Captures packets from DUT egress
//
// FIXED: Properly captures packet ID from sw_data_if.id on egress
//////////////////////////////////////////////////////////////////////////////////

module fabric_monitor # (
    parameter NUM_PORT = 10,
    parameter DATA_WIDTH = 64,
    parameter QOS_TAG_WIDTH = 3,
    parameter PACKET_ID_WIDTH = 8
) (
    input wire clk,
    switch_data_if.monitor sw_data_if,
    switch_metadata_if.monitor sw_meta_if,
    ref mailbox #(Fabric_frame_tr) frame_mailbox
);

    //==========================================================================
    // Local Variables
    //==========================================================================
    bit [7:0] raw_data[$];
    Fabric_frame_tr frame;
    Fabric_frame_tr frame_with_dest;
    int ifg_clk;
    bit frame_started;
    time start_time;
    time end_time;

    // FIXED: Capture packet ID at start of frame
    logic [PACKET_ID_WIDTH-1:0] captured_pkt_id;
    int data_id;

    Fabric_frame_tr temp_frame_queue [$];

    bit [NUM_PORT-1:0]          dest;
    bit [QOS_TAG_WIDTH-1:0]     qos_tag;
    bit [PACKET_ID_WIDTH-1:0]   meta_id;

    bit [NUM_PORT-1:0]          dest_queue [$];
    bit [QOS_TAG_WIDTH-1:0]     qos_tag_queue [$];
    bit [PACKET_ID_WIDTH-1:0]   meta_id_queue [$];

    //==========================================================================
    // Data Path Monitor - Captures packet data and ID from egress
    //==========================================================================
    initial begin
        ifg_clk = 0;
        frame_started = 0;
        captured_pkt_id = 0;

        forever begin
            @(posedge clk);

            if (sw_data_if.valid && sw_data_if.ready) begin
                if (frame_started == 0) begin
                    // FIXED: Capture packet ID at START of frame (first beat)
                    start_time = $time;
                    captured_pkt_id = sw_data_if.id;
                    data_id = int'(sw_data_if.id);
                    
                    // Debug: Show captured ID
                    // $display("[MON] Frame start: captured pkt_id=%0d", captured_pkt_id);
                end
                frame_started = 1;

                // Collect data bytes based on keep signal
                for (int i = 0; i < DATA_WIDTH/8; i++) begin
                    if (i < sw_data_if.keep)
                        raw_data.push_back(sw_data_if.data[i * 8 +: 8]);
                end

                if (sw_data_if.last) begin
                    // FIXED: Use the captured_pkt_id from frame start
                    frame = Fabric_frame_tr::create_from_raw(
                        .raw_data       (raw_data),
                        .dest           (0),
                        .ifg_clk        (ifg_clk),
                        .is_bad_frame   (sw_data_if.is_bad_frame),
                        .id             (data_id)  // Use captured ID
                    );

                    end_time = $time;
                    frame.start_time = start_time;
                    frame.end_time = end_time;

                    temp_frame_queue.push_back(frame);

                    // Clear the buffer for next frame
                    raw_data = {};
                    ifg_clk = 0;
                    frame_started = 0;
                    captured_pkt_id = 0;
                end
            end else begin
                ifg_clk++;
            end
        end
    end

    //==========================================================================
    // Metadata Path Monitor - Captures destination and QoS from metadata IF
    //==========================================================================
    initial begin
        forever begin
            @(posedge clk);

            if (sw_meta_if.valid && sw_meta_if.ready) begin
                dest_queue.push_back(sw_meta_if.dest_port_mask);
                qos_tag_queue.push_back(sw_meta_if.qos_tag);
                meta_id_queue.push_back(sw_meta_if.id);
            end
        end
    end

    //==========================================================================
    // Frame Assembly - Combines data with metadata
    //==========================================================================
    initial begin
        forever begin
            @(posedge clk);
            
            // Check if we have both frame data and metadata ready
            if (temp_frame_queue.size() != 0) begin
                // Pop frame from data queue
                frame_with_dest = temp_frame_queue.pop_front();
                
                // Try to match with metadata if available
                if (meta_id_queue.size() != 0 &&
                    qos_tag_queue.size() != 0 &&
                    dest_queue.size() != 0) begin
                    
                    dest    = dest_queue.pop_front();
                    qos_tag = qos_tag_queue.pop_front();
                    meta_id = meta_id_queue.pop_front();

                    // Check if IDs match (they should for proper operation)
                    if (meta_id == frame_with_dest.id) begin
                        frame_with_dest.dest = dest;
                        // frame_with_dest.qos_tag = qos_tag;  // If field exists
                    end else begin
                        // IDs don't match - still forward frame but log warning
                        $display("[MON WARN] ID mismatch: data_id=%0d meta_id=%0d", 
                                 frame_with_dest.id, meta_id);
                        frame_with_dest.dest = dest;
                    end
                end
                
                // Always put frame to mailbox (with or without metadata match)
                frame_mailbox.put(frame_with_dest);
            end
        end
    end

endmodule

`default_nettype wire