`timescale 1ns / 1ps
// `default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Company: IUST
// Engineer: Parham Soltani
//
// Create Date:  2025-11-25
// Module Name: first_none_zero_except_k_qos
// Description: QoS-aware priority encoder that finds the highest priority
//              non-zero bit, with fallback to round-robin for equal priorities
// Dependencies:
//
// Additional Comments:
// - When qos_enable=1, selects the port with highest QoS priority (lowest value)
// - When qos_enable=0, behaves like standard first_none_zero_except_k
//////////////////////////////////////////////////////////////////////////////////

`include "fabric_params.vh"

module first_none_zero_except_k_qos #(
    parameter int N              = 64,
    parameter int META_DATA_WIDTH = 32,
    parameter int QOS_TAG_WIDTH  = 3,
    // DO NOT CHANGE BELOW
    parameter int LOGN = $clog2(N)
) (
    input  wire                         clk,
    input  wire [N-1:0]                 data_i,
    input  wire [META_DATA_WIDTH-1:0]   metadata_i [N],
    input  wire                         qos_enable,
    input  wire                         ready_o,
    output wire [LOGN-1:0]              data_o,
    output wire [QOS_TAG_WIDTH-1:0]     qos_o,
    output wire                         data_valid_o
);

    localparam QOS_OFFSET = `META_QOS_OFFSET;
    localparam QOS_LEVELS = (1 << QOS_TAG_WIDTH);

    // Internal registers
    reg [LOGN-1:0]          none_zero_reg = '0;
    reg [LOGN-1:0]          prev_index_reg = '0;
    reg                     valid_o_reg = '0;
    reg [QOS_TAG_WIDTH-1:0] qos_reg = '0;

    // Combinational search results
    reg [LOGN-1:0]          comb_idx;
    reg                     comb_valid;
    reg [QOS_TAG_WIDTH-1:0] comb_qos;

    //==========================================================================
    // QoS Extraction Helper
    //==========================================================================
    function automatic logic [QOS_TAG_WIDTH-1:0] extract_qos(
        input logic [META_DATA_WIDTH-1:0] meta
    );
        logic [QOS_TAG_WIDTH-1:0] qos_val;
        qos_val = meta[QOS_OFFSET +: QOS_TAG_WIDTH];
        return (qos_val >= QOS_LEVELS) ? (QOS_LEVELS - 1) : qos_val;
    endfunction

    //==========================================================================
    // Priority Selection Logic
    //==========================================================================
    always @(*) begin
        comb_idx   = '0;
        comb_valid = 1'b0;
        comb_qos   = '1;  // Start with lowest priority (highest value)

        if (qos_enable) begin
            // QoS-aware selection: find highest priority (lowest QoS value)
            for (int i = 0; i < N; i++) begin
                if (data_i[i]) begin
                    // Skip previous index unless it's the only option
                    if (!(valid_o_reg && (i[LOGN-1:0] == prev_index_reg))) begin
                        logic [QOS_TAG_WIDTH-1:0] port_qos;
                        port_qos = extract_qos(metadata_i[i]);
                        
                        // Select if higher priority (lower value) or first valid
                        if (!comb_valid || (port_qos < comb_qos)) begin
                            comb_idx   = i[LOGN-1:0];
                            comb_valid = 1'b1;
                            comb_qos   = port_qos;
                        end
                    end
                end
            end
            
            // Fallback: if only prev_index is available, use it
            if (!comb_valid && valid_o_reg && data_i[prev_index_reg]) begin
                comb_idx   = prev_index_reg;
                comb_valid = 1'b1;
                comb_qos   = extract_qos(metadata_i[prev_index_reg]);
            end
            
        end else begin
            // Standard first-match (no QoS)
            for (int i = 0; i < N; i++) begin
                if (data_i[i] && !comb_valid) begin
                    if (!(valid_o_reg && (i[LOGN-1:0] == prev_index_reg))) begin
                        comb_idx   = i[LOGN-1:0];
                        comb_valid = 1'b1;
                        comb_qos   = extract_qos(metadata_i[i]);
                    end
                end
            end
            
            // Fallback
            if (!comb_valid && valid_o_reg && data_i[prev_index_reg]) begin
                comb_idx   = prev_index_reg;
                comb_valid = 1'b1;
                comb_qos   = extract_qos(metadata_i[prev_index_reg]);
            end
        end
    end

    //==========================================================================
    // Output Assignments
    //==========================================================================
    assign data_o       = none_zero_reg;
    assign data_valid_o = valid_o_reg;
    assign qos_o        = qos_reg;

    //==========================================================================
    // Register Update
    //==========================================================================
    always @(posedge clk) begin
        if (ready_o) begin
            if (comb_valid) begin
                valid_o_reg    <= 1'b1;
                none_zero_reg  <= comb_idx;
                prev_index_reg <= comb_idx;
                qos_reg        <= comb_qos;
            end else begin
                valid_o_reg <= 1'b0;
            end
        end
    end

endmodule

`default_nettype wire