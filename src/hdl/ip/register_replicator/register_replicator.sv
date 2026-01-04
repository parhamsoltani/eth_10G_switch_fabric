`timescale 1ns / 1ps
`default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Company: IUST
// Engineer: Parham Soltani
// 
// Create Date:  2025-04-19 11:20:33
// Module Name: register_replicator
// Project Name: 
// Target Devices: 
// Tool Versions: Vivado 2022.2
// Description: 
// Dependencies: 
// 
// Additional Comments: 

//////////////////////////////////////////////////////////////////////////////////


module register_replicator #(
    parameter NUM_REPLICATION = 2,
    parameter WIDTH           = 10
) (
    input   wire    clk,
    input   wire    [WIDTH-1:0] data_in,
    output  wire    [WIDTH-1:0] data_out [NUM_REPLICATION]
);

    (* dont_touch = "yes" *) reg [WIDTH-1:0] reg_out [NUM_REPLICATION];

    generate
        for (genvar i = 0; i < NUM_REPLICATION; i++) begin
            assign data_out [i] = reg_out [i];
        end
    endgenerate


    always @(posedge clk) begin
        for (int i=0; i<NUM_REPLICATION; ++i) begin
            reg_out [i] <= data_in;
        end
    end
    
endmodule

`default_nettype wire 