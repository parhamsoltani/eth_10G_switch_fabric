`timescale 1ns / 1ps
`default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Company: IUST
// Engineer: Parham Soltani
// 
// Create Date:  2025-08-04 18:41:14
// Module Name: dest_finder_s
// Project Name: 
// Target Devices: 
// Tool Versions: Vivado 2022.2
// Description: 
// Dependencies: 
// 
// Additional Comments: 

//////////////////////////////////////////////////////////////////////////////////



module dest_finder_s #(      
    parameter   S                       = 10,
    // DO NOT CHANGE
    parameter   S_LOG                   = $clog2(S)
) (
    input  wire                     clk,
    input  wire [S-1:0]             none_mepty_ports,
    input  wire [S-1:0]             block_ports,
    input  wire [S_LOG-1:0]         rr_counter,
    input  wire                     dfifo_last,
    input  wire [S_LOG-1:0]         dfifo_last_port_index,

    output wire                     dest_valid_o         
);

    reg dest_valid_reg = 0;

    reg is_none_blocked = 0;
    reg is_non_empty = 0;

    reg [S-1:0] remain_packet = 0;

    reg [S_LOG-1:0] chosen_dest;

    assign dest_valid_o = dest_valid_reg;

    always @(posedge clk) begin
        is_none_blocked <= !block_ports[rr_counter];
        is_non_empty    <= none_mepty_ports[rr_counter];
        chosen_dest     <= rr_counter;
    end

    always @(posedge clk) begin
        if (is_none_blocked && (remain_packet[chosen_dest] || is_non_empty)) begin
            dest_valid_reg <= 1;
            remain_packet[chosen_dest] <= 1;
        end else begin
            dest_valid_reg <= 0;
        end
        if (dfifo_last) begin
            remain_packet[dfifo_last_port_index] <= 0;
        end
    end
endmodule

`default_nettype wire 