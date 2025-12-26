`timescale 1ns / 1ns

module sdpram_init_value_all_same
#(
    // User Configurable Parameters
    parameter   WIDTH               = 72,
    parameter   DEPTH               = 512,
    parameter   MEM_VALUE           = 2,
    parameter   MEMORY_PRIMITIVE    = "distributed",
    parameter   XPM_READ_LATENCY    = 1,
    // DO NOT change following parameters
    parameter   DEPTH_LOG           = $clog2(DEPTH)
)
(
    input   wire                    clk,

    input   wire                    wr_en_i,
    input   wire [DEPTH_LOG-1:0]    wr_addr_i,
    input   wire [WIDTH-1:0]        wr_data_i,

    input   wire                    rd_en_i,
    input   wire [DEPTH_LOG-1:0]    rd_addr_i,
    output  wire [WIDTH-1:0]        rd_data_o
);

    localparam WRITE_MODE_B = "READ_FIRST";

    generate
        if (MEM_VALUE == 0 && DEPTH == 16384) begin : gen_init_0_16384
            sdpram_init_value #(
                .WIDTH             (WIDTH),
                .DEPTH             (DEPTH),
                .INIT_FILE_NAME    ("mem_init_all_0_depth_16384.mem"),
                .MEMORY_PRIMITIVE  (MEMORY_PRIMITIVE),
                .WRITE_MODE_B      (WRITE_MODE_B),
                .XPM_READ_LATENCY  (XPM_READ_LATENCY)
            ) mem_inst (
                .clk        (clk),
                .wr_en_i    (wr_en_i),
                .wr_addr_i  (wr_addr_i),
                .wr_data_i  (wr_data_i),
                .rd_en_i    (rd_en_i),
                .rd_addr_i  (rd_addr_i),
                .rd_data_o  (rd_data_o)
            );
        end
        else if (MEM_VALUE == 1 && DEPTH == 10) begin : gen_init_1_10
            sdpram_init_value #(
                .WIDTH             (WIDTH),
                .DEPTH             (DEPTH),
                .INIT_FILE_NAME    ("mem_init_all_1_depth_10.mem"),
                .MEMORY_PRIMITIVE  (MEMORY_PRIMITIVE),
                .WRITE_MODE_B      (WRITE_MODE_B),
                .XPM_READ_LATENCY  (XPM_READ_LATENCY)
            ) mem_inst (
                .clk        (clk),
                .wr_en_i    (wr_en_i),
                .wr_addr_i  (wr_addr_i),
                .wr_data_i  (wr_data_i),
                .rd_en_i    (rd_en_i),
                .rd_addr_i  (rd_addr_i),
                .rd_data_o  (rd_data_o)
            );
        end
        else begin : gen_init_default
            sdpram_init_value #(
                .WIDTH             (WIDTH),
                .DEPTH             (DEPTH),
                .INIT_FILE_NAME    ("none"),
                .MEMORY_PRIMITIVE  (MEMORY_PRIMITIVE),
                .WRITE_MODE_B      (WRITE_MODE_B),
                .XPM_READ_LATENCY  (XPM_READ_LATENCY)
            ) mem_inst (
                .clk        (clk),
                .wr_en_i    (wr_en_i),
                .wr_addr_i  (wr_addr_i),
                .wr_data_i  (wr_data_i),
                .rd_en_i    (rd_en_i),
                .rd_addr_i  (rd_addr_i),
                .rd_data_o  (rd_data_o)
            );
        end
    endgenerate

endmodule