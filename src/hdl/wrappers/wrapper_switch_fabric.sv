`timescale 1ns / 1ps
`default_nettype none

`include "fabric_params.vh"

module wrapper_switch_fabric #(
    parameter NUM_PORTS = `NUM_PORTS,
    parameter DATA_WIDTH = `DATA_WIDTH,
    parameter ID_WIDTH = `PACKET_ID_WIDTH
)(
    input wire clk,
    input wire reset,

    // Flattened RX data interface
    input  wire [DATA_WIDTH-1:0]        rx_data [NUM_PORTS],
    input  wire [$clog2(DATA_WIDTH/8+1)-1:0] rx_keep [NUM_PORTS],
    input  wire                         rx_valid [NUM_PORTS],
    input  wire                         rx_last [NUM_PORTS],
    input  wire                         rx_is_bad_frame [NUM_PORTS],
    output wire                         rx_ready [NUM_PORTS],

    // Flattened RX metadata interface
    input  wire [NUM_PORTS-1:0]         rx_dest_port_mask [NUM_PORTS],
    input  wire [2:0]                   rx_qos_tag [NUM_PORTS],
    input  wire                         rx_meta_valid [NUM_PORTS],
    output wire                         rx_meta_ready [NUM_PORTS],

    // Flattened TX data interface
    output wire [DATA_WIDTH-1:0]        tx_data [NUM_PORTS],
    output wire [$clog2(DATA_WIDTH/8+1)-1:0] tx_keep [NUM_PORTS],
    output wire                         tx_valid [NUM_PORTS],
    output wire                         tx_last [NUM_PORTS],
    output wire                         tx_is_bad_frame [NUM_PORTS],
    output wire [2:0]                   tx_qos_tag [NUM_PORTS],
    input  wire                         tx_ready [NUM_PORTS],

    // Status
    output wire [31:0]                  status_pkt_rx [NUM_PORTS],
    output wire [31:0]                  status_pkt_tx [NUM_PORTS],
    output wire [ID_WIDTH:0]            status_free_ids
);

    logic rst_n;
    assign rst_n = ~reset;

    // Interface instances
    switch_data_if #(.DATA_WIDTH(DATA_WIDTH), .ID_WIDTH(ID_WIDTH))
        rx_data_if [NUM_PORTS] ();

    switch_metadata_if #(.PORT_MASK_WIDTH(NUM_PORTS), .ID_WIDTH(ID_WIDTH))
        rx_meta_if [NUM_PORTS] ();

    switch_data_if #(.DATA_WIDTH(DATA_WIDTH), .ID_WIDTH(ID_WIDTH))
        tx_data_if [NUM_PORTS] ();

    // Wire up interfaces
    genvar i;
    generate
        for (i = 0; i < NUM_PORTS; i++) begin : gen_if_wiring

            // RX Data
            assign rx_data_if[i].data = rx_data[i];
            assign rx_data_if[i].keep = rx_keep[i];
            assign rx_data_if[i].valid = rx_valid[i];
            assign rx_data_if[i].last = rx_last[i];
            assign rx_data_if[i].is_bad_frame = rx_is_bad_frame[i];
            assign rx_data_if[i].id = '0;  // Assigned by fabric
            assign rx_ready[i] = rx_data_if[i].ready;

            // RX Meta
            assign rx_meta_if[i].dest_port_mask = rx_dest_port_mask[i];
            assign rx_meta_if[i].qos_tag = rx_qos_tag[i];
            assign rx_meta_if[i].valid = rx_meta_valid[i];
            assign rx_meta_if[i].id = '0;
            assign rx_meta_ready[i] = rx_meta_if[i].ready;

            // TX Data
            assign tx_data[i] = tx_data_if[i].data;
            assign tx_keep[i] = tx_data_if[i].keep;
            assign tx_valid[i] = tx_data_if[i].valid;
            assign tx_last[i] = tx_data_if[i].last;
            assign tx_is_bad_frame[i] = tx_data_if[i].is_bad_frame;
            assign tx_qos_tag[i] = tx_data_if[i].qos_tag;
            assign tx_data_if[i].ready = tx_ready[i];

        end
    endgenerate

    // Core fabric instance
    switch_fabric #(
        .NUM_PORTS(NUM_PORTS),
        .DATA_WIDTH(DATA_WIDTH),
        .ID_WIDTH(ID_WIDTH)
    ) fabric_core (
        .clk(clk),
        .rst_n(rst_n),
        .rx_data_if(rx_data_if),
        .rx_meta_if(rx_meta_if),
        .tx_data_if(tx_data_if),
        .pkt_count_rx(status_pkt_rx),
        .pkt_count_tx(status_pkt_tx),
        .pkt_drop_count(),
        .free_ids(status_free_ids)
    );

endmodule

`default_nettype wire