`timescale 1ns / 1ps
`default_nettype none

`include "fabric_params.vh"

module switch_fabric #(
    parameter NUM_PORTS         = `NUM_PORTS,
    parameter DATA_WIDTH        = `DATA_WIDTH,
    parameter ID_WIDTH          = `PACKET_ID_WIDTH,
    parameter VOQ_DEPTH         = `VOQ_DEPTH_PER_QOS,
    parameter XPQ_DEPTH         = `XPQ_DEPTH,
    parameter PACKET_BUF_DEPTH  = `PACKET_BUFFER_DEPTH
)(
    input  logic clk,
    input  logic rst_n,

    // External interfaces
    switch_data_if.slave        rx_data_if [NUM_PORTS],
    switch_metadata_if.slave    rx_meta_if [NUM_PORTS],
    switch_data_if.master       tx_data_if [NUM_PORTS],

    // Statistics/debug
    output logic [31:0]         pkt_count_rx [NUM_PORTS],
    output logic [31:0]         pkt_count_tx [NUM_PORTS],
    output logic [31:0]         pkt_drop_count [NUM_PORTS],
    output logic [ID_WIDTH:0]   free_ids
);

    // =========================================================================
    // Internal Wiring
    // =========================================================================

    // Packet ID Manager
    logic [NUM_PORTS-1:0]   id_alloc_req;
    logic [NUM_PORTS-1:0]   id_alloc_grant;
    logic [ID_WIDTH-1:0]    allocated_id [NUM_PORTS];
    logic [NUM_PORTS-1:0]   id_release_req;
    logic [ID_WIDTH-1:0]    release_id [NUM_PORTS];

    // VOQ stage
    logic                   voq_wr_valid [NUM_PORTS][NUM_PORTS];
    logic [DATA_WIDTH-1:0]  voq_wr_data [NUM_PORTS];
    logic [DATA_WIDTH/8-1:0] voq_wr_keep [NUM_PORTS];
    logic                   voq_wr_last [NUM_PORTS];
    logic [ID_WIDTH-1:0]    voq_wr_id [NUM_PORTS];
    logic                   voq_wr_is_bad [NUM_PORTS];
    logic [2:0]             voq_wr_qos [NUM_PORTS];
    logic                   voq_wr_ready [NUM_PORTS][NUM_PORTS];

    logic                   voq_rd_valid [NUM_PORTS][NUM_PORTS];
    logic [DATA_WIDTH-1:0]  voq_rd_data [NUM_PORTS][NUM_PORTS];
    logic [DATA_WIDTH/8-1:0] voq_rd_keep [NUM_PORTS][NUM_PORTS];
    logic                   voq_rd_last [NUM_PORTS][NUM_PORTS];
    logic [ID_WIDTH-1:0]    voq_rd_id [NUM_PORTS][NUM_PORTS];
    logic                   voq_rd_is_bad [NUM_PORTS][NUM_PORTS];
    logic [2:0]             voq_rd_qos [NUM_PORTS][NUM_PORTS];
    logic                   voq_rd_ready [NUM_PORTS][NUM_PORTS];

    // XPQ stage
    logic                   xpq_wr_valid [NUM_PORTS][NUM_PORTS];
    logic [DATA_WIDTH-1:0]  xpq_wr_data [NUM_PORTS][NUM_PORTS];
    logic [DATA_WIDTH/8-1:0] xpq_wr_keep [NUM_PORTS][NUM_PORTS];
    logic                   xpq_wr_last [NUM_PORTS][NUM_PORTS];
    logic [ID_WIDTH-1:0]    xpq_wr_id [NUM_PORTS][NUM_PORTS];
    logic                   xpq_wr_is_bad [NUM_PORTS][NUM_PORTS];
    logic [2:0]             xpq_wr_qos [NUM_PORTS][NUM_PORTS];
    logic                   xpq_wr_ready [NUM_PORTS][NUM_PORTS];

    logic                   xpq_rd_valid [NUM_PORTS][NUM_PORTS];
    logic [DATA_WIDTH-1:0]  xpq_rd_data [NUM_PORTS][NUM_PORTS];
    logic [DATA_WIDTH/8-1:0] xpq_rd_keep [NUM_PORTS][NUM_PORTS];
    logic                   xpq_rd_last [NUM_PORTS][NUM_PORTS];
    logic [ID_WIDTH-1:0]    xpq_rd_id [NUM_PORTS][NUM_PORTS];
    logic                   xpq_rd_is_bad [NUM_PORTS][NUM_PORTS];
    logic [2:0]             xpq_rd_qos [NUM_PORTS][NUM_PORTS];
    logic                   xpq_rd_ready [NUM_PORTS][NUM_PORTS];

    // =========================================================================
    // Packet ID Manager
    // =========================================================================

    packet_id_manager #(
        .ID_WIDTH(ID_WIDTH),
        .MAX_PORTS(NUM_PORTS)
    ) id_manager (
        .clk(clk),
        .rst_n(rst_n),
        .alloc_req(id_alloc_req),
        .alloc_grant(id_alloc_grant),
        .allocated_id(allocated_id),
        .release_req(id_release_req),
        .release_id(release_id),
        .free_id_count(free_ids)
    );

    // =========================================================================
    // Fabric Ingress
    // =========================================================================

    fabric_ingress #(
        .NUM_PORTS(NUM_PORTS),
        .DATA_WIDTH(DATA_WIDTH),
        .ID_WIDTH(ID_WIDTH)
    ) ingress_stage (
        .clk(clk),
        .rst_n(rst_n),
        .rx_data_if(rx_data_if),
        .rx_meta_if(rx_meta_if),
        .voq_wr_valid(voq_wr_valid),
        .voq_wr_data(voq_wr_data),
        .voq_wr_keep(voq_wr_keep),
        .voq_wr_last(voq_wr_last),
        .voq_wr_id(voq_wr_id),
        .voq_wr_is_bad(voq_wr_is_bad),
        .voq_wr_qos(voq_wr_qos),
        .voq_wr_ready(voq_wr_ready),
        .id_alloc_req(id_alloc_req),
        .id_alloc_grant(id_alloc_grant),
        .allocated_id(allocated_id)
    );

    // =========================================================================
    // VOQ Array (NUM_PORTS × NUM_PORTS)
    // =========================================================================

    genvar src, dst;
    generate
        for (src = 0; src < NUM_PORTS; src++) begin : gen_voq_src
            for (dst = 0; dst < NUM_PORTS; dst++) begin : gen_voq_dst

                voq_buffer #(
                    .DATA_WIDTH(DATA_WIDTH),
                    .ID_WIDTH(ID_WIDTH),
                    .DEPTH_PER_QOS(VOQ_DEPTH),
                    .NUM_QOS_LEVELS(`QOS_LEVELS)
                ) voq (
                    .clk(clk),
                    .rst_n(rst_n),

                    .wr_valid(voq_wr_valid[src][dst]),
                    .wr_data(voq_wr_data[src]),
                    .wr_keep(voq_wr_keep[src]),
                    .wr_last(voq_wr_last[src]),
                    .wr_id(voq_wr_id[src]),
                    .wr_is_bad(voq_wr_is_bad[src]),
                    .wr_qos(voq_wr_qos[src]),
                    .wr_ready(voq_wr_ready[src][dst]),

                    .rd_valid(voq_rd_valid[src][dst]),
                    .rd_data(voq_rd_data[src][dst]),
                    .rd_keep(voq_rd_keep[src][dst]),
                    .rd_last(voq_rd_last[src][dst]),
                    .rd_id(voq_rd_id[src][dst]),
                    .rd_is_bad(voq_rd_is_bad[src][dst]),
                    .rd_qos(voq_rd_qos[src][dst]),
                    .rd_ready(voq_rd_ready[src][dst]),

                    .occupancy(),
                    .empty(),
                    .almost_full()
                );

            end
        end
    endgenerate

    // =========================================================================
    // Crosspoint (Arbitration)
    // =========================================================================

    fabric_crosspoint #(
        .NUM_PORTS(NUM_PORTS),
        .DATA_WIDTH(DATA_WIDTH),
        .ID_WIDTH(ID_WIDTH)
    ) crosspoint (
        .clk(clk),
        .rst_n(rst_n),
        .voq_rd_valid(voq_rd_valid),
        .voq_rd_data(voq_rd_data),
        .voq_rd_keep(voq_rd_keep),
        .voq_rd_last(voq_rd_last),
        .voq_rd_id(voq_rd_id),
        .voq_rd_is_bad(voq_rd_is_bad),
        .voq_rd_qos(voq_rd_qos),
        .voq_rd_ready(voq_rd_ready),
        .xpq_wr_valid(xpq_wr_valid),
        .xpq_wr_data(xpq_wr_data),
        .xpq_wr_keep(xpq_wr_keep),
        .xpq_wr_last(xpq_wr_last),
        .xpq_wr_id(xpq_wr_id),
        .xpq_wr_is_bad(xpq_wr_is_bad),
        .xpq_wr_qos(xpq_wr_qos),
        .xpq_wr_ready(xpq_wr_ready)
    );

    // =========================================================================
    // XPQ Array (NUM_PORTS × NUM_PORTS)
    // =========================================================================

    generate
        for (src = 0; src < NUM_PORTS; src++) begin : gen_xpq_src
            for (dst = 0; dst < NUM_PORTS; dst++) begin : gen_xpq_dst

                packet_buffer #(
                    .DATA_WIDTH(DATA_WIDTH),
                    .MAX_PACKET_SIZE(512),
                    .BUFFER_DEPTH(XPQ_DEPTH),
                    .ID_WIDTH(ID_WIDTH)
                ) xpq (
                    .clk(clk),
                    .rst_n(rst_n),

                    .wr_valid(xpq_wr_valid[src][dst]),
                    .wr_data(xpq_wr_data[src][dst]),
                    .wr_keep(xpq_wr_keep[src][dst]),
                    .wr_last(xpq_wr_last[src][dst]),
                    .wr_id(xpq_wr_id[src][dst]),
                    .wr_is_bad(xpq_wr_is_bad[src][dst]),
                    .wr_ready(xpq_wr_ready[src][dst]),

                    .rd_valid(xpq_rd_valid[src][dst]),
                    .rd_data(xpq_rd_data[src][dst]),
                    .rd_keep(xpq_rd_keep[src][dst]),
                    .rd_last(xpq_rd_last[src][dst]),
                    .rd_id(xpq_rd_id[src][dst]),
                    .rd_is_bad(xpq_rd_is_bad[src][dst]),
                    .rd_ready(xpq_rd_ready[src][dst]),

                    .packet_count(),
                    .word_count()
                );

            end
        end
    endgenerate

    // =========================================================================
    // Fabric Egress
    // =========================================================================

    fabric_egress #(
        .NUM_PORTS(NUM_PORTS),
        .DATA_WIDTH(DATA_WIDTH),
        .ID_WIDTH(ID_WIDTH)
    ) egress_stage (
        .clk(clk),
        .rst_n(rst_n),
        .xpq_rd_valid(xpq_rd_valid),
        .xpq_rd_data(xpq_rd_data),
        .xpq_rd_keep(xpq_rd_keep),
        .xpq_rd_last(xpq_rd_last),
        .xpq_rd_id(xpq_rd_id),
        .xpq_rd_is_bad(xpq_rd_is_bad),
        .xpq_rd_qos(xpq_rd_qos),
        .xpq_rd_ready(xpq_rd_ready),
        .tx_data_if(tx_data_if),
        .id_release_req(id_release_req),
        .release_id(release_id)
    );

    // =========================================================================
    // Statistics Counters
    // =========================================================================

    genvar p;
    generate
        for (p = 0; p < NUM_PORTS; p++) begin : gen_stats

            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    pkt_count_rx[p] <= 0;
                    pkt_count_tx[p] <= 0;
                    pkt_drop_count[p] <= 0;
                end else begin
                    // RX packet count
                    if (rx_data_if[p].valid && rx_data_if[p].ready && rx_data_if[p].last)
                        pkt_count_rx[p] <= pkt_count_rx[p] + 1;

                    // TX packet count
                    if (tx_data_if[p].valid && tx_data_if[p].ready && tx_data_if[p].last)
                        pkt_count_tx[p] <= pkt_count_tx[p] + 1;

                    // Drop count (when VOQ full)
                    if (rx_data_if[p].valid && !rx_data_if[p].ready)
                        pkt_drop_count[p] <= pkt_drop_count[p] + 1;
                end
            end

        end
    endgenerate

endmodule

`default_nettype wire