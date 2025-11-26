`timescale 1ns/1ps
`default_nettype none

module voq_model #(
    parameter DATA_WIDTH = 32,
    parameter ID_WIDTH = 10,
    parameter NUM_QOS = 3
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
    input  logic [2:0]              wr_qos,

    // Read interface
    input  logic                    rd_ready,
    output logic                    rd_valid,
    output logic [DATA_WIDTH-1:0]   rd_data,
    output logic [DATA_WIDTH/8-1:0] rd_keep,
    output logic                    rd_last,
    output logic [ID_WIDTH-1:0]     rd_id,
    output logic                    rd_is_bad,
    output logic [2:0]              rd_qos
);

    // Packet structure
    typedef struct {
        logic [DATA_WIDTH-1:0]   data;
        logic [DATA_WIDTH/8-1:0] keep;
        logic                    last;
        logic [ID_WIDTH-1:0]     id;
        logic                    is_bad;
        logic [2:0]              qos;
    } beat_t;

    // Queues per QoS level
    beat_t queue_p0[$];  // Priority 0 (high)
    beat_t queue_p1[$];  // Priority 1 (medium)
    beat_t queue_p2[$];  // Priority 2 (low)

    beat_t beat;
    int total_beats = 0;

    // Write logic
    always @(posedge clk) begin
        if (wr_valid) begin
            beat.data = wr_data;
            beat.keep = wr_keep;
            beat.last = wr_last;
            beat.id = wr_id;
            beat.is_bad = wr_is_bad;
            beat.qos = wr_qos;

            case (wr_qos)
                3'b000: queue_p0.push_back(beat);
                3'b001: queue_p1.push_back(beat);
                3'b010: queue_p2.push_back(beat);
                default: $warning("Invalid QoS tag: %0d", wr_qos);
            endcase

            total_beats++;
        end
    end

    // Read logic - strict priority
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_valid <= 1'b0;
        end else begin
            rd_valid <= 1'b0;

            if (rd_ready) begin
                if (queue_p0.size() > 0) begin
                    beat = queue_p0.pop_front();
                    rd_data <= beat.data;
                    rd_keep <= beat.keep;
                    rd_last <= beat.last;
                    rd_id <= beat.id;
                    rd_is_bad <= beat.is_bad;
                    rd_qos <= beat.qos;
                    rd_valid <= 1'b1;
                    total_beats--;
                end else if (queue_p1.size() > 0) begin
                    beat = queue_p1.pop_front();
                    rd_data <= beat.data;
                    rd_keep <= beat.keep;
                    rd_last <= beat.last;
                    rd_id <= beat.id;
                    rd_is_bad <= beat.is_bad;
                    rd_qos <= beat.qos;
                    rd_valid <= 1'b1;
                    total_beats--;
                end else if (queue_p2.size() > 0) begin
                    beat = queue_p2.pop_front();
                    rd_data <= beat.data;
                    rd_keep <= beat.keep;
                    rd_last <= beat.last;
                    rd_id <= beat.id;
                    rd_is_bad <= beat.is_bad;
                    rd_qos <= beat.qos;
                    rd_valid <= 1'b1;
                    total_beats--;
                end
            end
        end
    end

    // Reset logic
    always @(posedge clk) begin
        if (rst_n == 1'b0) begin
            queue_p0.delete();
            queue_p1.delete();
            queue_p2.delete();
            total_beats = 0;
        end
    end

endmodule

`default_nettype wire