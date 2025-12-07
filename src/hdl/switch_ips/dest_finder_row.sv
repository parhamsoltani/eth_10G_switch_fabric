`timescale 1ns / 1ps
// `default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Company: IUST
// Engineer: Parham Soltani
//
// Create Date:  2025-08-04 18:41:14
// Module Name: dest_finder_row
// Project Name:
// Target Devices:
// Tool Versions: Vivado 2022.2
// Description:
// Dependencies:
//
// Additional Comments:

//////////////////////////////////////////////////////////////////////////////////

// TODO: this version imagine always last come and the packets are 1 cell

module dest_finder_row #(
    parameter   NUM_PORT                = 10,
    parameter   S                       = 10,
    parameter   ROW_RTT_DELAY           = 6,
    // DO NOT CHANGE
    parameter   S_LOG                   = $clog2(S),
    parameter   NUM_PORT_LOG            = $clog2(NUM_PORT)
) (
    input  wire                     clk,
    input  wire [NUM_PORT-1:0]      none_mepty_ports, // update after 4clk
    input  wire [NUM_PORT-1:0]      block_ports,
    input  wire                     dfifo_last, // come after 5 clk

    output wire                     dest_valid_o,
    output wire [NUM_PORT_LOG-1:0]  dest_o
);





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


    wire [S_LOG-1:0] final_stage_counter = rr_counter[0];
    wire [S_LOG-1:0] last_counter = rr_counter[rr_index(0,ROW_RTT_DELAY)];
    wire [S_LOG-1:0] free_recent_counter = rr_counter[rr_index(0,S-3)];


    reg                     dest_valid_reg = 0;
    reg [NUM_PORT_LOG-1:0]  dest_reg = 0;


    reg [NUM_PORT-1:0]      possible_dests = 0;
    reg [NUM_PORT-1:0]      recent_dests = 0;

    wire [NUM_PORT_LOG-1:0]  dest_candidate;
    wire                     dest_candidate_valid;

    reg [NUM_PORT_LOG-1:0]  current_dests [S] = '{default:'0};
    reg                     current_dests_valid [S] = '{default:'0};


    wire [NUM_PORT_LOG-1:0] prev_dest       = current_dests[final_stage_counter];
    wire                    prev_dest_valid = current_dests_valid[final_stage_counter];

    assign dest_valid_o = dest_valid_reg;
    assign dest_o = dest_reg;

    always @(posedge clk) begin
        possible_dests <= (~recent_dests) & none_mepty_ports & (~block_ports);

        if (dest_candidate_valid) begin
            possible_dests[dest_candidate] <= 0;
        end

    end







    always @(posedge clk) begin
        // if (dfifo_last) begin
        //     current_dests_valid[last_counter] <= 0; // updated after 6D
        // end

        // if (prev_dest_valid) begin
        //     dest_reg <= prev_dest;
        //     dest_valid_reg <= 1;
        // end else begin


        if (dest_candidate_valid) begin

            dest_valid_reg <= 1;
            dest_reg <= dest_candidate; // 7D

            current_dests_valid[final_stage_counter] <= 1;
            current_dests[final_stage_counter] <= dest_candidate;
        end else begin
            dest_valid_reg <= 0;
            current_dests_valid[final_stage_counter] <= 0;
        end
        // end
    end


    always @(posedge clk) begin
        if (current_dests_valid[free_recent_counter]) begin
            recent_dests[current_dests[free_recent_counter]] <= 0;
        end

        if (dest_candidate_valid) begin
            recent_dests[dest_candidate] <= 1;
        end
    end





    first_none_zero_except_k #(
        .N(NUM_PORT)
    ) u_first_none_zero_except_k (
        .clk          (clk),
        .data_i       (possible_dests),
        .ready_o      (1'b1),
        .data_o       (dest_candidate),
        .data_valid_o (dest_candidate_valid)
    );



    //==============================================================================
    // Functions
    //==============================================================================


    function automatic int rr_index(input int port_index, input int delay_val);
        return (port_index + delay_val + 10*S) % S;
    endfunction

endmodule

`default_nettype wire