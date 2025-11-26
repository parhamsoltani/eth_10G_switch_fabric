`timescale 1ns / 1ps
`default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Company: Parman
// Engineer: Alireza Abbasian
// 
// Create Date:  2025-08-02 16:33:51
// Module Name: shared_voq
// Project Name: 
// Target Devices: 
// Tool Versions: Vivado 2022.2
// Description: 
// Dependencies: 
// 
// Additional Comments: 

//////////////////////////////////////////////////////////////////////////////////



module shared_voq #(
    parameter   NUM_PORT                = 10,            // number of ports     
    parameter   S                       = 10,            // speed up
    parameter   W_MINI                  = 64,            // bus data width (mini cell data width)
    parameter   MAIN_MEM_DEPTH          = 512,           // main mem depth
    parameter   XPQ_DEPTH               = 64,
    parameter   OUTPUT_QUEUE_DEPTH      = 128,
    parameter   MULTICAST_SUPPORT       = 0,
    parameter   MULTICAST_RATE          = 1,
    parameter   PACKET_ID_WIDTH         = 8,
    parameter   QOS_TAG_WIDTH           = 1,
    parameter   KEEP_WIDTH              = $clog2((W_MINI/8) + 1),
    // DO NOT CHANGE!
    parameter S_LOG                     = $clog2(S),
    parameter MAIN_MEM_DEPTH_LOG        = $clog2(MAIN_MEM_DEPTH),
    parameter NUM_PORT_LOG              = $clog2(NUM_PORT),
    parameter DFIFO_META_DATA_WIDTH     = S + KEEP_WIDTH + 1 + S_LOG, // valids+last minicell keep+is_bad_frame+last_minicell_index
    parameter NUM_XPQ                   = (NUM_PORT+S-1)/S,
    parameter NUM_XPQ_LOG               = NUM_XPQ == 1 ? 1 : $clog2(NUM_XPQ)
) (
    input   wire                                clk,

    input   wire [W_MINI-1:0]                   data_rx [S],
    input   wire [KEEP_WIDTH-1:0]               keep_rx [S],
    input   wire                                valid_rx [S],
    input   wire                                is_bad_frame_rx [S],
    input   wire [PACKET_ID_WIDTH-1:0]          packet_id_rx [S],
    input   wire                                last_rx [S],
    input   wire                                iq_fifo_almost_empty [S],
    input   wire [NUM_PORT-1:0]                 dest_mask_rx [S],
    input   wire                                dest_mask_valid_rx [S],
    output  wire                                rd_en_rx [S],

    input   wire [NUM_PORT_LOG-1:0]             pop_index_i,
    input   wire                                pop_i,
    output  wire                                cell_valid_o,
    output  wire [DFIFO_META_DATA_WIDTH-1:0]    cell_metadata_o,
    output  wire                                last_cell_o,
    output  wire [NUM_XPQ_LOG-1:0]              xpq_index_o,
    output  wire [S_LOG-1:0]                    dest_s_index_o,
    output  wire [W_MINI-1:0]                   main_mem_rd_data_o   [S],
    output  wire [NUM_PORT-1:0]                 none_mepty_fifos_o,
    

    output  wire [$clog2(MULTICAST_RATE * MAIN_MEM_DEPTH):0] addr_fifos_num_free_o,
    output  wire [MAIN_MEM_DEPTH_LOG:0]         free_fifo_count_o
);


    

    //==============================================================================
    // local parameters and integers
    //==============================================================================
    
    
    localparam MAIN_MEM_READ_LATENCY        = 2;

    
    localparam DFIFO_READY_THRESHOLD = 2*S+20;


    localparam READ_OFFSET = 0;

    localparam FULL_WAIT_DURATION = 50;

    //==============================================================================
    // wires
    //==============================================================================


    // === main_mem wires ===
    wire [S_LOG-1:0]      main_mem_wr_sel_i;
    wire                        main_mem_wr_en_i     [S];
    wire [MAIN_MEM_DEPTH_LOG-1:0] main_mem_wr_addr_i [S];
    wire [W_MINI-1:0]           main_mem_wr_data_i   [S];

    wire                        main_mem_rd_en_i;
    wire [MAIN_MEM_DEPTH_LOG-1:0] main_mem_rd_addr_i;
    

    // === dfifo wires ===
    wire                        dfifo_push_i;
    wire                        dfifo_push_last_i;
    wire [S_LOG-1:0]            dfifo_push_input_id_i;
    wire [NUM_PORT-1:0]         dfifo_push_output_id_i;
    wire [DFIFO_META_DATA_WIDTH-1:0] dfifo_push_meta_data_i;

    wire                        dfifo_pop_i;
    wire [NUM_PORT_LOG-1:0]     dfifo_pop_id_i;
    wire                        dfifo_pop_last_o;
    wire [DFIFO_META_DATA_WIDTH-1:0] dfifo_pop_meta_data_o;
    wire [S_LOG-1:0]            dfifo_pop_input_id_o;
    wire [MAIN_MEM_DEPTH_LOG-1:0] dfifo_pop_rd_addr_o;
    wire                        dfifo_ready;

    wire [MAIN_MEM_DEPTH_LOG-1:0] dfifo_tp_input_o [S];
    wire [MAIN_MEM_DEPTH_LOG-1:0] dfifo_hp_input_o [S];
    wire [S-1:0]                 dfifo_pop_from_last_packet_o;
    wire [NUM_PORT-1:0]          dfifo_none_mepty_fifos;




    // === packet_to_cell wires ===
    wire [W_MINI-1:0]         p2c_data_rx          [S];
    wire [KEEP_WIDTH-1:0]     p2c_keep_rx          [S];
    wire                      p2c_valid_rx         [S];
    wire                      p2c_is_bad_frame_rx  [S];
    wire                      p2c_last_rx          [S];
    wire [NUM_PORT-1:0]       p2c_dest_mask_rx     [S];
    wire                      p2c_dest_mask_valid_rx [S];
    wire                      p2c_end_time_slot    [S];
    wire                      p2c_start_time_slot  [S];
    wire [S_LOG-1:0]          p2c_rr_counter       [S];
    wire                      p2c_force_to_send    [S];

    wire [NUM_PORT-1:0]       p2c_dest_mask_o      [S];
    wire                      p2c_pop_iq_o         [S];
    wire                      p2c_wr_en_o          [S];
    wire [W_MINI-1:0]         p2c_data_o           [S];
    wire                      p2c_make_cell_o      [S];
    wire                      p2c_last_cell_o      [S];
    wire [DFIFO_META_DATA_WIDTH- 1:0] p2c_metadata_o [S];

    

    
    
    
    
    

    



    // delayed signals
    wire pop_i_D [0:5];
    wire [NUM_PORT_LOG-1:0] pop_index_D [0:1];
    wire [NUM_XPQ_LOG-1:0]              dest_q_D[0:3];
    wire [S_LOG-1:0]                    dest_r_D[0:3];


    //==============================================================================
    // regs
    //==============================================================================


    reg [S_LOG-1:0]                     rr_counter [S];
    reg                                 rr_sel [S];
 

    initial begin
        for (int i = 0; i < S; i++) begin
            rr_counter[i] = S-1-i;
        end
    end

    initial begin
        rr_sel[S-1] = 1'b1;
        for (int i = 0; i < S-1; i++) begin
            rr_sel[i] = 1'b0;
        end
    end


    reg                                 p2c_make_cell_selected;
    reg                                 p2c_last_cell_selected;
    reg [NUM_PORT-1:0]                  p2c_dest_mask_selected;
    reg [DFIFO_META_DATA_WIDTH-1:0]     p2c_metadata_selected;


    reg [NUM_XPQ_LOG-1:0]              dest_q_reg;
    reg [S_LOG-1:0]                    dest_r_reg;

    
    //==============================================================================
    // assignments
    //==============================================================================



    generate
        for (genvar i = 0; i < S; i++) begin : gen_assign_p2c
            assign p2c_data_rx[i]            = data_rx [i];
            assign p2c_keep_rx[i]            = keep_rx [i];
            assign p2c_valid_rx[i]           = valid_rx [i];
            assign p2c_is_bad_frame_rx[i]    = is_bad_frame_rx [i];
            assign p2c_last_rx[i]            = last_rx[i];
            assign p2c_dest_mask_rx[i]       = dest_mask_rx[i];
            assign p2c_dest_mask_valid_rx[i] = dest_mask_valid_rx[i];
            assign p2c_end_time_slot[i]      = rr_sel[rr_index(i,S-1)];
            assign p2c_start_time_slot[i]    = rr_sel[rr_index(i,0)];
            assign p2c_rr_counter[i]         = rr_counter[rr_index(i,0)];
            assign p2c_force_to_send[i]      = dfifo_pop_from_last_packet_o[i];
            
        end
    endgenerate

    

    


    

    generate
        for (genvar i = 0; i < S; i++) begin : gen_main_mem_inputs
            assign main_mem_wr_en_i[i]    = p2c_wr_en_o[i];
            assign main_mem_wr_addr_i[i]  = dfifo_tp_input_o[i];
            assign main_mem_wr_data_i[i]  = p2c_data_o[i];
        end
    endgenerate

    assign main_mem_wr_sel_i        = rr_counter[2];
    assign main_mem_rd_en_i         = pop_i_D[4];
    assign main_mem_rd_addr_i       = dfifo_pop_rd_addr_o;

    assign dfifo_push_i             = p2c_make_cell_selected;
    assign dfifo_push_last_i        = p2c_last_cell_selected;
    assign dfifo_push_output_id_i   = p2c_dest_mask_selected;
    assign dfifo_push_meta_data_i   = p2c_metadata_selected;
    assign dfifo_pop_i              = pop_i;
    assign dfifo_push_input_id_i    = rr_counter[1];
    assign dfifo_pop_id_i           = pop_index_i;


    assign rd_en_rx = p2c_pop_iq_o;

    assign cell_valid_o = pop_i_D[5];
    assign xpq_index_o = dest_q_D[3];
    assign dest_s_index_o = dest_r_D[3];
    assign cell_metadata_o = dfifo_pop_meta_data_o;
    assign last_cell_o = dfifo_pop_last_o;
    assign none_mepty_fifos_o = dfifo_none_mepty_fifos;


    



    //==============================================================================
    // Main Controls
    //==============================================================================

    always @(posedge clk) begin
        dest_q_reg <= pop_index_D[1] / S; // 2D
        dest_r_reg <= pop_index_D[1] % S;
    end

    always @(posedge clk) begin
        p2c_make_cell_selected        <= p2c_make_cell_o[rr_counter[0]];
        p2c_last_cell_selected        <= p2c_last_cell_o[rr_counter[0]];
        p2c_dest_mask_selected        <= p2c_dest_mask_o[rr_counter[0]];
        p2c_metadata_selected         <= p2c_metadata_o[rr_counter[0]];
    end

    always @(posedge clk) begin
        for (int i = S-1; i > 0; i--) begin
            rr_counter[i] <= rr_counter[i-1];
        end
        rr_counter[0] <= rr_counter[S-1];
    end

    always @(posedge clk) begin
        for (int i = S-1; i > 0; i--) begin
            rr_sel[i] <= rr_sel[i-1];
        end
        rr_sel[0] <= rr_sel[S-1];
    end

    //==============================================================================
    // Instantiated Modules
    //==============================================================================

    generate
        for (genvar i = 0; i < S; i++) begin : gen_p2c
            packet_to_cell #(
                .NUM_PORT(NUM_PORT),
                .S(S),
                .W_MINI(W_MINI),
                .FULL_WAIT_DURATION(FULL_WAIT_DURATION)
            ) p2c (
                .clk(clk),
                .data_rx(p2c_data_rx[i]),
                .keep_rx(p2c_keep_rx[i]),
                .valid_rx(p2c_valid_rx[i]),
                .is_bad_frame_rx(p2c_is_bad_frame_rx[i]),
                .last_rx(p2c_last_rx[i]),
                .dest_mask_rx(p2c_dest_mask_rx[i]),
                .dest_mask_valid_rx(p2c_dest_mask_valid_rx[i]),
                .end_time_slot(p2c_end_time_slot[i]),
                .start_time_slot(p2c_start_time_slot[i]),
                .rr_counter(p2c_rr_counter[i]),
                .force_to_send(p2c_force_to_send[i]),
                .dfifo_ready(dfifo_ready),
                .dest_mask_o(p2c_dest_mask_o[i]),
                .pop_iq_o(p2c_pop_iq_o[i]),
                .wr_en_o(p2c_wr_en_o[i]),
                .data_o(p2c_data_o[i]),
                .make_cell_o(p2c_make_cell_o[i]),
                .last_cell_o(p2c_last_cell_o[i]),
                .metadata_o(p2c_metadata_o[i])
            );
        end
    endgenerate


    


    


    pipeline_mem_with_in_barrel #(
        .WIDTH(W_MINI),
        .DEPTH(MAIN_MEM_DEPTH),
        .NUM_MEM(S),
        .XPM_READ_LATENCY(MAIN_MEM_READ_LATENCY)
    ) main_mem (
        .clk(clk),
        .wr_sel_i(main_mem_wr_sel_i),
        .wr_en_i(main_mem_wr_en_i),
        .wr_addr_i(main_mem_wr_addr_i),
        .wr_data_i(main_mem_wr_data_i),
        .rd_en_i(main_mem_rd_en_i),
        .rd_addr_i(main_mem_rd_addr_i),
        .rd_data_o(main_mem_rd_data_o)
    );

    generate;
        if (MULTICAST_SUPPORT) begin : gen_multicast_dfifo
            packet_mode_fifo_array_multicast #(
                .MAIN_MEM_DEPTH      (MAIN_MEM_DEPTH),
                .NUM_FIFO            (NUM_PORT),
                .NUM_IN              (S),
                .ADDRESS_COPY_RATE   (MULTICAST_RATE),
                .META_DATA_WIDTH     (DFIFO_META_DATA_WIDTH),
                .READY_THRESHOLD     (DFIFO_READY_THRESHOLD)
            ) dfifo (
                .clk(clk),
                .push_i(dfifo_push_i),
                .push_last_i(dfifo_push_last_i),
                .push_input_id_i(dfifo_push_input_id_i),
                .push_output_id_i(dfifo_push_output_id_i),
                .push_meta_data_i(dfifo_push_meta_data_i),
                .pop_i(dfifo_pop_i),
                .pop_id_i(dfifo_pop_id_i),
                .pop_last_o(dfifo_pop_last_o),
                .pop_meta_data_o(dfifo_pop_meta_data_o),
                .pop_input_id_o(dfifo_pop_input_id_o),
                .pop_rd_addr_o(dfifo_pop_rd_addr_o),
                .ready(dfifo_ready),
                .tp_input_o(dfifo_tp_input_o),
                .hp_input_o(dfifo_hp_input_o),
                .pop_from_last_packet_o(dfifo_pop_from_last_packet_o),
                .none_mepty_fifos(dfifo_none_mepty_fifos),
                .addr_fifos_num_free_o(addr_fifos_num_free_o),
                .free_fifo_count_o(free_fifo_count_o)
            );
        end else begin : gen_unicast_dfifo
            packet_mode_fifo_array #(
                .MAIN_MEM_DEPTH      (MAIN_MEM_DEPTH),
                .NUM_FIFO            (NUM_PORT),
                .NUM_IN              (S),
                .ADDRESS_COPY_RATE   (1),
                .META_DATA_WIDTH     (DFIFO_META_DATA_WIDTH),
                .READY_THRESHOLD     (DFIFO_READY_THRESHOLD)
            ) dfifo (
                .clk(clk),
                .push_i(dfifo_push_i),
                .push_last_i(dfifo_push_last_i),
                .push_input_id_i(dfifo_push_input_id_i),
                .push_output_id_i(dfifo_push_output_id_i),
                .push_meta_data_i(dfifo_push_meta_data_i),
                .pop_i(dfifo_pop_i),
                .pop_id_i(dfifo_pop_id_i),
                .pop_last_o(dfifo_pop_last_o),
                .pop_meta_data_o(dfifo_pop_meta_data_o),
                .pop_input_id_o(dfifo_pop_input_id_o),
                .pop_rd_addr_o(dfifo_pop_rd_addr_o),
                .ready(dfifo_ready),
                .tp_input_o(dfifo_tp_input_o),
                .hp_input_o(dfifo_hp_input_o),
                .pop_from_last_packet_o(dfifo_pop_from_last_packet_o),
                .none_mepty_fifos(dfifo_none_mepty_fifos),
                .addr_fifos_num_free_o(addr_fifos_num_free_o),
                .free_fifo_count_o(free_fifo_count_o)
            );
        end
    endgenerate

    


    delayed_regs #(
        .WIDTH      (1),
        .NUM_DELAY  (5)
    ) dest_valid_delay_inst (
        .clk            (clk),
        .signal_in      (pop_i),
        .delayed_signal (pop_i_D)
    );

    delayed_regs #(
        .WIDTH      (NUM_PORT_LOG),
        .NUM_DELAY  (1)
    ) pop_index_delay_inst (
        .clk            (clk),
        .signal_in      (pop_index_i),
        .delayed_signal (pop_index_D)
    );

    // Delay line for dest_q_reg
    delayed_regs #(
        .WIDTH      (NUM_XPQ_LOG),
        .NUM_DELAY  (3)
    ) dest_q_delay_inst (
        .clk            (clk),
        .signal_in      (dest_q_reg),
        .delayed_signal (dest_q_D)
    );

    // Delay line for dest_r_reg
    delayed_regs #(
        .WIDTH      (S_LOG),
        .NUM_DELAY  (3)
    ) dest_r_delay_inst (
        .clk            (clk),
        .signal_in      (dest_r_reg),
        .delayed_signal (dest_r_D)
    );



    //==============================================================================
    // Functions
    //==============================================================================


    function automatic int rr_index(input int port_index, input int delay_val);
        return (port_index + delay_val + 10*S) % S;
    endfunction

endmodule

`default_nettype wire 