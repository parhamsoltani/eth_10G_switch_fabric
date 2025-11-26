`timescale 1ns/1ps
`default_nettype none

module xpq_model #(
    parameter DATA_WIDTH = 32,
    parameter ID_WIDTH = 10,
    parameter MAX_DEPTH = 512
)(
    input  logic clk,
    input  logic rst_n,

    // Write interface
    input  logic                    wr_valid,
    input  logic [DATA_WIDTH-1:0]   wr_data,
    input  logic [DATA_WIDTH/8-1:0] wr_keep,
    input  logic                    wr_last,
    input  logic [ID_WIDTH-1:0]     wr_id,
    input  logic                    wr_is_bad,
    output logic                    wr_ready,

    // Read interface
    input  logic                    rd_ready,
    output logic                    rd_valid,
    output logic [DATA_WIDTH-1:0]   rd_data,
    output logic [DATA_WIDTH/8-1:0] rd_keep,
    output logic                    rd_last,
    output logic [ID_WIDTH-1:0]     rd_id,
    output logic                    rd_is_bad,

    // Status
    output logic [15:0]             occupancy
);

    typedef struct {
        logic [DATA_WIDTH-1:0]   data;
        logic [DATA_WIDTH/8-1:0] keep;
        logic                    last;
        logic [ID_WIDTH-1:0]     id;
        logic                    is_bad;
    } beat_t;

    beat_t fifo[$];
    beat_t beat;

    assign wr_ready = (fifo.size() < MAX_DEPTH);
    assign occupancy = fifo.size();

    // Write
    always @(posedge clk) begin
        if (wr_valid && wr_ready) begin
            beat.data = wr_data;
            beat.keep = wr_keep;
            beat.last = wr_last;
            beat.id = wr_id;
            beat.is_bad = wr_is_bad;
            fifo.push_back(beat);
        end
    end

    // Read
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_valid <= 1'b0;
        end else begin
            rd_valid <= 1'b0;

            if (rd_ready && fifo.size() > 0) begin
                beat = fifo.pop_front();
                rd_data <= beat.data;
                rd_keep <= beat.keep;
                rd_last <= beat.last;
                rd_id <= beat.id;
                rd_is_bad <= beat.is_bad;
                rd_valid <= 1'b1;
            end
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            fifo.delete();
        end
    end

endmodule

`default_nettype wire