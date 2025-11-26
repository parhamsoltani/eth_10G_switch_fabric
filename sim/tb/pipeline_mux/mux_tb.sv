`timescale 1ns/1ps
`default_nettype none

module tb_pipeline_mux;
    // ---- Params you might tweak ----
    localparam int N  = 15;
    localparam int K  = 2;
    localparam int W  = 8;
    localparam int CYCLES = 2000; // stimulus cycles
    // --------------------------------

    // Clock
      reg clk = 0;
      // Clock generation: 100MHz
    initial begin
        forever begin
            #5 clk = ~clk; // 100 MHz
        end
    end

    // DUT I/O
    reg [W-1:0] in [N];
    reg [$clog2(N)-1:0] sel;
    reg [$clog2(N)-1:0] sel_d;
    reg [W-1:0] out;


    // Function to compute layers/latency
    function automatic int ceil_div(input int a, input int b);
        return (a + b - 1) / b;
    endfunction
    function automatic int layers_needed(input int n, input int k);
        int l = 0, x = n;
        while (x > 1) begin
            x = ceil_div(x, k);
            l++;
        end
        return l;
    endfunction
    localparam int L = layers_needed(N, K);

    // Instantiate DUT
    pipeline_mux #(
        .N(N),
        .K(K),
        .W(W)
    ) dut (
        .clk(clk),
        .in(in),
        .sel(sel),
        .out(out)
    );
    // ================================================

    localparam int DLY   =  layers_needed(N, K);

    logic [W-1:0] exp_q[$];
    logic [W-1:0] exp;

    int errors = 0;
    int checks = 0;
    int cycle  = 0;


    initial begin
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        forever  begin

            @(posedge clk);
            #1;
            sel_d = sel;
            sel = $urandom_range(N-1, 0);
            if (cycle != 0) begin
                for (int i = 0; i < N; i++)
                    in[i] = $urandom();
            
                // Push expected output for this cycle; it will be checked after DLY cycles
                exp_q.push_back( in[sel_d] );

                // Once we've accumulated DLY items, start checking oldest against DUT
                if (cycle >= DLY + 1) begin
                    exp = exp_q.pop_front();
                    checks++;
                    if (out !== exp) begin
                        errors++;
                        $error("[%0t] cycle %0d MISMATCH: out=%0h exp=%0h", $time, cycle, out, exp);
                    end
                end

            end

            if (cycle == CYCLES + DLY + 1) begin
                $display("[TB] Done. Checks=%0d Errors=%0d", checks, errors);
                $stop;
            end

            cycle++;
        end
    end

endmodule

`default_nettype wire
