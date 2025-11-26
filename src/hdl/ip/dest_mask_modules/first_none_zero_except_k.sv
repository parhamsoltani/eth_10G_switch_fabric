`timescale 1ns / 1ps
`default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Company: Parman
// Engineer: Alireza Abbasian
// 
// Create Date:  2025-08-13 17:19:23
// Module Name: first_none_zero_except_k
// Project Name: 
// Target Devices: 
// Tool Versions: Vivado 2022.2
// Description: 
// Dependencies: 
// 
// Additional Comments: 

//////////////////////////////////////////////////////////////////////////////////



module first_none_zero_except_k #(
    parameter int N    = 64,
    // DO NOT CHANGE BELOW
    parameter int LOGN = $clog2(N)
) (
    input  wire                  clk,
    input  wire [N-1:0]          data_i,
    input  wire                  ready_o,         // update none_zero_reg when 1
    output wire [LOGN-1:0]       data_o,        // current stored index
    output wire                  data_valid_o
);

    // Internal register holding current index
    reg [LOGN-1:0]  none_zero_reg = '0;
    reg [LOGN-1:0]  prev_index_reg = '0;
    reg             valid_o_reg = '0;

    // Combinational search results
    reg [LOGN-1:0] comb_idx;
    reg            comb_valid;

    always @ ( * ) begin
        comb_idx   = '0;
        comb_valid = 1'b0;

        // Scan all bits; keep last matching index found
        for (int i = 0; i < N; i++) begin
            if (data_i[i]) begin
                if (!(valid_o_reg && (i == prev_index_reg))) begin
                    comb_idx   = i;
                    comb_valid = 1'b1;
                end
            end
        end
    end

    assign data_o = none_zero_reg;
    assign data_valid_o = valid_o_reg;

    // Update register when ready_o and a valid candidate
    always @(posedge clk) begin
        if (ready_o) begin
            if (comb_valid) begin
                valid_o_reg <= 1;
                none_zero_reg <= comb_idx;
                prev_index_reg <= comb_idx;

                
                
            end else begin
                valid_o_reg <= 0;
            end
        end 
    end

endmodule


`default_nettype wire 