`timescale 1ns / 1ps
`default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Company: IUST
// Engineer: Parham Soltani
//
// Create Date:  2025-11-25
// Module Name: qos_shaper
// Description: Token bucket traffic shaper for QoS flow control
//              Implements per-QoS-level rate limiting with burst tolerance
//////////////////////////////////////////////////////////////////////////////////

`include "qos_defines.vh"

module qos_shaper #(
    parameter QOS_LEVELS        = `PRIORITY_LEVELS,     // Number of QoS priority levels
    parameter QOS_TAG_WIDTH     = `QOS_TAG_WIDTH,       // Width of QoS tag
    parameter TOKEN_WIDTH       = 16,                    // Token counter width
    parameter BUCKET_DEPTH      = 65536,                 // Max tokens (burst size)
    parameter REFILL_RATE       = 1024,                  // Tokens added per cycle
    // DO NOT CHANGE
    parameter QOS_TAG_MAX       = 2**QOS_TAG_WIDTH
)(
    input  wire                         clk,
    input  wire                         reset,

    // Configuration interface (from microprocessor)
    input  wire                         cfg_enable,
    input  wire [TOKEN_WIDTH-1:0]       cfg_rate [QOS_LEVELS],        // Tokens/cycle per QoS
    input  wire [TOKEN_WIDTH-1:0]       cfg_burst [QOS_LEVELS],       // Max burst per QoS

    // Packet interface
    input  wire                         pkt_valid,
    input  wire [QOS_TAG_WIDTH-1:0]     pkt_qos_tag,
    input  wire [15:0]                  pkt_length,                    // Packet size in bytes
    output reg                          pkt_admit,                     // Allow transmission

    // Statistics
    output wire [31:0]                  shaped_pkts [QOS_LEVELS],      // Packets shaped
    output wire [31:0]                  dropped_pkts [QOS_LEVELS]      // Packets dropped
);

    //==========================================================================
    // Local Parameters
    //==========================================================================
    localparam TOKENS_PER_BYTE = 8;  // Token cost per byte

    //==========================================================================
    // Registers & Wires
    //==========================================================================

    // Token buckets (one per QoS level)
    reg [TOKEN_WIDTH-1:0]   token_count [QOS_LEVELS];
    reg [TOKEN_WIDTH-1:0]   refill_rate_reg [QOS_LEVELS];
    reg [TOKEN_WIDTH-1:0]   burst_limit_reg [QOS_LEVELS];

    // Statistics counters
    reg [31:0]              shaped_count [QOS_LEVELS];
    reg [31:0]              dropped_count [QOS_LEVELS];

    // Packet cost calculation
    wire [TOKEN_WIDTH-1:0]  pkt_cost;
    wire [QOS_TAG_WIDTH-1:0] safe_qos_tag;

    // Internal signals
    reg                     bucket_has_tokens;
    reg [TOKEN_WIDTH-1:0]   new_token_count;

    //==========================================================================
    // Assignments
    //==========================================================================

    assign pkt_cost = pkt_length[15:0] * TOKENS_PER_BYTE;

    // Clamp QoS tag to valid range
    assign safe_qos_tag = (pkt_qos_tag >= QOS_LEVELS) ?
                          QOS_TAG_WIDTH'(QOS_LEVELS-1) : pkt_qos_tag;

    // Export statistics
    generate
        for (genvar i = 0; i < QOS_LEVELS; i++) begin : g_stats_out
            assign shaped_pkts[i]  = shaped_count[i];
            assign dropped_pkts[i] = dropped_count[i];
        end
    endgenerate

    //==========================================================================
    // Initialization
    //==========================================================================

    initial begin
        for (int i = 0; i < QOS_LEVELS; i++) begin
            token_count[i] = BUCKET_DEPTH;
            shaped_count[i] = 0;
            dropped_count[i] = 0;
        end
        pkt_admit = 1'b0;
    end

    //==========================================================================
    // Configuration Update
    //==========================================================================

    always @(posedge clk) begin
        if (reset) begin
            for (int i = 0; i < QOS_LEVELS; i++) begin
                refill_rate_reg[i] <= REFILL_RATE;
                burst_limit_reg[i] <= BUCKET_DEPTH;
            end
        end else if (cfg_enable) begin
            for (int i = 0; i < QOS_LEVELS; i++) begin
                refill_rate_reg[i] <= cfg_rate[i];
                burst_limit_reg[i] <= cfg_burst[i];
            end
        end
    end

    //==========================================================================
    // Token Bucket Logic
    //==========================================================================

    always @(posedge clk) begin
        if (reset) begin
            for (int i = 0; i < QOS_LEVELS; i++) begin
                token_count[i] <= burst_limit_reg[i];
                shaped_count[i] <= 0;
                dropped_count[i] <= 0;
            end
            pkt_admit <= 1'b0;

        end else begin
            // Default: deny admission
            pkt_admit <= 1'b0;

            // Token refill (for all buckets every cycle)
            for (int i = 0; i < QOS_LEVELS; i++) begin
                if (token_count[i] < burst_limit_reg[i]) begin
                    new_token_count = token_count[i] + refill_rate_reg[i];
                    token_count[i] <= (new_token_count > burst_limit_reg[i]) ?
                                      burst_limit_reg[i] : new_token_count;
                end
            end

            // Packet admission check
            if (pkt_valid && cfg_enable) begin
                bucket_has_tokens = (token_count[safe_qos_tag] >= pkt_cost);

                if (bucket_has_tokens) begin
                    // Admit packet and consume tokens
                    pkt_admit <= 1'b1;
                    token_count[safe_qos_tag] <= token_count[safe_qos_tag] - pkt_cost;
                    shaped_count[safe_qos_tag] <= shaped_count[safe_qos_tag] + 1;

                end else begin
                    // Drop packet (insufficient tokens)
                    dropped_count[safe_qos_tag] <= dropped_count[safe_qos_tag] + 1;
                end

            end else if (pkt_valid && !cfg_enable) begin
                // Shaping disabled: admit all packets
                pkt_admit <= 1'b1;
            end
        end
    end

    //==========================================================================
    // Assertions (Simulation Only)
    //==========================================================================

    // synthesis translate_off
    property p_token_overflow;
        @(posedge clk) disable iff (reset)
        (token_count[safe_qos_tag] <= burst_limit_reg[safe_qos_tag]);
    endproperty

    assert property (p_token_overflow)
    else $error("[QoS_SHAPER] Token overflow in bucket %0d", safe_qos_tag);

    property p_valid_qos_tag;
        @(posedge clk) disable iff (reset)
        pkt_valid |-> (pkt_qos_tag < QOS_TAG_MAX);
    endproperty

    assert property (p_valid_qos_tag)
    else $warning("[QoS_SHAPER] Invalid QoS tag %0d (max: %0d)", pkt_qos_tag, QOS_TAG_MAX-1);
    // synthesis translate_on

endmodule

`default_nettype wire