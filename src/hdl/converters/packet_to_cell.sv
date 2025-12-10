`timescale 1ns / 1ps
`default_nettype none

module packet_to_cell #(
    parameter NUM_PORT = 10,
    parameter S = 10,
    parameter W_MINI = 64,
    parameter FULL_WAIT_DURATION = 50,
    parameter KEEP_WIDTH = $clog2(W_MINI/8 + 1),
    parameter S_LOG = $clog2(S)
)(
    input  wire                     clk,

    // RX interface
    input  wire [W_MINI-1:0]        data_rx,
    input  wire [KEEP_WIDTH-1:0]    keep_rx,
    input  wire                     valid_rx,
    input  wire                     is_bad_frame_rx,
    input  wire                     last_rx,
    input  wire [NUM_PORT-1:0]      dest_mask_rx,
    input  wire                     dest_mask_valid_rx,
    input  wire                     end_time_slot,
    input  wire                     start_time_slot,
    input  wire [S_LOG-1:0]         rr_counter,
    input  wire                     force_to_send,
    input  wire                     dfifo_ready,

    // Cell output
    output reg  [NUM_PORT-1:0]      dest_mask_o,
    output reg                      pop_iq_o,
    output reg                      wr_en_o,
    output reg  [W_MINI-1:0]        data_o,
    output reg                      make_cell_o,
    output reg                      last_cell_o,
    output reg  [S+KEEP_WIDTH+1+S_LOG-1:0] metadata_o
);

    typedef enum {IDLE, COLLECT, SEND_CELL} state_t;
    state_t state;

    reg [W_MINI-1:0] cell_buffer [S-1:0];
    reg [S-1:0] cell_valid;
    reg [S_LOG-1:0] cell_count;
    reg [KEEP_WIDTH-1:0] last_keep;
    reg last_minicell_bad;
    reg [NUM_PORT-1:0] dest_mask_reg;

    always_ff @(posedge clk) begin
        pop_iq_o <= 1'b0;
        wr_en_o <= 1'b0;
        make_cell_o <= 1'b0;

        case (state)
            IDLE: begin
                if (valid_rx && dest_mask_valid_rx && dfifo_ready) begin
                    dest_mask_reg <= dest_mask_rx;
                    cell_count <= '0;
                    cell_valid <= '0;
                    state <= COLLECT;
                end
            end

            COLLECT: begin
                if (valid_rx) begin
                    pop_iq_o <= 1'b1;
                    wr_en_o <= 1'b1;
                    cell_buffer[cell_count] <= data_rx;
                    cell_valid[cell_count] <= 1'b1;
                    cell_count <= cell_count + 1;

                    if (last_rx) begin
                        last_keep <= keep_rx;
                        last_minicell_bad <= is_bad_frame_rx;
                        state <= SEND_CELL;
                    end else if (cell_count == S-1 || (force_to_send && end_time_slot)) begin
                        state <= SEND_CELL;
                    end
                end
            end

            SEND_CELL: begin
                if (start_time_slot || force_to_send) begin
                    make_cell_o <= 1'b1;
                    last_cell_o <= (cell_count == 0) || last_rx;
                    dest_mask_o <= dest_mask_reg;

                    // Pack metadata
                    metadata_o <= {cell_valid, last_keep, last_minicell_bad, cell_count};

                    state <= IDLE;
                end
            end
        endcase
    end

    assign data_o = cell_buffer[rr_counter];

endmodule

`default_nettype wire