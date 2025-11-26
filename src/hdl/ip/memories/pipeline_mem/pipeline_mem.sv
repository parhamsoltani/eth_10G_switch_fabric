// `timescale 1ns / 1ps
// `default_nettype none
// //////////////////////////////////////////////////////////////////////////////////
// // Company: Parman
// // Engineer: Alireza Abbasian
// // 
// // Create Date:  2025-07-26 10:18:21
// // Module Name: pipeline_mem
// // Project Name: 
// // Target Devices: 
// // Tool Versions: Vivado 2022.2
// // Description: 
// // Dependencies: 
// // 
// // Additional Comments: 

// //////////////////////////////////////////////////////////////////////////////////


// module pipeline_mem
// #(
// 	// User Configurable Parameters
// 	parameter	WIDTH		            = 136,
//     parameter   DEPTH                   = 512,
//     parameter   NUM_MEM                 = 8,
//     parameter   NUM_PORT                = 8,
// 	parameter	MEMORY_PRIMITIVE	    = "block",			// "auto", "block", "distributed", "ultra"
//     parameter	XPM_READ_LATENCY        = 2,                // read latency = XPM_READ_LATENCY+2
// 	// DO NOT change following parameters
// 	parameter	DEPTH_LOG		    = $clog2(DEPTH),
//     parameter   NUM_PORT_LOG        = $clog2(NUM_PORT)
// )
// (
// 	input	wire						clk,

// 	input	wire						wr_en_i[NUM_PORT],
// 	input	wire	[DEPTH_LOG-1:0]	    wr_addr_i[NUM_PORT],
// 	input	wire	[WIDTH-1:0]	        wr_data_i [NUM_PORT],
//     input   wire    [NUM_PORT_LOG-1:0]  wr_port_index_i,

// 	input	wire						rd_en_i[NUM_PORT],
// 	input	wire	[DEPTH_LOG-1:0]	    rd_addr_i[NUM_PORT],
//     input   wire    [NUM_PORT_LOG-1:0]  rd_port_index_i,
// 	output	wire	[WIDTH-1:0]	        rd_data_o [NUM_MEM]
// );


//     reg                 wr_en_reg     [NUM_MEM];    
//     reg [DEPTH_LOG-1:0] rd_addr_reg   [NUM_MEM]; 
//     reg [WIDTH-1:0]     wr_data_reg   [NUM_MEM]; 
//     reg [DEPTH_LOG-1:0] wr_addr_reg   [NUM_MEM];  


//     generate
//         for (genvar i = 0; i < NUM_MEM; i++) begin
//             wr_en_reg[i] = wr_en_i[]
//         end
//     endgenerate

//     always @(posedge clk) begin
//         for (int i=1; i<NUM_MEM; ++i) begin
//             wr_en_reg[i]   <= wr_en_reg[i-1];  
//             wr_addr_reg[i] <= wr_addr_reg[i-1];
//             rd_en_reg[i]   <= rd_en_reg[i-1];  
//             rd_addr_reg[i] <= rd_addr_reg[i-1];
//         end
//     end


//     generate
//         for (genvar i = 0; i < NUM_MEM; i = i + 1) begin : gen_mem
//             sdpram_xpm #(
//                 .WIDTH              (WIDTH),    
//                 .DEPTH              (DEPTH), 
//                 .MEMORY_PRIMITIVE   (MEMORY_PRIMITIVE),
//                 .WRITE_MODE_B       ("READ_FIRST"),     
//                 .XPM_READ_LATENCY   (XPM_READ_LATENCY)     
//             ) mini_cell_mem (
//                 .clk            (clk),
//                 .wr_en_i        (wr_en_reg[i]),
//                 .wr_addr_i      (wr_addr_reg[i]),
//                 .wr_data_i      (wr_data_i[i]),
//                 .rd_en_i        (1),
//                 .rd_addr_i      (rd_addr_reg[i]),
//                 .rd_data_o      (rd_data_o[i])
//             );
//         end
//     endgenerate
			
		

// endmodule 

// `default_nettype wire 