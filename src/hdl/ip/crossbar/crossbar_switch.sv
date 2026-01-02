`timescale 1ns / 1ps
`default_nettype none

module crossbar_switch #(
    parameter NUM_PORT      = 10,
    parameter DATA_WIDTH    = 64,
    parameter ARBITER_TYPE  = "RR"  // "RR" or "PRIORITY"
)(
    input  wire                             clk,
    input  wire                             reset,

    // Input requests
    input  wire [NUM_PORT-1:0]              req,
    input  wire [DATA_WIDTH-1:0]            data_in  [NUM_PORT],
    input  wire [NUM_PORT-1:0]              valid_in,

    // Grants back to inputs - Changed from wire to logic
    output logic [NUM_PORT-1:0][NUM_PORT-1:0] grant,

    // Outputs
    output logic [DATA_WIDTH-1:0]           data_out [NUM_PORT],
    output logic [NUM_PORT-1:0]             valid_out
);

    localparam PORT_ID_WIDTH = $clog2(NUM_PORT);

    // Per-output arbitration
    logic [NUM_PORT-1:0][NUM_PORT-1:0]  arb_req;
    logic [NUM_PORT-1:0][NUM_PORT-1:0]  arb_grant;
    logic [NUM_PORT-1:0][PORT_ID_WIDTH-1:0] selected_input;

    // =====================================================
    // ARBITERS (one per output port)
    // =====================================================
    generate
        for (genvar out = 0; out < NUM_PORT; out++) begin : gen_arbiter
            // Collect requests for this output
            always_comb begin
                for (int in_port = 0; in_port < NUM_PORT; in_port++) begin
                    arb_req[out][in_port] = req[in_port] & valid_in[in_port];
                end
            end

            arbiter_rr #(
                .N(NUM_PORT)
            ) port_arbiter (
                .clk        (clk),
                .reset      (reset),
                .req        (arb_req[out]),
                .grant      (arb_grant[out]),
                .grant_id   (selected_input[out]),
                .grant_valid(valid_out[out])
            );

            // Mux data based on arbitration
            always_comb begin
                data_out[out] = data_in[selected_input[out]];
            end
        end
    endgenerate

    // =====================================================
    // GRANT MATRIX
    // =====================================================
    always_comb begin
        for (int in_port = 0; in_port < NUM_PORT; in_port++) begin
            for (int out_port = 0; out_port < NUM_PORT; out_port++) begin
                grant[in_port][out_port] = arb_grant[out_port][in_port];
            end
        end
    end

endmodule

`default_nettype wire