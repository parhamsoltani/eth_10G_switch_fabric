`timescale 1ns / 1ps
// `default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Company: IUST
// Engineer: Parham Soltani
//
// Create Date:  2025-04-07 20:39:12
// Module Name: switch_fabric
// Project Name: switch
// Target Devices: ku3p
// Tool Versions: Vivado 2022.2
// Description:
// Dependencies:
//
// Additional Comments:

//////////////////////////////////////////////////////////////////////////////////



module switch_fabric #(
    parameter   NUM_PORT                = 10,            // number of ports
    parameter   S                       = 10,            // speed up
    parameter   W_MINI                  = 64,            // bus data width (mini cell data width)
    parameter   MAIN_MEM_DEPTH          = 512,           // main mem depth
    parameter   XPQ_DEPTH               = 64,
    parameter   OUTPUT_QUEUE_DEPTH      = 128,
    parameter   MULTICAST_SUPPORT       = 0,
    parameter   MULTICAST_RATE          = 1,        // Address fifos depth = MULTICAST_RATE* MAIN_MEM_DEPTH
    parameter   PACKET_ID_WIDTH         = 8,
    parameter   QOS_TAG_WIDTH           = 1
) (
    input   wire                                clk,
    input   wire                                reset,
    switch_data_if.slave_mp                     rx_data_if  [NUM_PORT],
    switch_metadata_if.slave_mp                 rx_meta_if  [NUM_PORT],
    switch_data_if.master_mp                    tx_data_if  [NUM_PORT],
    output  wire [$clog2(MULTICAST_RATE * MAIN_MEM_DEPTH):0] addr_fifos_num_free_o,
    output  wire [$clog2(MAIN_MEM_DEPTH):0]         free_fifo_count_o
);




    //==============================================================================
    // local parameters and typedefs
    //==============================================================================
    localparam KEEP_WIDTH = $clog2((W_MINI/8) + 1);

    localparam INPUT_QUEUE_DEPTH     = 2*S+10;
    localparam INPUT_QUEUE_TUSER     = PACKET_ID_WIDTH + 1 + KEEP_WIDTH;

    localparam OUTPUT_QUEUE_TUSER    = 1 + KEEP_WIDTH;
    localparam OQ_PROG_FULL_THRESH    = 30;
    localparam NOT_READY_LIMIT    = 20;






    //==============================================================================
    // wires, regs and memories
    //==============================================================================


    // Wires between ingress/egress switches and switch_s
    wire [W_MINI-1:0] data_rx        [NUM_PORT];
    wire [KEEP_WIDTH-1:0] keep_rx    [NUM_PORT];
    wire valid_rx                  [NUM_PORT];
    wire is_bad_frame_rx           [NUM_PORT];
    wire [PACKET_ID_WIDTH-1:0] packet_id_rx [NUM_PORT];
    wire last_rx                  [NUM_PORT];
    wire iq_fifo_almost_empty     [NUM_PORT];
    wire [NUM_PORT-1:0] dest_mask_rx [NUM_PORT];
    wire dest_mask_valid_rx       [NUM_PORT];
    wire rd_en_rx                 [NUM_PORT];

    wire [W_MINI-1:0] data_tx        [NUM_PORT];
    wire [KEEP_WIDTH-1:0] keep_tx    [NUM_PORT];
    wire valid_tx                  [NUM_PORT];
    wire is_bad_frame_tx           [NUM_PORT];
    wire last_tx                  [NUM_PORT];
    wire oq_wr_prog_full          [NUM_PORT];












    //==============================================================================
    // Main Controls
    //==============================================================================






    //==============================================================================
    // Instantiated Modules
    //==============================================================================

    generate;
        if (NUM_PORT <= S) begin       : gen_under_s        //FIXME
            switch_s #(
                .NUM_PORT(NUM_PORT),
                .S(S),
                .W_MINI(W_MINI),
                .MAIN_MEM_DEPTH(MAIN_MEM_DEPTH),
                .XPQ_DEPTH(XPQ_DEPTH),
                .OUTPUT_QUEUE_DEPTH(OUTPUT_QUEUE_DEPTH),
                .MULTICAST_SUPPORT(MULTICAST_SUPPORT),
                .MULTICAST_RATE(MULTICAST_RATE),
                .PACKET_ID_WIDTH(PACKET_ID_WIDTH),
                .QOS_TAG_WIDTH(QOS_TAG_WIDTH)
            ) switch_inst (
                .clk(clk),

                .data_rx(data_rx),
                .keep_rx(keep_rx),
                .valid_rx(valid_rx),
                .is_bad_frame_rx(is_bad_frame_rx),
                .packet_id_rx(packet_id_rx),
                .last_rx(last_rx),
                .iq_fifo_almost_empty(iq_fifo_almost_empty),
                .dest_mask_rx(dest_mask_rx),
                .dest_mask_valid_rx(dest_mask_valid_rx),
                .rd_en_rx(rd_en_rx),

                .data_tx(data_tx),
                .keep_tx(keep_tx),
                .valid_tx(valid_tx),
                .is_bad_frame_tx(is_bad_frame_tx),
                .last_tx(last_tx),
                .oq_wr_prog_full(oq_wr_prog_full),
                .addr_fifos_num_free_o(addr_fifos_num_free_o),
                .free_fifo_count_o(free_fifo_count_o)
            );

        end else if (NUM_PORT <= 2*S) begin :gen_2s
            switch_2s #(
                .NUM_PORT(NUM_PORT),
                .S(S),
                .W_MINI(W_MINI),
                .MAIN_MEM_DEPTH(MAIN_MEM_DEPTH),
                .XPQ_DEPTH(XPQ_DEPTH),
                .OUTPUT_QUEUE_DEPTH(OUTPUT_QUEUE_DEPTH),
                .MULTICAST_SUPPORT(MULTICAST_SUPPORT),
                .MULTICAST_RATE(MULTICAST_RATE),
                .PACKET_ID_WIDTH(PACKET_ID_WIDTH),
                .QOS_TAG_WIDTH(QOS_TAG_WIDTH)
            ) switch_inst (
                .clk(clk),

                .data_rx(data_rx),
                .keep_rx(keep_rx),
                .valid_rx(valid_rx),
                .is_bad_frame_rx(is_bad_frame_rx),
                .packet_id_rx(packet_id_rx),
                .last_rx(last_rx),
                .iq_fifo_almost_empty(iq_fifo_almost_empty),
                .dest_mask_rx(dest_mask_rx),
                .dest_mask_valid_rx(dest_mask_valid_rx),
                .rd_en_rx(rd_en_rx),

                .data_tx(data_tx),
                .keep_tx(keep_tx),
                .valid_tx(valid_tx),
                .is_bad_frame_tx(is_bad_frame_tx),
                .last_tx(last_tx),
                .oq_wr_prog_full(oq_wr_prog_full),
                .addr_fifos_num_free_o(addr_fifos_num_free_o),
                .free_fifo_count_o(free_fifo_count_o)
            );
        end else begin : gen_high_radix
            switch_high_radix_matching #(
                .NUM_PORT(NUM_PORT),
                .S(S),
                .W_MINI(W_MINI),
                .MAIN_MEM_DEPTH(MAIN_MEM_DEPTH),
                .XPQ_DEPTH(XPQ_DEPTH),
                .OUTPUT_QUEUE_DEPTH(OUTPUT_QUEUE_DEPTH),
                .MULTICAST_SUPPORT(MULTICAST_SUPPORT),
                .MULTICAST_RATE(MULTICAST_RATE),
                .PACKET_ID_WIDTH(PACKET_ID_WIDTH),
                .QOS_TAG_WIDTH(QOS_TAG_WIDTH)
            ) switch_inst (
                .clk(clk),

                .data_rx(data_rx),
                .keep_rx(keep_rx),
                .valid_rx(valid_rx),
                .is_bad_frame_rx(is_bad_frame_rx),
                .packet_id_rx(packet_id_rx),
                .last_rx(last_rx),
                .iq_fifo_almost_empty(iq_fifo_almost_empty),
                .dest_mask_rx(dest_mask_rx),
                .dest_mask_valid_rx(dest_mask_valid_rx),
                .rd_en_rx(rd_en_rx),

                .data_tx(data_tx),
                .keep_tx(keep_tx),
                .valid_tx(valid_tx),
                .is_bad_frame_tx(is_bad_frame_tx),
                .last_tx(last_tx),
                .oq_wr_prog_full(oq_wr_prog_full),
                .addr_fifos_num_free_o(addr_fifos_num_free_o),
                .free_fifo_count_o(free_fifo_count_o)
            );

        end
    endgenerate



    generate
        for (genvar i = 0; i < NUM_PORT; i++) begin : gen_ports

            ingress_switch #(
                .NUM_PORT(NUM_PORT),
                .W_MINI(W_MINI),
                .KEEP_WIDTH(KEEP_WIDTH),
                .PACKET_ID_WIDTH(PACKET_ID_WIDTH),
                .QOS_TAG_WIDTH(QOS_TAG_WIDTH),
                .INPUT_QUEUE_DEPTH(INPUT_QUEUE_DEPTH),
                .INPUT_QUEUE_TUSER(INPUT_QUEUE_TUSER)
            ) ingress_inst (
                .clk(clk),
                .rx_data_if(rx_data_if[i]),
                .rx_meta_if(rx_meta_if[i]),
                .rd_en_rx(rd_en_rx[i]),
                .data_rx(data_rx[i]),
                .keep_rx(keep_rx[i]),
                .valid_rx(valid_rx[i]),
                .is_bad_frame_rx(is_bad_frame_rx[i]),
                .packet_id_rx(packet_id_rx[i]),
                .last_rx(last_rx[i]),
                .iq_fifo_almost_empty(iq_fifo_almost_empty[i]),
                .dest_mask_rx(dest_mask_rx[i]),
                .dest_mask_valid_rx(dest_mask_valid_rx[i])
            );

            egress_switch #(
                .NUM_PORT(NUM_PORT),
                .W_MINI(W_MINI),
                .KEEP_WIDTH(KEEP_WIDTH),
                .OUTPUT_QUEUE_DEPTH(OUTPUT_QUEUE_DEPTH),
                .OUTPUT_QUEUE_TUSER(OUTPUT_QUEUE_TUSER),
                .OQ_PROG_FULL_THRESH(OQ_PROG_FULL_THRESH),
                .NOT_READY_LIMIT (NOT_READY_LIMIT)
            ) egress_inst (
                .clk(clk),
                .tx_data_if(tx_data_if[i]),
                .data_tx(data_tx[i]),
                .keep_tx(keep_tx[i]),
                .valid_tx(valid_tx[i]),
                .is_bad_frame_tx(is_bad_frame_tx[i]),
                .last_tx(last_tx[i]),
                .oq_wr_prog_full(oq_wr_prog_full[i])
            );

        end
    endgenerate





    //==============================================================================
    // Functions
    //==============================================================================





    // synthesis translate_off ============================
    initial begin
        $display(" ******************* Switch Configs: *******************");
        $display();
        $display("NUM_PORT =            %0d", NUM_PORT          );
        $display("S =                   %0d", S                 );
        $display("W_MINI =              %0d", W_MINI            );
        $display("MAIN_MEM_DEPTH =      %0d", MAIN_MEM_DEPTH    );
        $display("XPQ_DEPTH =           %0d", XPQ_DEPTH         );
        $display("OUTPUT_QUEUE_DEPTH =  %0d", OUTPUT_QUEUE_DEPTH);
        $display("MULTICAST_SUPPORT =   %0d", MULTICAST_SUPPORT );
        $display("MULTICAST_RATE =      %0d", MULTICAST_RATE    );
        $display("PACKET_ID_WIDTH =     %0d", PACKET_ID_WIDTH   );
        $display("QOS_TAG_WIDTH =       %0d", QOS_TAG_WIDTH     );
        $display(" *******************************************************");
    end

    // synthesis translate_on =============================


endmodule


`default_nettype wire