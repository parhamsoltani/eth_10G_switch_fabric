`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Switch Interface to AXI-Stream Adapter
// Converts switch_data_if to axis_if
//////////////////////////////////////////////////////////////////////////////////

module switch_to_axis_adapter #(
    parameter DATA_WIDTH = 64,
    parameter ID_WIDTH   = 8,
    parameter KEEP_WIDTH = $clog2((DATA_WIDTH/8) + 1)
) (
    input  wire                     clk,
    input  wire                     reset,

    // Switch interface input
    switch_data_if.slave            sw_data_in,

    // AXI-Stream output
    axis_if.master_mp               axis_out
);

    // Convert keep count back to tkeep bitmask
    function automatic [(DATA_WIDTH/8)-1:0] expand_keep;
        input [KEEP_WIDTH-1:0] keep_count;
        integer i;
        begin
            expand_keep = 0;
            for (i = 0; i < DATA_WIDTH/8; i = i + 1) begin
                if (i < keep_count)
                    expand_keep[i] = 1'b1;
            end
        end
    endfunction

    // Connect data path
    assign axis_out.tdata  = sw_data_in.data;
    assign axis_out.tkeep  = expand_keep(sw_data_in.keep);
    assign axis_out.tvalid = sw_data_in.valid;
    assign axis_out.tlast  = sw_data_in.last;
    assign axis_out.tuser  = sw_data_in.is_bad_frame;

    assign sw_data_in.ready = axis_out.tready;

endmodule

`default_nettype wire