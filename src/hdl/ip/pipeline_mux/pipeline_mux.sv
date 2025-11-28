`timescale 1ns / 1ps
`default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Company: IUST
// Engineer: Morteza Seyedi
// 
// Create Date:  2025-08-09
// Module Name: pipeline_mux
// Project Name: 
// Target Devices: 
// Tool Versions: Vivado 2022.2
// Description: 
// Dependencies: 
// 
// Additional Comments: 

//////////////////////////////////////////////////////////////////////////////////

module pipeline_mux #(
    parameter int N  = 23,   // N >= 2
    parameter int K  = 4,    // power-of-two tile size
    parameter int W  = 1
)(
    input  wire                  clk,
    input  wire [W-1:0]          in   [N],
    input  wire [$clog2(N)-1:0]  sel,   // overall select (0..N-1)
    output reg  [W-1:0]          out
);

    localparam int SB = $clog2(K);

    // helpers
    function automatic int ceil_div (input int a, input int b);
        return (a + b - 1) / b;
    endfunction

    function automatic int layers_needed (input int n, input int k);
        int l = 0, x = n;
        while (x > 1) begin 
            x = ceil_div(x, k);
            l++; 
        end
        return l;
    endfunction
    localparam int L = layers_needed(N, K);

    // compile-time counts
    function automatic int in_count_at (input int lvl);
        int x = N;
        for (int i = 0; i < lvl; i++)
            x = ceil_div(x, K);
        return x;
    endfunction

    wire [L*SB-1:0] sel_internal = {{(L*SB-$clog2(N)){1'b0}},sel};

    // ---------- delay SB-bit slices of sel_internal (one per layer) ----------
    // guard for the case L*SB > $bits(sel_internal): missing high bits => 0
    wire [SB-1:0] sel_delay [L][ceil_div(N, K)];
    generate
        for (genvar lvl = 0; lvl < L; lvl++) begin
            localparam int MUX_IN_LAYER = in_count_at(lvl+1);

            if (lvl == 0) begin : NO_PIPE

                register_replicator #(
                    .NUM_REPLICATION    (MUX_IN_LAYER),
                    .WIDTH              (SB)
                ) reg_rep (
                    .clk                (clk),
                    .data_in            (sel_internal[lvl*SB +: SB]),
                    .data_out           (sel_delay[lvl][0:MUX_IN_LAYER-1])
                );

            end else begin : PIPE

                reg [SB-1:0] pipe [lvl];
                always @(posedge clk) begin
                    pipe[0] <= sel_internal[lvl*SB +: SB];
                    for (integer s = 1; s < lvl; s++) 
                        pipe[s] <= pipe[s-1];
                end
                register_replicator #(
                    .NUM_REPLICATION    (MUX_IN_LAYER),
                    .WIDTH              (SB)
                ) reg_rep (
                    .clk                (clk),
                    .data_in            (pipe[lvl-1]),
                    .data_out           (sel_delay[lvl][0:MUX_IN_LAYER-1])
                );

            end
        end
    endgenerate


    // ---------- data across layers ----------
    wire [W-1:0] level_data [L+1][ceil_div(N, K)*K];

    // level 0 = inputs
    for (genvar i = 0; i < N; i++) begin : L0
        assign level_data[0][i] = in[i];
    end

    // ---------- build layers ----------
    generate
        for (genvar lvl = 0; lvl < L; lvl++) begin : LAYER
            localparam int IN  = in_count_at(lvl);
            localparam int OUT = in_count_at(lvl+1);

            for (genvar j = 0; j < OUT; j++) begin : TILE
                mux_tile #(
                    .K(K),
                    .W(W)
                ) u_tile (
                    .clk (clk),
                    .in  (level_data[lvl][j*K +: K]),
                    .sel (sel_delay[lvl][j]),
                    .out (level_data[lvl+1][j])
                );
            end
        end
    endgenerate

    // final output
    assign out = level_data[L][0];

endmodule

`default_nettype wire 
