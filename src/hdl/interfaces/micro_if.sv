`timescale 1ns / 1ps
`default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Company: IUST
// Engineer: Parham Soltani
// 
// Create Date:  2025-04-04 11:51:34
// interface Name: micro_if
// Project Name: 
// Tool Versions: Vivado 2022.2
// Description: 
// Dependencies: 
// 
// Additional Comments: 

//////////////////////////////////////////////////////////////////////////////////



`ifndef MICRO_IF_SV
`define MICRO_IF_SV


interface micro_if  #(
    parameter   MICRO_ADDR_WIDTH = 20,
    parameter   MICRO_DATA_WIDTH = 16
    );

    logic                            clk;
    logic                            cs;
    logic                            wr;
    logic    [MICRO_ADDR_WIDTH-1:0]  addr;
    logic    [MICRO_DATA_WIDTH-1:0]  idata;
    logic    [MICRO_DATA_WIDTH-1:0]  odata;

    modport master_mp (
        input   clk, odata,
        output  cs, wr, addr, idata
    );

    modport slave_mp (
        input   clk, cs, wr, addr, idata, 
        output  odata
    );

    // monitor modport
    modport monitor_mp (
        input   clk, cs, wr, addr, idata, odata
    );
endinterface

`endif // MICRO_IF_SV

`default_nettype wire 