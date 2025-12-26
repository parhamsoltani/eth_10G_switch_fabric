`timescale 1ns / 1ps
`default_nettype none

`include "qos_defines.vh"

module qos_aware_arbiter #(
    parameter NUM_PORT = 10,
    parameter QOS_TAG_WIDTH = `QOS_TAG_WIDTH,
    parameter S = 10,
    parameter S_LOG = $clog2(S)
)(
    input wire clk,
    input wire rst_n,
    input wire [NUM_PORT-1:0] req_i,
    input wire [QOS_TAG_WIDTH-1:0] qos_tag_i [NUM_PORT],
    output reg [NUM_PORT-1:0] grant_o,
    output reg grant_valid_o
);

    localparam QOS_LEVELS = `QOS_LEVELS;
    
    // Extract weights from define
    logic [7:0] WEIGHTS [QOS_LEVELS];
    initial begin
        WEIGHTS = `QOS_WEIGHTS;
    end

    reg [7:0] weight_counter [QOS_LEVELS];
    reg [S_LOG-1:0] current_ptr;

    wire [NUM_PORT-1:0] delayed_req [S];
    delayed_regs #(
        .WIDTH(NUM_PORT), 
        .NUM_DELAY(S)
    ) u_req_delay (
        .clk(clk),
        .signal_in(req_i),
        .delayed_signal(delayed_req)
    );

    integer i, p;
    integer qos_level;
    integer total_weight;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_ptr <= 0;
            grant_o <= 0;
            grant_valid_o <= 0;
            for (i = 0; i < QOS_LEVELS; i = i + 1) begin
                weight_counter[i] <= WEIGHTS[i];
            end
        end else begin
            grant_o <= 0;
            grant_valid_o <= 0;
            
            // Try to grant from each port starting at current_ptr
            for (p = 0; p < NUM_PORT; p = p + 1) begin
                if (!grant_valid_o) begin  // Only grant once per cycle
                    qos_level = qos_tag_i[(current_ptr + p) % NUM_PORT];
                    if (qos_level >= QOS_LEVELS) qos_level = QOS_LEVELS - 1;
                    
                    if (delayed_req[0][(current_ptr + p) % NUM_PORT] && 
                        weight_counter[qos_level] > 0) begin
                        grant_o[(current_ptr + p) % NUM_PORT] <= 1;
                        grant_valid_o <= 1;
                        weight_counter[qos_level] <= weight_counter[qos_level] - 1;
                        current_ptr <= (current_ptr + p + 1) % NUM_PORT;
                    end
                end
            end
            
            // Check if all weights exhausted
            total_weight = 0;
            for (i = 0; i < QOS_LEVELS; i = i + 1) begin
                total_weight = total_weight + weight_counter[i];
            end
            
            // Reset counters when all exhausted
            if (total_weight == 0) begin
                for (i = 0; i < QOS_LEVELS; i = i + 1) begin
                    weight_counter[i] <= WEIGHTS[i];
                end
            end
        end
    end

endmodule

`default_nettype wire