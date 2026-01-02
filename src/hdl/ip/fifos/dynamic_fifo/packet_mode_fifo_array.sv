`timescale 1ns / 1ps
// `default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Company: IUST
// Engineer: Parham Soltani
//
// Create Date:  2025-07-27 17:58:20
// Module Name: packet_mode_fifo_array
// Description: Fixed timing for rd_addr_out_reg mux selection
//////////////////////////////////////////////////////////////////////////////////

module packet_mode_fifo_array #(
    parameter MAIN_MEM_DEPTH                = 1024,
    parameter NUM_FIFO                      = 10,
    parameter NUM_IN                        = 10,
    parameter ADDRESS_COPY_RATE             = 2,
    parameter META_DATA_WIDTH               = 8,
    parameter READY_THRESHOLD               = 10,
    // DO NOT CHANGE!
    parameter MAIN_MEM_DEPTH_LOG            = $clog2(MAIN_MEM_DEPTH),
    parameter NUM_FIFO_LOG                  = (NUM_FIFO == 1) ? 1 : $clog2(NUM_FIFO),
    parameter NUM_IN_LOG                    = (NUM_IN   == 1) ? 1 : $clog2(NUM_IN)
)(
    input   wire                            clk,
    input   wire                            push_i,
    input   wire                            push_last_i,
    input   wire [NUM_IN_LOG-1:0]           push_input_id_i,
    input   wire [NUM_FIFO-1:0]             push_output_id_i,
    input   wire [META_DATA_WIDTH-1:0]      push_meta_data_i,
    input   wire                            pop_i,
    input   wire [NUM_FIFO_LOG-1:0]         pop_id_i,
    output  wire                            pop_last_o,
    output  wire [META_DATA_WIDTH-1:0]      pop_meta_data_o,
    output  wire [NUM_IN_LOG-1:0]           pop_input_id_o,
    output  wire [MAIN_MEM_DEPTH_LOG-1:0]   pop_rd_addr_o,
    output  wire                            ready,
    output  wire [MAIN_MEM_DEPTH_LOG-1:0]   tp_input_o [NUM_IN],
    output  wire [MAIN_MEM_DEPTH_LOG-1:0]   hp_input_o [NUM_IN],
    output  wire [NUM_IN-1:0]               pop_from_last_packet_o,
    output  wire [NUM_FIFO-1:0]             none_mepty_fifos,
    output  wire [$clog2(ADDRESS_COPY_RATE * MAIN_MEM_DEPTH):0] addr_fifos_num_free_o,
    output  wire [MAIN_MEM_DEPTH_LOG:0]     free_fifo_count_o
);

    localparam ADDRESS_FIFO_DEPTH           = 2**($clog2(ADDRESS_COPY_RATE * MAIN_MEM_DEPTH));
    localparam FREE_FIFO_DEPTH              = 2**(MAIN_MEM_DEPTH_LOG);
    localparam NP_WIDTH                     = NUM_IN_LOG + MAIN_MEM_DEPTH_LOG + 1 + META_DATA_WIDTH;
    localparam OUT_MEM_WIDTH                = MAIN_MEM_DEPTH_LOG + 1;

    localparam ADDRESS_FIFO_MAIN_MEM_MEMORY_PRIMITIVE   = ADDRESS_FIFO_DEPTH > 64 ? "block" : "distributed";
    localparam ADDRESS_FIFO_NP_MEMORY_PRIMITIVE         = ADDRESS_FIFO_DEPTH > 64 ? "block" : "distributed";
    localparam ADDRESS_FIFO_HP_TP_MEMORY_PRIMITIVE      = NUM_FIFO > 64 ? "block" : "distributed";
    localparam ADDRESS_FIFO_FREE_FIFO_MEMORY_PRIMITIVE  = ADDRESS_FIFO_DEPTH > 64 ? "block" : "distributed";
    localparam FREE_FIFO_MEMORY_PRIMITIVE               = FREE_FIFO_DEPTH > 64 ? "block" : "distributed";
    localparam NP_MEMORY_PRIMITIVE                      = MAIN_MEM_DEPTH > 64 ? "block" : "distributed";
    localparam OUT_MEM_MEMORY_PRIMITIVE                 = NUM_FIFO > 64 ? "block" : "distributed";

    localparam READY_THRESHOLD_INT = READY_THRESHOLD > 2*NUM_IN+5 ? READY_THRESHOLD : 2*NUM_IN+5;

    // addr_fifos input wires
    reg                                 addr_fifos_push;
    wire [MAIN_MEM_DEPTH_LOG-1:0]       addr_fifos_push_data;
    wire [NUM_FIFO_LOG-1:0]             addr_fifos_push_id;
    reg                                 addr_fifos_pop;
    reg  [NUM_FIFO_LOG-1:0]             addr_fifos_pop_id;
    // addr_fifos output wires
    wire [MAIN_MEM_DEPTH_LOG-1:0]       addr_fifos_pop_data;
    wire                                addr_fifos_full;
    wire [$clog2(ADDRESS_FIFO_DEPTH):0] addr_fifos_num_free;
    wire [NUM_FIFO-1:0]                 addr_fifos_none_mepty_fifos;

    // free_fifo input wires
    wire                                free_fifo_push;
    wire [MAIN_MEM_DEPTH_LOG-1:0]       free_fifo_push_data;
    wire                                free_fifo_pop;
    // free_fifo output wires
    wire [MAIN_MEM_DEPTH_LOG-1:0]       free_fifo_pop_data;
    wire                                free_fifo_full;
    wire                                free_fifo_empty;
    wire [MAIN_MEM_DEPTH_LOG:0]         free_fifo_count;

    // np signal ports
    wire                                np_wr_en;
    wire [MAIN_MEM_DEPTH_LOG-1:0]       np_wr_addr;
    wire [NP_WIDTH-1:0]                 np_wr_data;
    wire                                np_rd_en;
    wire [MAIN_MEM_DEPTH_LOG-1:0]       np_rd_addr;
    wire [NP_WIDTH-1:0]                 np_rd_data;

    // out_addr_mem signal ports
    wire                                out_addr_mem_wr_en;
    wire [NUM_FIFO_LOG-1:0]             out_addr_mem_wr_addr;
    wire [OUT_MEM_WIDTH-1:0]            out_addr_mem_wr_data;
    wire                                out_addr_mem_rd_en;
    wire [NUM_FIFO_LOG-1:0]             out_addr_mem_rd_addr;
    wire [OUT_MEM_WIDTH-1:0]            out_addr_mem_rd_data;

    wire [MAIN_MEM_DEPTH_LOG-1:0]       prev_rd_addr;
    wire                                prev_last;
    wire [NUM_FIFO_LOG-1:0]             first_none_zero_index;

    wire                                push_D                  [0:1];
    wire                                push_last_D             [0:1];
    wire [MAIN_MEM_DEPTH_LOG-1:0]       free_fifo_pop_data_D    [0:1];
    wire                                pop_D                   [0:6];
    wire [NUM_FIFO_LOG-1:0]             pop_id_D                [0:5];
    wire [META_DATA_WIDTH-1:0]          push_meta_data_D        [0:1];
    wire [NUM_IN_LOG-1:0]               push_input_id_D         [0:1];
    wire [MAIN_MEM_DEPTH_LOG-1:0]       rd_addr_out_reg_D       [0:2];
    wire [NUM_IN_LOG-1:0]               pop_input_id_D          [0:1];
    wire                                pop_last_D              [0:1];

    // FIX: Track the mux select decision separately from prev_last
    // We capture the decision at cycle 2 (when addr_fifos_pop is set)
    // and delay it to align with when we need to select (cycle 4, combinational before cycle 5 reg)
    reg                                 use_addr_fifo_reg;      // Captured at cycle 2
    reg                                 use_addr_fifo_d1;       // Cycle 3
    reg                                 use_addr_fifo_d2;       // Cycle 4 - use this for mux

    // prev_rd_addr delayed to align with addr_fifos_pop_data
    // FIX: Array size must be [0:3] for NUM_DELAY=3
    wire [MAIN_MEM_DEPTH_LOG-1:0]       prev_rd_addr_D          [0:3];

    reg [MAIN_MEM_DEPTH_LOG-1:0]    tp_input_reg [NUM_IN];
    reg [MAIN_MEM_DEPTH_LOG-1:0]    hp_input_reg [NUM_IN];
    reg                             sof [NUM_IN];
    reg                             ready_from_free_fifo = 1;
    reg                             ready_from_addr_fifo = 1;
    reg                             ready_reg = 1;
    reg [MAIN_MEM_DEPTH_LOG-1:0]    push_hp;
    reg [MAIN_MEM_DEPTH_LOG-1:0]    push_tp;
    reg [MAIN_MEM_DEPTH_LOG-1:0]    rd_addr_out_reg;
    reg                             pop_from_last_packet_reg [NUM_IN];
    reg [MAIN_MEM_DEPTH_LOG-1:0]    pop_hp = MAIN_MEM_DEPTH-1;

    initial begin
        for (int i = 0; i < NUM_IN; ++i) begin
            tp_input_reg[i]             = i;
            hp_input_reg[i]             = i;
            sof[i]                      = 1'b1;
            pop_from_last_packet_reg[i] = 0;
        end
    end

    // ========================= module inputs ==================================
    // address fifo input signals
    always @(posedge clk) begin
        addr_fifos_push <= push_i && sof[push_input_id_i];
    end
    assign addr_fifos_push_data  = push_hp;
    assign addr_fifos_push_id    = first_none_zero_index;

    // FIX: Capture both addr_fifos_pop and the mux decision at cycle 2
    // Timing:
    // Cycle 0: pop_i asserted
    // Cycle 1: prev_last valid from out_addr_mem (1-cycle read latency)
    // Cycle 2: addr_fifos_pop and use_addr_fifo_reg registered
    // Cycle 3: use_addr_fifo_d1
    // Cycle 4: use_addr_fifo_d2 valid, addr_fifos_pop_data valid (2-cycle latency from cycle 2)
    // Cycle 4->5: rd_addr_out_reg captures mux output
    always @(posedge clk) begin
        addr_fifos_pop     <= pop_D[0] && prev_last;
        addr_fifos_pop_id  <= pop_id_D[1];
        use_addr_fifo_reg  <= pop_D[0] && prev_last;  // Same condition as addr_fifos_pop
    end

    // Delay the mux select by 2 more cycles to align with addr_fifos_pop_data
    always @(posedge clk) begin
        use_addr_fifo_d1 <= use_addr_fifo_reg;
        use_addr_fifo_d2 <= use_addr_fifo_d1;
    end

    // free address fifo input signals
    assign free_fifo_push       = pop_D[4];
    assign free_fifo_push_data  = rd_addr_out_reg;
    assign free_fifo_pop        = push_i;

    // concat np and last and metadata mem input signals
    assign np_wr_en    = push_D[1];
    assign np_wr_addr  = push_tp;
    assign np_wr_data  = {push_input_id_D[1], free_fifo_pop_data_D[1], push_last_D[1], push_meta_data_D[1]};
    assign np_rd_en    = pop_D[4];
    assign np_rd_addr  = rd_addr_out_reg;

    // out address mem input signals
    assign out_addr_mem_wr_en    = pop_D[5];
    assign out_addr_mem_wr_addr  = pop_id_D[5];
    assign out_addr_mem_wr_data  = {np_rd_data[NP_WIDTH-NUM_IN_LOG-1:META_DATA_WIDTH + 1], np_rd_data[META_DATA_WIDTH]};
    assign out_addr_mem_rd_en    = pop_i;
    assign out_addr_mem_rd_addr  = pop_id_i;

    assign prev_rd_addr         = out_addr_mem_rd_data[OUT_MEM_WIDTH-1:1];
    assign prev_last            = out_addr_mem_rd_data[0];
    // ==========================================================================

    //  ================= output signals ========================================
    assign ready            = ready_reg;
    assign none_mepty_fifos = addr_fifos_none_mepty_fifos;
    assign pop_rd_addr_o    = rd_addr_out_reg;
    assign pop_input_id_o   = np_rd_data[NP_WIDTH-1:NP_WIDTH-NUM_IN_LOG];
    assign pop_meta_data_o  = np_rd_data[META_DATA_WIDTH-1:0];
    assign pop_last_o       = np_rd_data[META_DATA_WIDTH];
    assign addr_fifos_num_free_o = addr_fifos_num_free;
    assign free_fifo_count_o = free_fifo_count;

    generate
        for (genvar i = 0; i < NUM_IN; i++) begin
            assign tp_input_o[i]            = tp_input_reg[i];
            assign hp_input_o[i]            = hp_input_reg[i];
            assign pop_from_last_packet_o[i] = pop_from_last_packet_reg[i];
        end
    endgenerate
    // ==========================================================================

    // ========================= logic =========================================

    always @(posedge clk) begin
        ready_from_free_fifo  <= (free_fifo_count     >= READY_THRESHOLD_INT);
        ready_from_addr_fifo  <= (addr_fifos_num_free >= READY_THRESHOLD_INT);
    end

    always @(posedge clk) begin
        ready_reg <= ready_from_free_fifo && ready_from_addr_fifo;
    end

    always @(posedge clk) begin
        if (push_i && push_last_i) begin
            sof[push_input_id_i] <= 1;
        end else if (push_i && (!push_last_i)) begin
            sof[push_input_id_i] <= 0;
        end
    end

    always @(posedge clk) begin
        if (push_i) begin
            tp_input_reg[push_input_id_i] <= free_fifo_pop_data;
        end
    end

    always @(posedge clk) begin
        if (push_i && push_last_i) begin
            hp_input_reg[push_input_id_i] <= free_fifo_pop_data;
        end
    end

    always @(posedge clk) begin
        push_hp <= hp_input_reg[push_input_id_i];
        push_tp <= tp_input_reg[push_input_id_i];
    end

    // FIX: Use use_addr_fifo_d2 as mux select - this is aligned with addr_fifos_pop_data
    // Both signals are valid at cycle 4, and rd_addr_out_reg captures at cycle 5
    // Use prev_rd_addr_D[3] which is 3 cycles delayed from cycle 1 = valid at cycle 4
    always @(posedge clk) begin
        rd_addr_out_reg <= use_addr_fifo_d2 ? addr_fifos_pop_data : prev_rd_addr_D[3];
    end

    always @(posedge clk) begin
        pop_hp <= hp_input_reg[pop_input_id_o];
    end

    always @(posedge clk) begin
        if (pop_last_D[1]) begin
            pop_from_last_packet_reg[pop_input_id_D[1]] <= 0;
        end else if ((rd_addr_out_reg_D[2] == pop_hp) && pop_D[6]) begin
            pop_from_last_packet_reg[pop_input_id_D[1]] <= 1;
        end
    end

    // synthesis translate_off
    always @(posedge clk) begin
        if (rd_addr_out_reg_D[1] == tp_input_reg[pop_input_id_o] && pop_D[5]) begin
            $warning("poped from last cell: input = %0d, output = %0d", pop_input_id_o, pop_id_D[5]);
        end
    end
    // synthesis translate_on

    // ==========================================================================

    // ============================ instances ===================================
    delayed_regs #(
        .WIDTH      (1),
        .NUM_DELAY  (1)
    ) push_delay_inst (
        .clk            (clk),
        .signal_in      (push_i),
        .delayed_signal (push_D)
    );

    delayed_regs #(
        .WIDTH      (NUM_IN_LOG),
        .NUM_DELAY  (1)
    ) push_input_id_delay_inst (
        .clk            (clk),
        .signal_in      (push_input_id_i),
        .delayed_signal (push_input_id_D)
    );

    delayed_regs #(
        .WIDTH      (MAIN_MEM_DEPTH_LOG),
        .NUM_DELAY  (2)
    ) rd_addr_out_reg_delay_inst (
        .clk            (clk),
        .signal_in      (rd_addr_out_reg),
        .delayed_signal (rd_addr_out_reg_D)
    );

    delayed_regs #(
        .WIDTH      (NUM_IN_LOG),
        .NUM_DELAY  (1)
    ) pop_input_id_delay_inst (
        .clk            (clk),
        .signal_in      (pop_input_id_o),
        .delayed_signal (pop_input_id_D)
    );

    // Delay prev_rd_addr by 3 cycles to align with addr_fifos_pop_data and use_addr_fifo_d2
    // prev_rd_addr valid at cycle 1
    // prev_rd_addr_D[3] valid at cycle 4
    delayed_regs #(
        .WIDTH      (MAIN_MEM_DEPTH_LOG),
        .NUM_DELAY  (3)
    ) prev_rd_addr_delay_inst (
        .clk            (clk),
        .signal_in      (prev_rd_addr),
        .delayed_signal (prev_rd_addr_D)
    );

    delayed_regs #(
        .WIDTH      (1),
        .NUM_DELAY  (1)
    ) push_last_delay_inst (
        .clk            (clk),
        .signal_in      (push_last_i),
        .delayed_signal (push_last_D)
    );

    delayed_regs #(
        .WIDTH      (META_DATA_WIDTH),
        .NUM_DELAY  (1)
    ) push_meta_data_delay_inst (
        .clk            (clk),
        .signal_in      (push_meta_data_i),
        .delayed_signal (push_meta_data_D)
    );

    delayed_regs #(
        .WIDTH      (MAIN_MEM_DEPTH_LOG),
        .NUM_DELAY  (1)
    ) free_fifo_pop_data_delay_inst (
        .clk            (clk),
        .signal_in      (free_fifo_pop_data),
        .delayed_signal (free_fifo_pop_data_D)
    );

    delayed_regs #(
        .WIDTH      (1),
        .NUM_DELAY  (6)
    ) pop_delay_inst (
        .clk            (clk),
        .signal_in      (pop_i),
        .delayed_signal (pop_D)
    );

    delayed_regs #(
        .WIDTH      (NUM_FIFO_LOG),
        .NUM_DELAY  (5)
    ) pop_id_delay_inst (
        .clk            (clk),
        .signal_in      (pop_id_i),
        .delayed_signal (pop_id_D)
    );

    delayed_regs #(
        .WIDTH      (1),
        .NUM_DELAY  (1)
    ) pop_last_delay_inst (
        .clk            (clk),
        .signal_in      (pop_last_o),
        .delayed_signal (pop_last_D)
    );

    linklist_dynamic_fifo #(
        .DATA_WIDTH                    (MAIN_MEM_DEPTH_LOG),
        .MAIN_MEM_DEPTH                (ADDRESS_FIFO_DEPTH),
        .NUM_FIFO                      (NUM_FIFO),
        .MAIN_MEM_MEMORY_PRIMITIVE     (ADDRESS_FIFO_MAIN_MEM_MEMORY_PRIMITIVE),
        .NP_MEMORY_PRIMITIVE           (ADDRESS_FIFO_NP_MEMORY_PRIMITIVE),
        .HP_TP_MEMORY_PRIMITIVE        (ADDRESS_FIFO_HP_TP_MEMORY_PRIMITIVE),
        .FREE_FIFO_MEMORY_PRIMITIVE    (ADDRESS_FIFO_FREE_FIFO_MEMORY_PRIMITIVE),
        .MAIN_MEM_READ_LATENCY         (1),
        .INLCUDE_PROTECTION            (0)
    ) addr_fifos (
        .clk                (clk),
        .push               (addr_fifos_push),
        .push_data          (addr_fifos_push_data),
        .push_id            (addr_fifos_push_id),
        .pop                (addr_fifos_pop),
        .pop_id             (addr_fifos_pop_id),
        .pop_data           (addr_fifos_pop_data),
        .full               (addr_fifos_full),
        .num_free           (addr_fifos_num_free),
        .none_mepty_fifos   (addr_fifos_none_mepty_fifos)
    );

    sync_fifo_init_value #(
        .WIDTH              (MAIN_MEM_DEPTH_LOG),
        .DEPTH              (FREE_FIFO_DEPTH),
        .N1                 (NUM_IN),
        .N2                 (MAIN_MEM_DEPTH - 1),
        .MEMORY_PRIMITIVE   (FREE_FIFO_MEMORY_PRIMITIVE),
        .FWFT_MODE          (1),
        .INLCUDE_PROTECTION (0)
    ) free_fifo (
        .clk        (clk),
        .rst        (1'b0),
        .push       (free_fifo_push),
        .push_data  (free_fifo_push_data),
        .pop        (free_fifo_pop),
        .pop_data   (free_fifo_pop_data),
        .full       (free_fifo_full),
        .empty      (free_fifo_empty),
        .count      (free_fifo_count)
    );

    sdpram_xpm #(
        .WIDTH              (NP_WIDTH),
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

    sdpram_init_value_all_same #(
        .WIDTH              (OUT_MEM_WIDTH),
        .DEPTH              (NUM_FIFO),
        .MEM_VALUE          (1),
        .MEMORY_PRIMITIVE   (OUT_MEM_MEMORY_PRIMITIVE),
        .XPM_READ_LATENCY   (1)
    ) out_addr_mem (
        .clk        (clk),
        .wr_en_i    (out_addr_mem_wr_en),
        .wr_addr_i  (out_addr_mem_wr_addr),
        .wr_data_i  (out_addr_mem_wr_data),
        .rd_en_i    (out_addr_mem_rd_en),
        .rd_addr_i  (out_addr_mem_rd_addr),
        .rd_data_o  (out_addr_mem_rd_data)
    );

    first_non_zero #(
        .N                (NUM_FIFO)
    ) u_first_non_zero (
        .clk                (clk),
        .data_i             (push_output_id_i),
        .data_o             (first_none_zero_index)
    );

endmodule

`default_nettype wire