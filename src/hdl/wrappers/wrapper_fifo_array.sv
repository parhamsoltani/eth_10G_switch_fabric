`default_nettype none



`include "implement_options.vh"
module wrapper_fifo_array #(
    parameter DATA_WIDTH                 = $clog2(`D),
    parameter MAIN_MEM_DEPTH             = `U * `D,
    parameter NUM_FIFO                   = `N,
    parameter MAIN_MEM_READ_LATENCY      = 1,
    parameter INLCUDE_PROTECTION         = 0,

    // DO NOT CHANGE
    parameter POINTER_WIDTH              = $clog2(MAIN_MEM_DEPTH),
    parameter FIFO_ID_WIDTH              = $clog2(NUM_FIFO),
    parameter FREE_FIFO_DEPTH_LOG        = $clog2(MAIN_MEM_DEPTH - NUM_FIFO),
    parameter FREE_FIFO_DEPTH            = 2**(FREE_FIFO_DEPTH_LOG)
)(
    input   wire                            clk,
    input   wire                            push,
    input   wire [DATA_WIDTH-1:0]           push_data,
    input   wire [FIFO_ID_WIDTH-1:0]        push_id,
    input   wire                            pop,
    input   wire [FIFO_ID_WIDTH-1:0]        pop_id,
    output  wire [DATA_WIDTH-1:0]           pop_data,
    output  wire                            full , 
    output  wire [FREE_FIFO_DEPTH_LOG:0]    num_free, 
    output  wire [NUM_FIFO-1:0]             none_mepty_fifos
);

    parameter MAIN_MEM_MEMORY_PRIMITIVE  = MAIN_MEM_DEPTH > 64 ? "block" : "distributed";
    parameter NP_MEMORY_PRIMITIVE        = MAIN_MEM_DEPTH > 64 ? "block" : "distributed";
    parameter HP_TP_MEMORY_PRIMITIVE     = NUM_FIFO > 64 ? "block" : "distributed";
    parameter FREE_FIFO_MEMORY_PRIMITIVE = MAIN_MEM_DEPTH > 64 ? "block" : "distributed";

    // Registered Inputs
    reg push_reg;
    reg [DATA_WIDTH-1:0] push_data_reg;
    reg [FIFO_ID_WIDTH-1:0] push_id_reg;

    reg pop_reg;
    reg [FIFO_ID_WIDTH-1:0] pop_id_reg;

    always @(posedge clk) begin
        push_reg     <= push;
        push_data_reg <= push_data;
        push_id_reg   <= push_id;

        pop_reg      <= pop;
        pop_id_reg   <= pop_id;
    end

    linklist_dynamic_fifo #(
        .DATA_WIDTH                 (DATA_WIDTH),
        .MAIN_MEM_DEPTH             (MAIN_MEM_DEPTH),
        .NUM_FIFO                   (NUM_FIFO),
        .MAIN_MEM_MEMORY_PRIMITIVE  (MAIN_MEM_MEMORY_PRIMITIVE),
        .NP_MEMORY_PRIMITIVE        (NP_MEMORY_PRIMITIVE),
        .HP_TP_MEMORY_PRIMITIVE     (HP_TP_MEMORY_PRIMITIVE),
        .FREE_FIFO_MEMORY_PRIMITIVE (FREE_FIFO_MEMORY_PRIMITIVE),
        .MAIN_MEM_READ_LATENCY      (MAIN_MEM_READ_LATENCY),
        .INLCUDE_PROTECTION         (INLCUDE_PROTECTION)
    ) dut (
        .clk                (clk),
        .push               (push_reg),
        .push_data          (push_data_reg),
        .push_id            (push_id_reg),
        .pop                (pop_reg),
        .pop_id             (pop_id_reg),
        .pop_data           (pop_data),
        .full               (full),
        .num_free           (num_free),
        .none_mepty_fifos   (none_mepty_fifos)
    );

endmodule



`default_nettype wire 