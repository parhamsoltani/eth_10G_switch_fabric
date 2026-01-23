`timescale 1ns / 1ps
`include "fabric_params.vh"
`include "implement_options.vh"

module fpga_top #(
    parameter NUM_PORTS = `NUM_PORTS,
    parameter W_MINI    = `DATA_WIDTH,
    parameter ID_WIDTH  = `PACKET_ID_WIDTH
)(
    // board pins (keep these small)
    input  wire           clk,
    input  wire           reset_n,

    // micro / management simple signals used by your QoS wrapper
    input  wire [15:0]    uif_addr,
    input  wire           uif_wr_en,
    input  wire [31:0]    uif_wr_data,
    input  wire           uif_rd_en,
    output wire [31:0]    uif_rd_data,

    // small debug
    output wire [3:0]     user_led
);

    // instantiate interfaces internally (NOT ports)
    switch_data_if        rx_data_if   [NUM_PORTS] ();
    switch_metadata_if   rx_meta_if   [NUM_PORTS] ();
    switch_data_if       tx_data_if   [NUM_PORTS] ();

    // instantiate the existing QoS wrapper / fabric
    switch_fabric_qos_wrapper #(
        .NUM_PORT(NUM_PORTS),
        .S(`S),
        .W_MINI(W_MINI),
        .MAIN_MEM_DEPTH(`D),
        .XPQ_DEPTH(`X),
        .OUTPUT_QUEUE_DEPTH(`OUTPUT_QUEUE_DEPTH),
        .MULTICAST_SUPPORT(`MULTICAST_SUPPORT),
        .MULTICAST_RATE(`U),
        .PACKET_ID_WIDTH(ID_WIDTH),
        .QOS_TAG_WIDTH(`QOS_TAG_WIDTH),
        .ENABLE_QOS(1)
    ) fabric_top_inst (
        .clk(clk),
        .reset(~reset_n),

        // pass *interfaces* (still internal)
        .rx_data_if(rx_data_if),
        .rx_meta_if(rx_meta_if),
        .tx_data_if(tx_data_if),

        // micro interface mapped to on-board physical pins
        .uif_addr(uif_addr),
        .uif_wr_en(uif_wr_en),
        .uif_wr_data(uif_wr_data),
        .uif_rd_en(uif_rd_en),
        .uif_rd_data(uif_rd_data),

        // debug outputs (unused here)
        .addr_fifos_num_free_o(),
        .free_fifo_count_o(),
        .qos_stats_overflow()
    );

    // simple heartbeat LED
    reg [23:0] hb;
    always @(posedge clk) begin
        if (!reset_n) hb <= 24'h0;
        else hb <= hb + 1;
    end
    assign user_led = hb[23:20];

endmodule
