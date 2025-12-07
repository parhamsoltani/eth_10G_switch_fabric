`timescale 1ns / 1ps

class qos_latency_tracker;

    typedef struct {
        time tx_time;
        int src_port;
        int dst_port;
        logic [2:0] qos;
    } packet_record_t;

    packet_record_t pending_packets [int];
    real total_latency [8];
    int packet_count [8];
    real avg_latency [8];
    real min_latency [8];
    real max_latency [8];

    function new();
        for (int i = 0; i < 8; i++) begin
            total_latency[i] = 0.0;
            packet_count[i] = 0;
            avg_latency[i] = 0.0;
            min_latency[i] = 1e9;
            max_latency[i] = 0.0;
        end
    endfunction

    function void record_tx(int id, int src, int dst, logic [2:0] qos);
        packet_record_t rec;
        rec.tx_time = $time;
        rec.src_port = src;
        rec.dst_port = dst;
        rec.qos = qos;
        pending_packets[id] = rec;
    endfunction

    function void record_rx(int id, int dst, logic [2:0] qos);
        if (pending_packets.exists(id)) begin
            automatic packet_record_t rec = pending_packets[id];
            automatic real latency = real'($time - rec.tx_time);
            automatic int qos_idx = int'(qos);

            total_latency[qos_idx] += latency;
            packet_count[qos_idx]++;

            if (latency < min_latency[qos_idx]) min_latency[qos_idx] = latency;
            if (latency > max_latency[qos_idx]) max_latency[qos_idx] = latency;

            pending_packets.delete(id);
        end
    endfunction

    function void calculate_stats();
        for (int i = 0; i < 8; i++) begin
            if (packet_count[i] > 0) begin
                avg_latency[i] = total_latency[i] / real'(packet_count[i]);
            end
        end
    endfunction

    function void print_summary();
        calculate_stats();
        $display("\n═══ QoS Latency Summary ═══");
        for (int i = 0; i < 8; i++) begin
            if (packet_count[i] > 0) begin
                $display("  Priority %0d: %5d pkts, avg=%.1fns, min=%.1fns, max=%.1fns",
                    i, packet_count[i], avg_latency[i], min_latency[i], max_latency[i]);
            end
        end
    endfunction

endclass