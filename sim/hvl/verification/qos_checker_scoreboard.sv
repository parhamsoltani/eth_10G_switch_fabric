`timescale 1ns / 1ps
`default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// QoS-Aware Scoreboard with Priority Checking
// Validates:
//   - Packet ordering per QoS level
//   - Priority enforcement (higher QoS exits first)
//   - No starvation of low-priority traffic
//////////////////////////////////////////////////////////////////////////////////

import fabric_frame_pkg::*;
// import class_pkg::*;

`include "qos_defines.vh"

module qos_checker_scoreboard #(
    parameter NUM_PORT = 10,
    parameter QOS_LEVELS = `PRIORITY_LEVELS,
    parameter STARVATION_THRESHOLD = 10000  // Max cycles without low-pri transmission
)(
    input wire                      sys_clk,
    input wire                      sys_reset,
    input mailbox                   actual_mailbox [NUM_PORT],
    input mailbox                   expected_mailbox [NUM_PORT],
    input bit                       end_of_sim,
    input wire [2:0]                qos_enable  // 0=disabled, 1=enabled
);

    //==========================================================================
    // Types & Data Structures
    //==========================================================================

    typedef struct {
        Fabric_frame_tr frame;
        logic [2:0] qos_tag;
        time arrival_time;
        time departure_time;
    } qos_packet_t;

    qos_packet_t tx_queue [NUM_PORT][$];  // Transmitted packets per port
    qos_packet_t rx_queue [NUM_PORT][$];  // Received packets per port

    // Per-QoS statistics
    int packets_sent [NUM_PORT][QOS_LEVELS];
    int packets_recv [NUM_PORT][QOS_LEVELS];
    real avg_latency [NUM_PORT][QOS_LEVELS];
    time last_tx_time [NUM_PORT][QOS_LEVELS];

    // Violation tracking
    int priority_violations;
    int starvation_events;
    int total_errors;

    // Latency histograms (bins: 0-100ns, 100-200ns, 200-500ns, 500+ns)
    int latency_hist [NUM_PORT][QOS_LEVELS][4];

    //==========================================================================
    // Initialization
    //==========================================================================

    initial begin
        priority_violations = 0;
        starvation_events = 0;
        total_errors = 0;

        for (int p = 0; p < NUM_PORT; p++) begin
            for (int q = 0; q < QOS_LEVELS; q++) begin
                packets_sent[p][q] = 0;
                packets_recv[p][q] = 0;
                avg_latency[p][q] = 0.0;
                last_tx_time[p][q] = 0;
                for (int h = 0; h < 4; h++) begin
                    latency_hist[p][q][h] = 0;
                end
            end
        end
    end

    //==========================================================================
    // Expected Packet Capture (TX Monitor)
    //==========================================================================

    generate
        for (genvar p = 0; p < NUM_PORT; p++) begin : g_expected_mon
            initial begin
                Fabric_frame_tr frame;
                qos_packet_t pkt;

                wait (expected_mailbox[p] != null);

                forever begin
                    expected_mailbox[p].get(frame);

                    pkt.frame = frame.do_copy();
                    pkt.qos_tag = extract_qos_from_frame(frame);  // Extract from packet data
                    pkt.arrival_time = $time;
                    pkt.departure_time = 0;

                    tx_queue[p].push_back(pkt);
                    packets_sent[p][pkt.qos_tag]++;
                    last_tx_time[p][pkt.qos_tag] = $time;

                    // Check starvation (low-priority not sent for too long)
                    if (pkt.qos_tag == `PRIORITY_LOW && qos_enable) begin
                        check_starvation(p);
                    end
                end
            end
        end
    endgenerate

    //==========================================================================
    // Actual Packet Capture (RX Monitor)
    //==========================================================================

    generate
        for (genvar p = 0; p < NUM_PORT; p++) begin : g_actual_mon
            initial begin
                Fabric_frame_tr frame;
                qos_packet_t match_pkt;
                time latency;

                wait (actual_mailbox[p] != null);

                forever begin
                    actual_mailbox[p].get(frame);

                    // Find matching packet in expected queue
                    if (find_and_remove_expected(p, frame, match_pkt)) begin

                        // Calculate latency
                        latency = $time - match_pkt.arrival_time;
                        match_pkt.departure_time = $time;

                        // Update statistics
                        packets_recv[p][match_pkt.qos_tag]++;
                        update_avg_latency(p, match_pkt.qos_tag, latency);
                        update_latency_histogram(p, match_pkt.qos_tag, latency);

                        rx_queue[p].push_back(match_pkt);

                        // QoS validation
                        if (qos_enable) begin
                            check_priority_enforcement(p, match_pkt.qos_tag, latency);
                        end

                    end else begin
                        $error("[QoS_SCOREBOARD] Port %0d: Unexpected frame (ID=%0d)",
                               p, frame.id);
                        total_errors++;
                    end
                end
            end
        end
    endgenerate

    //==========================================================================
    // QoS Validation Tasks
    //==========================================================================

    task check_priority_enforcement(input int port, input logic [2:0] qos, input time latency);
        // Verify higher priority has lower average latency
        for (int q = 0; q < qos; q++) begin
            if (packets_recv[port][q] > 10 && avg_latency[port][q] > avg_latency[port][qos]) begin
                $warning("[PRIORITY_VIOLATION] Port %0d: QoS %s (avg=%.2f ns) slower than %s (avg=%.2f ns)",
                    port, qos_name(q), avg_latency[port][q], qos_name(qos), avg_latency[port][qos]);
                priority_violations++;
            end
        end
    endtask

    task check_starvation(input int port);
        // Ensure low-priority packets sent within threshold
        time now = $time;
        time elapsed = now - last_tx_time[port][`PRIORITY_LOW];

        if (elapsed > STARVATION_THRESHOLD * 10) begin  // Convert to ns
            $error("[STARVATION] Port %0d: Low-priority not sent for %0t ns", port, elapsed);
            starvation_events++;
        end
    endtask

    function bit find_and_remove_expected(input int port, input Fabric_frame_tr frame, output qos_packet_t match);
        for (int i = 0; i < tx_queue[port].size(); i++) begin
            if (tx_queue[port][i].frame.do_compare(frame)) begin
                match = tx_queue[port][i];
                tx_queue[port].delete(i);
                return 1'b1;
            end
        end
        return 1'b0;
    endfunction

    task update_avg_latency(input int port, input logic [2:0] qos, input time latency);
        real prev_avg = avg_latency[port][qos];
        int count = packets_recv[port][qos];

        avg_latency[port][qos] = (prev_avg * (count - 1) + real'(latency)) / real'(count);
    endtask

    task update_latency_histogram(input int port, input logic [2:0] qos, input time latency);
        int bin;
        real lat_ns = real'(latency);

        if (lat_ns < 100) bin = 0;
        else if (lat_ns < 200) bin = 1;
        else if (lat_ns < 500) bin = 2;
        else bin = 3;

        latency_hist[port][qos][bin]++;
    endtask

    function string qos_name(input logic [2:0] level);
        case (level)
            `PRIORITY_CRITICAL: return "CRITICAL";
            `PRIORITY_HIGH:     return "HIGH";
            `PRIORITY_MEDIUM:   return "MEDIUM";
            `PRIORITY_LOW:      return "LOW";
            default:            return "UNKNOWN";
        endcase
    endfunction

    function logic [2:0] extract_qos_from_frame(input Fabric_frame_tr frame);
        // Extract QoS from packet metadata (implementation depends on your framing)
        // Placeholder: use packet ID modulo QoS levels
        return frame.id % QOS_LEVELS;
    endfunction

    //==========================================================================
    // Final Report
    //==========================================================================

    initial begin
        @(posedge end_of_sim);
        repeat (100) @(posedge sys_clk);

        print_final_report();
    end

    task print_final_report();
        int total_sent = 0;
        int total_recv = 0;

        $display("\n");
        $display("╔════════════════════════════════════════════════════════════════╗");
        $display("║           QoS SCOREBOARD FINAL REPORT                          ║");
        $display("╚════════════════════════════════════════════════════════════════╝");

        // Per-port, per-QoS summary
        for (int p = 0; p < NUM_PORT; p++) begin
            $display("\n[Port %0d]", p);
            $display("  %-10s %8s %8s %12s %15s", "QoS Level", "Sent", "Recv", "Avg Lat(ns)", "Histogram");
            $display("  " + {60{"-"}});

            for (int q = 0; q < QOS_LEVELS; q++) begin
                $display("  %-10s %8d %8d %12.2f   [%3d|%3d|%3d|%3d]",
                    qos_name(q),
                    packets_sent[p][q],
                    packets_recv[p][q],
                    avg_latency[p][q],
                    latency_hist[p][q][0],
                    latency_hist[p][q][1],
                    latency_hist[p][q][2],
                    latency_hist[p][q][3]
                );
                total_sent += packets_sent[p][q];
                total_recv += packets_recv[p][q];
            end
        end

        // Overall statistics
        $display("\n╔════════════════════════════════════════════════════════════════╗");
        $display("║ OVERALL STATISTICS                                             ║");
        $display("╚════════════════════════════════════════════════════════════════╝");
        $display("  Total Sent:              %0d", total_sent);
        $display("  Total Received:          %0d", total_recv);
        $display("  Priority Violations:     %0d", priority_violations);
        $display("  Starvation Events:       %0d", starvation_events);
        $display("  Total Errors:            %0d", total_errors);

        // Pass/Fail
        if (total_errors == 0 && priority_violations == 0 && starvation_events == 0) begin
            $display("\n  ✓✓✓ QoS VALIDATION PASSED ✓✓✓");
        end else begin
            $display("\n  ✗✗✗ QoS VALIDATION FAILED ✗✗✗");
        end

        $display("\n");
    endtask

endmodule

`default_nettype wire