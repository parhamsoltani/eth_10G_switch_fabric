`timescale 1ns / 1ps
`default_nettype none

module qos_aware_arbiter #(
    parameter NUM_PORT = 10,
    parameter QOS_TAG_WIDTH = 3,
    parameter S = 10,
    parameter S_LOG = $clog2(S)
)(
    input wire clk,
    input wire rst_n,
    input wire [NUM_PORT-1:0] req_i,  // Requests from ports
    input wire [QOS_TAG_WIDTH-1:0] qos_tag_i [NUM_PORT],  // QoS tags per request
    output reg [NUM_PORT-1:0] grant_o,  // Grants
    output reg grant_valid_o
);

    // Weights from qos_defines_enhanced.vh (as in  example: 50,30,20 scaled)
    localparam bit [7:0] WEIGHTS [`QOS_LEVELS-1:0] = `QOS_WEIGHTS;

    reg [7:0] weight_counter [`QOS_LEVELS-1:0];  // Counters for weighted shares
    reg [S_LOG-1:0] current_ptr;  // Current RR pointer

    // Delayed regs for multi-cycle arbitration (from des_main_2.txt)
    wire [NUM_PORT-1:0] delayed_req [S];
    delayed_regs #(.WIDTH(NUM_PORT), .NUM_DELAY(S)) u_req_delay (
        .clk(clk),
        .signal_in(req_i),
        .delayed_signal(delayed_req)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_ptr <= 0;
            grant_o <= 0;
            grant_valid_o <= 0;
            for (int i = 0; i < `QOS_LEVELS; i++) weight_counter[i] <= WEIGHTS[i];
        end else begin
            grant_o <= 0;
            grant_valid_o <= 0;
            for (int p = 0; p < NUM_PORT; p++) begin
                int qos = qos_tag_i[(current_ptr + p) % NUM_PORT];
                if (delayed_req[0][(current_ptr + p) % NUM_PORT] && weight_counter[qos] > 0) begin  // Use delayed[0] for immediate
                    grant_o[(current_ptr + p) % NUM_PORT] <= 1;
                    grant_valid_o <= 1;
                    weight_counter[qos] <= weight_counter[qos] - 1;
                    current_ptr <= (current_ptr + p + 1) % NUM_PORT;
                    break;
                end
            end
            // Reset counters if all zero (fairness)
            if (weight_counter.sum() == 0) begin  // Pseudo-code; use loop in real
                for (int i = 0; i < `QOS_LEVELS; i++) weight_counter[i] <= WEIGHTS[i];
            end
        end
    end

endmodule

`default_nettype wire