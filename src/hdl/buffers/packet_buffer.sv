`timescale 1ns / 1ps
// `default_nettype none

`include "fabric_params.vh"

module packet_buffer #(
    parameter DATA_WIDTH        = `DATA_WIDTH,
    parameter MAX_PACKET_SIZE   = 512,      // In DATA_WIDTH words
    parameter BUFFER_DEPTH      = `PACKET_BUFFER_DEPTH,
    parameter ID_WIDTH          = `PACKET_ID_WIDTH,
    parameter ADDR_WIDTH        = $clog2(BUFFER_DEPTH)
)(
    input  logic clk,
    input  logic rst_n,

    // Write interface (packet ingress)
    input  logic                    wr_valid,
    input  logic [DATA_WIDTH-1:0]   wr_data,
    input  logic [DATA_WIDTH/8-1:0] wr_keep,
    input  logic                    wr_last,
    input  logic [ID_WIDTH-1:0]     wr_id,
    input  logic                    wr_is_bad,
    output logic                    wr_ready,

    // Read interface (packet egress)
    output logic                    rd_valid,
    output logic [DATA_WIDTH-1:0]   rd_data,
    output logic [DATA_WIDTH/8-1:0] rd_keep,
    output logic                    rd_last,
    output logic [ID_WIDTH-1:0]     rd_id,
    output logic                    rd_is_bad,
    input  logic                    rd_ready,

    // Status
    output logic [15:0]             packet_count,
    output logic [31:0]             word_count
);

    // Packet descriptor structure
    typedef struct packed {
        logic [ADDR_WIDTH-1:0]  head_ptr;
        logic [ADDR_WIDTH-1:0]  tail_ptr;
        logic [15:0]            length;     // In words
        logic                   valid;
        logic                   is_bad;
    } packet_desc_t;

    // Memory cell structure
    typedef struct packed {
        logic [DATA_WIDTH-1:0]      data;
        logic [DATA_WIDTH/8-1:0]    keep;
        logic [ADDR_WIDTH-1:0]      next_ptr;
        logic                       is_last;
    } memory_cell_t;

    // Storage
    memory_cell_t           memory [BUFFER_DEPTH];
    packet_desc_t           descriptors [2**ID_WIDTH];

    // Free list
    logic [ADDR_WIDTH-1:0]  free_list [BUFFER_DEPTH];
    logic [ADDR_WIDTH:0]    free_head;
    logic [ADDR_WIDTH:0]    free_tail;
    logic [ADDR_WIDTH:0]    free_count;

    // Write state machine
    typedef enum logic [1:0] {
        WR_IDLE,
        WR_PACKET,
        WR_COMMIT
    } wr_state_t;

    wr_state_t wr_state;
    logic [ADDR_WIDTH-1:0] wr_head;
    logic [ADDR_WIDTH-1:0] wr_current;
    logic [15:0] wr_word_count;

    // Read state machine
    typedef enum logic [1:0] {
        RD_IDLE,
        RD_PACKET,
        RD_WAIT
    } rd_state_t;

    rd_state_t rd_state;
    logic [ADDR_WIDTH-1:0] rd_current;
    logic [ID_WIDTH-1:0] rd_current_id;

    // Packet queue (FIFO of IDs)
    logic [ID_WIDTH-1:0] packet_queue [2**ID_WIDTH];
    logic [ID_WIDTH:0] pkt_wr_ptr;
    logic [ID_WIDTH:0] pkt_rd_ptr;
    logic [ID_WIDTH:0] pkt_count;

    assign packet_count = pkt_count[15:0];
    assign wr_ready = (free_count > MAX_PACKET_SIZE);

    // Initialize free list
    initial begin
        for (int i = 0; i < BUFFER_DEPTH; i++) begin
            free_list[i] = i;
        end
        free_head = 0;
        free_tail = BUFFER_DEPTH;
        free_count = BUFFER_DEPTH;
        pkt_wr_ptr = 0;
        pkt_rd_ptr = 0;
        pkt_count = 0;
    end

    // Write FSM
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_state <= WR_IDLE;
            wr_word_count <= 0;
        end else begin
            case (wr_state)
                WR_IDLE: begin
                    if (wr_valid && wr_ready) begin
                        // Allocate head pointer
                        wr_head <= free_list[free_head];
                        wr_current <= free_list[free_head];
                        wr_word_count <= 1;

                        // Initialize descriptor
                        descriptors[wr_id].head_ptr <= free_list[free_head];
                        descriptors[wr_id].is_bad <= wr_is_bad;

                        // Write first word
                        memory[free_list[free_head]].data <= wr_data;
                        memory[free_list[free_head]].keep <= wr_keep;
                        memory[free_list[free_head]].is_last <= wr_last;

                        free_head <= (free_head + 1) % BUFFER_DEPTH;
                        free_count <= free_count - 1;

                        if (wr_last) begin
                            wr_state <= WR_COMMIT;
                        end else begin
                            wr_state <= WR_PACKET;
                        end
                    end
                end

                WR_PACKET: begin
                    if (wr_valid) begin
                        // Link previous cell to new cell
                        memory[wr_current].next_ptr <= free_list[free_head];

                        // Write current word
                        memory[free_list[free_head]].data <= wr_data;
                        memory[free_list[free_head]].keep <= wr_keep;
                        memory[free_list[free_head]].is_last <= wr_last;

                        wr_current <= free_list[free_head];
                        wr_word_count <= wr_word_count + 1;

                        free_head <= (free_head + 1) % BUFFER_DEPTH;
                        free_count <= free_count - 1;

                        if (wr_last) begin
                            wr_state <= WR_COMMIT;
                        end
                    end
                end

                WR_COMMIT: begin
                    // Finalize descriptor
                    memory[wr_current].next_ptr <= {ADDR_WIDTH{1'b1}};  // NULL
                    descriptors[wr_id].tail_ptr <= wr_current;
                    descriptors[wr_id].length <= wr_word_count;
                    descriptors[wr_id].valid <= 1'b1;

                    // Enqueue packet ID
                    packet_queue[pkt_wr_ptr] <= wr_id;
                    pkt_wr_ptr <= (pkt_wr_ptr + 1) % (2**ID_WIDTH);
                    pkt_count <= pkt_count + 1;

                    wr_state <= WR_IDLE;
                end
            endcase
        end
    end

    // Read FSM
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_state <= RD_IDLE;
            rd_valid <= 1'b0;
        end else begin
            case (rd_state)
                RD_IDLE: begin
                    rd_valid <= 1'b0;
                    if (pkt_count > 0) begin
                        // Dequeue packet ID
                        rd_current_id <= packet_queue[pkt_rd_ptr];
                        pkt_rd_ptr <= (pkt_rd_ptr + 1) % (2**ID_WIDTH);
                        pkt_count <= pkt_count - 1;

                        // Start reading from head
                        rd_current <= descriptors[packet_queue[pkt_rd_ptr]].head_ptr;
                        rd_id <= packet_queue[pkt_rd_ptr];
                        rd_is_bad <= descriptors[packet_queue[pkt_rd_ptr]].is_bad;

                        rd_state <= RD_PACKET;
                    end
                end

                RD_PACKET: begin
                    rd_valid <= 1'b1;
                    rd_data <= memory[rd_current].data;
                    rd_keep <= memory[rd_current].keep;
                    rd_last <= memory[rd_current].is_last;

                    if (rd_ready) begin
                        // Return current cell to free list
                        free_list[free_tail] <= rd_current;
                        free_tail <= (free_tail + 1) % BUFFER_DEPTH;
                        free_count <= free_count + 1;

                        if (memory[rd_current].is_last) begin
                            // Packet complete
                            descriptors[rd_current_id].valid <= 1'b0;
                            rd_state <= RD_IDLE;
                        end else begin
                            // Move to next cell
                            rd_current <= memory[rd_current].next_ptr;
                            rd_state <= RD_WAIT;
                        end
                    end
                end

                RD_WAIT: begin
                    // 1-cycle bubble for memory read
                    rd_valid <= 1'b0;
                    rd_state <= RD_PACKET;
                end
            endcase
        end
    end

    // Word count (for monitoring)
    assign word_count = (BUFFER_DEPTH - free_count);

endmodule

// `default_nettype wire