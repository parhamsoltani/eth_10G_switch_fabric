`timescale 1ns / 1ps
`include "qos_defines.vh"

module qos_scheduler #(
    parameter NUM_INPUTS = `NUM_PORTS,
    parameter QOS_LEVELS = `QOS_LEVELS,
    parameter QOS_TAG_WIDTH = `QOS_TAG_WIDTH,
    parameter ENABLE_AGING = `SCHEDULER_ENABLE_AGING,
    parameter AGING_THRESHOLD = `SCHEDULER_AGING_THRESHOLD
)(
    input  wire clk,
    input  wire reset,

    input  wire [NUM_INPUTS-1:0] request,
    input  wire [QOS_TAG_WIDTH-1:0] qos_tag [NUM_INPUTS],

    output logic [NUM_INPUTS-1:0] grant,
    output logic grant_valid
);

    //═══════════════════════════════════════════════════════════════════════════
    // Local Parameters
    //═══════════════════════════════════════════════════════════════════════════

    localparam AGE_COUNTER_WIDTH = $clog2(AGING_THRESHOLD + 1);

    //═══════════════════════════════════════════════════════════════════════════
    // Internal Signals
    //═══════════════════════════════════════════════════════════════════════════

    // Per-priority-level request vectors
    logic [NUM_INPUTS-1:0] priority_requests [QOS_LEVELS];
    logic [QOS_LEVELS-1:0] priority_present;

    // Aging mechanism
    logic [AGE_COUNTER_WIDTH-1:0] age_counter [NUM_INPUTS];
    logic [NUM_INPUTS-1:0] aged_boosted;

    // Selected priority level (highest active)
    logic [QOS_TAG_WIDTH-1:0] selected_priority;
    logic [$clog2(QOS_LEVELS)-1:0] selected_priority_idx;

    // Per-priority grant signals
    logic [NUM_INPUTS-1:0] priority_grant [QOS_LEVELS];
    logic [QOS_LEVELS-1:0] priority_grant_valid;

    //═══════════════════════════════════════════════════════════════════════════
    // Priority Classification (Full 8-level support)
    //═══════════════════════════════════════════════════════════════════════════

    always_comb begin
        // Initialize all priority request vectors to zero
        for (int p = 0; p < QOS_LEVELS; p++) begin
            priority_requests[p] = '0;
        end

        // Classify each input to its priority level
        for (int i = 0; i < NUM_INPUTS; i++) begin
            if (request[i]) begin
                if (qos_tag[i] < QOS_LEVELS) begin
                    priority_requests[qos_tag[i]][i] = 1'b1;
                end else begin
                    // Out-of-range → lowest priority
                    priority_requests[0][i] = 1'b1;
                end
            end
        end

        // Apply aging boost to highest priority level
        if (ENABLE_AGING) begin
            priority_requests[QOS_LEVELS-1] = priority_requests[QOS_LEVELS-1] | aged_boosted;
        end

        // Determine which priority levels have pending requests
        for (int p = 0; p < QOS_LEVELS; p++) begin
            priority_present[p] = |priority_requests[p];
        end
    end

    //═══════════════════════════════════════════════════════════════════════════
    // Priority Selection (Strict Priority - Highest First)
    //═══════════════════════════════════════════════════════════════════════════

    always_comb begin
        selected_priority_idx = '0;
        selected_priority = '0;

        // Find highest priority level with pending requests
        // Priority 7 (highest) checked first, down to 0 (lowest)
        for (int p = QOS_LEVELS - 1; p >= 0; p--) begin
            if (priority_present[p]) begin
                selected_priority_idx = p[$clog2(QOS_LEVELS)-1:0];
                selected_priority = p[QOS_TAG_WIDTH-1:0];
                break;
            end
        end
    end

    //═══════════════════════════════════════════════════════════════════════════
    // Round-Robin Arbiters (One per Priority Level)
    //═══════════════════════════════════════════════════════════════════════════

    generate
        for (genvar p = 0; p < QOS_LEVELS; p++) begin : gen_rr_arbiters
            round_robin_arbiter #(
                .NUM_INPUTS(NUM_INPUTS)
            ) rr_arb (
                .clk(clk),
                .reset(reset),
                .request(priority_requests[p]),
                .enable(priority_present[p]),
                .grant(priority_grant[p]),
                .grant_valid(priority_grant_valid[p])
            );
        end
    endgenerate

    //═══════════════════════════════════════════════════════════════════════════
    // Grant Selection Based on Highest Active Priority
    //═══════════════════════════════════════════════════════════════════════════

    always_comb begin
        grant = '0;
        grant_valid = 1'b0;

        if (|priority_present) begin
            grant = priority_grant[selected_priority_idx];
            grant_valid = priority_grant_valid[selected_priority_idx];
        end
    end

    //═══════════════════════════════════════════════════════════════════════════
    // Aging Mechanism (Anti-Starvation)
    //═══════════════════════════════════════════════════════════════════════════

    generate
        if (ENABLE_AGING) begin : gen_aging

            always_ff @(posedge clk) begin
                if (reset) begin
                    for (int i = 0; i < NUM_INPUTS; i++) begin
                        age_counter[i] <= '0;
                    end
                    aged_boosted <= '0;
                end else begin
                    aged_boosted <= '0;

                    for (int i = 0; i < NUM_INPUTS; i++) begin
                        if (request[i] && !grant[i]) begin
                            if (age_counter[i] < AGING_THRESHOLD) begin
                                age_counter[i] <= age_counter[i] + 1'b1;
                            end else begin
                                aged_boosted[i] <= 1'b1;
                            end
                        end else begin
                            age_counter[i] <= '0;
                        end
                    end
                end
            end

        end else begin : gen_no_aging
            always_comb begin
                aged_boosted = '0;
            end
            // Initialize age counters to avoid warnings
            initial begin
                for (int i = 0; i < NUM_INPUTS; i++) begin
                    age_counter[i] = '0;
                end
            end
        end
    endgenerate

    //═══════════════════════════════════════════════════════════════════════════
    // Assertions
    //═══════════════════════════════════════════════════════════════════════════

    `ifndef SYNTHESIS
    `ifdef SIMULATION

    // Only one grant at a time
    property one_hot_grant;
        @(posedge clk) disable iff (reset)
        grant_valid |-> $onehot(grant);
    endproperty
    assert property (one_hot_grant) else
        $error("[QoS_SCHED] Multiple grants issued: grant=%b", grant);

    // Grant only when requested
    property grant_when_request;
        @(posedge clk) disable iff (reset)
        grant_valid |-> ((grant & request) == grant);
    endproperty
    assert property (grant_when_request) else
        $error("[QoS_SCHED] Grant without request: grant=%b, request=%b", grant, request);

    // Highest priority always served first
    property strict_priority;
        @(posedge clk) disable iff (reset)
        grant_valid |-> (grant == priority_grant[selected_priority_idx]);
    endproperty
    assert property (strict_priority) else
        $error("[QoS_SCHED] Strict priority violated");

    `endif
    `endif

endmodule

`default_nettype wire