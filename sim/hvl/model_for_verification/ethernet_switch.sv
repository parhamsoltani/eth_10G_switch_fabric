`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Ethernet Switch Wrapper for Testbench
//////////////////////////////////////////////////////////////////////////////////

`include "sim_options.vh"
`include "implement_options.vh"
`include "fabric_params.vh"

module ethernet_switch #(
    parameter MICRO_ADDR_WIDTH      = 16,
    parameter MICRO_DATA_WIDTH      = 16,
    parameter LINE_RATE             = `LINE_RATE,
    parameter NUM_PORT              = `NUM_PORTS,
    parameter S                     = `S,
    parameter W_MINI                = `DATA_WIDTH,
    parameter MAIN_MEM_DEPTH        = `D,
    parameter XPQ_DEPTH             = `X,
    parameter OUTPUT_QUEUE_DEPTH    = `OUTPUT_QUEUE_DEPTH,
    parameter MULTICAST_SUPPORT     = `MULTICAST_SUPPORT,
    parameter MULTICAST_RATE        = `U,
    parameter PACKET_ID_WIDTH       = `PACKET_ID_WIDTH,
    parameter QOS_TAG_WIDTH         = `QOS_TAG_WIDTH
)(
    input  wire                     sys_clk,
    input  wire                     reset,
    
    // AXI-Stream interfaces from testbench
    axis_if.slave_mp                rx_axis [NUM_PORT],
    axis_if.master_mp               tx_axis [NUM_PORT],
    
    // IPG control
    output wire [3:0]               xg_ctl_tx_ipg_value [NUM_PORT],
    
    // Micro interface from testbench
    micro_if.slave_mp               m_if_in
);

    //==========================================================================
    // Local Parameters
    //==========================================================================
    localparam AXIS_DATA_WIDTH = 64;
    localparam AXIS_KEEP_WIDTH = AXIS_DATA_WIDTH / 8;
    localparam KEEP_WIDTH = $clog2((W_MINI/8) + 1);
    localparam ID_WIDTH = 10;

    //==========================================================================
    // Internal Interfaces
    //==========================================================================
    switch_data_if #(
        .DATA_WIDTH(W_MINI),
        .ID_WIDTH(ID_WIDTH),
        .KEEP_WIDTH(KEEP_WIDTH)
    ) rx_data_if [NUM_PORT] ();
    
    switch_metadata_if #(
        .PORT_MASK_WIDTH(NUM_PORT),
        .ID_WIDTH(PACKET_ID_WIDTH),
        .QOS_TAG_WIDTH(QOS_TAG_WIDTH)
    ) rx_meta_if [NUM_PORT] ();
    
    switch_data_if #(
        .DATA_WIDTH(W_MINI),
        .ID_WIDTH(ID_WIDTH),
        .KEEP_WIDTH(KEEP_WIDTH)
    ) tx_data_if [NUM_PORT] ();

    //==========================================================================
    // Microprocessor Interface
    //==========================================================================
    wire [15:0] uif_addr    = m_if_in.addr;
    wire        uif_wr_en   = m_if_in.wr_en;
    wire [31:0] uif_wr_data = {16'h0, m_if_in.wr_data};
    wire        uif_rd_en   = m_if_in.rd_en;
    wire [31:0] uif_rd_data;
    
    assign m_if_in.rd_data = uif_rd_data[MICRO_DATA_WIDTH-1:0];

    //==========================================================================
    // Debug Signals
    //==========================================================================
    wire [$clog2(MULTICAST_RATE * MAIN_MEM_DEPTH):0] addr_fifos_num_free;
    wire [$clog2(MAIN_MEM_DEPTH):0] free_fifo_count;
    wire [NUM_PORT-1:0] qos_stats_overflow;

    //==========================================================================
    // Packet Tracking
    //==========================================================================
    reg [PACKET_ID_WIDTH-1:0] packet_id_counter [NUM_PORT];
    reg [NUM_PORT-1:0] is_first_word;
    
    generate
        for (genvar i = 0; i < NUM_PORT; i++) begin : gen_pkt_tracking
            always @(posedge sys_clk) begin
                if (reset) begin
                    packet_id_counter[i] <= 0;
                    is_first_word[i] <= 1'b1;
                end else begin
                    if (rx_axis[i].tvalid && rx_axis[i].tready) begin
                        if (rx_axis[i].tlast) begin
                            packet_id_counter[i] <= packet_id_counter[i] + 1;
                            is_first_word[i] <= 1'b1;
                        end else begin
                            is_first_word[i] <= 1'b0;
                        end
                    end
                end
            end
        end
    endgenerate

    //==========================================================================
    // RX Path Conversion
    //==========================================================================
    generate
        for (genvar i = 0; i < NUM_PORT; i++) begin : gen_rx_conv
            
            // Count keep bytes
            wire [KEEP_WIDTH-1:0] keep_count;
            reg [KEEP_WIDTH-1:0] keep_cnt_reg;
            integer j;
            always @(*) begin
                keep_cnt_reg = 0;
                for (j = 0; j < AXIS_KEEP_WIDTH; j = j + 1) begin
                    keep_cnt_reg = keep_cnt_reg + rx_axis[i].tkeep[j];
                end
            end
            assign keep_count = keep_cnt_reg;
            
            // Destination mask
            wire [7:0] dest_byte = rx_axis[i].tdata[47:40];
            reg [NUM_PORT-1:0] dest_mask_calc;
            
            always @(*) begin
                if (dest_byte == 8'hFF) begin
                    dest_mask_calc = {NUM_PORT{1'b1}};
                    dest_mask_calc[i] = 1'b0;
                end else if (dest_byte[0]) begin
                    dest_mask_calc = {NUM_PORT{1'b1}};
                    dest_mask_calc[i] = 1'b0;
                end else begin
                    dest_mask_calc = {NUM_PORT{1'b0}};
                    if (dest_byte < NUM_PORT)
                        dest_mask_calc[dest_byte] = 1'b1;
                    else
                        dest_mask_calc[0] = 1'b1;
                end
            end

            // Data path
            assign rx_data_if[i].data         = rx_axis[i].tdata[W_MINI-1:0];
            assign rx_data_if[i].keep         = keep_count;
            assign rx_data_if[i].valid        = rx_axis[i].tvalid;
            assign rx_data_if[i].last         = rx_axis[i].tlast;
            assign rx_data_if[i].is_bad_frame = rx_axis[i].tuser[0];
            assign rx_data_if[i].id           = {{(ID_WIDTH-PACKET_ID_WIDTH){1'b0}}, packet_id_counter[i]};
            assign rx_data_if[i].qos_tag      = 3'b000;
            assign rx_axis[i].tready          = rx_data_if[i].ready;

            // Metadata
            assign rx_meta_if[i].dest_port_mask = dest_mask_calc;
            assign rx_meta_if[i].id             = packet_id_counter[i];
            assign rx_meta_if[i].qos_tag        = {QOS_TAG_WIDTH{1'b0}};
            assign rx_meta_if[i].vlan_id        = 12'h000;
            assign rx_meta_if[i].valid          = rx_axis[i].tvalid && is_first_word[i];
        end
    endgenerate

    //==========================================================================
    // TX Path Conversion
    //==========================================================================
    generate
        for (genvar i = 0; i < NUM_PORT; i++) begin : gen_tx_conv
            
            // Generate tkeep
            reg [AXIS_KEEP_WIDTH-1:0] tkeep_gen;
            integer k;
            always @(*) begin
                tkeep_gen = 0;
                for (k = 0; k < AXIS_KEEP_WIDTH; k = k + 1) begin
                    if (tx_data_if[i].keep == 0 || k < tx_data_if[i].keep)
                        tkeep_gen[k] = 1'b1;
                end
            end

            assign tx_axis[i].tdata  = {{(AXIS_DATA_WIDTH-W_MINI){1'b0}}, tx_data_if[i].data};
            assign tx_axis[i].tkeep  = tkeep_gen;
            assign tx_axis[i].tvalid = tx_data_if[i].valid;
            assign tx_axis[i].tlast  = tx_data_if[i].last;
            assign tx_axis[i].tuser  = tx_data_if[i].is_bad_frame;
            assign tx_data_if[i].ready = tx_axis[i].tready;
        end
    endgenerate

    //==========================================================================
    // DUT
    //==========================================================================
    switch_fabric_qos_wrapper #(
        .NUM_PORT(NUM_PORT),
        .S(S),
        .W_MINI(W_MINI),
        .MAIN_MEM_DEPTH(MAIN_MEM_DEPTH),
        .XPQ_DEPTH(XPQ_DEPTH),
        .OUTPUT_QUEUE_DEPTH(OUTPUT_QUEUE_DEPTH),
        .MULTICAST_SUPPORT(MULTICAST_SUPPORT),
        .MULTICAST_RATE(MULTICAST_RATE),
        .PACKET_ID_WIDTH(PACKET_ID_WIDTH),
        .QOS_TAG_WIDTH(QOS_TAG_WIDTH),
        .ENABLE_QOS(1)
    ) u_switch_fabric_qos (
        .clk(sys_clk),
        .reset(reset),
        .rx_data_if(rx_data_if),
        .rx_meta_if(rx_meta_if),
        .tx_data_if(tx_data_if),
        .uif_addr(uif_addr),
        .uif_wr_en(uif_wr_en),
        .uif_wr_data(uif_wr_data),
        .uif_rd_en(uif_rd_en),
        .uif_rd_data(uif_rd_data),
        .addr_fifos_num_free_o(addr_fifos_num_free),
        .free_fifo_count_o(free_fifo_count),
        .qos_stats_overflow(qos_stats_overflow)
    );

    //==========================================================================
    // IPG
    //==========================================================================
    generate
        for (genvar i = 0; i < NUM_PORT; i++) begin : gen_ipg
            assign xg_ctl_tx_ipg_value[i] = 4'd12;
        end
    endgenerate

endmodule