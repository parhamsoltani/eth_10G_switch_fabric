`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// QoS Latency Tracker - Simple version for basic latency measurements
//////////////////////////////////////////////////////////////////////////////////

class qos_latency_tracker_simple;
    // Per-priority statistics
    longint total_latency[8];   // Accumulated latency per priority (in ps)
    int pkt_count[8];           // Packet count per priority
    longint min_latency[8];     // Minimum latency per priority
    longint max_latency[8];     // Maximum latency per priority
    
    // TX timestamp storage - indexed by packet ID
    time tx_timestamps[256];
    bit tx_valid[256];
    int tx_qos[256];
    
    function new();
        for (int i = 0; i < 8; i++) begin
            total_latency[i] = 0;
            pkt_count[i] = 0;
            min_latency[i] = {64{1'b1}};  // Max value
            max_latency[i] = 0;
        end
        for (int i = 0; i < 256; i++) begin
            tx_valid[i] = 0;
        end
    endfunction
    
    // Record TX event
    function void record_tx(int pkt_id, int src_port, int dst_port, int qos);
        if (pkt_id > 0 && pkt_id < 256) begin
            tx_timestamps[pkt_id] = $time;
            tx_valid[pkt_id] = 1;
            tx_qos[pkt_id] = qos;
        end
    endfunction
    
    // Record RX event and calculate latency
    function void record_rx(int pkt_id, int rx_port, int qos);
        automatic longint latency;
        automatic int prio_idx;
        
        if (pkt_id > 0 && pkt_id < 256 && tx_valid[pkt_id]) begin
            latency = $time - tx_timestamps[pkt_id];
            prio_idx = tx_qos[pkt_id];  // Use TX QoS for consistency
            
            if (prio_idx >= 0 && prio_idx < 8) begin
                total_latency[prio_idx] += latency;
                pkt_count[prio_idx]++;
                
                if (latency < min_latency[prio_idx])
                    min_latency[prio_idx] = latency;
                if (latency > max_latency[prio_idx])
                    max_latency[prio_idx] = latency;
            end
            
            // Clear entry
            tx_valid[pkt_id] = 0;
        end
    endfunction
    
    // Get average latency for a priority level (returns ns)
    function real get_avg_latency(int prio_level);
        if (prio_level < 0 || prio_level >= 8) return 0.0;
        if (pkt_count[prio_level] == 0) return 0.0;
        // Convert from ps to ns
        return (real'(total_latency[prio_level]) / real'(pkt_count[prio_level])) / 1000.0;
    endfunction
    
    // Get packet count for a priority level
    function int get_pkt_count(int prio_level);
        if (prio_level < 0 || prio_level >= 8) return 0;
        return pkt_count[prio_level];
    endfunction
    
    // Get min latency for a priority level (returns ns)
    function real get_min_latency(int prio_level);
        if (prio_level < 0 || prio_level >= 8) return 0.0;
        if (pkt_count[prio_level] == 0) return 0.0;
        return real'(min_latency[prio_level]) / 1000.0;
    endfunction
    
    // Get max latency for a priority level (returns ns)
    function real get_max_latency(int prio_level);
        if (prio_level < 0 || prio_level >= 8) return 0.0;
        if (pkt_count[prio_level] == 0) return 0.0;
        return real'(max_latency[prio_level]) / 1000.0;
    endfunction
    
    // Print summary
    function void print_summary();
        $display("\n═══ QoS Latency Summary ═══");
        for (int i = 0; i < 8; i++) begin
            if (pkt_count[i] > 0) begin
                $display("  Priority %0d: %5d pkts, avg=%7.1fns, min=%7.1fns, max=%7.1fns",
                    i, pkt_count[i],
                    get_avg_latency(i),
                    get_min_latency(i),
                    get_max_latency(i));
            end
        end
    endfunction
    
    // Reset all statistics
    function void reset();
        for (int i = 0; i < 8; i++) begin
            total_latency[i] = 0;
            pkt_count[i] = 0;
            min_latency[i] = {64{1'b1}};
            max_latency[i] = 0;
        end
        for (int i = 0; i < 256; i++) begin
            tx_valid[i] = 0;
        end
    endfunction
    
endclass