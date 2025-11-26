`timescale 1ns / 1ps
`default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 2025
// Design Name: Round-Robin Arbiter
// Module Name: round_robin_arbiter
// Project Name: Ethernet Switch with QoS
// Target Devices: Xilinx UltraScale+
// Description:
//   Round-robin arbiter with mask-based prioritization
//   - Grants requests in circular order based on pointer position
//   - Single-cycle latency
//   - Synthesizable priority encoder implementation
//
//////////////////////////////////////////////////////////////////////////////////

module round_robin_arbiter #(
    parameter NUM_INPUTS = 8
)(
    input  wire clk,
    input  wire reset,
    input  wire [NUM_INPUTS-1:0] request,
    input  wire enable,
    output logic [NUM_INPUTS-1:0] grant,
    output logic grant_valid
);

    //═══════════════════════════════════════════════════════════════════════════
    // Internal Signals
    //═══════════════════════════════════════════════════════════════════════════

    logic [$clog2(NUM_INPUTS)-1:0] rr_pointer;
    logic [NUM_INPUTS-1:0] masked_request;
    logic [NUM_INPUTS-1:0] unmasked_grant;
    logic [NUM_INPUTS-1:0] masked_grant;
    logic [NUM_INPUTS-1:0] selected_grant;

    //═══════════════════════════════════════════════════════════════════════════
    // Rotate request vector to prioritize inputs after pointer
    //═══════════════════════════════════════════════════════════════════════════

    always_comb begin
        // Mask out requests at or before pointer
        for (int i = 0; i < NUM_INPUTS; i++) begin
            if (unsigned'(i) > unsigned'(rr_pointer)) begin
                masked_request[i] = request[i];
            end else begin
                masked_request[i] = 1'b0;
            end
        end
    end

    //═══════════════════════════════════════════════════════════════════════════
    // Priority Encoder for Masked Requests (Higher Indices First)
    //═══════════════════════════════════════════════════════════════════════════

    always_comb begin
        masked_grant = '0;

        // Find first '1' in masked_request, starting from LSB
        // This is synthesizable as a priority encoder
        for (int i = 0; i < NUM_INPUTS; i++) begin
            if (masked_request[i] && (masked_grant == '0)) begin
                masked_grant[i] = 1'b1;
            end
        end
    end

    //═══════════════════════════════════════════════════════════════════════════
    // Priority Encoder for Unmasked Requests (Fallback)
    //═══════════════════════════════════════════════════════════════════════════

    always_comb begin
        unmasked_grant = '0;

        // Find first '1' in request, starting from LSB
        for (int i = 0; i < NUM_INPUTS; i++) begin
            if (request[i] && (unmasked_grant == '0)) begin
                unmasked_grant[i] = 1'b1;
            end
        end
    end

    //═══════════════════════════════════════════════════════════════════════════
    // Select Grant (Prefer Masked, Fallback to Unmasked)
    //═══════════════════════════════════════════════════════════════════════════

    always_comb begin
        if (|masked_request) begin
            // Use masked grant if any masked requests exist
            selected_grant = masked_grant;
        end else begin
            // Wrap around to beginning if no masked requests
            selected_grant = unmasked_grant;
        end
    end

    //═══════════════════════════════════════════════════════════════════════════
    // Output Assignment
    //═══════════════════════════════════════════════════════════════════════════

    always_comb begin
        grant = selected_grant;
        grant_valid = enable && (|request);
    end

    //═══════════════════════════════════════════════════════════════════════════
    // Update Pointer on Grant
    //═══════════════════════════════════════════════════════════════════════════

    always_ff @(posedge clk) begin
        if (reset) begin
            rr_pointer <= '0;
        end else if (grant_valid) begin
            // Convert one-hot grant to binary index
            // This synthesizes to a simple encoder
            rr_pointer <= '0;
            for (int i = 0; i < NUM_INPUTS; i++) begin
                if (grant[i]) begin
                    rr_pointer <= i[$clog2(NUM_INPUTS)-1:0];
                end
            end
        end
    end

    //═══════════════════════════════════════════════════════════════════════════
    // Assertions
    //═══════════════════════════════════════════════════════════════════════════

    `ifndef SYNTHESIS
    `ifdef SIMULATION

    // Grant must be one-hot when valid
    property grant_one_hot;
        @(posedge clk) disable iff (reset)
        grant_valid |-> $onehot(grant);
    endproperty
    assert property (grant_one_hot) else
        $error("[RR_ARB] Grant not one-hot: grant=%b", grant);

    // Grant must correspond to a request
    property grant_matches_request;
        @(posedge clk) disable iff (reset)
        grant_valid |-> ((grant & request) == grant);
    endproperty
    assert property (grant_matches_request) else
        $error("[RR_ARB] Grant without request: grant=%b, request=%b", grant, request);

    // No grant when disabled
    property no_grant_when_disabled;
        @(posedge clk) disable iff (reset)
        !enable |-> !grant_valid;
    endproperty
    assert property (no_grant_when_disabled) else
        $error("[RR_ARB] Grant issued while disabled");

    `endif
    `endif

endmodule

`default_nettype wire