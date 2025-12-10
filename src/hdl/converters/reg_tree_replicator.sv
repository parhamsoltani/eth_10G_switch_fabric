`timescale 1ns / 1ps
`default_nettype none

module reg_tree_replicator #(
    parameter WIDTH = 64,
    parameter LEAFS = 8,
    parameter MAX_FANOUT = 4
)(
    input  wire             clk,
    input  wire [WIDTH-1:0] data_in,
    output wire [WIDTH-1:0] data_out [LEAFS]
);

    localparam LEVELS = $clog2(LEAFS) / $clog2(MAX_FANOUT) + 1;

    reg [WIDTH-1:0] tree [LEVELS][LEAFS];

    // Input
    always_ff @(posedge clk) begin
        tree[0][0] <= data_in;
    end

    // Tree replication
    genvar level, leaf;
    generate
        for (level = 1; level < LEVELS; level++) begin : g_level
            for (leaf = 0; leaf < LEAFS; leaf++) begin : g_leaf
                always_ff @(posedge clk) begin
                    tree[level][leaf] <= tree[level-1][leaf / MAX_FANOUT];
                end
            end
        end
    endgenerate

    // Output
    generate
        for (leaf = 0; leaf < LEAFS; leaf++) begin : g_out
            assign data_out[leaf] = tree[LEVELS-1][leaf];
        end
    endgenerate

endmodule