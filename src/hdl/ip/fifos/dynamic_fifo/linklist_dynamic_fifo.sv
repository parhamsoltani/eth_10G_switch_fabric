`timescale 1ns / 1ps
`default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Company: Parman
// Engineer: Alireza Abbasian
// 
// Create Date:  2025-07-27 17:58:20
// Module Name: linklist_dynamic_fifo
// Project Name: 
// Target Devices: 
// Tool Versions: Vivado 2022.2
// Description: 
// Dependencies: 
// 
// Additional Comments: 

// 3 clk between 2 pop of same queue
// user should be careful don't push if the whole mem is full
// all memories have delay 1 (except main mem which is parametric) and are simple dual port, read first
// after two clk of pop cmd, pop error is ready and after 3 clk the pop empty is ready
// pop data is ready after MAIN_MEM_READ_LATENCY + 1 clk
// memory type of each of them is parameter of module
// each signal name: moduleNameWhichSignalExisted_PortNameSignalExisted_delay
// exactly after push, we can pop from same queue
// in next versions we can support  2 clk between 2 pop from same queue by comparing pop id with previous NP_dr_addr
// all output are registered
// we have no protection if a free queue poped or push when free address fifo is empty
//////////////////////////////////////////////////////////////////////////////////



module linklist_dynamic_fifo #(
    parameter DATA_WIDTH                    = 9,
    parameter MAIN_MEM_DEPTH                = 1024,
    parameter NUM_FIFO                      = 10,
    parameter MAIN_MEM_MEMORY_PRIMITIVE     = "block",      // "auto", "block", "distributed", "ultra"
    parameter NP_MEMORY_PRIMITIVE           = "block",   
    parameter HP_TP_MEMORY_PRIMITIVE        = "block",
    parameter FREE_FIFO_MEMORY_PRIMITIVE    = "block",
    parameter MAIN_MEM_READ_LATENCY         = 1,
    parameter INLCUDE_PROTECTION            = 0,            // Not implemented yet!
    // DO NOT CHANGE!
    parameter POINTER_WIDTH                 = $clog2(MAIN_MEM_DEPTH),
    parameter FIFO_ID_WIDTH                 = $clog2(NUM_FIFO),
    parameter FREE_FIFO_DEPTH_LOG           = $clog2(MAIN_MEM_DEPTH - NUM_FIFO),
    parameter FREE_FIFO_DEPTH               = 2**(FREE_FIFO_DEPTH_LOG)
)(
    input   wire                            clk,
    input   wire                            push,
    input   wire [DATA_WIDTH-1:0]           push_data,
    input   wire [FIFO_ID_WIDTH-1:0]        push_id,
    input   wire                            pop,
    input   wire [FIFO_ID_WIDTH-1:0]        pop_id,
    output  wire [DATA_WIDTH-1:0]           pop_data,
    // output  wire                            pop_error,
    // output  wire                            pop_empty,
    output  wire                            full , 
    output  wire [FREE_FIFO_DEPTH_LOG:0]    num_free, 
    output  wire [NUM_FIFO-1:0]             none_mepty_fifos
);



    // main_mem signal ports
    wire                            main_mem_wr_en;
    wire [POINTER_WIDTH-1:0]        main_mem_wr_addr;
    wire [DATA_WIDTH-1:0]           main_mem_wr_data;

    wire                            main_mem_rd_en;
    wire [POINTER_WIDTH-1:0]        main_mem_rd_addr;
    wire [DATA_WIDTH-1:0]           main_mem_rd_data;

    // np (next pointer) signal ports
    wire                            np_wr_en;
    wire [POINTER_WIDTH-1:0]        np_wr_addr;
    wire [POINTER_WIDTH-1:0]        np_wr_data;

    wire                            np_rd_en;
    wire [POINTER_WIDTH-1:0]        np_rd_addr;
    wire [POINTER_WIDTH-1:0]        np_rd_data;

    // tp_1 signal ports
    wire                            tp_1_wr_en;
    wire [FIFO_ID_WIDTH-1:0]        tp_1_wr_addr;
    wire [POINTER_WIDTH-1:0]        tp_1_wr_data;

    wire                            tp_1_rd_en;
    wire [FIFO_ID_WIDTH-1:0]        tp_1_rd_addr;
    wire [POINTER_WIDTH-1:0]        tp_1_rd_data;

    // tp_2 signal ports
    wire                            tp_2_wr_en;
    wire [FIFO_ID_WIDTH-1:0]        tp_2_wr_addr;
    wire [POINTER_WIDTH-1:0]        tp_2_wr_data;

    wire                            tp_2_rd_en;
    wire [FIFO_ID_WIDTH-1:0]        tp_2_rd_addr;
    wire [POINTER_WIDTH-1:0]        tp_2_rd_data;

    // hp signal ports
    wire                            hp_wr_en;
    wire [FIFO_ID_WIDTH-1:0]        hp_wr_addr;
    wire [POINTER_WIDTH-1:0]        hp_wr_data;

    wire                            hp_rd_en;
    wire [FIFO_ID_WIDTH-1:0]        hp_rd_addr;
    wire [POINTER_WIDTH-1:0]        hp_rd_data;

    // free_fifo signal ports
    wire                            faf_push;
    wire [POINTER_WIDTH-1:0]        faf_push_data;
    wire                            faf_pop;
    wire [POINTER_WIDTH-1:0]        faf_pop_data;
    wire                            faf_full;
    wire                            faf_empty;
    wire [FREE_FIFO_DEPTH_LOG:0]    faf_count;

    wire [DATA_WIDTH-1:0]       push_data_D     [0:1];
    wire                        push_D          [0:1];
    wire                        pop_D           [0:2];
    wire [FIFO_ID_WIDTH-1:0]    pop_id_D        [0:2];
    wire [POINTER_WIDTH-1:0]    faf_pop_data_D  [0:1];

    // reg pop_error_reg;
    // reg pop_empty_reg;
    reg not_push_in_same_last_pop = 1'b1;
    reg [NUM_FIFO-1:0] none_mepty_fifos_reg = 0;


    
    // assigning intermediate wiring
    // tp_1 inputs
    assign tp_1_wr_data = faf_pop_data;
    assign tp_1_wr_addr = push_id;
    assign tp_1_wr_en   = push;
    assign tp_1_rd_en   = push;
    assign tp_1_rd_addr = push_id;

    // tp_2
    assign tp_2_wr_data  = faf_pop_data;
    assign tp_2_wr_addr  = push_id;
    assign tp_2_wr_en    = push;
    assign tp_2_rd_en    = pop_D[1];
    assign tp_2_rd_addr  = pop_id_D[1];

    // main_mem
    assign main_mem_wr_data  = push_data_D[1];
    assign main_mem_wr_addr  = tp_1_rd_data;
    assign main_mem_wr_en    = push_D[1];
    assign main_mem_rd_en    = pop_D[1];
    assign main_mem_rd_addr  = hp_rd_data;

    // hp
    assign hp_wr_data  = np_rd_data;
    assign hp_wr_addr  = pop_id_D[2];
    assign hp_wr_en    = pop_D[2];
    assign hp_rd_en    = pop;
    assign hp_rd_addr  = pop_id;

    // np
    assign np_wr_data  = faf_pop_data_D[1];
    assign np_wr_addr  = tp_1_rd_data;
    assign np_wr_en    = push_D[1];
    assign np_rd_en    = pop_D[1];
    assign np_rd_addr  = hp_rd_data;

    // free_fifo
    assign faf_push       = pop_D[1];
    assign faf_push_data  = hp_rd_data;
    assign faf_pop        = push;



    // assing outputs
    assign full         = faf_empty;
    assign num_free     = faf_count;
    assign pop_data     = main_mem_rd_data;
    // assign pop_error    = pop_error_reg;
    // assign pop_empty    = pop_empty_reg;
    assign none_mepty_fifos = none_mepty_fifos_reg;


    // always @(posedge clk) begin
    //     pop_error_reg <= pop_D[1] && (tp_2_rd_data == hp_rd_data);
    // end

    always @(posedge clk) begin
        not_push_in_same_last_pop <= !(push && (push_id==pop_id_D[1]) && pop_D[1]);
    end

    // always @(posedge clk) begin
    //     pop_empty_reg <=    (pop_D[2] && (tp_2_rd_data == np_rd_data)) &&
    //                         (!(push && (push_id==pop_id_D[2]) && pop_D[2])) &&
    //                         not_push_in_same_last_pop;
    // end


    always @(posedge clk) begin
        if (push) begin
            none_mepty_fifos_reg[push_id] <= 1;
        end
        if (
            (pop_D[2] && (tp_2_rd_data == np_rd_data)) &&
            (!(push && (push_id==pop_id_D[2]) && pop_D[2])) &&
            not_push_in_same_last_pop
        ) begin
            none_mepty_fifos_reg[pop_id_D[2]] <= 0;
        end
    end


    

    delayed_regs #(
        .WIDTH      (DATA_WIDTH),
        .NUM_DELAY  (1)
    ) push_data_delay_inst (
        .clk            (clk),
        .signal_in      (push_data),
        .delayed_signal (push_data_D)
    );

    // push_D: 1-cycle delay of push
    delayed_regs #(
        .WIDTH      (1),
        .NUM_DELAY  (1)
    ) push_delay_inst (
        .clk            (clk),
        .signal_in      (push),
        .delayed_signal (push_D)
    );

    // pop_D: 2-cycle delay of pop
    delayed_regs #(
        .WIDTH      (1),
        .NUM_DELAY  (2)
    ) pop_delay_inst (
        .clk            (clk),
        .signal_in      (pop),
        .delayed_signal (pop_D)
    );

    // pop_id_D: 2-cycle delay of pop_id
    delayed_regs #(
        .WIDTH      (FIFO_ID_WIDTH),
        .NUM_DELAY  (2)
    ) pop_id_delay_inst (
        .clk            (clk),
        .signal_in      (pop_id),
        .delayed_signal (pop_id_D)
    );

    // faf_pop_data: 1-cycle delay of pop_data
    delayed_regs #(
        .WIDTH      (POINTER_WIDTH),
        .NUM_DELAY  (1)
    ) faf_pop_data_delay_inst (
        .clk            (clk),
        .signal_in      (faf_pop_data),
        .delayed_signal (faf_pop_data_D)
    );



    // main_mem: Stores FIFO data
    sdpram_xpm #(
        .WIDTH              (DATA_WIDTH),
        .DEPTH              (MAIN_MEM_DEPTH),
        .MEMORY_PRIMITIVE   (MAIN_MEM_MEMORY_PRIMITIVE),
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

    // np: Stores next pointers
    sdpram_xpm #(
        .WIDTH              (POINTER_WIDTH),
        .DEPTH              (MAIN_MEM_DEPTH),
        .MEMORY_PRIMITIVE   (NP_MEMORY_PRIMITIVE),
        .WRITE_MODE_B       ("READ_FIRST"),
        .XPM_READ_LATENCY   (1)
    ) np (
        .clk        (clk),
        .wr_en_i    (np_wr_en),
        .wr_addr_i  (np_wr_addr),
        .wr_data_i  (np_wr_data),
        .rd_en_i    (np_rd_en),
        .rd_addr_i  (np_rd_addr),
        .rd_data_o  (np_rd_data)
    );

    // tp_1: First tail pointer
    sdpram_init_value_n1_n2 #(
        .WIDTH              (POINTER_WIDTH),
        .DEPTH              (NUM_FIFO),
        .N1                 (0),
        .N2                 (NUM_FIFO - 1),
        .MEMORY_PRIMITIVE   (HP_TP_MEMORY_PRIMITIVE),
        .XPM_READ_LATENCY   (1)
    ) tp_1 (
        .clk        (clk),
        .wr_en_i    (tp_1_wr_en),
        .wr_addr_i  (tp_1_wr_addr),
        .wr_data_i  (tp_1_wr_data),
        .rd_en_i    (tp_1_rd_en),
        .rd_addr_i  (tp_1_rd_addr),
        .rd_data_o  (tp_1_rd_data)
    );

    // tp_2: Second tail pointer
    sdpram_init_value_n1_n2 #(
        .WIDTH              (POINTER_WIDTH),
        .DEPTH              (NUM_FIFO),
        .N1                 (0),
        .N2                 (NUM_FIFO - 1),
        .MEMORY_PRIMITIVE   (HP_TP_MEMORY_PRIMITIVE),
        .XPM_READ_LATENCY   (1)
    ) tp_2 (
        .clk        (clk),
        .wr_en_i    (tp_2_wr_en),
        .wr_addr_i  (tp_2_wr_addr),
        .wr_data_i  (tp_2_wr_data),
        .rd_en_i    (tp_2_rd_en),
        .rd_addr_i  (tp_2_rd_addr),
        .rd_data_o  (tp_2_rd_data)
    );

    // hp: Head pointer
    sdpram_init_value_n1_n2 #(
        .WIDTH              (POINTER_WIDTH),
        .DEPTH              (NUM_FIFO),
        .N1                 (0),
        .N2                 (NUM_FIFO - 1),
        .MEMORY_PRIMITIVE   (HP_TP_MEMORY_PRIMITIVE),
        .XPM_READ_LATENCY   (1)
    ) hp (
        .clk        (clk),
        .wr_en_i    (hp_wr_en),
        .wr_addr_i  (hp_wr_addr),
        .wr_data_i  (hp_wr_data),
        .rd_en_i    (hp_rd_en),
        .rd_addr_i  (hp_rd_addr),
        .rd_data_o  (hp_rd_data)
    );

    // free address fifo (FAF)
    sync_fifo_init_value #(
        .WIDTH              (POINTER_WIDTH),
        .DEPTH              (FREE_FIFO_DEPTH),
        .N1                 (NUM_FIFO),
        .N2                 (MAIN_MEM_DEPTH - 1),
        .MEMORY_PRIMITIVE   (FREE_FIFO_MEMORY_PRIMITIVE),
        .FWFT_MODE          (1),
        .INLCUDE_PROTECTION (INLCUDE_PROTECTION)
    ) free_fifo (
        .clk        (clk),
        .rst        (1'b0),  // no reset
        .push       (faf_push),
        .push_data  (faf_push_data),
        .pop        (faf_pop),
        .pop_data   (faf_pop_data),
        .full       (faf_full),
        .empty      (faf_empty),
        .count      (faf_count)
    );



    

endmodule

`default_nettype wire 