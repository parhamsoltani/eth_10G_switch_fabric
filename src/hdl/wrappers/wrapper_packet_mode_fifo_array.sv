`default_nettype none



`include "implement_options.vh"

module wrapper_packet_mode_fifo_array #(
    parameter MAIN_MEM_DEPTH                = `D,
    parameter NUM_FIFO                      = `N,
    parameter NUM_IN                        = `S,
    parameter ADDRESS_COPY_RATE             = `U,
    parameter   MULTICAST_SUPPORT       = `MULTICAST_SUPPORT,
    parameter META_DATA_WIDTH               = 8,
    parameter READY_THRESHOLD               = 2*(`S) + 10,

    // DO NOT CHANGE!
    parameter MAIN_MEM_DEPTH_LOG            = $clog2(MAIN_MEM_DEPTH),
    parameter NUM_FIFO_LOG                  = (NUM_FIFO == 1) ? 1 : $clog2(NUM_FIFO),
    parameter NUM_IN_LOG                    = (NUM_IN   == 1) ? 1 : $clog2(NUM_IN)
)(
    input   wire                            clk,

    // Inputs to be registered
    input   wire                            push_i,
    input   wire                            push_last_i,
    input   wire [NUM_IN_LOG-1:0]           push_input_id_i,
    input   wire [NUM_FIFO-1:0]             push_output_id_i,
    input   wire [META_DATA_WIDTH-1:0]      push_meta_data_i,
    input   wire                            pop_i,
    input   wire [NUM_FIFO_LOG-1:0]         pop_id_i,

    // Outputs from original module
    output  wire                            pop_last_o,
    output  wire [META_DATA_WIDTH-1:0]      pop_meta_data_o,
    output  wire [NUM_IN_LOG-1:0]           pop_input_id_o,
    output  wire [MAIN_MEM_DEPTH_LOG-1:0]   pop_rd_addr_o,
    output  wire                            ready, 
    output  wire [MAIN_MEM_DEPTH_LOG-1:0]   tp_input_o [NUM_IN],
    output  wire [MAIN_MEM_DEPTH_LOG-1:0]   hp_input_o [NUM_IN],
    output  wire [NUM_IN-1:0]               pop_from_last_packet_o,
    output  wire [NUM_FIFO-1:0]             none_mepty_fifos
);

    // === Registered inputs ===
    reg push_i_r;
    reg push_last_i_r;
    reg [NUM_IN_LOG-1:0]        push_input_id_i_r;
    reg [NUM_FIFO-1:0]          push_output_id_i_r;
    reg [META_DATA_WIDTH-1:0]   push_meta_data_i_r;
    reg pop_i_r;
    reg [NUM_FIFO_LOG-1:0]   pop_id_i_r;

    // === Input register logic ===
    always @(posedge clk) begin
        push_i_r            <= push_i;
        push_last_i_r       <= push_last_i;
        push_input_id_i_r   <= push_input_id_i;
        push_output_id_i_r  <= push_output_id_i;
        push_meta_data_i_r  <= push_meta_data_i;
        pop_i_r             <= pop_i;
        pop_id_i_r          <= pop_id_i;
    end

    // === Module instantiation ===
    generate;
        if (MULTICAST_SUPPORT) begin : gen_multicast_dfifo
            packet_mode_fifo_array_multicast #(
                .MAIN_MEM_DEPTH     (MAIN_MEM_DEPTH),
                .NUM_FIFO           (NUM_FIFO),
                .NUM_IN             (NUM_IN),
                .ADDRESS_COPY_RATE  (ADDRESS_COPY_RATE),
                .META_DATA_WIDTH    (META_DATA_WIDTH),
                .READY_THRESHOLD    (READY_THRESHOLD)
            ) fifo_array_inst (
                .clk                    (clk),
                .push_i                 (push_i_r),
                .push_last_i            (push_last_i_r),
                .push_input_id_i        (push_input_id_i_r),
                .push_output_id_i       (push_output_id_i_r),
                .push_meta_data_i       (push_meta_data_i_r),
                .pop_i                  (pop_i_r),
                .pop_id_i               (pop_id_i_r),
                .pop_last_o             (pop_last_o),
                .pop_meta_data_o        (pop_meta_data_o),
                .pop_input_id_o         (pop_input_id_o),
                .pop_rd_addr_o          (pop_rd_addr_o),
                .ready                  (ready),
                .tp_input_o             (tp_input_o),
                .hp_input_o             (hp_input_o),
                .pop_from_last_packet_o   (pop_from_last_packet_o),
                .none_mepty_fifos       (none_mepty_fifos)
            );
        end else begin : gen_unicast_dfifo
            packet_mode_fifo_array #(
                .MAIN_MEM_DEPTH     (MAIN_MEM_DEPTH),
                .NUM_FIFO           (NUM_FIFO),
                .NUM_IN             (NUM_IN),
                .ADDRESS_COPY_RATE  (ADDRESS_COPY_RATE),
                .META_DATA_WIDTH    (META_DATA_WIDTH),
                .READY_THRESHOLD    (READY_THRESHOLD)
            ) fifo_array_inst (
                .clk                    (clk),
                .push_i                 (push_i_r),
                .push_last_i            (push_last_i_r),
                .push_input_id_i        (push_input_id_i_r),
                .push_output_id_i       (push_output_id_i_r),
                .push_meta_data_i       (push_meta_data_i_r),
                .pop_i                  (pop_i_r),
                .pop_id_i               (pop_id_i_r),
                .pop_last_o             (pop_last_o),
                .pop_meta_data_o        (pop_meta_data_o),
                .pop_input_id_o         (pop_input_id_o),
                .pop_rd_addr_o          (pop_rd_addr_o),
                .ready                  (ready),
                .tp_input_o             (tp_input_o),
                .hp_input_o             (hp_input_o),
                .pop_from_last_packet_o   (pop_from_last_packet_o),
                .none_mepty_fifos       (none_mepty_fifos)
            );
        end
    endgenerate

    

endmodule



`default_nettype wire 