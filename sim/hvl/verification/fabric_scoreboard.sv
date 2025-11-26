`timescale 1ns / 1ps
`default_nettype none

module fabric_scoreboard #(
    parameter NUM_PORTS = 10,
    parameter DATA_WIDTH = 32,
    parameter ID_WIDTH = 10
);

    typedef struct {
        logic [ID_WIDTH-1:0]     id;
        int                      src_port;
        int                      dst_port;
        logic [2:0]              qos;
        int                      size_bytes;
        time                     tx_time;
        time                     rx_time;
        bit                      is_bad;
    } packet_record_t;

    packet_record_t tx_packets[$];  // Transmitted packets
    packet_record_t rx_packets[$];  // Received packets

    int match_count = 0;
    int mismatch_count = 0;
    int lost_count = 0;
    int duplicate_count = 0;

    // Latency statistics per QoS
    real min_latency[3] = '{1000000.0, 1000000.0, 1000000.0};
    real max_latency[3] = '{0.0, 0.0, 0.0};
    real sum_latency[3] = '{0.0, 0.0, 0.0};
    int  pkt_count[3] = '{0, 0, 0};

    // Record transmitted packet
    task record_tx(
        input logic [ID_WIDTH-1:0] id,
        input int src_port,
        input int dst_port,
        input logic [2:0] qos,
        input int size_bytes,
        input bit is_bad
    );
        packet_record_t pkt;
        pkt.id = id;
        pkt.src_port = src_port;
        pkt.dst_port = dst_port;
        pkt.qos = qos;
        pkt.size_bytes = size_bytes;
        pkt.tx_time = $time;
        pkt.is_bad = is_bad;
        tx_packets.push_back(pkt);

        $display("[SB] TX: ID=%0d src=%0d dst=%0d qos=%0d size=%0d time=%0t",
                 id, src_port, dst_port, qos, size_bytes, $time);
    endtask

    // Record received packet
    task record_rx(
        input logic [ID_WIDTH-1:0] id,
        input int dst_port,
        input logic [2:0] qos,
        input int size_bytes,
        input bit is_bad
    );
        packet_record_t pkt;
        pkt.id = id;
        pkt.dst_port = dst_port;
        pkt.qos = qos;
        pkt.size_bytes = size_bytes;
        pkt.rx_time = $time;
        pkt.is_bad = is_bad;
        rx_packets.push_back(pkt);

        // Find matching TX packet
        automatic bit found = 0;
        for (int i = 0; i < tx_packets.size(); i++) begin
            if (tx_packets[i].id == id && tx_packets[i].dst_port == dst_port) begin
                found = 1;

                // Calculate latency
                real latency_ns = pkt.rx_time - tx_packets[i].tx_time;
                int qos_idx = qos[1:0];

                if (latency_ns < min_latency[qos_idx])
                    min_latency[qos_idx] = latency_ns;
                if (latency_ns > max_latency[qos_idx])
                    max_latency[qos_idx] = latency_ns;
                sum_latency[qos_idx] += latency_ns;
                pkt_count[qos_idx]++;

                // Verify packet integrity
                if (tx_packets[i].qos != qos) begin
                    $error("[SB] QoS mismatch: ID=%0d expected=%0d got=%0d",
                           id, tx_packets[i].qos, qos);
                    mismatch_count++;
                end else if (tx_packets[i].size_bytes != size_bytes) begin
                    $error("[SB] Size mismatch: ID=%0d expected=%0d got=%0d",
                           id, tx_packets[i].size_bytes, size_bytes);
                    mismatch_count++;
                end else begin
                    match_count++;
                end

                $display("[SB] RX: ID=%0d dst=%0d qos=%0d latency=%.2f ns",
                         id, dst_port, qos, latency_ns);

                tx_packets.delete(i);
                break;
            end
        end

        if (!found) begin
            $warning("[SB] Received unexpected packet: ID=%0d dst=%0d", id, dst_port);
            duplicate_count++;
        end
    endtask

    // Final report
    task print_report();
        $display("\n========================================");
        $display("  FABRIC SCOREBOARD REPORT");
        $display("========================================");
        $display("Packets matched:    %0d", match_count);
        $display("Packets mismatched: %0d", mismatch_count);
        $display("Packets lost:       %0d", tx_packets.size());
        $display("Packets duplicate:  %0d", duplicate_count);

        $display("\nLatency Statistics (ns):");
        for (int q = 0; q < 3; q++) begin
            if (pkt_count[q] > 0) begin
                $display("  QoS %0d: min=%.2f max=%.2f avg=%.2f count=%0d",
                         q, min_latency[q], max_latency[q],
                         sum_latency[q]/pkt_count[q], pkt_count[q]);
            end
        end

        if (mismatch_count == 0 && tx_packets.size() == 0) begin
            $display("\n*** TEST PASSED ***");
        end else begin
            $display("\n*** TEST FAILED ***");
        end
        $display("========================================\n");
    endtask

endmodule

`default_nettype wire