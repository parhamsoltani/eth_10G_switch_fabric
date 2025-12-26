`timescale 1ns / 1ps
// `default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Company: IUST
// Engineer: Parham Soltani
//
// Create Date:  2025-11-25
// Module Name: dest_finder_row_matching_qos
// Project Name:
// Target Devices:
// Tool Versions: Vivado 2022.2
// Description: QoS-aware dual-channel matching arbiter
// Extends dest_finder_row_matching.sv with priority-based selection
// Dependencies:
//
// Additional Comments:
// - Maintains 2-channel matching for conflict resolution
// - Adds QoS priority preemption
// - Preserves all timing characteristics of original design
// - FIXED: Added metadata input ports for QoS extraction
//////////////////////////////////////////////////////////////////////////////////

`include "fabric_params.vh"
`include "qos_defines.vh"

module dest_finder_row_matching_qos #(
    parameter   NUM_PORT                = 10,
    parameter   S                       = 10,
    parameter   ROW_RTT_DELAY           = 6,
    parameter   QOS_LEVELS              = `QOS_LEVELS,
    parameter   QOS_TAG_WIDTH           = `QOS_TAG_WIDTH,
    parameter   META_DATA_WIDTH         = `META_DATA_WIDTH,
    // DO NOT CHANGE
    parameter   S_LOG                   = $clog2(S),
    parameter   NUM_PORT_LOG            = $clog2(NUM_PORT)
) (
    input  wire                     clk,

    // Channel 1 inputs
    input  wire [NUM_PORT-1:0]      none_mepty_ports_1,
    input  wire [META_DATA_WIDTH-1:0] metadata_1 [NUM_PORT],  // ← ADDED

    // Channel 2 inputs
    input  wire [NUM_PORT-1:0]      none_mepty_ports_2,
    input  wire [META_DATA_WIDTH-1:0] metadata_2 [NUM_PORT],  // ← ADDED

    // Shared inputs
    input  wire [NUM_PORT-1:0]      block_ports,
    input  wire                     dfifo_last_1,
    input  wire                     dfifo_last_2,

    // Enable/disable QoS-aware selection
    input  wire                     qos_enable,

    // Outputs (same as original)
    output wire                     dest_valid_o_1,
    output wire                     dest_valid_o_2,
    output wire [NUM_PORT_LOG-1:0]  dest_o_1,
    output wire [NUM_PORT_LOG-1:0]  dest_o_2
);

    //==========================================================================
    // QoS Tag Extraction (from metadata)
    //==========================================================================
    // Metadata structure: {minicells_keep[S], last_keep[KEEP_WIDTH],
    //                       is_bad_frame[1], last_index[S_LOG], qos[QOS_TAG_WIDTH]}
    localparam QOS_OFFSET = `META_QOS_OFFSET;

    function automatic logic [QOS_TAG_WIDTH-1:0] extract_qos(
        input logic [META_DATA_WIDTH-1:0] meta
    );
        logic [QOS_TAG_WIDTH-1:0] qos_val;
        qos_val = meta[QOS_OFFSET +: QOS_TAG_WIDTH];
        // Clamp to valid range
        return (qos_val >= QOS_LEVELS) ? (QOS_LEVELS - 1) : qos_val;
    endfunction

    //==========================================================================
    // QoS Priority Comparison (lower value = higher priority)
    //==========================================================================
    function automatic logic qos_higher_priority(
        input logic [QOS_TAG_WIDTH-1:0] qos_a,
        input logic [QOS_TAG_WIDTH-1:0] qos_b
    );
        return (qos_a < qos_b);
    endfunction

    //==========================================================================
    // Shared RR Timing Wheel (same as original)
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
    wire [S_LOG-1:0] free_recent_counter   = rr_counter[rr_index(0, S-3)];

    //==========================================================================
    // Channel 1 State
    //==========================================================================
    reg                        dest_valid_reg_1 = 0;
    reg [NUM_PORT_LOG-1:0]     dest_reg_1       = 0;
    reg [NUM_PORT-1:0]         possible_dests_1 = 0;
    reg [NUM_PORT-1:0]         recent_dests_1   = 0;

    wire [NUM_PORT_LOG-1:0]    dest_candidate_1;
    wire                       dest_candidate_valid_1;
    wire [QOS_TAG_WIDTH-1:0]   dest_candidate_qos_1;

    reg [NUM_PORT_LOG-1:0]     current_dests_1 [S] = '{default:'0};
    reg                        current_dests_valid_1 [S] = '{default:'0};
    reg                        dest_ready_1;

    assign dest_valid_o_1 = dest_valid_reg_1;
    assign dest_o_1       = dest_reg_1;

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
    // Channel 2 State
    //==========================================================================
    reg                        dest_valid_reg_2 = 0;
    reg [NUM_PORT_LOG-1:0]     dest_reg_2       = 0;
    reg [NUM_PORT-1:0]         possible_dests_2 = 0;
    reg [NUM_PORT-1:0]         recent_dests_2   = 0;

    wire [NUM_PORT_LOG-1:0]    dest_candidate_2;
    wire                       dest_candidate_valid_2;
    wire [QOS_TAG_WIDTH-1:0]   dest_candidate_qos_2;

    reg [NUM_PORT_LOG-1:0]     current_dests_2 [S] = '{default:'0};
    reg                        current_dests_valid_2 [S] = '{default:'0};
    reg                        dest_ready_2;

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

    //==========================================================================
    // Buffering State
    //==========================================================================
    reg [NUM_PORT_LOG-1:0]     buf_data1 = 0;
    reg [NUM_PORT_LOG-1:0]     buf_data2 = 0;
    reg                        buf_val1  = 0;
    reg                        buf_val2  = 0;
    reg [QOS_TAG_WIDTH-1:0]    buf_qos1  = '0;
    reg [QOS_TAG_WIDTH-1:0]    buf_qos2  = '0;

    // Snapshot new candidates
    wire                       new_val1  = dest_candidate_valid_1;
    wire [NUM_PORT_LOG-1:0]    new_data1 = dest_candidate_1;
    wire [QOS_TAG_WIDTH-1:0]   new_qos1  = dest_candidate_qos_1;

    wire                       new_val2  = dest_candidate_valid_2;
    wire [NUM_PORT_LOG-1:0]    new_data2 = dest_candidate_2;
    wire [QOS_TAG_WIDTH-1:0]   new_qos2  = dest_candidate_qos_2;

    wire [1:0] num_valid_1 = new_val1 + buf_val1;
    wire [1:0] num_valid_2 = new_val2 + buf_val2;

    //==========================================================================
    // QoS-AWARE ARBITRATION LOGIC
    //==========================================================================

    always @(posedge clk) begin
        // Defaults
        dest_valid_reg_1 <= 1'b0;
        dest_valid_reg_2 <= 1'b0;
        dest_ready_1     <= 1'b0;
        dest_ready_2     <= 1'b0;
        current_dests_valid_1[final_stage_counter] <= 1'b0;
        current_dests_valid_2[final_stage_counter] <= 1'b0;

        //======================================================================
        // CASE 1: Both channels have 2 candidates
        //======================================================================
        if ((num_valid_1 == 2) && (num_valid_2 == 2)) begin
            dest_valid_reg_1 <= 1'b1;
            dest_valid_reg_2 <= 1'b1;
            dest_ready_1     <= 1'b1;
            dest_ready_2     <= 1'b1;
            current_dests_valid_1[final_stage_counter] <= 1'b1;
            current_dests_valid_2[final_stage_counter] <= 1'b1;

            if (buf_data1 != buf_data2) begin
                dest_reg_1 <= buf_data1;
                current_dests_1[final_stage_counter] <= buf_data1;
                dest_reg_2 <= buf_data2;
                current_dests_2[final_stage_counter] <= buf_data2;
                buf_data1 <= new_data1; buf_val1 <= 1'b1; buf_qos1 <= new_qos1;
                buf_data2 <= new_data2; buf_val2 <= 1'b1; buf_qos2 <= new_qos2;

            end else if (buf_data1 != new_data2) begin
                dest_reg_1 <= buf_data1;
                current_dests_1[final_stage_counter] <= buf_data1;
                dest_reg_2 <= new_data2;
                current_dests_2[final_stage_counter] <= new_data2;
                buf_data1 <= new_data1; buf_val1 <= 1'b1; buf_qos1 <= new_qos1;

            end else if (new_data1 != buf_data2) begin
                dest_reg_1 <= new_data1;
                current_dests_1[final_stage_counter] <= new_data1;
                dest_reg_2 <= buf_data2;
                current_dests_2[final_stage_counter] <= buf_data2;
                buf_data2 <= new_data2; buf_val2 <= 1'b1; buf_qos2 <= new_qos2;

            end else begin
                // QoS-AWARE: Swap if new2 has higher priority
                if (qos_enable && qos_higher_priority(new_qos2, new_qos1)) begin
                    dest_reg_1 <= new_data2;
                    current_dests_1[final_stage_counter] <= new_data2;
                    dest_reg_2 <= new_data1;
                    current_dests_2[final_stage_counter] <= new_data1;
                end else begin
                    dest_reg_1 <= new_data1;
                    current_dests_1[final_stage_counter] <= new_data1;
                    dest_reg_2 <= new_data2;
                    current_dests_2[final_stage_counter] <= new_data2;
                end
            end

        //======================================================================
        // CASE 2: Ch1 has 2, Ch2 has 1
        //======================================================================
        end else if ((num_valid_1 == 2) && (num_valid_2 == 1)) begin
            dest_valid_reg_1 <= 1'b1;
            dest_valid_reg_2 <= 1'b1;
            dest_ready_1     <= 1'b1;
            dest_ready_2     <= 1'b1;
            current_dests_valid_1[final_stage_counter] <= 1'b1;
            current_dests_valid_2[final_stage_counter] <= 1'b1;

            if (buf_val2) begin
                dest_reg_2 <= buf_data2;
                current_dests_2[final_stage_counter] <= buf_data2;
                buf_val2 <= 1'b0;

                if (buf_data1 != buf_data2) begin
                    dest_reg_1 <= buf_data1;
                    current_dests_1[final_stage_counter] <= buf_data1;
                    buf_data1 <= new_data1; buf_val1 <= 1'b1; buf_qos1 <= new_qos1;
                end else begin
                    if (qos_enable && qos_higher_priority(new_qos1, buf_qos1)) begin
                        dest_reg_1 <= new_data1;
                        current_dests_1[final_stage_counter] <= new_data1;
                    end else begin
                        dest_reg_1 <= buf_data1;
                        current_dests_1[final_stage_counter] <= buf_data1;
                        buf_data1 <= new_data1; buf_val1 <= 1'b1; buf_qos1 <= new_qos1;
                    end
                end

            end else begin
                dest_reg_2 <= new_data2;
                current_dests_2[final_stage_counter] <= new_data2;

                if (buf_data1 != new_data2) begin
                    dest_reg_1 <= buf_data1;
                    current_dests_1[final_stage_counter] <= buf_data1;
                    buf_data1 <= new_data1; buf_val1 <= 1'b1; buf_qos1 <= new_qos1;
                end else begin
                    if (qos_enable && qos_higher_priority(new_qos1, buf_qos1)) begin
                        dest_reg_1 <= new_data1;
                        current_dests_1[final_stage_counter] <= new_data1;
                    end else begin
                        dest_reg_1 <= buf_data1;
                        current_dests_1[final_stage_counter] <= buf_data1;
                        buf_data1 <= new_data1; buf_val1 <= 1'b1; buf_qos1 <= new_qos1;
                    end
                end
            end

        //======================================================================
        // CASE 3: Ch1 has 1, Ch2 has 2
        //======================================================================
        end else if ((num_valid_1 == 1) && (num_valid_2 == 2)) begin
            dest_valid_reg_1 <= 1'b1;
            dest_valid_reg_2 <= 1'b1;
            dest_ready_1     <= 1'b1;
            dest_ready_2     <= 1'b1;
            current_dests_valid_1[final_stage_counter] <= 1'b1;
            current_dests_valid_2[final_stage_counter] <= 1'b1;

            if (buf_val1) begin
                dest_reg_1 <= buf_data1;
                current_dests_1[final_stage_counter] <= buf_data1;
                buf_val1 <= 1'b0;

                if (buf_data1 != buf_data2) begin
                    dest_reg_2 <= buf_data2;
                    current_dests_2[final_stage_counter] <= buf_data2;
                    buf_data2 <= new_data2; buf_val2 <= 1'b1; buf_qos2 <= new_qos2;
                end else begin
                    if (qos_enable && qos_higher_priority(new_qos2, buf_qos2)) begin
                        dest_reg_2 <= new_data2;
                        current_dests_2[final_stage_counter] <= new_data2;
                    end else begin
                        dest_reg_2 <= buf_data2;
                        current_dests_2[final_stage_counter] <= buf_data2;
                        buf_data2 <= new_data2; buf_val2 <= 1'b1; buf_qos2 <= new_qos2;
                    end
                end

            end else begin
                dest_reg_1 <= new_data1;
                current_dests_1[final_stage_counter] <= new_data1;

                if (new_data1 != buf_data2) begin
                    dest_reg_2 <= buf_data2;
                    current_dests_2[final_stage_counter] <= buf_data2;
                    buf_data2 <= new_data2; buf_val2 <= 1'b1; buf_qos2 <= new_qos2;
                end else begin
                    if (qos_enable && qos_higher_priority(new_qos2, buf_qos2)) begin
                        dest_reg_2 <= new_data2;
                        current_dests_2[final_stage_counter] <= new_data2;
                    end else begin
                        dest_reg_2 <= buf_data2;
                        current_dests_2[final_stage_counter] <= buf_data2;
                        buf_data2 <= new_data2; buf_val2 <= 1'b1; buf_qos2 <= new_qos2;
                    end
                end
            end

        //======================================================================
        // CASE 4: Both have exactly 1
        //======================================================================
        end else if ((num_valid_1 == 1) && (num_valid_2 == 1)) begin
            if (buf_val1 && buf_val2) begin
                if (buf_data1 != buf_data2) begin
                    if (qos_enable && qos_higher_priority(buf_qos2, buf_qos1)) begin
                        dest_reg_1 <= buf_data2; dest_valid_reg_1 <= 1'b1; dest_ready_1 <= 1'b1;
                        current_dests_1[final_stage_counter] <= buf_data2;
                        current_dests_valid_1[final_stage_counter] <= 1'b1;
                        dest_reg_2 <= buf_data1; dest_valid_reg_2 <= 1'b1; dest_ready_2 <= 1'b1;
                        current_dests_2[final_stage_counter] <= buf_data1;
                        current_dests_valid_2[final_stage_counter] <= 1'b1;
                    end else begin
                        dest_reg_1 <= buf_data1; dest_valid_reg_1 <= 1'b1; dest_ready_1 <= 1'b1;
                        current_dests_1[final_stage_counter] <= buf_data1;
                        current_dests_valid_1[final_stage_counter] <= 1'b1;
                        dest_reg_2 <= buf_data2; dest_valid_reg_2 <= 1'b1; dest_ready_2 <= 1'b1;
                        current_dests_2[final_stage_counter] <= buf_data2;
                        current_dests_valid_2[final_stage_counter] <= 1'b1;
                    end
                    buf_val1 <= 1'b0; buf_val2 <= 1'b0;

                end else begin
                    if (qos_enable && qos_higher_priority(buf_qos2, buf_qos1)) begin
                        dest_reg_1 <= buf_data2; dest_valid_reg_1 <= 1'b1; dest_ready_1 <= 1'b1;
                        current_dests_1[final_stage_counter] <= buf_data2;
                        current_dests_valid_1[final_stage_counter] <= 1'b1;
                        dest_ready_2 <= 1'b0;
                        buf_val2 <= 1'b0;
                    end else begin
                        dest_reg_1 <= buf_data1; dest_valid_reg_1 <= 1'b1; dest_ready_1 <= 1'b1;
                        current_dests_1[final_stage_counter] <= buf_data1;
                        current_dests_valid_1[final_stage_counter] <= 1'b1;
                        dest_ready_2 <= 1'b0;
                        buf_val1 <= 1'b0;
                    end
                end

            end else if (buf_val1 && new_val2) begin
                if (buf_data1 != new_data2) begin
                    if (qos_enable && qos_higher_priority(new_qos2, buf_qos1)) begin
                        dest_reg_1 <= new_data2; dest_valid_reg_1 <= 1'b1; dest_ready_1 <= 1'b1;
                        current_dests_1[final_stage_counter] <= new_data2;
                        current_dests_valid_1[final_stage_counter] <= 1'b1;
                        dest_reg_2 <= buf_data1; dest_valid_reg_2 <= 1'b1; dest_ready_2 <= 1'b1;
                        current_dests_2[final_stage_counter] <= buf_data1;
                        current_dests_valid_2[final_stage_counter] <= 1'b1;
                        buf_val1 <= 1'b0;
                    end else begin
                        dest_reg_1 <= buf_data1; dest_valid_reg_1 <= 1'b1; dest_ready_1 <= 1'b1;
                        current_dests_1[final_stage_counter] <= buf_data1;
                        current_dests_valid_1[final_stage_counter] <= 1'b1;
                        dest_reg_2 <= new_data2; dest_valid_reg_2 <= 1'b1; dest_ready_2 <= 1'b1;
                        current_dests_2[final_stage_counter] <= new_data2;
                        current_dests_valid_2[final_stage_counter] <= 1'b1;
                        buf_val1 <= 1'b0;
                    end

                end else begin
                    if (qos_enable && qos_higher_priority(new_qos2, buf_qos1)) begin
                        dest_reg_1 <= new_data2; dest_valid_reg_1 <= 1'b1; dest_ready_1 <= 1'b1;
                        current_dests_1[final_stage_counter] <= new_data2;
                        current_dests_valid_1[final_stage_counter] <= 1'b1;
                        dest_ready_2 <= 1'b0;
                        buf_data2 <= buf_data1; buf_val2 <= 1'b1; buf_qos2 <= buf_qos1;
                        buf_val1 <= 1'b0;
                    end else begin
                        dest_reg_1 <= buf_data1; dest_valid_reg_1 <= 1'b1; dest_ready_1 <= 1'b1;
                        current_dests_1[final_stage_counter] <= buf_data1;
                        current_dests_valid_1[final_stage_counter] <= 1'b1;
                        dest_ready_2 <= 1'b0;
                        buf_data2 <= new_data2; buf_val2 <= 1'b1; buf_qos2 <= new_qos2;
                        buf_val1 <= 1'b0;
                    end
                end

            end else if (new_val1 && buf_val2) begin
                if (new_data1 != buf_data2) begin
                    if (qos_enable && qos_higher_priority(buf_qos2, new_qos1)) begin
                        dest_reg_1 <= buf_data2; dest_valid_reg_1 <= 1'b1; dest_ready_1 <= 1'b1;
                        current_dests_1[final_stage_counter] <= buf_data2;
                        current_dests_valid_1[final_stage_counter] <= 1'b1;
                        dest_reg_2 <= new_data1; dest_valid_reg_2 <= 1'b1; dest_ready_2 <= 1'b1;
                        current_dests_2[final_stage_counter] <= new_data1;
                        current_dests_valid_2[final_stage_counter] <= 1'b1;
                        buf_val2 <= 1'b0;
                    end else begin
                        dest_reg_1 <= new_data1; dest_valid_reg_1 <= 1'b1; dest_ready_1 <= 1'b1;
                        current_dests_1[final_stage_counter] <= new_data1;
                        current_dests_valid_1[final_stage_counter] <= 1'b1;
                        dest_reg_2 <= buf_data2; dest_valid_reg_2 <= 1'b1; dest_ready_2 <= 1'b1;
                        current_dests_2[final_stage_counter] <= buf_data2;
                        current_dests_valid_2[final_stage_counter] <= 1'b1;
                        buf_val2 <= 1'b0;
                    end

                end else begin
                    if (qos_enable && qos_higher_priority(buf_qos2, new_qos1)) begin
                        dest_reg_1 <= buf_data2; dest_valid_reg_1 <= 1'b1; dest_ready_1 <= 1'b1;
                        current_dests_1[final_stage_counter] <= buf_data2;
                        current_dests_valid_1[final_stage_counter] <= 1'b1;
                        dest_ready_2 <= 1'b0;
                        buf_data1 <= new_data1; buf_val1 <= 1'b1; buf_qos1 <= new_qos1;
                        buf_val2 <= 1'b0;
                    end else begin
                        dest_reg_1 <= new_data1; dest_valid_reg_1 <= 1'b1; dest_ready_1 <= 1'b1;
                        current_dests_1[final_stage_counter] <= new_data1;
                        current_dests_valid_1[final_stage_counter] <= 1'b1;
                        dest_ready_2 <= 1'b0;
                    end
                end

            end else begin
                if (new_data1 != new_data2) begin
                    if (qos_enable && qos_higher_priority(new_qos2, new_qos1)) begin
                        dest_reg_1 <= new_data2; dest_valid_reg_1 <= 1'b1; dest_ready_1 <= 1'b1;
                        current_dests_1[final_stage_counter] <= new_data2;
                        current_dests_valid_1[final_stage_counter] <= 1'b1;
                        dest_reg_2 <= new_data1; dest_valid_reg_2 <= 1'b1; dest_ready_2 <= 1'b1;
                        current_dests_2[final_stage_counter] <= new_data1;
                        current_dests_valid_2[final_stage_counter] <= 1'b1;
                    end else begin
                        dest_reg_1 <= new_data1; dest_valid_reg_1 <= 1'b1; dest_ready_1 <= 1'b1;
                        current_dests_1[final_stage_counter] <= new_data1;
                        current_dests_valid_1[final_stage_counter] <= 1'b1;
                        dest_reg_2 <= new_data2; dest_valid_reg_2 <= 1'b1; dest_ready_2 <= 1'b1;
                        current_dests_2[final_stage_counter] <= new_data2;
                        current_dests_valid_2[final_stage_counter] <= 1'b1;
                    end

                end else begin
                    if (qos_enable && qos_higher_priority(new_qos2, new_qos1)) begin
                        dest_reg_1 <= new_data2; dest_valid_reg_1 <= 1'b1; dest_ready_1 <= 1'b1;
                        current_dests_1[final_stage_counter] <= new_data2;
                        current_dests_valid_1[final_stage_counter] <= 1'b1;
                        dest_ready_2 <= 1'b0;
                        buf_data2 <= new_data1; buf_val2 <= 1'b1; buf_qos2 <= new_qos1;
                    end else begin
                        dest_reg_1 <= new_data1; dest_valid_reg_1 <= 1'b1; dest_ready_1 <= 1'b1;
                        current_dests_1[final_stage_counter] <= new_data1;
                        current_dests_valid_1[final_stage_counter] <= 1'b1;
                        dest_ready_2 <= 1'b0;
                        buf_data2 <= new_data2; buf_val2 <= 1'b1; buf_qos2 <= new_qos2;
                    end
                end
            end

        //======================================================================
        // CASE 5: Fewer than 2 total candidates
        //======================================================================
        end else begin
            dest_ready_1 <= 1'b1;
            dest_ready_2 <= 1'b1;
            buf_val1     <= 1'b0;
            buf_val2     <= 1'b0;

            if (buf_val1) begin
                dest_reg_1 <= buf_data1; dest_valid_reg_1 <= 1'b1;
                current_dests_1[final_stage_counter] <= buf_data1;
                current_dests_valid_1[final_stage_counter] <= 1'b1;
            end else if (new_val1) begin
                dest_reg_1 <= new_data1; dest_valid_reg_1 <= 1'b1;
                current_dests_1[final_stage_counter] <= new_data1;
                current_dests_valid_1[final_stage_counter] <= 1'b1;
            end else begin
                dest_valid_reg_1 <= 1'b0;
                current_dests_valid_1[final_stage_counter] <= 1'b0;
            end

            if (buf_val2) begin
                dest_reg_2 <= buf_data2; dest_valid_reg_2 <= 1'b1;
                current_dests_2[final_stage_counter] <= buf_data2;
                current_dests_valid_2[final_stage_counter] <= 1'b1;
            end else if (new_val2) begin
                dest_reg_2 <= new_data2; dest_valid_reg_2 <= 1'b1;
                current_dests_2[final_stage_counter] <= new_data2;
                current_dests_valid_2[final_stage_counter] <= 1'b1;
            end else begin
                dest_valid_reg_2 <= 1'b0;
                current_dests_valid_2[final_stage_counter] <= 1'b0;
            end
        end
    end

    //==========================================================================
    // QoS-AWARE First-Non-Zero Priority Encoders
    //==========================================================================
    first_none_zero_except_k_qos #(
        .N(NUM_PORT),
        .META_DATA_WIDTH(META_DATA_WIDTH),
        .QOS_TAG_WIDTH(QOS_TAG_WIDTH)
    ) u_first_none_zero_qos_1 (
        .clk              (clk),
        .data_i           (possible_dests_1),
        .metadata_i       (metadata_1),          // ← CONNECTED
        .qos_enable       (qos_enable),
        .ready_o          (dest_ready_1),
        .data_o           (dest_candidate_1),
        .qos_o            (dest_candidate_qos_1),
        .data_valid_o     (dest_candidate_valid_1)
    );

    first_none_zero_except_k_qos #(
        .N(NUM_PORT),
        .META_DATA_WIDTH(META_DATA_WIDTH),
        .QOS_TAG_WIDTH(QOS_TAG_WIDTH)
    ) u_first_none_zero_qos_2 (
        .clk              (clk),
        .data_i           (possible_dests_2),
        .metadata_i       (metadata_2),          // ← CONNECTED
        .qos_enable       (qos_enable),
        .ready_o          (dest_ready_2),
        .data_o           (dest_candidate_2),
        .qos_o            (dest_candidate_qos_2),
        .data_valid_o     (dest_candidate_valid_2)
    );

    //==========================================================================
    // Helper Functions
    //==========================================================================
    function automatic int rr_index(input int port_index, input int delay_val);
        return (port_index + delay_val + 10*S) % S;
    endfunction

endmodule

`default_nettype wire