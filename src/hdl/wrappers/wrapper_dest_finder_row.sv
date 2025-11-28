`timescale 1ns / 1ps
`default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Company: IUST
// Engineer: Parham Soltani
// 
// Create Date:  2025-08-13 20:28:28
// Module Name: wrapper_dest_finder_row
// Project Name: 
// Target Devices: 
// Tool Versions: Vivado 2022.2
// Description: 
// Dependencies: 
// 
// Additional Comments: 

//////////////////////////////////////////////////////////////////////////////////



module wrapper_dest_finder_row #(
    parameter   NUM_PORT     = 120,
    parameter   S            = 10,
    // DO NOT CHANGE
    parameter   S_LOG        = $clog2(S),
    parameter   NUM_PORT_LOG = $clog2(NUM_PORT)
) (
    input  wire                     clk,
    input  wire [NUM_PORT-1:0]      none_mepty_ports, // update after 4clk
    input  wire [NUM_PORT-1:0]      block_ports,
    input  wire                     dfifo_last,       // comes after 5 clk

    output wire                     dest_valid_o,
    output wire [NUM_PORT_LOG-1:0]  dest_o
);

    // Registered versions of inputs (except clk)
    reg [NUM_PORT-1:0] none_mepty_ports_reg;
    reg [NUM_PORT-1:0] block_ports_reg;
    reg                dfifo_last_reg;

    // Register inputs on posedge clk
    always @(posedge clk) begin
        none_mepty_ports_reg <= none_mepty_ports;
        block_ports_reg      <= block_ports;
        dfifo_last_reg       <= dfifo_last;
    end

    // Internal wires for outputs
    wire                     dest_valid_o_int;
    wire [NUM_PORT_LOG-1:0]  dest_o_int;

    // Instantiate main module
    dest_finder_row #(
        .NUM_PORT(NUM_PORT),
        .S(S),
        .S_LOG(S_LOG),
        .NUM_PORT_LOG(NUM_PORT_LOG)
    ) u_dest_finder_row (
        .clk              (clk),
        .none_mepty_ports (none_mepty_ports_reg),
        .block_ports      (block_ports_reg),
        .dfifo_last       (dfifo_last_reg),
        .dest_valid_o     (dest_valid_o_int),
        .dest_o           (dest_o_int)
    );

    // Pass through outputs
    assign dest_valid_o = dest_valid_o_int;
    assign dest_o       = dest_o_int;

endmodule


`default_nettype wire 