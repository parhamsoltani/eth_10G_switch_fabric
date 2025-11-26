`timescale 1ns / 1ns
`default_nettype none



module sync_fifo_init_value #(
    parameter WIDTH              = 72,
    parameter DEPTH              = 512,
    parameter N1                 = 64,
    parameter N2                 = 128,
    parameter MEMORY_PRIMITIVE   = "distributed",   // "auto", "block", "distributed", "ultra"
    parameter FWFT_MODE          = 1,
    parameter INLCUDE_PROTECTION = 1,
    // DO NOT CHANGE!
    parameter DEPTH_LOG          = $clog2(DEPTH),
    parameter INIT_DATA_COUNT    = N2 - N1 + 1 // dont change
)(
    input  wire                    clk,
    input  wire                    rst,        // synchronous, active-high reset
    input  wire                    push,
    input  wire [WIDTH-1:0]        push_data,
    input  wire                    pop,
    output wire [WIDTH-1:0]        pop_data,
    output wire                    full , //non-net output port 'full' cannot be initialized at declaration in SystemVerilog mode
    output wire                    empty,
    output wire  [DEPTH_LOG:0]     count
);

    localparam INIT_LOW = FWFT_MODE ? N1 + 1 : N1;

    
    localparam XPM_READ_LATENCY      = 1;
    localparam MEM_DEPTH          = 2**DEPTH_LOG;


    reg                    full_reg = INIT_DATA_COUNT == DEPTH;
    reg                    empty_reg = INIT_DATA_COUNT == 0;
    reg  [DEPTH_LOG:0]     count_reg = INIT_DATA_COUNT;

    reg [DEPTH_LOG:0] wr_ptr  = FWFT_MODE? INIT_DATA_COUNT-1:INIT_DATA_COUNT;
    reg [DEPTH_LOG:0] rd_ptr  = 0;

    wire [1:0] select_control_unit = INLCUDE_PROTECTION ? {push && !full_reg, pop && !empty_reg} : {push, pop};

    wire [WIDTH-1:0]        mem_rd_data;
    wire                    mem_rd_en = FWFT_MODE ? 1: pop;
    wire [DEPTH_LOG-1:0]    mem_rd_ptr = FWFT_MODE ? rd_ptr[DEPTH_LOG-1:0] + pop : rd_ptr[DEPTH_LOG-1:0];

    assign full     = full_reg;
    assign empty    = empty_reg;
    assign count    = count_reg;

    generate 
        if(FWFT_MODE) begin

            // RAM output and prefetch register
            
            reg  [WIDTH-1:0] data_out_r = N1;

            assign pop_data = data_out_r;

            
            // Pointer & counter update
            always @(posedge clk) begin
                // pack enables into a two-bit vector
                case (select_control_unit)
                    2'b10: begin
                        // write only
                        if (count_reg == 0) begin
                            data_out_r <= push_data;
                        end else begin
                            wr_ptr <= wr_ptr + 1;
                        end
                        count_reg  <= count_reg + 1;
                        if (count_reg == MEM_DEPTH) 
                            full_reg    <= 1;
                        
                        empty_reg   <= 0;
                    end
                    2'b01: begin
                        // read only
                        rd_ptr <= rd_ptr + 1;
                        count_reg  <= count_reg - 1;
                        data_out_r <= mem_rd_data;

                        full_reg    <= 0;
                        
                        if (count_reg == 1)
                            empty_reg   <= 1;
                    end
                    2'b11: begin
                        // simultaneous write and read: pointers advance, count_reg unchanged
                        if (count_reg == 0 || count_reg == 1) begin
                            data_out_r <= push_data;
                        end else begin
                            wr_ptr <= wr_ptr + 1;
                            rd_ptr <= rd_ptr + 1;
                            data_out_r <= mem_rd_data;
                        end
                    end
                endcase
            end
        end else if (!FWFT_MODE ) begin

            assign pop_data = mem_rd_data;
            

            // Pointer & counter update
            always @(posedge clk) begin
                // pack enables into a two-bit vector
                case (select_control_unit)
                    2'b10: begin
                        // write only
                        wr_ptr <= wr_ptr + 1;
                        count_reg  <= count_reg + 1;
                        if (count_reg == MEM_DEPTH - 1) 
                            full_reg    <= 1;
                        
                        empty_reg   <= 0;
                    end
                    2'b01: begin
                        // read only
                        rd_ptr <= rd_ptr + 1;
                        count_reg  <= count_reg - 1;

                        full_reg    <= 0;
                        
                        if (count_reg == 1)
                            empty_reg   <= 1;
                    end
                    2'b11: begin
                        // simultaneous write and read: pointers advance, count_reg unchanged
                        wr_ptr <= wr_ptr + 1;
                        rd_ptr <= rd_ptr + 1;
                    end
                endcase
            end
        end 
    endgenerate



    sdpram_init_value_n1_n2 #(
        .WIDTH             (WIDTH),
        .DEPTH             (MEM_DEPTH),
        .N1                (INIT_LOW),
        .N2                (N2),
        .MEMORY_PRIMITIVE  (MEMORY_PRIMITIVE),
        .XPM_READ_LATENCY  (XPM_READ_LATENCY)
    ) mem_inst (
        .clk        (clk),
        .wr_en_i    (push),
        .wr_addr_i  (wr_ptr[DEPTH_LOG-1:0]),
        .wr_data_i  (push_data),
        .rd_en_i    (mem_rd_en),
        .rd_addr_i  (mem_rd_ptr),
        .rd_data_o  (mem_rd_data)
    );


endmodule

`default_nettype wire
