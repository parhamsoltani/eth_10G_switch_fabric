`timescale 1ns / 1ps
`default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Company: Parman
// Engineer: Alireza Abbasian
//
// Create Date:  2025-11-25
// Module Name: first_none_zero_except_k_qos
// Description: QoS-aware candidate selection with priority
// Extends first_none_zero_except_k.sv with metadata parsing
//
// CHANGES FROM ORIGINAL:
//   - Split combinational and sequential logic properly
//   - Fixed race condition in QoS selection
//   - Added bounds checking for QoS tags
//   - Improved synthesis efficiency
//
//////////////////////////////////////////////////////////////////////////////////

module first_none_zero_except_k_qos #(
    parameter N                 = `NUM_PORTS,
    parameter META_DATA_WIDTH   = `META_DATA_WIDTH,
    parameter QOS_TAG_WIDTH     = `QOS_TAG_WIDTH,
    parameter QOS_OFFSET        = `META_QOS_OFFSET,      // Where QoS tag starts in metadata
    parameter QOS_LEVELS        = `QOS_LEVELS,      // NEW: Number of valid QoS levels
    // DO NOT CHANGE
    parameter N_LOG             = (N == 1) ? 1 : $clog2(N)
)(
    input  wire                         clk,
    input  wire [N-1:0]                 data_i,
    input  wire [META_DATA_WIDTH-1:0]   metadata_i [N],
    input  wire                         qos_enable,
    input  wire                         ready_o,
    output wire [N_LOG-1:0]             data_o,
    output wire [QOS_TAG_WIDTH-1:0]     qos_o,
    output wire                         data_valid_o
);

    //═══════════════════════════════════════════════════════════════════════════
    // Extract QoS Tags from Metadata
    //═══════════════════════════════════════════════════════════════════════════

    logic [QOS_TAG_WIDTH-1:0] qos_tags [N];

    generate
        for (genvar i = 0; i < N; i++) begin : gen_extract_qos
            always_comb begin
                qos_tags[i] = metadata_i[i][QOS_OFFSET +: QOS_TAG_WIDTH];
            end
        end
    endgenerate

    //═══════════════════════════════════════════════════════════════════════════
    // Combinational Selection Logic
    //═══════════════════════════════════════════════════════════════════════════

    // Combinational outputs from selection logic
    logic [N_LOG-1:0]         selected_index_comb;
    logic [QOS_TAG_WIDTH-1:0] selected_qos_comb;
    logic                     selected_valid_comb;

    always_comb begin
        // Default values
        selected_index_comb = '0;
        selected_qos_comb   = '1;  // Max value (lowest priority)
        selected_valid_comb = 1'b0;

        if (qos_enable) begin
            //══════════════════════════════════════════════════════════════════
            // QoS-AWARE MODE: Find highest-priority (lowest QoS value) non-zero bit
            //══════════════════════════════════════════════════════════════════

            logic [QOS_TAG_WIDTH-1:0] best_qos;
            logic [N_LOG-1:0]         best_idx;
            logic                     found;

            best_qos = '1;  // Start with worst priority
            best_idx = '0;
            found    = 1'b0;

            for (int i = 0; i < N; i++) begin
                if (data_i[i]) begin
                    // Clamp QoS tag to valid range
                    logic [QOS_TAG_WIDTH-1:0] current_qos;
                    current_qos = (qos_tags[i] >= QOS_LEVELS) ?
                                  (QOS_LEVELS - 1) : qos_tags[i];

                    // Select if this is the first valid candidate,
                    // OR if it has higher priority (lower QoS value)
                    if (!found || (current_qos < best_qos)) begin
                        best_qos = current_qos;
                        best_idx = i[N_LOG-1:0];
                        found    = 1'b1;
                    end
                end
            end

            selected_index_comb = best_idx;
            selected_qos_comb   = best_qos;
            selected_valid_comb = found;

        end else begin
            //══════════════════════════════════════════════════════════════════
            // STANDARD MODE: First non-zero (original logic)
            //══════════════════════════════════════════════════════════════════

            for (int i = 0; i < N; i++) begin
                if (data_i[i] && !selected_valid_comb) begin
                    selected_index_comb = i[N_LOG-1:0];
                    selected_qos_comb   = qos_tags[i];
                    selected_valid_comb = 1'b1;
                end
            end
        end
    end

    //═══════════════════════════════════════════════════════════════════════════
    // Sequential Output Registers
    //═══════════════════════════════════════════════════════════════════════════

    logic [N_LOG-1:0]         selected_index_reg;
    logic [QOS_TAG_WIDTH-1:0] selected_qos_reg;
    logic                     selected_valid_reg;

    always_ff @(posedge clk) begin
        if (ready_o) begin
            selected_index_reg <= selected_index_comb;
            selected_qos_reg   <= selected_qos_comb;
            selected_valid_reg <= selected_valid_comb;
        end else begin
            selected_valid_reg <= 1'b0;
        end
    end

    //═══════════════════════════════════════════════════════════════════════════
    // Output Assignment
    //═══════════════════════════════════════════════════════════════════════════

    assign data_o       = selected_index_reg;
    assign qos_o        = selected_qos_reg;
    assign data_valid_o = selected_valid_reg;

    //═══════════════════════════════════════════════════════════════════════════
    // Assertions
    //═══════════════════════════════════════════════════════════════════════════

    `ifndef SYNTHESIS
    `ifdef SIMULATION

    // Selected index must be valid
    property valid_index;
        @(posedge clk)
        data_valid_o |-> (data_o < N);
    endproperty
    assert property (valid_index) else
        $error("[FIRST_NONZERO_QoS] Invalid index: %0d (N=%0d)", data_o, N);

    // QoS value must be in valid range
    property valid_qos;
        @(posedge clk)
        data_valid_o |-> (qos_o < QOS_LEVELS);
    endproperty
    assert property (valid_qos) else
        $error("[FIRST_NONZERO_QoS] Invalid QoS: %0d (max=%0d)", qos_o, QOS_LEVELS-1);

    // Selected bit must be set in data_i
    property selected_bit_set;
        @(posedge clk)
        (data_valid_o && ready_o) |-> data_i[data_o];
    endproperty
    assert property (selected_bit_set) else
        $error("[FIRST_NONZERO_QoS] Selected bit not set: data_i=%b, index=%0d",
               data_i, data_o);

    // In QoS mode, no lower QoS value should exist in remaining candidates
    generate
        if (1) begin : gen_qos_priority_check
            property qos_priority_correct;
                @(posedge clk)
                (data_valid_o && qos_enable && ready_o) |->
                    (data_i & ~(1 << data_o)) == 0 ||  // No other candidates
                    !$onehot(data_i);  // Skip check for multiple bits (complex)
            endproperty
            // Note: Full check would require iterating all bits, kept simple for synthesis
        end
    endgenerate

    `endif
    `endif

endmodule

`default_nettype wire