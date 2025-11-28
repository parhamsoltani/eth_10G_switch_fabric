`timescale 1ns / 1ps
`default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Company: IUST
// Engineer: Parham Soltani
// 
// Create Date:  2025-08-04 18:41:14
// Module Name: dest_finder_row_matching
// Project Name: 
// Target Devices: 
// Tool Versions: Vivado 2022.2
// Description: 
// Dependencies: 
// 
// Additional Comments: 

//////////////////////////////////////////////////////////////////////////////////

// TODO: this version imagine always last come and the packets are 1 cell

module dest_finder_row_matching #(
    parameter   NUM_PORT                = 10,
    parameter   S                       = 10,
    parameter   ROW_RTT_DELAY           = 6,
    // DO NOT CHANGE
    parameter   S_LOG                   = $clog2(S),
    parameter   NUM_PORT_LOG            = $clog2(NUM_PORT)
) (
    input  wire                     clk,
    input  wire [NUM_PORT-1:0]      none_mepty_ports_1, // update after 4clk
    input  wire [NUM_PORT-1:0]      none_mepty_ports_2, // update after 4clk
    input  wire [NUM_PORT-1:0]      block_ports,
    input  wire                     dfifo_last_1,       // comes after 5 clk
    input  wire                     dfifo_last_2,       // comes after 5 clk

    output wire                     dest_valid_o_1,
    output wire                     dest_valid_o_2,
    output wire [NUM_PORT_LOG-1:0]  dest_o_1,
    output wire [NUM_PORT_LOG-1:0]  dest_o_2
);

    //==========================================================================
    // Shared RR timing wheel (same as original)
    //==========================================================================
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
    wire [S_LOG-1:0] last_counter          = rr_counter[rr_index(0,ROW_RTT_DELAY)];
    wire [S_LOG-1:0] free_recent_counter   = rr_counter[rr_index(0,S-3)];

    //==========================================================================
    // Channel 1 state
    //==========================================================================
    reg                        dest_valid_reg_1 = 0;
    reg [NUM_PORT_LOG-1:0]     dest_reg_1       = 0;

    reg [NUM_PORT-1:0]         possible_dests_1 = 0;
    reg [NUM_PORT-1:0]         recent_dests_1   = 0;

    wire [NUM_PORT_LOG-1:0]    dest_candidate_1;
    wire                       dest_candidate_valid_1;

    reg [NUM_PORT_LOG-1:0]     current_dests_1 [S] = '{default:'0};
    reg                        current_dests_valid_1 [S] = '{default:'0};

    wire [NUM_PORT_LOG-1:0]    prev_dest_1       = current_dests_1[final_stage_counter];
    wire                       prev_dest_valid_1 = current_dests_valid_1[final_stage_counter];



    reg dest_ready_1;
    reg dest_ready_2;

    assign dest_valid_o_1 = dest_valid_reg_1;
    assign dest_o_1       = dest_reg_1;

    // Build candidate mask and clear chosen bit (same pattern as original)
    always @(posedge clk) begin
        possible_dests_1 <= (~recent_dests_1) & none_mepty_ports_1 & (~block_ports);
        if (dest_candidate_valid_1) begin
            possible_dests_1[dest_candidate_1] <= 0;
        end
    end

    

    always @(posedge clk) begin
        if (current_dests_valid_1[free_recent_counter]) begin
            recent_dests_1[current_dests_1[free_recent_counter]] <= 0;
        end
        if (dest_candidate_valid_1) begin
            recent_dests_1[dest_candidate_1] <= 1;
        end
    end

    

    //==========================================================================
    // Channel 2 state
    //==========================================================================
    reg                        dest_valid_reg_2 = 0;
    reg [NUM_PORT_LOG-1:0]     dest_reg_2       = 0;

    reg [NUM_PORT-1:0]         possible_dests_2 = 0;
    reg [NUM_PORT-1:0]         recent_dests_2   = 0;

    wire [NUM_PORT_LOG-1:0]    dest_candidate_2;
    wire                       dest_candidate_valid_2;

    reg [NUM_PORT_LOG-1:0]     current_dests_2 [S] = '{default:'0};
    reg                        current_dests_valid_2 [S] = '{default:'0};

    wire [NUM_PORT_LOG-1:0]    prev_dest_2       = current_dests_2[final_stage_counter];
    wire                       prev_dest_valid_2 = current_dests_valid_2[final_stage_counter];

    assign dest_valid_o_2 = dest_valid_reg_2;
    assign dest_o_2       = dest_reg_2;

    always @(posedge clk) begin
        possible_dests_2 <= (~recent_dests_2) & none_mepty_ports_2 & (~block_ports);
        if (dest_candidate_valid_2) begin
            possible_dests_2[dest_candidate_2] <= 0;
        end
    end

    

    always @(posedge clk) begin
        if (current_dests_valid_2[free_recent_counter]) begin
            recent_dests_2[current_dests_2[free_recent_counter]] <= 0;
        end
        if (dest_candidate_valid_2) begin
            recent_dests_2[dest_candidate_2] <= 1;
        end
    end


    reg [NUM_PORT_LOG-1:0] buf_data1 = 0;
    reg [NUM_PORT_LOG-1:0] buf_data2 = 0;
    reg                    buf_val1  = 0;
    reg                    buf_val2  = 0;

    // Snapshot "new" candidates for readability
    wire                    new_val1 = dest_candidate_valid_1;
    wire [NUM_PORT_LOG-1:0] new_data1 = dest_candidate_1;

    wire                    new_val2 = dest_candidate_valid_2;
    wire [NUM_PORT_LOG-1:0] new_data2 = dest_candidate_2;

    wire [1:0] num_valid_1 = new_val1 + buf_val1;
    wire [1:0] num_valid_2 = new_val2 + buf_val2;





    
    always @(posedge clk) begin
        // defaults each cycle
        dest_valid_reg_1 <= 1'b0;
        dest_valid_reg_2 <= 1'b0;
        dest_ready_1     <= 1'b0;
        dest_ready_2     <= 1'b0;
        current_dests_valid_1[final_stage_counter] <= 1'b0;
        current_dests_valid_2[final_stage_counter] <= 1'b0;


        if ((num_valid_1==2) && (num_valid_2==2)) begin
            // both channels will definitely output
            dest_valid_reg_1 <= 1'b1;
            dest_valid_reg_2 <= 1'b1;
            dest_ready_1     <= 1'b1;
            dest_ready_2     <= 1'b1;
            current_dests_valid_1[final_stage_counter] <= 1'b1;
            current_dests_valid_2[final_stage_counter] <= 1'b1;

            if (buf_data1 != buf_data2) begin
                // send both buffers
                dest_reg_1 <= buf_data1;
                current_dests_1[final_stage_counter] <= buf_data1;

                dest_reg_2 <= buf_data2;
                current_dests_2[final_stage_counter] <= buf_data2;

                // rotate buffers with new arrivals
                buf_data1 <= new_data1; buf_val1 <= 1'b1;
                buf_data2 <= new_data2; buf_val2 <= 1'b1;

            end else if (buf_data1 != new_data2) begin
                // ch1: buffer, ch2: new2
                dest_reg_1 <= buf_data1;
                current_dests_1[final_stage_counter] <= buf_data1;

                dest_reg_2 <= new_data2;
                current_dests_2[final_stage_counter] <= new_data2;

                // refill ch1 buffer with new1, ch2 keeps buffer
                buf_data1 <= new_data1; buf_val1 <= 1'b1;

            end else if (new_data1 != buf_data2) begin
                // ch1: new1, ch2: buffer
                dest_reg_1 <= new_data1;
                current_dests_1[final_stage_counter] <= new_data1;

                dest_reg_2 <= buf_data2;
                current_dests_2[final_stage_counter] <= buf_data2;

                // refill ch2 buffer with new2
                buf_data2 <= new_data2; buf_val2 <= 1'b1;

            end else begin
                // only remaining case: new1 != new2
                dest_reg_1 <= new_data1;
                current_dests_1[final_stage_counter] <= new_data1;

                dest_reg_2 <= new_data2;
                current_dests_2[final_stage_counter] <= new_data2;

                // keep both buffers intact
            end

        end else if ((num_valid_1==2) && (num_valid_2==1)) begin
            // both channels will output this cycle
            dest_valid_reg_1 <= 1'b1;
            dest_valid_reg_2 <= 1'b1;
            dest_ready_1     <= 1'b1;
            dest_ready_2     <= 1'b1;
            current_dests_valid_1[final_stage_counter] <= 1'b1;
            current_dests_valid_2[final_stage_counter] <= 1'b1;

            if (buf_val2) begin
                
                dest_reg_2 <= buf_data2;
                current_dests_2[final_stage_counter] <= buf_data2;
                buf_val2  <= 1'b0;

                if (buf_data1 != buf_data2) begin
                    // ch1: buffer; ch2: buffer
                    dest_reg_1 <= buf_data1;
                    current_dests_1[final_stage_counter] <= buf_data1;

                    // rotate ch1 buffer; ch2 buffer consumed
                    buf_data1 <= new_data1; buf_val1 <= 1'b1;

                end else begin
                    // conflict → ch1: new1; ch2: buffer
                    dest_reg_1 <= new_data1;
                    current_dests_1[final_stage_counter] <= new_data1;

                end
            end else begin
                
                dest_reg_2 <= new_data2;
                current_dests_2[final_stage_counter] <= new_data2;

                if (buf_data1 != new_data2) begin
                    // ch1: buffer; ch2: new2
                    dest_reg_1 <= buf_data1;
                    current_dests_1[final_stage_counter] <= buf_data1;

                    // rotate ch1 buffer
                    buf_data1 <= new_data1; buf_val1 <= 1'b1;

                end else begin
                    // conflict → ch1: new1; ch2: new2
                    dest_reg_1 <= new_data1;
                    current_dests_1[final_stage_counter] <= new_data1;

                end
            end
        end else if ((num_valid_1==1) && (num_valid_2==2)) begin
            // both channels will output this cycle
            dest_valid_reg_1 <= 1'b1;
            dest_valid_reg_2 <= 1'b1;
            dest_ready_1     <= 1'b1;
            dest_ready_2     <= 1'b1;
            current_dests_valid_1[final_stage_counter] <= 1'b1;
            current_dests_valid_2[final_stage_counter] <= 1'b1;

            if (buf_val1) begin
                // ch1 uses buf1 only
                dest_reg_1 <= buf_data1;
                current_dests_1[final_stage_counter] <= buf_data1;
                buf_val1 <= 1'b0;

                if (buf_data1 != buf_data2) begin
                    // ch1: buffer; ch2: buffer
                    

                    dest_reg_2 <= buf_data2;
                    current_dests_2[final_stage_counter] <= buf_data2;

                    // ch1 buffer consumed; rotate ch2 buffer
                    
                    buf_data2 <= new_data2; buf_val2 <= 1'b1;

                end else begin
      
                    dest_reg_2 <= new_data2;
                    current_dests_2[final_stage_counter] <= new_data2;
                    
                end
            end else begin

                current_dests_1[final_stage_counter] <= new_data1;
                dest_reg_1 <= new_data1;

                if (new_data1 != buf_data2) begin
                    // ch1: new1; ch2: buffer

                    dest_reg_2 <= buf_data2;
                    current_dests_2[final_stage_counter] <= buf_data2;

                    // rotate ch2 buffer
                    buf_data2 <= new_data2; buf_val2 <= 1'b1;

                end else begin
                    
                    dest_reg_2 <= new_data2;
                    current_dests_2[final_stage_counter] <= new_data2;

                end
            end

        end else if ((num_valid_1==1) && (num_valid_2==1)) begin
            if (buf_val1 && buf_val2) begin
                if (buf_data1 != buf_data2) begin
                    // both buffers, different
                    dest_reg_1       <= buf_data1;  dest_valid_reg_1 <= 1'b1; dest_ready_1 <= 1'b1;
                    current_dests_1      [final_stage_counter] <= buf_data1;
                    current_dests_valid_1[final_stage_counter] <= 1'b1;

                    dest_reg_2       <= buf_data2;  dest_valid_reg_2 <= 1'b1; dest_ready_2 <= 1'b1;
                    current_dests_2      [final_stage_counter] <= buf_data2;
                    current_dests_valid_2[final_stage_counter] <= 1'b1;

                    buf_val1 <= 1'b0; buf_val2 <= 1'b0; // both consumed
                end else begin
                    // both buffers, same → ch1 wins, ch2 stalls (keeps buffer)
                    dest_reg_1       <= buf_data1;  dest_valid_reg_1 <= 1'b1; dest_ready_1 <= 1'b1;
                    current_dests_1      [final_stage_counter] <= buf_data1;
                    current_dests_valid_1[final_stage_counter] <= 1'b1;

                    dest_ready_2 <= 1'b0; // no output for ch2
                    // buf2 remains set
                    // if new2 existed (it doesn't in 1-of-total), nothing to do
                end

            end else if (buf_val1 && new_val2) begin
                if (buf_data1 != new_data2) begin
                    // ch1: buffer; ch2: new2
                    dest_reg_1       <= buf_data1;  dest_valid_reg_1 <= 1'b1; dest_ready_1 <= 1'b1;
                    current_dests_1      [final_stage_counter] <= buf_data1;
                    current_dests_valid_1[final_stage_counter] <= 1'b1;

                    dest_reg_2       <= new_data2;  dest_valid_reg_2 <= 1'b1; dest_ready_2 <= 1'b1;
                    current_dests_2      [final_stage_counter] <= new_data2;
                    current_dests_valid_2[final_stage_counter] <= 1'b1;

                    buf_val1 <= 1'b0; // ch1 buffer consumed
                    // ch2 had no buffer

                end else begin
                    // conflict → ch1 outputs; ch2 stalls, buffer the new2
                    dest_reg_1       <= buf_data1;  dest_valid_reg_1 <= 1'b1; dest_ready_1 <= 1'b1;
                    current_dests_1      [final_stage_counter] <= buf_data1;
                    current_dests_valid_1[final_stage_counter] <= 1'b1;

                    dest_ready_2 <= 1'b0;
                    // buffer ch2 new
                    buf_data2 <= new_data2; buf_val2 <= 1'b1;
                    // ch1 buffer consumed
                    buf_val1 <= 1'b0;
                end

            end else if (new_val1 && buf_val2) begin
                if (new_data1 != buf_data2) begin
                    // ch1: new1; ch2: buffer
                    dest_reg_1       <= new_data1;  dest_valid_reg_1 <= 1'b1; dest_ready_1 <= 1'b1;
                    current_dests_1      [final_stage_counter] <= new_data1;
                    current_dests_valid_1[final_stage_counter] <= 1'b1;

                    dest_reg_2       <= buf_data2;  dest_valid_reg_2 <= 1'b1; dest_ready_2 <= 1'b1;
                    current_dests_2      [final_stage_counter] <= buf_data2;
                    current_dests_valid_2[final_stage_counter] <= 1'b1;

                    buf_val2 <= 1'b0; // ch2 buffer consumed

                end else begin
                    // conflict → ch1 outputs; ch2 stalls (keeps its buffer)
                    dest_reg_1       <= new_data1;  dest_valid_reg_1 <= 1'b1; dest_ready_1 <= 1'b1;
                    current_dests_1      [final_stage_counter] <= new_data1;
                    current_dests_valid_1[final_stage_counter] <= 1'b1;

                    dest_ready_2 <= 1'b0;
                    // ch2 keeps buffer
                end

            end else begin
                // both have only NEW (no buffers)
                if (new_data1 != new_data2) begin
                    dest_reg_1       <= new_data1;  dest_valid_reg_1 <= 1'b1; dest_ready_1 <= 1'b1;
                    current_dests_1      [final_stage_counter] <= new_data1;
                    current_dests_valid_1[final_stage_counter] <= 1'b1;

                    dest_reg_2       <= new_data2;  dest_valid_reg_2 <= 1'b1; dest_ready_2 <= 1'b1;
                    current_dests_2      [final_stage_counter] <= new_data2;
                    current_dests_valid_2[final_stage_counter] <= 1'b1;
                end else begin
                    // same → ch1 wins, ch2 buffers its new
                    dest_reg_1       <= new_data1;  dest_valid_reg_1 <= 1'b1; dest_ready_1 <= 1'b1;
                    current_dests_1      [final_stage_counter] <= new_data1;
                    current_dests_valid_1[final_stage_counter] <= 1'b1;

                    dest_ready_2 <= 1'b0;
                    buf_data2 <= new_data2; buf_val2 <= 1'b1;
                end
            end

        
        end else begin
            
            dest_ready_1 <= 1'b1;
            dest_ready_2 <= 1'b1;
            buf_val1     <= 1'b0;  // clear by default; re-assert only if we purposely (re)buffer
            buf_val2     <= 1'b0;

            // ----------------------
            // Channel 1
            // ----------------------
            if (buf_val1) begin
                // Output buffered dest
                dest_reg_1                               <= buf_data1;
                dest_valid_reg_1                         <= 1'b1;
                current_dests_1      [final_stage_counter] <= buf_data1;
                current_dests_valid_1[final_stage_counter] <= 1'b1;
                // buffer consumed (buf_val1 already cleared)

            end else if (new_val1) begin
                // Output new dest
                dest_reg_1                               <= new_data1;
                dest_valid_reg_1                         <= 1'b1;
                current_dests_1      [final_stage_counter] <= new_data1;
                current_dests_valid_1[final_stage_counter] <= 1'b1;
                // no buffering needed

            end else begin
                // No output on ch1
                dest_valid_reg_1                         <= 1'b0;
                current_dests_valid_1[final_stage_counter] <= 1'b0;
            end

            // ----------------------
            // Channel 2
            // ----------------------
            if (buf_val2) begin
                // Output buffered dest
                dest_reg_2                               <= buf_data2;
                dest_valid_reg_2                         <= 1'b1;
                current_dests_2      [final_stage_counter] <= buf_data2;
                current_dests_valid_2[final_stage_counter] <= 1'b1;
                // buffer consumed (buf_val2 already cleared)

            end else if (new_val2) begin
                // Output new dest
                dest_reg_2                               <= new_data2;
                dest_valid_reg_2                         <= 1'b1;
                current_dests_2      [final_stage_counter] <= new_data2;
                current_dests_valid_2[final_stage_counter] <= 1'b1;
                // no buffering needed

            end else begin
                // No output on ch2
                dest_valid_reg_2                         <= 1'b0;
                current_dests_valid_2[final_stage_counter] <= 1'b0;
            end
        end

    end






    // first_none_zero_except_k for channel 1
    first_none_zero_except_k #(
        .N(NUM_PORT)
    ) u_first_none_zero_except_k_1 (
        .clk          (clk),
        .data_i       (possible_dests_1),
        .ready_o      (dest_ready_1),
        .data_o       (dest_candidate_1),
        .data_valid_o (dest_candidate_valid_1)
    );

    // first_none_zero_except_k for channel 2
    first_none_zero_except_k #(
        .N(NUM_PORT)
    ) u_first_none_zero_except_k_2 (
        .clk          (clk),
        .data_i       (possible_dests_2),
        .ready_o      (dest_ready_2),
        .data_o       (dest_candidate_2),
        .data_valid_o (dest_candidate_valid_2)
    );

    //==========================================================================
    // Functions
    //==========================================================================
    function automatic int rr_index(input int port_index, input int delay_val);
        return (port_index + delay_val + 10*S) % S;
    endfunction

endmodule


`default_nettype wire 