`timescale 1ns / 1ps

import fabric_frame_pkg::*;

module fabric_monitor # (
    parameter NUM_PORT = 10,
    parameter   DATA_WIDTH              = 64,
    parameter   QOS_TAG_WIDTH           = 3,
    parameter   PACKET_ID_WIDTH         = 10
) (
    input wire clk,
    switch_data_if.monitor sw_data_if,
    switch_metadata_if.monitor sw_meta_if,
    ref mailbox #(Fabric_frame_tr) frame_mailbox
);

    bit [7:0] raw_data[$];
    Fabric_frame_tr frame;
    Fabric_frame_tr frame_with_dest;
    int ifg_clk;
    bit frame_started;
    time start_time;
    time end_time;

    int data_id;

    Fabric_frame_tr temp_frame_queue [$];

    bit [NUM_PORT-1:0]          dest;
    bit [QOS_TAG_WIDTH-1:0]     qos_tag;
    bit [PACKET_ID_WIDTH-1:0]   meta_id;

    bit [NUM_PORT-1:0]          dest_queue [$];
    bit [QOS_TAG_WIDTH-1:0]     qos_tag_queue [$];
    bit [PACKET_ID_WIDTH-1:0]   meta_id_queue [$];

    initial begin
        ifg_clk = 0;
        frame_started = 0;

        forever begin
            @(posedge clk);

            if (sw_data_if.valid && sw_data_if.ready) begin
                if (frame_started == 0) begin
                    start_time = $time;
                    data_id = sw_data_if.id;
                end
                frame_started = 1;

                for (int i = 0; i < DATA_WIDTH/8; i++) begin
                    if (i < sw_data_if.keep)
                        raw_data.push_back(sw_data_if.data[i * 8 +: 8]);
                end

                if (sw_data_if.last) begin
                    frame = Fabric_frame_tr::create_from_raw(
                        .raw_data       (raw_data),
                        .dest           (0),
                        .ifg_clk        (ifg_clk),
                        .is_bad_frame   (sw_data_if.is_bad_frame),
                        .id             (data_id)
                    );

                    end_time = $time;
                    frame.start_time = start_time;
                    frame.end_time = end_time;

                    temp_frame_queue.push_back(frame);

                    raw_data = {}; // Clear the buffer for next frame
                    ifg_clk = 0;
                    frame_started = 0;
                end
            end else begin
                ifg_clk++;
            end
        end
    end

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

    initial begin
        forever begin
            @(posedge clk);
            if (meta_id_queue.size() != 0 &&
                temp_frame_queue.size() != 0 &&
                qos_tag_queue.size() != 0 &&
                dest_queue.size() != 0
            ) begin
                frame_with_dest = temp_frame_queue.pop_front();
                dest    = dest_queue.pop_front();
                qos_tag = qos_tag_queue.pop_front();
                meta_id = meta_id_queue.pop_front();

                if (meta_id == frame_with_dest.id) begin
                    frame_with_dest.dest = dest;
                    // Assuming Fabric_frame_tr has a qos_tag field
                    // frame_with_dest.qos_tag = qos_tag;
                    frame_mailbox.put(frame_with_dest);
                end
            end
        end
    end

endmodule

`default_nettype wire