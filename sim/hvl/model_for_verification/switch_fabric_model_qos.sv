`timescale 1ns / 1ps
`default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// QoS-Aware Switch Fabric Behavioral Model
// Golden reference for QoS priority scheduling verification
//////////////////////////////////////////////////////////////////////////////////

import fabric_frame_pkg::*;

`include "qos_defines.vh"

module switch_fabric_model_qos #(
    parameter   NUM_PORT                = 10,
    parameter   S                       = 10,
    parameter   W_MINI                  = 64,
    parameter   QOS_TAG_WIDTH           = 3,
    parameter   PACKET_ID_WIDTH         = 8
) (
    input   wire                                clk,
    input   wire                                reset,
    switch_data_if.slave_mp                     rx_data_if  [NUM_PORT],
    switch_metadata_if.slave_mp                 rx_meta_if  [NUM_PORT],
    switch_data_if.master_mp                    tx_data_if  [NUM_PORT],
    input   wire                                qos_enable
);

    //==========================================================================
    // Types
    //==========================================================================

    typedef struct {
        Fabric_frame_tr frame;
        logic [QOS_TAG_WIDTH-1:0] qos_tag;
        time arrival_time;
        int src_port;
    } qos_frame_t;

    //==========================================================================
    // Storage
    //==========================================================================

    mailbox frame_mailbox_in [NUM_PORT];
    mailbox frame_mailbox_out [NUM_PORT];

    // Priority queues per output port (one queue per QoS level)
    qos_frame_t priority_queues [NUM_PORT][`PRIORITY_LEVELS][$];

    // Scheduling state
    int current_qos_level [NUM_PORT];  // Current QoS being served per port
    int round_robin_idx [NUM_PORT];    // RR index within same QoS

    event frame_sent [NUM_PORT];

    //==========================================================================
    // Initialization
    //==========================================================================

    initial begin
        for (int p = 0; p < NUM_PORT; p++) begin
            current_qos_level[p] = 0;
            round_robin_idx[p] = 0;
        end
    end

    //==========================================================================
    // Input Monitors (Capture Frames with QoS Tags)
    //==========================================================================

    generate
        for (genvar i = 0; i < NUM_PORT; i++) begin : g_rx_mon
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
            ) u_fabric_monitor (
                .clk(clk),
                .sw_data_if(rx_data_if[i]),
                .sw_meta_if(rx_meta_if[i]),
                .frame_mailbox(temp_mailbox)
            );
        end
    endgenerate

    //==========================================================================
    // Output Drivers
    //==========================================================================

    generate
        for (genvar g = 0; g < NUM_PORT; g++) begin : g_tx_drv
            mailbox gen_to_driver_mailbox_temp;

            initial begin
                wait (frame_mailbox_out[g] != null);
                gen_to_driver_mailbox_temp = frame_mailbox_out[g];
            end

            fabric_driver #(
                .NUM_PORT(NUM_PORT),
                .DATA_WIDTH(W_MINI)
            ) u_fabric_driver (
                .clk(clk),
                .sw_data_if(tx_data_if[g]),
                .frame_mailbox(gen_to_driver_mailbox_temp),
                .frame_sent(frame_sent[g])
            );
        end
    endgenerate

    //==========================================================================
    // QoS-Aware Forwarding Logic
    //==========================================================================

    task forward_frame_qos(int src_port, Fabric_frame_tr frame, logic [2:0] qos_tag);
        qos_frame_t qos_pkt;

        qos_pkt.frame = frame.do_copy();
        qos_pkt.qos_tag = qos_tag;
        qos_pkt.arrival_time = $time;
        qos_pkt.src_port = src_port;

        // Enqueue to all destination ports based on dest mask
        for (int dst = 0; dst < NUM_PORT; dst++) begin
            if (frame.dest[dst]) begin
                int qos_idx = int'(qos_tag);
                priority_queues[dst][qos_idx].push_back(qos_pkt);
            end
        end
    endtask

    //==========================================================================
    // Priority Scheduler (Strict Priority with WFQ Fallback)
    //==========================================================================

    task schedule_transmission(int port);
        qos_frame_t selected_pkt;
        bit found = 1'b0;

        if (qos_enable) begin
            // Strict priority: serve highest non-empty queue
            for (int q = 0; q < `PRIORITY_LEVELS; q++) begin
                if (priority_queues[port][q].size() > 0) begin
                    selected_pkt = priority_queues[port][q].pop_front();
                    found = 1'b1;
                    current_qos_level[port] = q;
                    break;
                end
            end

        end else begin
            // QoS disabled: simple round-robin across all queues
            for (int attempts = 0; attempts < `PRIORITY_LEVELS; attempts++) begin
                int q = (current_qos_level[port] + attempts) % `PRIORITY_LEVELS;
                if (priority_queues[port][q].size() > 0) begin
                    selected_pkt = priority_queues[port][q].pop_front();
                    found = 1'b1;
                    current_qos_level[port] = (q + 1) % `PRIORITY_LEVELS;
                    break;
                end
            end
        end

        // Transmit selected packet
        if (found) begin
            frame_mailbox_out[port].put(selected_pkt.frame.do_copy());
        end
    endtask

    //==========================================================================
    // Main Forwarding Threads
    //==========================================================================

    generate
        for (genvar i = 0; i < NUM_PORT; i++) begin : g_fwd
            initial begin
                Fabric_frame_tr frame_in;
                logic [2:0] qos_tag;

                frame_mailbox_in[i] = new();
                frame_mailbox_out[i] = new();

                wait (frame_mailbox_in[i] != null);

                forever begin
                    frame_mailbox_in[i].get(frame_in);

                    // Extract QoS tag (from packet metadata or assume based on ID)
                    qos_tag = extract_qos_tag(frame_in);

                    forward_frame_qos(i, frame_in, qos_tag);
                end
            end
        end
    endgenerate

    //==========================================================================
    // Transmission Scheduler (Per-Port)
    //==========================================================================

    generate
        for (genvar p = 0; p < NUM_PORT; p++) begin : g_sched
            initial begin
                forever begin
                    @(posedge clk);

                    // Check if any queue has packets
                    bit has_packets = 1'b0;
                    for (int q = 0; q < `PRIORITY_LEVELS; q++) begin
                        if (priority_queues[p][q].size() > 0) begin
                            has_packets = 1'b1;
                            break;
                        end
                    end

                    if (has_packets) begin
                        schedule_transmission(p);
                    end
                end
            end
        end
    endgenerate

    //==========================================================================
    // Helper Functions
    //==========================================================================

    function logic [2:0] extract_qos_tag(Fabric_frame_tr frame);
        // Extract from packet data (implementation-specific)
        // For now, use packet ID modulo priority levels
        return frame.id % `PRIORITY_LEVELS;
    endfunction

endmodule

`default_nettype wire