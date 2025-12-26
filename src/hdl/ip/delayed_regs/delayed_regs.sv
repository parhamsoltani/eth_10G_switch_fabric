`timescale 1ns / 1ps
// `default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Company: IUST
// Engineer: Parham Soltani
//
// Create Date:  2025-07-26 10:54:20
// Module Name: delayed_regs
// Project Name:
// Target Devices:
// Tool Versions: Vivado 2022.2
// Description:
// Dependencies:
//
// Additional Comments:

//////////////////////////////////////////////////////////////////////////////////


module delayed_regs #(
    parameter WIDTH = 8,
    parameter NUM_DELAY = 2
) (
    input  wire                  clk,
    input  wire [WIDTH-1:0]      signal_in,
    output wire [WIDTH-1:0]      delayed_signal [NUM_DELAY+1]
);

    // Always assign the first output to the input (no delay)
    assign delayed_signal[0] = signal_in;

    generate
        if (NUM_DELAY > 0) begin : gen_delays
            reg [WIDTH-1:0] delay_regs [NUM_DELAY-1:0];

            // Assign delayed outputs
            for (genvar i = 0; i < NUM_DELAY; i = i + 1) begin : delay_chain
                assign delayed_signal[i+1] = delay_regs[i];
            end

            // Create the delay chain
            always @(posedge clk) begin
                delay_regs[0] <= signal_in;
                for (int i = 1; i < NUM_DELAY; i = i + 1) begin
                    delay_regs[i] <= delay_regs[i - 1];
                end
            end
        end
    endgenerate

endmodule

`default_nettype wire