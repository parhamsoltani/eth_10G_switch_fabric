`timescale 1ns / 1ps
`default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Company: IUST
// Engineer: Parham Soltani
//
// Create Date:  2025-08-03 10:32:42
// Module Name: pipeline_mem
// Project Name:
// Target Devices:
// Tool Versions: Vivado 2022.2
// Description: Pipeline memory with delayed address/enable signals for 
//              multi-bank memory access
// Dependencies: sdpram_xpm, delayed_regs
//
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////

module pipeline_mem #(
    // User Configurable Parameters
    parameter WIDTH            = 136,
    parameter DEPTH            = 8,
    parameter NUM_MEM          = 8,
    parameter XPM_READ_LATENCY = 1,
    // DO NOT change following parameters
    parameter DEPTH_LOG        = $clog2(DEPTH)
) (
    input  wire                    clk,

    input  wire                    wr_en_i   [NUM_MEM],
    input  wire [DEPTH_LOG-1:0]    wr_addr_i,
    input  wire [WIDTH-1:0]        wr_data_i [NUM_MEM],

    input  wire                    rd_en_i,
    input  wire [DEPTH_LOG-1:0]    rd_addr_i,
    output wire [WIDTH-1:0]        rd_data_o [NUM_MEM]
);

    // Determine memory primitive based on depth
    localparam MEMORY_PRIMITIVE = (DEPTH <= 64)   ? "distributed" :
                                  (DEPTH < 4000)  ? "block" : "ultra";

    // Delayed signals
    wire                  rd_en_D   [NUM_MEM];
    wire [DEPTH_LOG-1:0]  wr_addr_D [NUM_MEM];
    wire [DEPTH_LOG-1:0]  rd_addr_D [NUM_MEM];

    // ============================================================
    // Memory Bank Instantiation
    // ============================================================
    generate
        for (genvar i = 0; i < NUM_MEM; i = i + 1) begin : gen_mem
            sdpram_xpm #(
                .WIDTH            (WIDTH),
                .DEPTH            (DEPTH),
                .MEMORY_PRIMITIVE (MEMORY_PRIMITIVE),
                .WRITE_MODE_B     ("READ_FIRST"),
                .XPM_READ_LATENCY (XPM_READ_LATENCY)
            ) uut (
                .clk       (clk),
                .wr_en_i   (wr_en_i[i]),
                .wr_addr_i (wr_addr_D[i]),
                .wr_data_i (wr_data_i[i]),
                .rd_en_i   (rd_en_D[i]),
                .rd_addr_i (rd_addr_D[i]),
                .rd_data_o (rd_data_o[i])
            );
        end
    endgenerate

    // ============================================================
    // Delay Line Instantiations
    // ============================================================

    // Delay line for rd_en_i (1-bit signal)
    delayed_regs #(
        .WIDTH     (1),
        .NUM_DELAY (NUM_MEM - 1)
    ) rd_en_delay_inst (
        .clk            (clk),
        .signal_in      (rd_en_i),
        .delayed_signal (rd_en_D)
    );

    // Delay line for wr_addr_i (DEPTH_LOG-bit address)
    delayed_regs #(
        .WIDTH     (DEPTH_LOG),
        .NUM_DELAY (NUM_MEM - 1)
    ) wr_addr_delay_inst (
        .clk            (clk),
        .signal_in      (wr_addr_i),
        .delayed_signal (wr_addr_D)
    );

    // Delay line for rd_addr_i (DEPTH_LOG-bit address)
    delayed_regs #(
        .WIDTH     (DEPTH_LOG),
        .NUM_DELAY (NUM_MEM - 1)
    ) rd_addr_delay_inst (
        .clk            (clk),
        .signal_in      (rd_addr_i),
        .delayed_signal (rd_addr_D)
    );

endmodule

`default_nettype wire