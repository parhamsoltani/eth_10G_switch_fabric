`timescale 1ns / 1ps
`default_nettype none

module qos_checker #(
    parameter NUM_PORTS = 10,
    parameter ID_WIDTH = 10
);

    // Track packet transmission order
    typedef struct {
        logic [ID_WIDTH-1:0] id;
        logic [2:0]          qos;
        time                 time_sent;
    } qos_event_t;

    qos_event_t event_queue[$];

    // QoS violation counters
    int priority_inversions = 0;
    int starvation_events = 0;

    // Check for priority inversion
    task check_priority_order(
        input logic [ID_WIDTH-1:0] id,
        input logic [2:0] qos,
        input time current_time
    );
        qos_event_t evt;
        evt.id = id;
        evt.qos = qos;
        evt.time_sent = current_time;

        // Check against recent events
        foreach (event_queue[i]) begin
            if (event_queue[i].qos > qos) begin
                // Lower priority packet sent before this higher priority one
                real time_diff = current_time - event_queue[i].time_sent;

                if (time_diff < 1000) begin  // Within 1us
                    $warning("[QoS] Priority inversion: P%0d after P%0d (%.2f ns)",
                             qos, event_queue[i].qos, time_diff);
                    priority_inversions++;
                end
            end
        end

        // Add to queue (keep last 100 events)
        event_queue.push_back(evt);
        if (event_queue.size() > 100)
            event_queue.pop_front();
    endtask

    // Check for starvation (low priority not served for too long)
    task check_starvation(
        input logic [2:0] qos,
        input time current_time
    );
        static time last_p2_service = 0;

        if (qos == 3'b010) begin  // Priority 2 (low)
            last_p2_service = current_time;
        end else begin
            if (last_p2_service > 0) begin
                real time_since = current_time - last_p2_service;
                if (time_since > 10000) begin  // > 10us
                    $warning("[QoS] Starvation: P2 not served for %.2f us", time_since/1000);
                    starvation_events++;
                    last_p2_service = current_time;  // Reset
                end
            end
        end
    endtask

    // Final report
    task print_report();
        $display("\n========================================");
        $display("  QoS CHECKER REPORT");
        $display("========================================");
        $display("Priority inversions: %0d", priority_inversions);
        $display("Starvation events:   %0d", starvation_events);

        if (priority_inversions == 0 && starvation_events == 0) begin
            $display("\n*** QoS CHECKS PASSED ***");
        end else begin
            $display("\n*** QoS VIOLATIONS DETECTED ***");
        end
        $display("========================================\n");
    endtask

endmodule

`default_nettype wire