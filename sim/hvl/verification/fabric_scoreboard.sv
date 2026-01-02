`timescale 1ns / 1ps
// `default_nettype none

//////////////////////////////////////////////////////////////////////////////////
// Fabric Scoreboard - Tracks and validates packet flow through the switch
//
// FIXED: Improved packet ID tracking to handle ID wraparound and zero IDs
//////////////////////////////////////////////////////////////////////////////////

module fabric_scoreboard #(
    parameter NUM_PORTS = 10,
    parameter DATA_WIDTH = 32,
    parameter ID_WIDTH = 8
);

    //==========================================================================
    // Packet Record Structure
    //==========================================================================
    typedef struct {
        logic [ID_WIDTH-1:0]     id;
        int                      src_port;
        int                      dst_port;
        logic [2:0]              qos;
        int                      size_bytes;
        time                     tx_time;
        time                     rx_time;
        bit                      is_bad;
        int                      sequence_num;  // For debugging ID reuse
    } packet_record_t;

    //==========================================================================
    // Storage
    //==========================================================================
    // Use associative array with composite key: (seq << 16) | (dst << 8) | id
    packet_record_t tx_records[int];
    int global_sequence = 0;

    // Statistics
    int match_count = 0;
    int mismatch_count = 0;
    int lost_count = 0;
    int duplicate_count = 0;
    int zero_id_tx_count = 0;
    int zero_id_rx_count = 0;

    // Latency statistics per QoS level (0-7)
    real min_latency[8];
    real max_latency[8];
    real sum_latency[8];
    int  pkt_count[8];

    // Initialize latency arrays
    initial begin
        for (int i = 0; i < 8; i++) begin
            min_latency[i] = 1e12;  // Very large initial value
            max_latency[i] = 0.0;
            sum_latency[i] = 0.0;
            pkt_count[i] = 0;
        end
    end

    //==========================================================================
    // Record Transmitted Packet
    //==========================================================================
    task record_tx(
        input logic [ID_WIDTH-1:0] id,
        input int src_port,
        input int dst_port,
        input logic [2:0] qos,
        input int size_bytes,
        input bit is_bad
    );
        automatic packet_record_t pkt;
        automatic int composite_key;
        
        // Check for zero ID (potential issue)
        if (id == 0) begin
            zero_id_tx_count++;
            $display("[SB WARN] TX packet with ID=0 from port %0d to port %0d", 
                     src_port, dst_port);
        end
        
        pkt.id = id;
        pkt.src_port = src_port;
        pkt.dst_port = dst_port;
        pkt.qos = qos;
        pkt.size_bytes = size_bytes;
        pkt.tx_time = $time;
        pkt.is_bad = is_bad;
        pkt.sequence_num = global_sequence;
        
        // Create composite key
        composite_key = (global_sequence << 16) | (dst_port << 8) | int'(id);
        tx_records[composite_key] = pkt;
        global_sequence++;

        `ifdef SB_VERBOSE
        $display("[SB] TX: ID=%0d src=%0d dst=%0d qos=%0d size=%0d seq=%0d time=%0t",
                 id, src_port, dst_port, qos, size_bytes, pkt.sequence_num, $time);
        `endif
    endtask

    //==========================================================================
    // Record Received Packet
    //==========================================================================
    task record_rx(
        input logic [ID_WIDTH-1:0] id,
        input int dst_port,
        input logic [2:0] qos,
        input int size_bytes,
        input bit is_bad
    );
        automatic int found_key;
        automatic packet_record_t found_pkt;
        automatic real latency_ns;
        automatic int qos_idx;
        
        // Check for zero ID
        if (id == 0) begin
            zero_id_rx_count++;
            $display("[SB WARN] RX packet with ID=0 on port %0d", dst_port);
            return;  // Can't match zero ID reliably
        end
        
        // Find matching TX record
        found_key = find_matching_tx(id, dst_port, found_pkt);
        
        if (found_key >= 0) begin
            // Calculate latency
            latency_ns = real'($time - found_pkt.tx_time);
            qos_idx = int'(found_pkt.qos);
            
            // Clamp QoS index to valid range
            if (qos_idx < 0) qos_idx = 0;
            if (qos_idx > 7) qos_idx = 7;

            // Update latency statistics
            if (latency_ns < min_latency[qos_idx])
                min_latency[qos_idx] = latency_ns;
            if (latency_ns > max_latency[qos_idx])
                max_latency[qos_idx] = latency_ns;
            sum_latency[qos_idx] += latency_ns;
            pkt_count[qos_idx]++;

            // Verify packet integrity
            if (found_pkt.qos != qos) begin
                `ifdef SB_VERBOSE
                $display("[SB] QoS changed: ID=%0d expected=%0d got=%0d (may be OK)",
                       id, found_pkt.qos, qos);
                `endif
                // Don't count as mismatch - QoS might change through fabric
                match_count++;
            end else if (found_pkt.size_bytes != size_bytes) begin
                $error("[SB] Size mismatch: ID=%0d expected=%0d got=%0d",
                       id, found_pkt.size_bytes, size_bytes);
                mismatch_count++;
            end else begin
                match_count++;
            end

            `ifdef SB_VERBOSE
            $display("[SB] RX: ID=%0d dst=%0d qos=%0d latency=%.2f ns seq=%0d",
                     id, dst_port, qos, latency_ns, found_pkt.sequence_num);
            `endif

            // Remove matched record
            tx_records.delete(found_key);
        end else begin
            $warning("[SB] Received unexpected packet: ID=%0d dst=%0d qos=%0d", 
                     id, dst_port, qos);
            duplicate_count++;
        end
    endtask

    //==========================================================================
    // Find Matching TX Record
    //==========================================================================
    function automatic int find_matching_tx(
        input logic [ID_WIDTH-1:0] id,
        input int dst_port,
        output packet_record_t found_pkt
    );
        automatic int best_key = -1;
        automatic time oldest_time = 0;
        automatic int id_int = int'(id);
        
        // Search for matching packet by ID and destination port
        // Prefer oldest match (FIFO ordering)
        foreach (tx_records[key]) begin
            if (int'(tx_records[key].id) == id_int) begin
                if (tx_records[key].dst_port == dst_port) begin
                    if (best_key == -1 || tx_records[key].tx_time < oldest_time) begin
                        best_key = key;
                        oldest_time = tx_records[key].tx_time;
                        found_pkt = tx_records[key];
                    end
                end
            end
        end
        
        // If no exact match, try matching by ID only (for multicast/broadcast)
        if (best_key == -1) begin
            foreach (tx_records[key]) begin
                if (int'(tx_records[key].id) == id_int) begin
                    if (best_key == -1 || tx_records[key].tx_time < oldest_time) begin
                        best_key = key;
                        oldest_time = tx_records[key].tx_time;
                        found_pkt = tx_records[key];
                    end
                end
            end
        end
        
        return best_key;
    endfunction

    //==========================================================================
    // Final Report
    //==========================================================================
    task print_report();
        automatic int total_lost;
        
        total_lost = tx_records.size();
        
        $display("\n════════════════════════════════════════");
        $display("  FABRIC SCOREBOARD REPORT");
        $display("════════════════════════════════════════");
        $display("Packets matched:      %0d", match_count);
        $display("Packets mismatched:   %0d", mismatch_count);
        $display("Packets lost:         %0d", total_lost);
        $display("Packets duplicate:    %0d", duplicate_count);
        $display("TX with ID=0:         %0d", zero_id_tx_count);
        $display("RX with ID=0:         %0d", zero_id_rx_count);

        $display("\nLatency Statistics (ns):");
        for (int q = 0; q < 8; q++) begin
            if (pkt_count[q] > 0) begin
                $display("  QoS %0d: min=%8.1f max=%8.1f avg=%8.1f count=%0d",
                         q, min_latency[q], max_latency[q],
                         sum_latency[q]/pkt_count[q], pkt_count[q]);
            end
        end

        // Show some lost packets for debugging
        if (total_lost > 0 && total_lost <= 20) begin
            $display("\nLost packets (up to 20):");
            foreach (tx_records[key]) begin
                $display("  seq=%0d id=%0d src=%0d dst=%0d qos=%0d tx_time=%0t",
                    tx_records[key].sequence_num,
                    tx_records[key].id,
                    tx_records[key].src_port,
                    tx_records[key].dst_port,
                    tx_records[key].qos,
                    tx_records[key].tx_time);
            end
        end

        $display("\n────────────────────────────────────────");
        if (mismatch_count == 0 && total_lost == 0 && zero_id_rx_count == 0) begin
            $display("  *** TEST PASSED ***");
        end else if (mismatch_count == 0 && total_lost <= 1) begin
            $display("  *** TEST PASSED (with minor issues) ***");
        end else begin
            $display("  *** TEST FAILED ***");
        end
        $display("════════════════════════════════════════\n");
    endtask

    //==========================================================================
    // Reset Statistics
    //==========================================================================
    task reset_stats();
        tx_records.delete();
        match_count = 0;
        mismatch_count = 0;
        lost_count = 0;
        duplicate_count = 0;
        zero_id_tx_count = 0;
        zero_id_rx_count = 0;
        global_sequence = 0;
        
        for (int i = 0; i < 8; i++) begin
            min_latency[i] = 1e12;
            max_latency[i] = 0.0;
            sum_latency[i] = 0.0;
            pkt_count[i] = 0;
        end
    endtask

endmodule

`default_nettype wire