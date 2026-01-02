`timescale 1ns / 1ps

`include "fabric_params.vh"

module voq_buffer #(
    parameter DATA_WIDTH    = `DATA_WIDTH,
    parameter NUM_QOS       = `QOS_LEVELS,
    parameter DEPTH_PER_QOS = `VOQ_DEPTH_PER_QOS,
    parameter ID_WIDTH      = `PACKET_ID_WIDTH
)(
    input  logic clk,
    input  logic rst_n,

    // Write interface
    input  logic                    wr_en,
    input  logic [DATA_WIDTH-1:0]   wr_data,
    input  logic [$clog2(NUM_QOS)-1:0] wr_qos,

    // Read interface  
    input  logic                    rd_en,
    output logic                    rd_valid,
    output logic [DATA_WIDTH-1:0]   rd_data,
    output logic [$clog2(NUM_QOS)-1:0] rd_qos,

    // Status
    output logic [NUM_QOS-1:0]      empty,
    output logic [NUM_QOS-1:0]      full
);

    localparam QOS_WIDTH = $clog2(NUM_QOS);

    // Per-QoS packet buffer signals
    logic [NUM_QOS-1:0]         pb_wr_valid;
    logic [NUM_QOS-1:0]         pb_wr_ready;
    logic [NUM_QOS-1:0]         pb_rd_valid;
    logic [NUM_QOS-1:0]         pb_rd_ready;
    logic [DATA_WIDTH-1:0]      pb_rd_data  [NUM_QOS];
    logic [15:0]                pb_pkt_count [NUM_QOS];

    // Arbiter signals
    logic [NUM_QOS-1:0]         arb_request;
    logic [NUM_QOS-1:0]         arb_grant;
    logic [QOS_WIDTH-1:0]       arb_winner;
    logic                       arb_valid;

    // Read pipeline registers
    logic                       rd_pending;
    logic [QOS_WIDTH-1:0]       rd_qos_pending;
    logic                       rd_valid_reg;
    logic [DATA_WIDTH-1:0]      rd_data_reg;
    logic [QOS_WIDTH-1:0]       rd_qos_reg;

    // Generate packet buffers for each QoS level
    genvar g;
    generate
        for (g = 0; g < NUM_QOS; g++) begin : gen_qos_buffers
            packet_buffer #(
                .DATA_WIDTH     (DATA_WIDTH),
                .BUFFER_DEPTH   (DEPTH_PER_QOS),
                .ID_WIDTH       (ID_WIDTH)
            ) u_packet_buffer (
                .clk            (clk),
                .rst_n          (rst_n),
                
                // Write interface - single beat packets
                .wr_valid       (pb_wr_valid[g]),
                .wr_data        (wr_data),
                .wr_keep        ({(DATA_WIDTH/8){1'b1}}),
                .wr_last        (1'b1),  // Single-beat packets
                .wr_id          ({ID_WIDTH{1'b0}}),
                .wr_is_bad      (1'b0),
                .wr_ready       (pb_wr_ready[g]),
                
                // Read interface
                .rd_valid       (pb_rd_valid[g]),
                .rd_data        (pb_rd_data[g]),
                .rd_keep        (),
                .rd_last        (),
                .rd_id          (),
                .rd_is_bad      (),
                .rd_ready       (pb_rd_ready[g]),
                
                // Status
                .packet_count   (pb_pkt_count[g]),
                .word_count     ()
            );

            // Write routing
            assign pb_wr_valid[g] = wr_en && (wr_qos == g);
            
            // Full status
            assign full[g] = !pb_wr_ready[g];
            
            // Arbiter request - only request if buffer has valid data ready
            assign arb_request[g] = pb_rd_valid[g];
        end
    endgenerate

    // Empty status - registered to avoid glitches during pipeline transitions
    // A queue is not empty if it has packets OR if data is pending in the read pipeline
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            empty <= '1;  // All queues empty on reset
        end else begin
            for (int i = 0; i < NUM_QOS; i++) begin
                // Not empty if: has packets, has valid output ready, or read is pending for this queue
                empty[i] <= (pb_pkt_count[i] == 0) && 
                            !pb_rd_valid[i] && 
                            !(rd_pending && rd_qos_pending == i) &&
                            !(rd_valid_reg && rd_qos_reg == i);
            end
        end
    end

    // Priority arbiter - QoS 0 is highest priority
    // Only arbitrate when read is requested and we're not waiting for a pending read
    always_comb begin
        arb_grant = '0;
        arb_winner = '0;
        arb_valid = 1'b0;
        
        if (rd_en && !rd_pending) begin
            for (int i = 0; i < NUM_QOS; i++) begin
                if (arb_request[i] && !arb_valid) begin
                    arb_grant[i] = 1'b1;
                    arb_winner = i[QOS_WIDTH-1:0];
                    arb_valid = 1'b1;
                end
            end
        end
    end

    // Read ready signals - acknowledge the selected buffer
    always_comb begin
        for (int i = 0; i < NUM_QOS; i++) begin
            pb_rd_ready[i] = arb_grant[i];
        end
    end

    // Read pipeline - capture which QoS was selected, then capture data
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_pending <= 1'b0;
            rd_qos_pending <= '0;
            rd_valid_reg <= 1'b0;
            rd_data_reg <= '0;
            rd_qos_reg <= '0;
        end else begin
            // Default: clear valid after one cycle if not re-granted
            if (rd_valid_reg && !rd_pending) begin
                rd_valid_reg <= 1'b0;
            end
            
            // Stage 1: Arbiter grants a read, capture which QoS
            if (arb_valid) begin
                rd_pending <= 1'b1;
                rd_qos_pending <= arb_winner;
            end
            
            // Stage 2: Data is now valid from the buffer, capture it
            if (rd_pending) begin
                rd_pending <= 1'b0;
                rd_valid_reg <= 1'b1;
                rd_data_reg <= pb_rd_data[rd_qos_pending];
                rd_qos_reg <= rd_qos_pending;
            end
        end
    end

    // Output assignments
    assign rd_valid = rd_valid_reg;
    assign rd_data  = rd_data_reg;
    assign rd_qos   = rd_qos_reg;

endmodule