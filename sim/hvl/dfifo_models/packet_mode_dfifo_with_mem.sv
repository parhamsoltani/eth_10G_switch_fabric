`timescale 1ns / 1ps
`default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Company: IUST
// Engineer: Parham Soltani
// 
// Create Date:  2025-07-30 13:32:03
// Module Name: packet_mode_dfifo_with_mem
// Project Name: 
// Target Devices: 
// Tool Versions: Vivado 2022.2
// Description: 
// Dependencies: 
// 
// Additional Comments: 

//////////////////////////////////////////////////////////////////////////////////



module packet_mode_dfifo_with_mem #(
    parameter DATA_WIDTH                    = 160,
    parameter MAIN_MEM_DEPTH                = 512,
    parameter NUM_FIFO                      = 140,
    parameter NUM_IN                        = 10,
    parameter ADDRESS_COPY_RATE             = 2,            
    parameter META_DATA_WIDTH               = 8,      
    parameter READY_THRESHOLD               = 10,
    parameter MAIN_MEM_READ_LATENCY         = 2,
    // DO NOT CHANGE!
    parameter NUM_FIFO_LOG      = (NUM_FIFO == 1) ? 1 : $clog2(NUM_FIFO),
    parameter NUM_IN_LOG        = (NUM_IN   == 1) ? 1 : $clog2(NUM_IN)
)(
    input  wire                             clk,
    input  wire                             push,
    input  wire                             push_last,
    input  wire [DATA_WIDTH-1:0]            push_data,
    input  wire [NUM_FIFO-1:0]              push_output_id,
    input  wire [NUM_IN_LOG-1:0]            push_input_id,
    input  wire [META_DATA_WIDTH-1:0]       push_metadata,

    input  wire                             pop,
    input  wire [NUM_FIFO_LOG-1:0]          pop_id,

    output wire [DATA_WIDTH-1:0]            pop_data,
    output wire [META_DATA_WIDTH-1:0]       pop_metadata,
    output wire                             pop_last,
    output wire                             full,
    output wire [NUM_FIFO-1:0]              none_mepty_fifos,
    output  wire [NUM_IN_LOG-1:0]           pop_input_id_o,
    output  wire [NUM_IN-1:0]               pop_from_last_packet_o
);

    localparam MAIN_MEM_DEPTH_LOG            = $clog2(MAIN_MEM_DEPTH);
    localparam MAIN_MEM_MEMORY_PRIMITIVE   = MAIN_MEM_DEPTH < 64 ? "distributed" : 
                                             MAIN_MEM_DEPTH < 4000 ? "block" : "ultra";
    
    // Inputs
    wire                                mem_cntr_push_i;
    wire                                mem_cntr_push_last_i;
    wire [NUM_IN_LOG-1:0]               mem_cntr_push_input_id_i;
    wire [NUM_FIFO-1:0]                 mem_cntr_push_output_id_i;
    wire [META_DATA_WIDTH-1:0]          mem_cntr_push_meta_data_i;
    wire                                mem_cntr_pop_i;
    wire [NUM_FIFO_LOG-1:0]             mem_cntr_pop_id_i;

    // Outputs
    wire                                mem_cntr_pop_last_o;
    wire [META_DATA_WIDTH-1:0]          mem_cntr_pop_meta_data_o;
    wire [MAIN_MEM_DEPTH_LOG-1:0]       mem_cntr_pop_rd_addr_o;
    wire                                mem_cntr_ready;
    wire [MAIN_MEM_DEPTH_LOG-1:0]       mem_cntr_tp_input_o [NUM_IN];
    wire [MAIN_MEM_DEPTH_LOG-1:0]       mem_cntr_hp_input_o [NUM_IN];
    wire [NUM_FIFO-1:0]                 mem_cntr_none_mepty_fifos;


    wire                                main_mem_wr_en;
    wire [MAIN_MEM_DEPTH_LOG-1:0]       main_mem_wr_addr;
    wire [DATA_WIDTH-1:0]               main_mem_wr_data;

    wire                                main_mem_rd_en;
    wire [MAIN_MEM_DEPTH_LOG-1:0]       main_mem_rd_addr;
    wire [DATA_WIDTH-1:0]               main_mem_rd_data;

    wire pop_D [0:4];




    assign mem_cntr_push_i            = push;
    assign mem_cntr_push_last_i       = push_last;
    assign mem_cntr_push_input_id_i   = push_input_id;
    assign mem_cntr_push_output_id_i  = push_output_id;
    assign mem_cntr_push_meta_data_i  = push_metadata;
    assign mem_cntr_pop_i             = pop;
    assign mem_cntr_pop_id_i          = pop_id;

    assign main_mem_wr_en   = push;
    assign main_mem_wr_addr = mem_cntr_tp_input_o[push_input_id];
    assign main_mem_wr_data = push_data;

    assign main_mem_rd_en   = pop_D[4];
    assign main_mem_rd_addr = mem_cntr_pop_rd_addr_o;

    assign pop_data         = main_mem_rd_data;        
    assign pop_metadata     = mem_cntr_pop_meta_data_o;            
    assign pop_last         = mem_cntr_pop_last_o;        
    assign full             = !mem_cntr_ready;    
    assign none_mepty_fifos = mem_cntr_none_mepty_fifos;                

        

    packet_mode_fifo_array #(
        .MAIN_MEM_DEPTH      (MAIN_MEM_DEPTH),
        .NUM_FIFO            (NUM_FIFO),
        .NUM_IN              (NUM_IN),
        .ADDRESS_COPY_RATE   (ADDRESS_COPY_RATE),
        .META_DATA_WIDTH     (META_DATA_WIDTH),
        .READY_THRESHOLD     (READY_THRESHOLD)
    ) packet_mode_mem_controller (
        .clk                 (clk),
        .push_i              (mem_cntr_push_i),
        .push_last_i         (mem_cntr_push_last_i),
        .push_input_id_i     (mem_cntr_push_input_id_i),
        .push_output_id_i    (mem_cntr_push_output_id_i),
        .push_meta_data_i    (mem_cntr_push_meta_data_i),
        .pop_i               (mem_cntr_pop_i),
        .pop_id_i            (mem_cntr_pop_id_i),
        .pop_last_o          (mem_cntr_pop_last_o),
        .pop_meta_data_o     (mem_cntr_pop_meta_data_o),
        .pop_rd_addr_o       (mem_cntr_pop_rd_addr_o),
        .ready               (mem_cntr_ready),
        .tp_input_o          (mem_cntr_tp_input_o),
        .hp_input_o          (mem_cntr_hp_input_o),
        .none_mepty_fifos    (mem_cntr_none_mepty_fifos),
        .pop_input_id_o      (pop_input_id_o),
        .pop_from_last_packet_o(pop_from_last_packet_o)
    );


    sdpram_xpm #(
        .WIDTH              (DATA_WIDTH),
        .DEPTH              (MAIN_MEM_DEPTH),
        .MEMORY_PRIMITIVE   (MAIN_MEM_MEMORY_PRIMITIVE),  // You can parameterize this as needed
        .WRITE_MODE_B       ("READ_FIRST"),
        .XPM_READ_LATENCY   (MAIN_MEM_READ_LATENCY)
    ) main_mem (
        .clk        (clk),
        .wr_en_i    (main_mem_wr_en),
        .wr_addr_i  (main_mem_wr_addr),
        .wr_data_i  (main_mem_wr_data),
        .rd_en_i    (main_mem_rd_en),
        .rd_addr_i  (main_mem_rd_addr),
        .rd_data_o  (main_mem_rd_data)
    );

    delayed_regs #(
        .WIDTH      (1),
        .NUM_DELAY  (4)
    ) pop_delay_inst (
        .clk            (clk),
        .signal_in      (pop),
        .delayed_signal (pop_D)
    );



endmodule

`default_nettype wire 