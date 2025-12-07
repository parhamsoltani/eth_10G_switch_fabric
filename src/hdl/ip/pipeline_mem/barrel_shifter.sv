`timescale 1ns / 1ps
// `default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Company: IUST
// Engineer: Parham Soltani
//
// Create Date:  2025-08-03 10:32:37
// Module Name: barrel_shifter
// Project Name:
// Target Devices:
// Tool Versions: Vivado 2022.2
// Description:
// Dependencies:
//
// Additional Comments:

//////////////////////////////////////////////////////////////////////////////////



module barrel_shifter #(
    parameter WIDTH = 8,
    parameter NUM_PORT = 4,
    // DO NOT CHANGE!
    parameter NUM_PORT_LOG = $clog2(NUM_PORT)
)(
    input  wire             clk,
    input  wire [WIDTH-1:0] data_in [NUM_PORT],
    input  wire [NUM_PORT_LOG-1:0] shift_val,
    output reg  [WIDTH-1:0] data_out [NUM_PORT]
);


    always @(posedge clk) begin
        for (int i=0; i<NUM_PORT; ++i) begin
            if (shift_val >= i) begin
                data_out[i] <= data_in[shift_val-i];
            end else begin
                data_out[i] <= data_in[shift_val-i+NUM_PORT];
            end
        end
    end


endmodule



`default_nettype wire