`timescale 1ns / 1ps
// `default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 2025
// Design Name: QoS Scheduler
// Module Name: qos_scheduler
// Project Name: Ethernet Switch with QoS
// Target Devices: Xilinx UltraScale+
// Description:
//   Strict priority scheduler with round-robin arbitration within priority levels
//   - CRITICAL (3) > HIGH (2) > MEDIUM (1) > LOW (0)
//   - Round-robin among requests of same priority level
//   - Single-cycle latency for grant decision
//   - Starvation prevention through aging mechanism (optional)
//
// Dependencies: qos_defines.vh, round_robin_arbiter.sv
//
// CHANGES FROM ORIGINAL:
//   - Moved round_robin_arbiter to separate file
//   - Fixed aging counter type (removed automatic variables from clocked block)
//   - Added bounds checking for QoS tags
//   - Improved synthesis attributes
//
//////////////////////////////////////////////////////////////////////////////////

`include "qos_defines.vh"

module qos_scheduler #(
    parameter NUM_INPUTS = `NUM_PORTS,
    parameter QOS_LEVELS = `QOS_LEVELS,
    parameter QOS_TAG_WIDTH = `QOS_TAG_WIDTH,
    parameter ENABLE_AGING = `SCHEDULER_ENABLE_AGING,           // Enable anti-starvation aging(=0)
    parameter AGING_THRESHOLD = `SCHEDULER_AGING_THRESHOLD      // Cycles before priority boost(=1000)
)(
    input  wire clk,
    input  wire reset,

    // Request interface
    input  wire [NUM_INPUTS-1:0] request,
    input  wire [QOS_TAG_WIDTH-1:0] qos_tag [NUM_INPUTS],

    // Grant interface (one-hot encoding)
    output logic [NUM_INPUTS-1:0] grant,
    output logic grant_valid
);

    //═══════════════════════════════════════════════════════════════════════════
    // Local Parameters
    //═══════════════════════════════════════════════════════════════════════════

    localparam PRIORITY_WIDTH = QOS_TAG_WIDTH;
    localparam AGE_COUNTER_WIDTH = $clog2(AGING_THRESHOLD + 1);

    //═══════════════════════════════════════════════════════════════════════════
    // Internal Signals
    //═══════════════════════════════════════════════════════════════════════════

    // Priority classification
    logic [NUM_INPUTS-1:0] critical_requests;
    logic [NUM_INPUTS-1:0] high_requests;
    logic [NUM_INPUTS-1:0] medium_requests;
    logic [NUM_INPUTS-1:0] low_requests;

    logic critical_present;
    logic high_present;
    logic medium_present;
    logic low_present;

    // Aging mechanism (anti-starvation)
    logic [AGE_COUNTER_WIDTH-1:0] age_counter [NUM_INPUTS];
    logic [NUM_INPUTS-1:0] aged_boosted;  // Inputs that aged out and got boosted

    // Selected priority level
    logic [PRIORITY_WIDTH-1:0] selected_priority;

    // Intermediate grant signals
    logic [NUM_INPUTS-1:0] grant_critical;
    logic [NUM_INPUTS-1:0] grant_high;
    logic [NUM_INPUTS-1:0] grant_medium;
    logic [NUM_INPUTS-1:0] grant_low;

    // Grant valid signals per priority
    logic grant_valid_critical;
    logic grant_valid_high;
    logic grant_valid_medium;
    logic grant_valid_low;



    //═══════════════════════════════════════════════════════════════════════════════
    // Priority Classification (8 levels → 4 queues)
    //═══════════════════════════════════════════════════════════════════════════════

    always_comb begin
        critical_requests = '0;
        high_requests     = '0;
        medium_requests   = '0;
        low_requests      = '0;

        for (int i = 0; i < NUM_INPUTS; i++) begin
            if (request[i]) begin
                // Bounds check
                if (qos_tag[i] >= QOS_LEVELS) begin
                    low_requests[i] = 1'b1;  // Out-of-range → LOW
                end else begin
                    // Map 8 priority levels to 4 queues
                    // Levels 7,6 → CRITICAL
                    // Levels 5,4 → HIGH
                    // Levels 3,2 → MEDIUM
                    // Levels 1,0 → LOW
                    case (qos_tag[i][2:1])  // Use top 2 bits
                        2'd3:    critical_requests[i] = 1'b1;  // Levels 6-7
                        2'd2:    high_requests[i]     = 1'b1;  // Levels 4-5
                        2'd1:    medium_requests[i]   = 1'b1;  // Levels 2-3
                        2'd0:    low_requests[i]      = 1'b1;  // Levels 0-1
                        default: low_requests[i]      = 1'b1;
                    endcase
                end
            end
        end

        // Apply aging boost
        if (ENABLE_AGING) begin
            critical_requests = critical_requests | aged_boosted;
        end

        critical_present = |critical_requests;
        high_present     = |high_requests;
        medium_present   = |medium_requests;
        low_present      = |low_requests;
    end


    //═══════════════════════════════════════════════════════════════════════════
    // Priority Selection (Strict Priority)
    //═══════════════════════════════════════════════════════════════════════════

    always_comb begin
        if (critical_present) begin
            selected_priority = `PRIORITY_CRITICAL;
        end else if (high_present) begin
            selected_priority = `PRIORITY_HIGH;
        end else if (medium_present) begin
            selected_priority = `PRIORITY_MEDIUM;
        end else if (low_present) begin
            selected_priority = `PRIORITY_LOW;
        end else begin
            selected_priority = `PRIORITY_LOW;  // Default (no effect when no requests)
        end
    end

    //═══════════════════════════════════════════════════════════════════════════
    // Round-Robin Arbiter for Each Priority Level
    //═══════════════════════════════════════════════════════════════════════════

    // Critical priority round-robin
    round_robin_arbiter #(
        .NUM_INPUTS(NUM_INPUTS)
    ) rr_critical (
        .clk(clk),
        .reset(reset),
        .request(critical_requests),
        .enable(critical_present),
        .grant(grant_critical),
        .grant_valid(grant_valid_critical)
    );

    // High priority round-robin
    round_robin_arbiter #(
        .NUM_INPUTS(NUM_INPUTS)
    ) rr_high (
        .clk(clk),
        .reset(reset),
        .request(high_requests),
        .enable(high_present),
        .grant(grant_high),
        .grant_valid(grant_valid_high)
    );

    // Medium priority round-robin
    round_robin_arbiter #(
        .NUM_INPUTS(NUM_INPUTS)
    ) rr_medium (
        .clk(clk),
        .reset(reset),
        .request(medium_requests),
        .enable(medium_present),
        .grant(grant_medium),
        .grant_valid(grant_valid_medium)
    );

    // Low priority round-robin
    round_robin_arbiter #(
        .NUM_INPUTS(NUM_INPUTS)
    ) rr_low (
        .clk(clk),
        .reset(reset),
        .request(low_requests),
        .enable(low_present),
        .grant(grant_low),
        .grant_valid(grant_valid_low)
    );

    //═══════════════════════════════════════════════════════════════════════════
    // Grant Selection Based on Priority
    //═══════════════════════════════════════════════════════════════════════════

    always_comb begin
        case (selected_priority)
            `PRIORITY_CRITICAL: begin
                grant = grant_critical;
                grant_valid = grant_valid_critical;
            end
            `PRIORITY_HIGH: begin
                grant = grant_high;
                grant_valid = grant_valid_high;
            end
            `PRIORITY_MEDIUM: begin
                grant = grant_medium;
                grant_valid = grant_valid_medium;
            end
            `PRIORITY_LOW: begin
                grant = grant_low;
                grant_valid = grant_valid_low;
            end
            default: begin
                grant = '0;
                grant_valid = 1'b0;
            end
        endcase
    end

    //═══════════════════════════════════════════════════════════════════════════
    // Aging Mechanism (Anti-Starvation)
    //═══════════════════════════════════════════════════════════════════════════

    generate
        if (ENABLE_AGING) begin : gen_aging

            // Aging counter update logic
            always_ff @(posedge clk) begin
                if (reset) begin
                    for (int i = 0; i < NUM_INPUTS; i++) begin
                        age_counter[i] <= '0;
                    end
                    aged_boosted <= '0;
                end else begin
                    // Clear aged boost flags
                    aged_boosted <= '0;

                    for (int i = 0; i < NUM_INPUTS; i++) begin
                        if (request[i] && !grant[i]) begin
                            // Request pending but not granted
                            if (age_counter[i] < AGING_THRESHOLD) begin
                                age_counter[i] <= age_counter[i] + 1'b1;
                            end else begin
                                // Aged out - boost to critical priority next cycle
                                aged_boosted[i] <= 1'b1;
                            end
                        end else if (grant[i]) begin
                            // Reset age counter when granted
                            age_counter[i] <= '0;
                        end else if (!request[i]) begin
                            // Reset age counter when no request
                            age_counter[i] <= '0;
                        end
                    end
                end
            end

        end else begin : gen_no_aging
            // Aging disabled - tie off signals
            always_comb begin
                aged_boosted = '0;
            end

            // Prevent warnings about unused signals
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
        $error("[QoS_SCHED] Multiple grants issued simultaneously: grant=%b", grant);

    // Grant only when requested
    property grant_when_request;
        @(posedge clk) disable iff (reset)
        grant_valid |-> ((grant & request) == grant);
    endproperty
    assert property (grant_when_request) else
        $error("[QoS_SCHED] Grant issued without request: grant=%b, request=%b", grant, request);

    // No grant when no request
    property no_grant_when_idle;
        @(posedge clk) disable iff (reset)
        (request == 0) |-> !grant_valid;
    endproperty
    assert property (no_grant_when_idle) else
        $error("[QoS_SCHED] Grant issued when idle");

    // Verify strict priority (critical always served first)
    property critical_has_priority;
        @(posedge clk) disable iff (reset)
        (critical_present && grant_valid) |-> (grant == grant_critical);
    endproperty
    assert property (critical_has_priority) else
        $error("[QoS_SCHED] Critical priority not served first");

    // Verify aging boosts work
    generate
        if (ENABLE_AGING) begin : gen_aging_check
            property aging_works;
                @(posedge clk) disable iff (reset)
                (|aged_boosted) |-> critical_present;
            endproperty
            assert property (aging_works) else
                $error("[QoS_SCHED] Aged boost not applied to critical requests");
        end
    endgenerate

    `endif
    `endif

endmodule

`default_nettype wire