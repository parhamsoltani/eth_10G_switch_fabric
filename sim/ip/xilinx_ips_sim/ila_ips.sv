`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Company: Parman
// Engineer: Alireza Abbasian
// 
// Create Date:  2025-04-10 17:32:46
// Module Name: ila_general
// Project Name: 
// Target Devices: 
// Tool Versions: Vivado 2022.2
// Description:  for simulation
// Dependencies: 
// 
// Additional Comments: 

//////////////////////////////////////////////////////////////////////////////////


module ila_8 (
clk,
probe0
);

input clk;
input [7 : 0] probe0;

endmodule

module ila_16 (
clk,
probe0
);

input clk;
input [15 : 0] probe0;

endmodule

module ila_32 (
clk,
probe0
);

input clk;
input [31 : 0] probe0;

endmodule

module ila_64 (
clk,
probe0
);

input clk;
input [63 : 0] probe0;

endmodule

module ila_128 (
clk,
probe0
);

input clk;
input [127 : 0] probe0;

endmodule

module ila_256 (
clk,
probe0
);

input clk;
input [255 : 0] probe0;

endmodule

module ila_512 (
clk,
probe0
);

input clk;
input [511 : 0] probe0;

endmodule

