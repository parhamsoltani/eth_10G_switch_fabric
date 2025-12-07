`timescale 1ns / 1ps
// `default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Company: IUST
// Engineer: Parham Soltani
//
// Create Date:  2025-08-16 19:13:52
// Module Name: wrapper_dest_finder_row_matching
// Project Name:
// Target Devices:
// Tool Versions: Vivado 2022.2
// Description:
// Dependencies:
//
// Additional Comments:

//////////////////////////////////////////////////////////////////////////////////



module wrapper_dest_finder_row_matching #(
    parameter   NUM_PORT     = 40,
    parameter   S            = 10,
    parameter   ROW_RTT_DELAY= 6,
    // DO NOT CHANGE
    parameter   S_LOG        = $clog2(S),
    parameter   NUM_PORT_LOG = $clog2(NUM_PORT)
) (
    input  wire                     clk,
    input  wire [NUM_PORT-1:0]      none_mepty_ports_1, // update after 4clk
    input  wire [NUM_PORT-1:0]      none_mepty_ports_2, // update after 4clk
    input  wire [NUM_PORT-1:0]      block_ports,
    input  wire                     dfifo_last_1,       // comes after 5 clk
    input  wire                     dfifo_last_2,       // comes after 5 clk

    output wire                     dest_valid_o_1,
    output wire                     dest_valid_o_2,
    output wire [NUM_PORT_LOG-1:0]  dest_o_1,
    output wire [NUM_PORT_LOG-1:0]  dest_o_2
);

    // Registered versions of inputs (except clk)
    reg [NUM_PORT-1:0] none_mepty_ports_1_reg;
    reg [NUM_PORT-1:0] none_mepty_ports_2_reg;
    reg [NUM_PORT-1:0] block_ports_reg;
    reg                dfifo_last_1_reg;
    reg                dfifo_last_2_reg;

    // Sample inputs on the rising edge of clk
    always @(posedge clk) begin
        none_mepty_ports_1_reg <= none_mepty_ports_1;
        none_mepty_ports_2_reg <= none_mepty_ports_2;
        block_ports_reg        <= block_ports;
        dfifo_last_1_reg       <= dfifo_last_1;
        dfifo_last_2_reg       <= dfifo_last_2;
    end

    // Internal wires for outputs
    wire                     dest_valid_o_1_int;
    wire                     dest_valid_o_2_int;
    wire [NUM_PORT_LOG-1:0]  dest_o_1_int;
    wire [NUM_PORT_LOG-1:0]  dest_o_2_int;

    // Instantiate main module
    dest_finder_row_matching #(
        .NUM_PORT(NUM_PORT),
        .S(S),
        .ROW_RTT_DELAY(ROW_RTT_DELAY),
        .S_LOG(S_LOG),
        .NUM_PORT_LOG(NUM_PORT_LOG)
    ) u_dest_finder_row_matching (
        .clk               (clk),
        .none_mepty_ports_1(none_mepty_ports_1_reg),
        .none_mepty_ports_2(none_mepty_ports_2_reg),
        .block_ports       (block_ports_reg),
        .dfifo_last_1      (dfifo_last_1_reg),
        .dfifo_last_2      (dfifo_last_2_reg),
        .dest_valid_o_1    (dest_valid_o_1_int),
        .dest_valid_o_2    (dest_valid_o_2_int),
        .dest_o_1          (dest_o_1_int),
        .dest_o_2          (dest_o_2_int)
    );

    // Pass-through outputs
    assign dest_valid_o_1 = dest_valid_o_1_int;
    assign dest_valid_o_2 = dest_valid_o_2_int;
    assign dest_o_1       = dest_o_1_int;
    assign dest_o_2       = dest_o_2_int;

endmodule


`default_nettype wire