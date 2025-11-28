`timescale 1ns / 1ps
`default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Company: IUST
// Engineer: Parham Soltani
// 
// Create Date:  2025-04-04 11:51:34
// interface Name: axis_if
// Project Name: 
// Tool Versions: Vivado 2022.2
// Description: 
// Dependencies: 
// 
// Additional Comments: 

//////////////////////////////////////////////////////////////////////////////////



`ifndef AXIS_IF_SV
`define AXIS_IF_SV

interface axis_if #(
    parameter DATA_WIDTH    = 32, 
    parameter USER_WIDTH    = 1
);

    logic                       clk;
    logic [DATA_WIDTH-1:0]      tdata;
    logic [(DATA_WIDTH/8)-1:0]  tkeep;
    logic                       tvalid;
    logic                       tready;
    logic                       tlast;
    logic [USER_WIDTH-1:0]      tuser;

    // Master modport
    modport master_mp (
        input  clk, tready,
        output tdata, tkeep, tvalid, tlast, tuser
    );

    // Slave modport
    modport slave_mp (
        input  clk, tdata, tkeep, tvalid, tlast, tuser,
        output tready
    );

    // monitor modport
    modport monitor_mp (
        input clk, tdata, tkeep, tvalid, tlast, tuser, tready
    );
endinterface

`endif


`default_nettype wire 