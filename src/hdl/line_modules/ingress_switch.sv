`timescale 1ns / 1ps
// `default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Company: IUST
// Engineer: Parham Soltani
//
// Create Date:  2025-08-02 16:00:45
// Module Name: ingress_switch
// Project Name:
// Target Devices:
// Tool Versions: Vivado 2022.2
// Description:
// Dependencies:
//
// Additional Comments:

//////////////////////////////////////////////////////////////////////////////////



module ingress_switch #(
    parameter   NUM_PORT                = 10,            // number of ports
    parameter   W_MINI                  = 64,            // bus data width (mini cell data width)
    parameter   KEEP_WIDTH              = 10,
    parameter   PACKET_ID_WIDTH         = 8,
    parameter   QOS_TAG_WIDTH           = 1,
    parameter   INPUT_QUEUE_DEPTH       = 16,
    parameter   INPUT_QUEUE_TUSER       = 1
) (
    input   wire                                clk,
    switch_data_if.slave_mp                     rx_data_if,
    switch_metadata_if.slave_mp                 rx_meta_if,
    input   wire                                rd_en_rx,
    output  wire [W_MINI-1:0]                   data_rx,
    output  wire [KEEP_WIDTH-1:0]               keep_rx,
    output  wire                                valid_rx,
    output  wire                                is_bad_frame_rx,
    output  wire [PACKET_ID_WIDTH-1:0]          packet_id_rx,
    output  wire                                last_rx,
    output  wire                                iq_fifo_almost_empty,
    output  wire [NUM_PORT-1:0]                 dest_mask_rx,
    output  wire                                dest_mask_valid_rx
);

    //==============================================================================
    // local parameters and integers
    //==============================================================================
    typedef enum logic [1:0] {
        START,
        HUNT,
        MATCH
    } dest_valid_state_t;

    // input_queue wires
    wire [W_MINI-1:0] input_queue_wr_tdata ;
    wire [INPUT_QUEUE_TUSER-1:0] input_queue_wr_tuser ;
    wire input_queue_wr_tvalid ;
    wire input_queue_wr_tlast ;
    wire input_queue_wr_tready ;
    wire input_queue_wr_prog_full ;

    wire [W_MINI-1:0] input_queue_rd_tdata;
    wire [INPUT_QUEUE_TUSER-1:0] input_queue_rd_tuser;
    wire input_queue_rd_tvalid;
    wire input_queue_rd_tlast;
    wire input_queue_rd_tready;
    wire input_queue_rd_almost_empty;


    dest_valid_state_t  dest_valid_state = START;

    reg [NUM_PORT-1:0]  dest_mask_rx_reg ;
    reg                 dest_mask_valid_rx_reg ;
    reg                 metadata_ready ;
    reg                 is_ids_equal ;




    initial begin
        dest_mask_rx_reg       = '0;
        dest_mask_valid_rx_reg = 1'b0;
        metadata_ready     = 1'b1;
        is_ids_equal       = 1'b0;
    end




    //==============================================================================
    // wires, regs and memories
    //==============================================================================



    // handle module input
    assign input_queue_wr_tdata   = rx_data_if.data;
    assign input_queue_wr_tuser   = {rx_data_if.id, rx_data_if.is_bad_frame, rx_data_if.keep};
    assign input_queue_wr_tvalid  = rx_data_if.valid;
    assign input_queue_wr_tlast   = rx_data_if.last;
    assign rx_data_if.ready       = input_queue_wr_tready;




    // drive output
    assign rx_meta_if.ready = metadata_ready;

    assign data_rx              = input_queue_rd_tdata;
    assign keep_rx              = input_queue_rd_tuser[KEEP_WIDTH-1:0];
    assign is_bad_frame_rx      = input_queue_rd_tuser[KEEP_WIDTH];
    assign packet_id_rx         = input_queue_rd_tuser[INPUT_QUEUE_TUSER-1:KEEP_WIDTH+1];
    assign valid_rx             = input_queue_rd_tvalid;
    assign last_rx              = input_queue_rd_tlast;
    assign iq_fifo_almost_empty = input_queue_rd_almost_empty;

    assign dest_mask_rx         = dest_mask_rx_reg;
    assign dest_mask_valid_rx   = dest_mask_valid_rx_reg;

    assign input_queue_rd_tready  = rd_en_rx;





    //==============================================================================
    // Main Controls
    //==============================================================================


    always @(posedge clk) begin
        is_ids_equal <= rx_meta_if.id == packet_id_rx;
    end

    always @(posedge clk) begin
        case (dest_valid_state)
            START: begin
                if (rx_meta_if.valid) begin
                    dest_mask_rx_reg <= rx_meta_if.dest_port_mask;
                    metadata_ready <= 1'b0;
                    dest_valid_state <= HUNT;
                end
            end
            HUNT: begin
                if (is_ids_equal) begin
                    dest_mask_valid_rx_reg <= 1'b1;
                    dest_valid_state <= MATCH;
                end
            end
            MATCH: begin
                if (valid_rx && rd_en_rx && last_rx) begin
                    metadata_ready <= 1'b1;
                    dest_mask_valid_rx_reg <= 1'b0;
                    dest_valid_state <= START;
                end
            end
        endcase
    end










    //==============================================================================
    // Instantiated Modules
    //==============================================================================
    axis_fifo #(
        .TDATA_WIDTH(W_MINI),
        .TUSER_WIDTH(INPUT_QUEUE_TUSER),
        .FIFO_DEPTH(INPUT_QUEUE_DEPTH)
    ) input_queue_inst (
        .async_rst      ('0),
        .clk            (clk),
        .wr_tdata       (input_queue_wr_tdata),
        .wr_tuser       (input_queue_wr_tuser),
        .wr_tvalid      (input_queue_wr_tvalid),
        .wr_tlast       (input_queue_wr_tlast),
        .wr_tready      (input_queue_wr_tready),
        .wr_prog_full   (input_queue_wr_prog_full),
        .rd_tdata       (input_queue_rd_tdata),
        .rd_tuser       (input_queue_rd_tuser),
        .rd_tvalid      (input_queue_rd_tvalid),
        .rd_tlast       (input_queue_rd_tlast),
        .rd_tready      (input_queue_rd_tready),
        .rd_almost_empty(input_queue_rd_almost_empty)
    );




    //==============================================================================
    // Functions
    //==============================================================================

endmodule

`default_nettype wire