`timescale 1ns / 1ps
`default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Company: Parman
// Engineer: Alireza Abbasian
// 
// Create Date:  2025-08-13 20:36:24
// Module Name: dest_finder_col
// Project Name: 
// Target Devices: 
// Tool Versions: Vivado 2022.2
// Description: 
// Dependencies: 
// 
// Additional Comments: 

//////////////////////////////////////////////////////////////////////////////////


// TODO: this version imagine always last come and the packets are 1 cell

module dest_finder_col #(
    parameter   S                       = 10,
    parameter   NUM_XPQ                 = 6,
    parameter   COL_READ_LATENCY        = 4,
    parameter   XPQ_EXTRA_READ_LATENCY  = 1,
    // DO NOT CHANGE
    parameter   S_LOG                   = $clog2(S),
    parameter   NUM_XPQ_LOG             = NUM_XPQ == 1 ? 1 : $clog2(NUM_XPQ)
) (
    input  wire                     clk,
    input  wire [S-1:0]             none_mepty_ports [NUM_XPQ],
    input  wire [S-1:0]             block_ports,
    input  wire                     dfifo_last,

    output wire                     chosen_xpq_valid_o,         // after 3 clk
    output wire [NUM_XPQ-1:0]       chosen_xpq_o,
    output wire [S_LOG-1:0]         cell2pkt_barrel_sel,
    output wire [S_LOG-1:0]         xpq_pop_id
);


    localparam COL_DEST_FINDER_LATENCY = 4;
    localparam C2P_START_OF_CELL_DELAY  = COL_DEST_FINDER_LATENCY + COL_READ_LATENCY;
    localparam C2P_BARREL_SEL_DELAY     = C2P_START_OF_CELL_DELAY + XPQ_EXTRA_READ_LATENCY;

    reg [S_LOG-1:0]                     rr_counter [S];

    initial begin
        for (int i = 0; i < S; i++) begin
            rr_counter[i] = S-1-i;
        end
    end

    always @(posedge clk) begin
        for (int i = S-1; i > 0; i--) begin
            rr_counter[i] <= rr_counter[i-1];
        end
        rr_counter[0] <= rr_counter[S-1];
    end

    wire [S_LOG-1:0]         dfifo_last_port_index = rr_counter[rr_index(0,C2P_START_OF_CELL_DELAY)];

    wire                     chosen_xpq_valid;
    wire [NUM_XPQ-1:0]       chosen_xpq;
    wire                     chosen_xpq_valid_D[0:1];
    wire [NUM_XPQ-1:0]       chosen_xpq_D[0:1];
    // reg [S-1:0] remain_packet = 0;

    wire [NUM_XPQ-1:0] none_empty_xpq [S];

    reg [NUM_XPQ-1:0] possible_dests; // 2D

    reg                 is_none_blocked = 0;
    reg [NUM_XPQ-1:0]   is_non_empty = 0;

    assign cell2pkt_barrel_sel = rr_counter[rr_index(0,C2P_BARREL_SEL_DELAY)];
    assign xpq_pop_id = rr_counter[COL_DEST_FINDER_LATENCY];
    assign chosen_xpq_o = chosen_xpq_D[1];
    assign chosen_xpq_valid_o = chosen_xpq_valid_D[1]; // 4D

    generate
        for (genvar i = 0; i < NUM_XPQ; i++) begin
            for (genvar j=0; j<S; ++j) begin
                assign none_empty_xpq[j][i] = none_mepty_ports[i][j];
            end
        end
    endgenerate

    always @(posedge clk) begin
        is_none_blocked <= !block_ports[rr_counter[0]];
        is_non_empty    <= none_empty_xpq[rr_counter[0]]; // 1D
    end

    always @(posedge clk) begin
        if (is_none_blocked) begin
            possible_dests <= is_non_empty;
        end else begin
            possible_dests <= 0;
        end
    end

    

    one_hot_none_zero #(
        .N               (NUM_XPQ)
    ) u_first_none_zero_datavalid (
        .clk             (clk),
        .data_i          (possible_dests),
        .data_o          (chosen_xpq),
        .data_valid_o    (chosen_xpq_valid) // 3D
    );

    // Delay for chosen_xpq_valid (1-bit)
    delayed_regs #(
        .WIDTH      (1),
        .NUM_DELAY  (1)
    ) chosen_xpq_valid_delay_inst (
        .clk            (clk),
        .signal_in      (chosen_xpq_valid),
        .delayed_signal (chosen_xpq_valid_D)
    );

    // Delay for chosen_xpq (NUM_XPQ bits)
    delayed_regs #(
        .WIDTH      (NUM_XPQ),
        .NUM_DELAY  (1)
    ) chosen_xpq_delay_inst (
        .clk            (clk),
        .signal_in      (chosen_xpq),
        .delayed_signal (chosen_xpq_D)
    );



    //==============================================================================
    // Functions
    //==============================================================================


    function automatic int rr_index(input int port_index, input int delay_val);
        return (port_index + delay_val + 10*S) % S;
    endfunction

endmodule

`default_nettype wire 