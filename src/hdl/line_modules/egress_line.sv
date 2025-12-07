`timescale 1ns / 1ps
// `default_nettype none

`include "fabric_params.vh"

module egress_line #(
    parameter DATA_WIDTH        = `DATA_WIDTH,
    parameter ID_WIDTH          = `PACKET_ID_WIDTH,
    parameter OUTPUT_Q_DEPTH    = `OUTPUT_QUEUE_DEPTH
)(
    input  logic clk,
    input  logic rst_n,

    // From fabric
    switch_data_if.slave        fabric_tx,

    // To external interface
    switch_data_if.master       external_tx,

    // Drop control
    input  logic                drop_bad_frames,

    // Statistics
    output logic [31:0]         pkt_tx_count,
    output logic [31:0]         pkt_drop_count
);

    // Output queue
    typedef struct packed {
        logic [DATA_WIDTH-1:0]      data;
        logic [DATA_WIDTH/8-1:0]    keep;
        logic                       last;
        logic                       is_bad;
        logic [2:0]                 qos;
        logic [ID_WIDTH-1:0]        id;
    } oq_entry_t;

    oq_entry_t oq_fifo[$];

    logic oq_wr_ready;
    logic oq_rd_valid;

    assign oq_wr_ready = (oq_fifo.size() < OUTPUT_Q_DEPTH);
    assign fabric_tx.ready = oq_wr_ready;

    // Write to output queue (with bad frame filtering)
    always @(posedge clk) begin
        if (fabric_tx.valid && oq_wr_ready) begin
            if (drop_bad_frames && fabric_tx.is_bad_frame && fabric_tx.last) begin
                // Drop entire bad frame
                pkt_drop_count <= pkt_drop_count + 1;
            end else begin
                oq_entry_t entry;
                entry.data = fabric_tx.data;
                entry.keep = fabric_tx.keep;
                entry.last = fabric_tx.last;
                entry.is_bad = fabric_tx.is_bad_frame;
                entry.qos = fabric_tx.qos_tag;
                entry.id = fabric_tx.id;
                oq_fifo.push_back(entry);
            end
        end
    end

    // Read from output queue
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            oq_rd_valid <= 1'b0;
            pkt_tx_count <= 0;
        end else begin
            oq_rd_valid <= 1'b0;

            if (external_tx.ready && oq_fifo.size() > 0) begin
                automatic oq_entry_t entry;
                entry = oq_fifo.pop_front();
                external_tx.data <= entry.data;
                external_tx.keep <= entry.keep;
                external_tx.last <= entry.last;
                external_tx.is_bad_frame <= entry.is_bad;
                external_tx.qos_tag <= entry.qos;
                external_tx.id <= entry.id;
                external_tx.valid <= 1'b1;
                oq_rd_valid <= 1'b1;

                if (entry.last) begin
                    pkt_tx_count <= pkt_tx_count + 1;
                end
            end else begin
                external_tx.valid <= 1'b0;
            end
        end
    end

endmodule

`default_nettype wire