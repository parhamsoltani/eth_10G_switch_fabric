`timescale 1ns/1ps
`default_nettype none



module fifo_array_model
#(
	// User Configurable Parameters
	parameter	WIDTH		    = 13,
    parameter   NUM_FIFO		= 32,
    parameter 	READ_LATENCY    = 1,
	// DO NOT change following parameters
	parameter	NUM_FIFO_LOG	= NUM_FIFO == 1 ? 1 : $clog2(NUM_FIFO)
)
(
	input	wire								clk,
	input	wire								push,
	input	wire	[WIDTH-1:0]	        		push_data,
	input	wire	[NUM_FIFO_LOG-1:0]	        push_id,
	input	wire								pop,
	input	wire	[NUM_FIFO_LOG-1:0]			pop_id,
	output	wire	[WIDTH-1:0]	        		pop_data
);

	int count;
	reg [WIDTH-1:0] mem [NUM_FIFO][$];

	wire [WIDTH-1:0] pop_data_reg [0:READ_LATENCY];
	reg [WIDTH-1:0] pop_data_0;

	assign pop_data = pop_data_reg[READ_LATENCY-1];

	always @(posedge clk) begin
		if (pop) begin
			if (count > 0) begin
				pop_data_0 = mem[pop_id].pop_front();
				count -=1;
			end	
		end
		if (push) begin
			mem[push_id].push_back(push_data);
			count +=1;
		end
        
	end

	delayed_regs #(
		.WIDTH      (WIDTH),
		.NUM_DELAY  (READ_LATENCY)
	) tp_2_rd_data_delay_inst (
		.clk            (clk),
		.signal_in      (pop_data_0),
		.delayed_signal (pop_data_reg)
	);

	
endmodule 

`default_nettype wire 