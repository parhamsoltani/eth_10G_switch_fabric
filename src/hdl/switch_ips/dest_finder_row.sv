`timescale 1ns / 1ps
`default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Company: IUST
// Engineer: Parham Soltani
//
// Create Date:  2025-08-04 18:41:14
// Module Name: dest_finder_row (Fixed - proper pending tracking)
//////////////////////////////////////////////////////////////////////////////////



module dest_finder_row #(
    parameter   NUM_PORT                = 10,
    parameter   S                       = 10,
    parameter   ROW_RTT_DELAY           = 6,
    parameter   S_LOG                   = $clog2(S),
    parameter   NUM_PORT_LOG            = $clog2(NUM_PORT)
) (
    input  wire                     clk,
    input  wire [NUM_PORT-1:0]      none_mepty_ports,
    input  wire [NUM_PORT-1:0]      block_ports,
    input  wire                     dfifo_last,

    output wire                     dest_valid_o,
    output wire [NUM_PORT_LOG-1:0]  dest_o
);

    // Round-robin timing wheel
    reg [S_LOG-1:0] rr_counter [S];

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

    wire [S_LOG-1:0] final_stage_counter   = rr_counter[0];
    wire [S_LOG-1:0] free_recent_counter   = rr_counter[rr_index(0, ROW_RTT_DELAY)];

    // Output registers
    reg                     dest_valid_reg = 0;
    reg [NUM_PORT_LOG-1:0]  dest_reg = 0;

    // Tracking registers
    reg [NUM_PORT-1:0]      pending_dests = 0;

    // Pipeline history for clearing pending
    reg [NUM_PORT_LOG-1:0]  current_dests [S];
    reg                     current_dests_valid [S];

    initial begin
        for (int i = 0; i < S; i++) begin
            current_dests[i] = '0;
            current_dests_valid[i] = 1'b0;
        end
    end

    // Priority encoder outputs
    wire [NUM_PORT_LOG-1:0] dest_candidate;
    wire                    dest_candidate_valid;

    // Compute available destinations: non-empty, not blocked, not pending
    wire [NUM_PORT-1:0] available_dests;
    assign available_dests = none_mepty_ports & (~block_ports) & (~pending_dests);

    assign dest_valid_o = dest_valid_reg;
    assign dest_o       = dest_reg;

    //==========================================================================
    // Main selection and pipeline update
    //==========================================================================
    always @(posedge clk) begin
        // Clear pending bit when selection exits pipeline
        if (current_dests_valid[free_recent_counter]) begin
            pending_dests[current_dests[free_recent_counter]] <= 1'b0;
        end

        // Process new selection
        if (dest_candidate_valid) begin
            // Output the selection
            dest_valid_reg <= 1'b1;
            dest_reg       <= dest_candidate;

            // Record in pipeline
            current_dests[final_stage_counter]       <= dest_candidate;
            current_dests_valid[final_stage_counter] <= 1'b1;

            // Mark as pending (exclude from future selections)
            pending_dests[dest_candidate] <= 1'b1;
        end else begin
            dest_valid_reg <= 1'b0;
            current_dests_valid[final_stage_counter] <= 1'b0;
        end
    end

    //==========================================================================
    // Priority encoder - use existing module
    //==========================================================================
    first_none_zero_except_k #(
        .N(NUM_PORT)
    ) u_first_none_zero_except_k (
        .clk          (clk),
        .data_i       (available_dests),
        .ready_o      (1'b1),
        .data_o       (dest_candidate),
        .data_valid_o (dest_candidate_valid)
    );

    function automatic int rr_index(input int port_index, input int delay_val);
        return (port_index + delay_val + 10*S) % S;
    endfunction

endmodule

`default_nettype wire