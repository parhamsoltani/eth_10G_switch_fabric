`timescale 1ns / 1ps
// `default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Company: IUST
// Engineer: Parham Soltani
//
// Create Date:  2025-11-25
// Module Name: qos_checker_enhanced
// Description: QoS verification with latency/jitter tracking
//////////////////////////////////////////////////////////////////////////////////

`include "qos_defines.vh"

import fabric_frame_pkg::*;

module qos_checker_enhanced #(
    parameter NUM_PORTS = `NUM_PORT,
    parameter ID_WIDTH = 10,
    parameter QOS_LEVELS = 3
);

    typedef struct {
        logic [ID_WIDTH-1:0] id;
        logic [2:0]          qos;
        time                 tx_time;
        time                 rx_time;
        int                  src_port;
        int                  dst_port;
    } qos_event_t;

    qos_event_t event_log[$];

    // Statistics per QoS level
    real min_latency[QOS_LEVELS];
    real max_latency[QOS_LEVELS];
    real sum_latency[QOS_LEVELS];
    real sum_latency_sq[QOS_LEVELS];  // For jitter calculation
    int  pkt_count[QOS_LEVELS];

    int priority_inversions = 0;
    int starvation_events = 0;

    initial begin
        for (int q = 0; q < QOS_LEVELS; q++) begin
            min_latency[q] = 1000000.0;
            max_latency[q] = 0.0;
            sum_latency[q] = 0.0;
            sum_latency_sq[q] = 0.0;
            pkt_count[q] = 0;
        end
    end

    // Record packet transmission
    task record_tx(
        input logic [ID_WIDTH-1:0] id,
        input int src_port,
        input int dst_port,
        input logic [2:0] qos
    );
        automatic qos_event_t evt;
        evt.id = id;
        evt.qos = qos;
        evt.tx_time = $time;
        evt.src_port = src_port;
        evt.dst_port = dst_port;
        evt.rx_time = 0;  // Will be filled on RX

        event_log.push_back(evt);

        $display("[QoS] TX: ID=%0d src=%0d→dst=%0d qos=%0d time=%0t",
                 id, src_port, dst_port, qos, $time);
    endtask

    // Record packet reception and calculate latency
    task record_rx(
        input logic [ID_WIDTH-1:0] id,
        input int dst_port,
        input logic [2:0] qos
    );
        automatic real latency_ns;
        automatic int qos_idx;
        automatic int found_idx;
        
        found_idx = -1;
        
        foreach (event_log[i]) begin
            if (event_log[i].id == id && event_log[i].dst_port == dst_port) begin
                found_idx = i;
                break;
            end
        end
        
        if (found_idx >= 0) begin
            latency_ns = real'($time - event_log[found_idx].tx_time);
            qos_idx = int'(qos[1:0]);

            // Update statistics
            if (latency_ns < min_latency[qos_idx])
                min_latency[qos_idx] = latency_ns;
            if (latency_ns > max_latency[qos_idx])
                max_latency[qos_idx] = latency_ns;

            sum_latency[qos_idx] += latency_ns;
            sum_latency_sq[qos_idx] += latency_ns * latency_ns;
            pkt_count[qos_idx]++;

            // Check priority inversion
            check_priority_order(id, qos, $time);

            $display("[QoS] RX: ID=%0d qos=%0d latency=%.2f ns",
                     id, qos, latency_ns);

            event_log.delete(found_idx);
        end
    endtask

    // Priority inversion detection
    task check_priority_order(
        input logic [ID_WIDTH-1:0] id,
        input logic [2:0] qos,
        input time current_time
    );
        automatic real time_diff;
        
        foreach (event_log[i]) begin
            if (event_log[i].qos > qos && event_log[i].rx_time == 0) begin
                time_diff = real'(current_time - event_log[i].tx_time);
                if (time_diff < 1000) begin  // Within 1us
                    $warning("[QoS] Priority inversion: P%0d after P%0d (%.2f ns)",
                             qos, event_log[i].qos, time_diff);
                    priority_inversions++;
                end
            end
        end
    endtask

    // Final report
    task print_report();
        automatic real avg;
        automatic real variance;
        automatic real jitter;
        
        $display("\n========================================");
        $display("  QoS CHECKER REPORT");
        $display("========================================");

        for (int q = 0; q < QOS_LEVELS; q++) begin
            if (pkt_count[q] > 0) begin
                avg = sum_latency[q] / pkt_count[q];
                variance = (sum_latency_sq[q] / pkt_count[q]) - (avg * avg);
                jitter = $sqrt(variance);

                $display("QoS Level %0d:", q);
                $display("  Packets:  %0d", pkt_count[q]);
                $display("  Min Lat:  %.2f ns", min_latency[q]);
                $display("  Max Lat:  %.2f ns", max_latency[q]);
                $display("  Avg Lat:  %.2f ns", avg);
                $display("  Jitter:   %.2f ns", jitter);
            end
        end

        $display("\nViolations:");
        $display("  Priority inversions: %0d", priority_inversions);
        $display("  Starvation events:   %0d", starvation_events);

        if (priority_inversions == 0 && starvation_events == 0)
            $display("\n*** QoS CHECKS PASSED ***");
        else
            $display("\n*** QoS VIOLATIONS DETECTED ***");

        $display("========================================\n");
    endtask

endmodule

`default_nettype wire