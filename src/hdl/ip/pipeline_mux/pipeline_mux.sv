`timescale 1ns / 1ps
// `default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Company: IUST
// Engineer: Parham Soltani
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
    parameter int N  = 23,   // N >= 1
    parameter int K  = 4,    // power-of-two tile size
    parameter int W  = 1
)(
    input  wire                  clk,
    input  wire [W-1:0]          in   [N],
    input  wire [$clog2(N)-1:0]  sel,   // overall select (0..N-1)
    output wire [W-1:0]          out
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

    generate
        if (L == 0) begin : gen_passthrough
            // No muxing needed (N == 1)
            assign out = in[0];
            
        end else begin : gen_mux_tree
            // Handle sel_internal with proper width
            localparam int SEL_INTERNAL_WIDTH = L * SB;
            wire [SEL_INTERNAL_WIDTH-1:0] sel_internal;
            
            if (SEL_INTERNAL_WIDTH > $clog2(N)) begin
                assign sel_internal = {{(SEL_INTERNAL_WIDTH - $clog2(N)){1'b0}}, sel};
            end else begin
                assign sel_internal = sel;
            end

            // ---------- delay SB-bit slices of sel_internal (one per layer) ----------
            wire [SB-1:0] sel_delay [L][ceil_div(N, K)];
            
            for (genvar lvl = 0; lvl < L; lvl++) begin : LAYER_SEL
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
                        for (int s = 1; s < lvl; s++)
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

            // ---------- data across layers ----------
            localparam int MAX_WIDTH = ceil_div(N, K) * K;
            wire [W-1:0] level_data [L+1][MAX_WIDTH];

            // level 0 = inputs
            for (genvar i = 0; i < N; i++) begin : L0_CONNECT
                assign level_data[0][i] = in[i];
            end
            
            // Pad unused inputs with zeros
            for (genvar i = N; i < MAX_WIDTH; i++) begin : L0_PAD
                assign level_data[0][i] = '0;
            end

            // ---------- build layers ----------
            for (genvar lvl = 0; lvl < L; lvl++) begin : LAYER
                localparam int OUT = in_count_at(lvl+1);

                for (genvar j = 0; j < OUT; j++) begin : TILE
                    mux_tile #(
                        .K(K),
                        .W(W),
                        .SB(SB)
                    ) u_tile (
                        .clk (clk),
                        .in  (level_data[lvl][j*K +: K]),
                        .sel (sel_delay[lvl][j]),
                        .out (level_data[lvl+1][j])
                    );
                end
            end

            // final output
            assign out = level_data[L][0];
        end
    endgenerate

endmodule

`default_nettype wire