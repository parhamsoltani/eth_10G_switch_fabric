`timescale 1ns / 1ps
`default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Company: IUST
// Engineer: Morteza Seyedi
// 
// Create Date:  2025-08-10
// Module Name: register_replicator
// Project Name: 
// Target Devices: 
// Tool Versions: Vivado 2022.2
// Description: 
// Dependencies: 
// 
// Additional Comments: 

//////////////////////////////////////////////////////////////////////////////////

module reg_tree_replicator #(
    parameter int unsigned WIDTH      = 10,
    parameter int unsigned LEAFS      = 25,
    parameter int unsigned MAX_FANOUT = 2
) (
    input  wire                    clk,
    input  wire [WIDTH-1:0]        data_in,
    output wire [WIDTH-1:0]        data_out [LEAFS]
);

    // ----------------------------
    // Utilities (constant funcs)
    // ----------------------------
    function automatic int unsigned powi(input int unsigned a, input int unsigned b);
        int unsigned p = 1;
        for (int i = 0; i < b; i++) p *= a;
        return p;
    endfunction

    function automatic int unsigned ceil_div(input int unsigned x, input int unsigned y);
        return (x + y - 1) / y;
    endfunction

    // Minimum stages S such that MAX_FANOUT**S >= LEAFS
    function automatic int unsigned compute_stages(input int unsigned leaves, input int unsigned m);
        int unsigned s = 0;
        int unsigned cap = 1;
        // handle m==1 gracefully (degenerate): force linear chain
        int unsigned base = (m < 2) ? 2 : m;

        if (leaves <= 1) begin
            return 0;
        end
        while (cap < leaves) begin
            s++;
            cap = cap * base;
        end
        return s;
    endfunction

    localparam int unsigned STAGES = compute_stages(LEAFS, MAX_FANOUT);

    // Nodes required at each stage s in [0..STAGES], counting from source (0) to leaves (STAGES)
    function automatic int unsigned nodes_at_stage(input int unsigned s);
        // minimal nodes needed before stage s to ultimately drive LEAFS with max fanout
        // nodes_at_stage(0) = 1 by construction
        int unsigned denom_pow = powi((MAX_FANOUT < 2) ? 2 : MAX_FANOUT, STAGES - s);
        return ceil_div(LEAFS, (denom_pow == 0) ? 1 : denom_pow);
    endfunction

    // Balanced partition helpers:
    // For stage s, with P parents and C children (next stage nodes),
    // parent n gets either floor(C/P) or ceil(C/P) children.
    function automatic int unsigned child_start_idx(input int unsigned C, input int unsigned P, input int unsigned n);
        // starting child index for parent n (prefix sum using floor)
        return (C * n) / P;
    endfunction

    function automatic int unsigned child_count_for_parent(input int unsigned C, input int unsigned P, input int unsigned n);
        int unsigned a = child_start_idx(C, P, n);
        int unsigned b = child_start_idx(C, P, n+1);
        return (b - a); // either floor(C/P) or ceil(C/P)
    endfunction


    wire [WIDTH-1:0] stage_bus [STAGES+1][LEAFS];
    assign stage_bus[0][0] = data_in;

    // ----------------------------
    // Build the tree
    // ----------------------------
    generate
        for (genvar s = 0; s < STAGES; s++) begin : g_stage
            localparam int unsigned PARENTS = nodes_at_stage(s);
            localparam int unsigned CHILDREN_TOTAL = nodes_at_stage(s+1);

            for (genvar n = 0; n < PARENTS; n++) begin : g_parent
                localparam int unsigned START   = child_start_idx(CHILDREN_TOTAL, PARENTS, n);
                localparam int unsigned COUNT   = child_count_for_parent(CHILDREN_TOTAL, PARENTS, n);
                // Safety: COUNT should always be >=1 and <= MAX_FANOUT by construction
                initial begin
                    if (COUNT == 0) $error("regtree_auto: zero fanout at stage %0d parent %0d", s, n);
                    if (COUNT > MAX_FANOUT) $error("regtree_auto: fanout %0d exceeds MAX_FANOUT %0d at stage %0d parent %0d", COUNT, MAX_FANOUT, s, n);
                end
		

                // replicate for this parent
                register_replicator #(
                    .NUM_REPLICATION(COUNT),
                    .WIDTH(WIDTH)
                ) u_rep (
                    .clk     (clk),
                    .data_in (stage_bus[s][n]),
                    .data_out(stage_bus[s+1][START +: COUNT])
                );
            end
        end

        for (genvar i = 0; i < LEAFS; i++) begin : g_out
            assign data_out[i] = stage_bus[STAGES][i];
        end
    endgenerate

endmodule


`default_nettype wire 