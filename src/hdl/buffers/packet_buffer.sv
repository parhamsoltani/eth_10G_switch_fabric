`timescale 1ns / 1ps

`include "fabric_params.vh"

module packet_buffer #(
    parameter DATA_WIDTH        = `DATA_WIDTH,
    parameter MAX_PACKET_SIZE   = 512,
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
        logic [15:0]            length;
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
    logic signed [ADDR_WIDTH+2:0] free_count;  // Extra bit for signed comparison

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
        RD_FETCH,
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
    logic [15:0] pkt_count;

    assign packet_count = pkt_count;
    
    // FIX: Changed from ">" to ">=" and use a reasonable threshold
    // Ready if we have at least 1 free slot (for single-beat packets)
    // Or use a smaller threshold for multi-beat packets
    assign wr_ready = (free_count > 0) && (wr_state == WR_IDLE || wr_state == WR_PACKET);
    
    assign word_count = BUFFER_DEPTH - free_count;

    // Combined always_ff for all state
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Write FSM reset
            wr_state <= WR_IDLE;
            wr_word_count <= 0;
            wr_head <= '0;
            wr_current <= '0;
            
            // Read FSM reset
            rd_state <= RD_IDLE;
            rd_valid <= 1'b0;
            rd_current <= '0;
            rd_current_id <= '0;
            rd_id <= '0;
            rd_is_bad <= 1'b0;
            rd_data <= '0;
            rd_keep <= '0;
            rd_last <= 1'b0;
            
            // Free list reset
            free_head <= 0;
            free_tail <= 0;  // Changed: tail starts at 0, wraps around
            free_count <= BUFFER_DEPTH;
            
            // Packet queue reset
            pkt_wr_ptr <= 0;
            pkt_rd_ptr <= 0;
            pkt_count <= 0;
            
            // Initialize free list
            for (int i = 0; i < BUFFER_DEPTH; i++) begin
                free_list[i] <= i[ADDR_WIDTH-1:0];
            end
            
        end else begin
            
            // Track allocation and free operations for free_count update
            automatic logic do_alloc = 1'b0;
            automatic logic do_free = 1'b0;
            
            //=================================================================
            // Write FSM
            //=================================================================
            case (wr_state)
                WR_IDLE: begin
                    if (wr_valid && (free_count > 0)) begin
                        // Allocate from free list
                        wr_head <= free_list[free_head[ADDR_WIDTH-1:0]];
                        wr_current <= free_list[free_head[ADDR_WIDTH-1:0]];
                        wr_word_count <= 1;

                        descriptors[wr_id].head_ptr <= free_list[free_head[ADDR_WIDTH-1:0]];
                        descriptors[wr_id].is_bad <= wr_is_bad;

                        memory[free_list[free_head[ADDR_WIDTH-1:0]]].data <= wr_data;
                        memory[free_list[free_head[ADDR_WIDTH-1:0]]].keep <= wr_keep;
                        memory[free_list[free_head[ADDR_WIDTH-1:0]]].is_last <= wr_last;

                        free_head <= (free_head + 1) % BUFFER_DEPTH;
                        do_alloc = 1'b1;
                        
                        if (wr_last) begin
                            wr_state <= WR_COMMIT;
                        end else begin
                            wr_state <= WR_PACKET;
                        end
                    end
                end

                WR_PACKET: begin
                    if (wr_valid && (free_count > 0)) begin
                        memory[wr_current].next_ptr <= free_list[free_head[ADDR_WIDTH-1:0]];

                        memory[free_list[free_head[ADDR_WIDTH-1:0]]].data <= wr_data;
                        memory[free_list[free_head[ADDR_WIDTH-1:0]]].keep <= wr_keep;
                        memory[free_list[free_head[ADDR_WIDTH-1:0]]].is_last <= wr_last;

                        wr_current <= free_list[free_head[ADDR_WIDTH-1:0]];
                        wr_word_count <= wr_word_count + 1;

                        free_head <= (free_head + 1) % BUFFER_DEPTH;
                        do_alloc = 1'b1;

                        if (wr_last) begin
                            wr_state <= WR_COMMIT;
                        end
                    end
                end

                WR_COMMIT: begin
                    memory[wr_current].next_ptr <= {ADDR_WIDTH{1'b1}};
                    descriptors[wr_id].tail_ptr <= wr_current;
                    descriptors[wr_id].length <= wr_word_count;
                    descriptors[wr_id].valid <= 1'b1;

                    packet_queue[pkt_wr_ptr[ID_WIDTH-1:0]] <= wr_id;
                    pkt_wr_ptr <= pkt_wr_ptr + 1;
                    pkt_count <= pkt_count + 1;

                    wr_state <= WR_IDLE;
                end

                default: wr_state <= WR_IDLE;
            endcase

            //=================================================================
            // Read FSM
            //=================================================================
            case (rd_state)
                RD_IDLE: begin
                    rd_valid <= 1'b0;
                    if (pkt_count > 0) begin
                        rd_current_id <= packet_queue[pkt_rd_ptr[ID_WIDTH-1:0]];
                        rd_current <= descriptors[packet_queue[pkt_rd_ptr[ID_WIDTH-1:0]]].head_ptr;
                        rd_id <= packet_queue[pkt_rd_ptr[ID_WIDTH-1:0]];
                        rd_is_bad <= descriptors[packet_queue[pkt_rd_ptr[ID_WIDTH-1:0]]].is_bad;
                        
                        pkt_rd_ptr <= pkt_rd_ptr + 1;
                        pkt_count <= pkt_count - 1;

                        rd_state <= RD_FETCH;
                    end
                end

                RD_FETCH: begin
                    // Fetch data from memory
                    rd_data <= memory[rd_current].data;
                    rd_keep <= memory[rd_current].keep;
                    rd_last <= memory[rd_current].is_last;
                    rd_valid <= 1'b1;
                    rd_state <= RD_PACKET;
                end

                RD_PACKET: begin
                    if (rd_ready) begin
                        // Return current cell to free list
                        free_list[free_tail[ADDR_WIDTH-1:0]] <= rd_current;
                        free_tail <= (free_tail + 1) % BUFFER_DEPTH;
                        do_free = 1'b1;

                        if (rd_last) begin
                            descriptors[rd_current_id].valid <= 1'b0;
                            rd_valid <= 1'b0;
                            rd_state <= RD_IDLE;
                        end else begin
                            rd_current <= memory[rd_current].next_ptr;
                            rd_valid <= 1'b0;
                            rd_state <= RD_FETCH;
                        end
                    end
                end

                default: rd_state <= RD_IDLE;
            endcase

            //=================================================================
            // Free count management
            //=================================================================
            if (do_alloc && !do_free) begin
                free_count <= free_count - 1;
            end else if (!do_alloc && do_free) begin
                free_count <= free_count + 1;
            end
            // If both or neither, free_count stays the same
        end
    end

endmodule