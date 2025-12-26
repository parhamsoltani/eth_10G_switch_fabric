`timescale 1ns / 1ps
`default_nettype none

`include "qos_defines.vh"

module qos_shaper #(
    parameter QOS_LEVELS = `QOS_LEVELS,
    parameter QOS_TAG_WIDTH = `QOS_TAG_WIDTH,
    parameter TOKEN_WIDTH = `TOKEN_WIDTH,
    parameter BUCKET_DEPTH = `BUCKET_DEPTH,
    parameter REFILL_RATE = `REFILL_RATE
)(
    input  wire                         clk,
    input  wire                         reset,
    input  wire                         cfg_enable,
    input  wire [TOKEN_WIDTH-1:0]       cfg_rate [QOS_LEVELS],
    input  wire [TOKEN_WIDTH-1:0]       cfg_burst [QOS_LEVELS],
    input  wire                         pkt_valid,
    input  wire [QOS_TAG_WIDTH-1:0]     pkt_qos_tag,
    input  wire [15:0]                  pkt_length,
    output reg                          pkt_admit,
    output wire [31:0]                  shaped_pkts [QOS_LEVELS],
    output wire [31:0]                  dropped_pkts [QOS_LEVELS]
);

    localparam TOKENS_PER_BYTE = 8;

    reg [TOKEN_WIDTH-1:0] token_count [QOS_LEVELS];
    reg [TOKEN_WIDTH-1:0] refill_rate_reg [QOS_LEVELS];
    reg [TOKEN_WIDTH-1:0] burst_limit_reg [QOS_LEVELS];
    reg [31:0] shaped_count [QOS_LEVELS];
    reg [31:0] dropped_count [QOS_LEVELS];

    wire [TOKEN_WIDTH-1:0] pkt_cost;
    wire [QOS_TAG_WIDTH-1:0] safe_qos_tag;
    reg bucket_has_tokens;
    reg [TOKEN_WIDTH-1:0] new_token_count;

    assign pkt_cost = pkt_length * TOKENS_PER_BYTE;
    assign safe_qos_tag = (pkt_qos_tag >= QOS_LEVELS) ? 
                          (QOS_LEVELS - 1) : pkt_qos_tag;

    genvar i;
    generate
        for (i = 0; i < QOS_LEVELS; i = i + 1) begin : g_stats
            assign shaped_pkts[i] = shaped_count[i];
            assign dropped_pkts[i] = dropped_count[i];
        end
    endgenerate

    integer j;

    always @(posedge clk) begin
        if (reset) begin
            for (j = 0; j < QOS_LEVELS; j = j + 1) begin
                token_count[j] <= BUCKET_DEPTH;
                refill_rate_reg[j] <= REFILL_RATE;
                burst_limit_reg[j] <= BUCKET_DEPTH;
                shaped_count[j] <= 0;
                dropped_count[j] <= 0;
            end
            pkt_admit <= 1'b0;
        end else begin
            // Update config
            if (cfg_enable) begin
                for (j = 0; j < QOS_LEVELS; j = j + 1) begin
                    refill_rate_reg[j] <= cfg_rate[j];
                    burst_limit_reg[j] <= cfg_burst[j];
                end
            end

            // Refill tokens
            for (j = 0; j < QOS_LEVELS; j = j + 1) begin
                if (token_count[j] < burst_limit_reg[j]) begin
                    new_token_count = token_count[j] + refill_rate_reg[j];
                    token_count[j] <= (new_token_count > burst_limit_reg[j]) ?
                                      burst_limit_reg[j] : new_token_count;
                end
            end

            // Packet admission
            pkt_admit <= 1'b0;
            if (pkt_valid) begin
                if (!cfg_enable) begin
                    pkt_admit <= 1'b1;
                end else begin
                    bucket_has_tokens = (token_count[safe_qos_tag] >= pkt_cost);
                    if (bucket_has_tokens) begin
                        pkt_admit <= 1'b1;
                        token_count[safe_qos_tag] <= token_count[safe_qos_tag] - pkt_cost;
                        shaped_count[safe_qos_tag] <= shaped_count[safe_qos_tag] + 1;
                    end else begin
                        dropped_count[safe_qos_tag] <= dropped_count[safe_qos_tag] + 1;
                    end
                end
            end
        end
    end

endmodule

`default_nettype wire