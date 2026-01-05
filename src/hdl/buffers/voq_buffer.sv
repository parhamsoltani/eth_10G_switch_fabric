`timescale 1ns / 1ps

`include "fabric_params.vh"

module voq_buffer #(
    parameter DATA_WIDTH     = `DATA_WIDTH,
    parameter ID_WIDTH       = `PACKET_ID_WIDTH,
    parameter DEPTH_PER_QOS  = `VOQ_DEPTH_PER_QOS,
    parameter NUM_QOS_LEVELS = `QOS_LEVELS,           // Match switch_fabric_qos.sv
    parameter KEEP_WIDTH     = DATA_WIDTH/8
)(
    input  logic clk,
    input  logic rst_n,

    // Write interface (full packet metadata)
    input  logic                    wr_valid,
    input  logic [DATA_WIDTH-1:0]   wr_data,
    input  logic [KEEP_WIDTH-1:0]   wr_keep,
    input  logic                    wr_last,
    input  logic [ID_WIDTH-1:0]     wr_id,
    input  logic                    wr_is_bad,
    input  logic [2:0]              wr_qos,
    output logic                    wr_ready,

    // Read interface (full packet metadata)
    output logic                    rd_valid,
    output logic [DATA_WIDTH-1:0]   rd_data,
    output logic [KEEP_WIDTH-1:0]   rd_keep,
    output logic                    rd_last,
    output logic [ID_WIDTH-1:0]     rd_id,
    output logic                    rd_is_bad,
    output logic [2:0]              rd_qos,
    input  logic                    rd_ready,

    // Status
    output logic [$clog2(DEPTH_PER_QOS * NUM_QOS_LEVELS + 1)-1:0] occupancy,
    output logic                    empty,
    output logic                    almost_full
);

    //==========================================================================
    // Local Parameters
    //==========================================================================
    localparam TOTAL_WIDTH = DATA_WIDTH + KEEP_WIDTH + ID_WIDTH + 1 + 1 + 3;
    localparam QOS_WIDTH = (NUM_QOS_LEVELS > 1) ? $clog2(NUM_QOS_LEVELS) : 1;

    //==========================================================================
    // Per-QoS FIFO Signals
    //==========================================================================
    logic [TOTAL_WIDTH-1:0] fifo_wr_data;
    logic [TOTAL_WIDTH-1:0] fifo_rd_data [NUM_QOS_LEVELS];
    logic [NUM_QOS_LEVELS-1:0] fifo_wr_en;
    logic [NUM_QOS_LEVELS-1:0] fifo_rd_en;
    logic [NUM_QOS_LEVELS-1:0] fifo_empty;
    logic [NUM_QOS_LEVELS-1:0] fifo_full;
    logic [NUM_QOS_LEVELS-1:0] fifo_prog_full;

    // Pack write data: {qos, is_bad, last, id, keep, data}
    assign fifo_wr_data = {wr_qos, wr_is_bad, wr_last, wr_id, wr_keep, wr_data};

    //==========================================================================
    // Per-QoS FIFOs using simple_fifo (wraps xpm_fifo_sync)
    //==========================================================================
    generate
        for (genvar q = 0; q < NUM_QOS_LEVELS; q++) begin : gen_qos_fifo

            // Write enable: route to correct QoS FIFO
            assign fifo_wr_en[q] = wr_valid && (wr_qos == q[2:0]) && !fifo_full[q];

            simple_fifo #(
                .DATA_WIDTH(TOTAL_WIDTH),
                .FIFO_DEPTH(DEPTH_PER_QOS),
                .XPM_READ_LATENCY(0),  // FWFT mode
                .PROG_FULL_THRESH(DEPTH_PER_QOS > 4 ? DEPTH_PER_QOS - 2 : 2)
            ) u_qos_fifo (
                .clk_i(clk),
                .reset_i(~rst_n),
                .push_i(fifo_wr_en[q]),
                .push_data_i(fifo_wr_data),
                .pop_i(fifo_rd_en[q]),
                .pop_data_o(fifo_rd_data[q]),
                .full_o(fifo_full[q]),
                .prog_full_o(fifo_prog_full[q]),
                .empty_o(fifo_empty[q])
            );

        end
    endgenerate

    //==========================================================================
    // Write Ready Logic
    //==========================================================================
    always_comb begin
        wr_ready = 1'b0;
        for (int q = 0; q < NUM_QOS_LEVELS; q++) begin
            if (wr_qos == q[2:0]) begin
                wr_ready = !fifo_full[q];
            end
        end
    end

    //==========================================================================
    // Strict Priority Read Arbiter
    // Higher QoS index = Higher Priority (QoS 7 > QoS 0)
    //==========================================================================
    logic [QOS_WIDTH-1:0] selected_qos;
    logic                 any_valid;

    always_comb begin
        selected_qos = '0;
        any_valid = 1'b0;

        // Strict priority: highest QoS first
        for (int q = NUM_QOS_LEVELS - 1; q >= 0; q--) begin
            if (!fifo_empty[q] && !any_valid) begin
                selected_qos = q[QOS_WIDTH-1:0];
                any_valid = 1'b1;
            end
        end
    end

    // Read enable to selected FIFO
    always_comb begin
        fifo_rd_en = '0;
        if (rd_ready && any_valid) begin
            fifo_rd_en[selected_qos] = 1'b1;
        end
    end

    //==========================================================================
    // Output Mux and Unpack
    //==========================================================================
    logic [TOTAL_WIDTH-1:0] selected_data;

    always_comb begin
        selected_data = fifo_rd_data[selected_qos];
    end

    assign rd_valid  = any_valid;
    assign rd_data   = selected_data[DATA_WIDTH-1:0];
    assign rd_keep   = selected_data[DATA_WIDTH+KEEP_WIDTH-1:DATA_WIDTH];
    assign rd_id     = selected_data[DATA_WIDTH+KEEP_WIDTH+ID_WIDTH-1:DATA_WIDTH+KEEP_WIDTH];
    assign rd_last   = selected_data[DATA_WIDTH+KEEP_WIDTH+ID_WIDTH];
    assign rd_is_bad = selected_data[DATA_WIDTH+KEEP_WIDTH+ID_WIDTH+1];
    assign rd_qos    = selected_data[TOTAL_WIDTH-1:TOTAL_WIDTH-3];

    //==========================================================================
    // Status Outputs
    //==========================================================================
    assign empty = &fifo_empty;
    assign almost_full = |fifo_prog_full;

    // Occupancy counter
    logic [$clog2(DEPTH_PER_QOS * NUM_QOS_LEVELS + 1)-1:0] occ_counter;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            occ_counter <= '0;
        end else begin
            case ({wr_valid && wr_ready, rd_ready && any_valid})
                2'b10:   occ_counter <= occ_counter + 1;
                2'b01:   occ_counter <= occ_counter - 1;
                default: occ_counter <= occ_counter;
            endcase
        end
    end
    
    assign occupancy = occ_counter;

endmodule

`default_nettype wire