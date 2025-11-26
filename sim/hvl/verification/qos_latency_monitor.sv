`timescale 1ns / 1ps
`default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// QoS Latency Tracking Monitor
// Measures end-to-end latency per QoS class with statistical analysis
//////////////////////////////////////////////////////////////////////////////////

`ifndef QOS_LATENCY_MONITOR_SV
`define QOS_LATENCY_MONITOR_SV

`include "qos_defines.vh"

class qos_latency_tracker;

    //==========================================================================
    // Data Types
    //==========================================================================

    typedef struct {
        bit [15:0] id;
        int src_port;
        int dst_port;
        logic [2:0] qos_tag;
        time tx_time;
        time rx_time;
        time latency;
        bit matched;
    } latency_record_t;

    //==========================================================================
    // Storage
    //==========================================================================

    latency_record_t records[$];  // All packet records

    // Per-QoS statistics
    real avg_latency [`PRIORITY_LEVELS];
    real std_dev_latency [`PRIORITY_LEVELS];
    time min_latency [`PRIORITY_LEVELS];
    time max_latency [`PRIORITY_LEVELS];
    int packet_count [`PRIORITY_LEVELS];

    // Jitter tracking (inter-packet arrival variation)
    time prev_rx_time [`PRIORITY_LEVELS];
    real avg_jitter [`PRIORITY_LEVELS];

    // Percentile tracking (for SLA validation)
    time latency_p50 [`PRIORITY_LEVELS];  // Median
    time latency_p95 [`PRIORITY_LEVELS];
    time latency_p99 [`PRIORITY_LEVELS];

    //==========================================================================
    // Constructor
    //==========================================================================

    function new();
        for (int i = 0; i < `PRIORITY_LEVELS; i++) begin
            avg_latency[i] = 0.0;
            std_dev_latency[i] = 0.0;
            min_latency[i] = time'(32'hFFFFFFFF);
            max_latency[i] = 0;
            packet_count[i] = 0;
            prev_rx_time[i] = 0;
            avg_jitter[i] = 0.0;
        end
    endfunction

    //==========================================================================
    // Record Transmission
    //==========================================================================

    function void record_tx(bit [15:0] id, int src, int dst, logic [2:0] qos);
        latency_record_t rec;
        rec.id = id;
        rec.src_port = src;
        rec.dst_port = dst;
        rec.qos_tag = qos;
        rec.tx_time = $time;
        rec.rx_time = 0;
        rec.latency = 0;
        rec.matched = 1'b0;

        records.push_back(rec);
    endfunction

    //==========================================================================
    // Record Reception
    //==========================================================================

    function void record_rx(bit [15:0] id, int port, logic [2:0] qos);
        foreach (records[i]) begin
            if (records[i].id == id && records[i].dst_port == port && !records[i].matched) begin
                records[i].rx_time = $time;
                records[i].latency = $time - records[i].tx_time;
                records[i].matched = 1'b1;

                // Clamp QoS to valid range
                int qos_idx = (qos >= `PRIORITY_LEVELS) ? `PRIORITY_LEVELS-1 : int'(qos);

                update_statistics(qos_idx, records[i].latency);

                return;
            end
        end

        $warning("[LATENCY_MONITOR] Unmatched RX: ID=%0d, Port=%0d", id, port);
    endfunction

    //==========================================================================
    // Statistics Update
    //==========================================================================

    function void update_statistics(int qos_idx, time lat);
        int n = packet_count[qos_idx];
        real lat_ns = real'(lat);

        // Update count
        packet_count[qos_idx]++;
        n++;

        // Running average
        real prev_avg = avg_latency[qos_idx];
        avg_latency[qos_idx] = (prev_avg * (n-1) + lat_ns) / real'(n);

        // Standard deviation (Welford's online algorithm)
        if (n > 1) begin
            real delta = lat_ns - prev_avg;
            real delta2 = lat_ns - avg_latency[qos_idx];
            std_dev_latency[qos_idx] = std_dev_latency[qos_idx] + delta * delta2;
        end

        // Min/Max
        if (lat < min_latency[qos_idx]) min_latency[qos_idx] = lat;
        if (lat > max_latency[qos_idx]) max_latency[qos_idx] = lat;

        // Jitter (variation between consecutive packets)
        if (prev_rx_time[qos_idx] != 0) begin
            time inter_arrival = $time - prev_rx_time[qos_idx];
            real jitter = $abs(real'(inter_arrival) - avg_jitter[qos_idx]);
            avg_jitter[qos_idx] = (avg_jitter[qos_idx] * (n-2) + jitter) / real'(n-1);
        end
        prev_rx_time[qos_idx] = $time;
    endfunction

    //==========================================================================
    // Percentile Calculation
    //==========================================================================

    function void compute_percentiles();
        time sorted_latencies [`PRIORITY_LEVELS][$];

        // Group latencies by QoS
        foreach (records[i]) begin
            if (records[i].matched) begin
                int q = int'(records[i].qos_tag);
                if (q < `PRIORITY_LEVELS) begin
                    sorted_latencies[q].push_back(records[i].latency);
                end
            end
        end

        // Sort and extract percentiles
        for (int q = 0; q < `PRIORITY_LEVELS; q++) begin
            if (sorted_latencies[q].size() == 0) continue;

            sorted_latencies[q].sort();
            int n = sorted_latencies[q].size();

            latency_p50[q] = sorted_latencies[q][n * 50 / 100];
            latency_p95[q] = sorted_latencies[q][n * 95 / 100];
            latency_p99[q] = sorted_latencies[q][n * 99 / 100];
        end
    endfunction

    //==========================================================================
    // Final Summary Report
    //==========================================================================

    function void print_summary();
        compute_percentiles();

        $display("\n");
        $display("╔══════════════════════════════════════════════════════════════════════════╗");
        $display("║                   QoS LATENCY ANALYSIS SUMMARY                           ║");
        $display("╚══════════════════════════════════════════════════════════════════════════╝");

        $display("\n%-12s %8s %10s %10s %10s %10s %10s %10s",
            "QoS Level", "Count", "Min(ns)", "Avg(ns)", "Max(ns)", "StdDev", "P95(ns)", "Jitter");
        $display({80{"-"}});

        for (int q = 0; q < `PRIORITY_LEVELS; q++) begin
            if (packet_count[q] > 0) begin
                real std_dev = (packet_count[q] > 1) ?
                    $sqrt(std_dev_latency[q] / real'(packet_count[q]-1)) : 0.0;

                $display("%-12s %8d %10.2f %10.2f %10.2f %10.2f %10.2f %10.2f",
                    qos_name(q),
                    packet_count[q],
                    real'(min_latency[q]),
                    avg_latency[q],
                    real'(max_latency[q]),
                    std_dev,
                    real'(latency_p95[q]),
                    avg_jitter[q]
                );
            end
        end

        $display({80{"="}});

        // Priority ordering validation
        if (packet_count[`PRIORITY_CRITICAL] > 0 && packet_count[`PRIORITY_LOW] > 0) begin
            if (avg_latency[`PRIORITY_CRITICAL] < avg_latency[`PRIORITY_LOW]) begin
                $display("\n  ✓ Priority enforcement verified:");
                $display("    CRITICAL avg: %.2f ns  <  LOW avg: %.2f ns",
                    avg_latency[`PRIORITY_CRITICAL], avg_latency[`PRIORITY_LOW]);
            end else begin
                $display("\n  ✗ PRIORITY VIOLATION DETECTED:");
                $display("    CRITICAL avg: %.2f ns  >=  LOW avg: %.2f ns",
                    avg_latency[`PRIORITY_CRITICAL], avg_latency[`PRIORITY_LOW]);
            end
        end

        // Latency distribution
        $display("\n[Latency Distribution]");
        for (int q = 0; q < `PRIORITY_LEVELS; q++) begin
            if (packet_count[q] > 0) begin
                $display("  %s:", qos_name(q));
                $display("    0-100ns:   %5d pkts (%5.1f%%)", latency_hist[0][q][0],
                    100.0*latency_hist[0][q][0]/packet_count[q]);
                $display("    100-200ns: %5d pkts (%5.1f%%)", latency_hist[0][q][1],
                    100.0*latency_hist[0][q][1]/packet_count[q]);
                $display("    200-500ns: %5d pkts (%5.1f%%)", latency_hist[0][q][2],
                    100.0*latency_hist[0][q][2]/packet_count[q]);
                $display("    500+ns:    %5d pkts (%5.1f%%)", latency_hist[0][q][3],
                    100.0*latency_hist[0][q][3]/packet_count[q]);
            end
        end

        $display("\n");
    endtask

    function string qos_name(int level);
        case (level)
            0: return "CRITICAL";
            1: return "HIGH";
            2: return "MEDIUM";
            3: return "LOW";
            default: return $sformatf("QoS_%0d", level);
        endcase
    endfunction

endclass

`endif // QOS_LATENCY_MONITOR_SV

`default_nettype wire