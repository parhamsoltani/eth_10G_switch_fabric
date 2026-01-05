`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// AXI-Stream to Switch Interface Adapter
// Converts axis_if to switch_data_if + switch_metadata_if
//////////////////////////////////////////////////////////////////////////////////

module axis_to_switch_adapter #(
    parameter DATA_WIDTH    = 64,
    parameter ID_WIDTH      = 8,
    parameter NUM_PORT      = 10,
    parameter QOS_TAG_WIDTH = 3,
    parameter KEEP_WIDTH    = $clog2((DATA_WIDTH/8) + 1)
) (
    input  wire                     clk,
    input  wire                     reset,

    // AXI-Stream input
    axis_if.slave_mp                axis_in,

    // Switch interface output
    switch_data_if.master           sw_data_out,
    switch_metadata_if.master       sw_meta_out
);

    // Internal signals
    reg [ID_WIDTH-1:0]      pkt_id_counter;
    reg [NUM_PORT-1:0]      dest_mask_reg;
    reg [QOS_TAG_WIDTH-1:0] qos_tag_reg;
    reg                     sof;  // Start of frame

    // Count keep bits to generate KEEP_WIDTH signal
    function automatic [KEEP_WIDTH-1:0] count_keep_bits;
        input [(DATA_WIDTH/8)-1:0] tkeep;
        integer i;
        begin
            count_keep_bits = 0;
            for (i = 0; i < DATA_WIDTH/8; i = i + 1) begin
                if (tkeep[i])
                    count_keep_bits = count_keep_bits + 1;
            end
        end
    endfunction

    // Extract destination from packet (simplified - uses first bytes as dest mask)
    // In real implementation, this would parse Ethernet header
    function automatic [NUM_PORT-1:0] extract_dest_mask;
        input [DATA_WIDTH-1:0] tdata;
        input                  is_sof;
        begin
            if (is_sof) begin
                // Simple extraction: use lower bits of destination MAC as port mask
                // Real implementation would do MAC table lookup
                extract_dest_mask = tdata[NUM_PORT-1:0];
                if (extract_dest_mask == 0)
                    extract_dest_mask = {NUM_PORT{1'b1}};  // Broadcast if no dest
            end else begin
                extract_dest_mask = 0;
            end
        end
    endfunction

    // Packet ID counter
    always @(posedge clk) begin
        if (reset) begin
            pkt_id_counter <= 0;
        end else if (axis_in.tvalid && axis_in.tready && axis_in.tlast) begin
            pkt_id_counter <= pkt_id_counter + 1;
        end
    end

    // Start of frame detection
    always @(posedge clk) begin
        if (reset) begin
            sof <= 1'b1;
        end else if (axis_in.tvalid && axis_in.tready) begin
            sof <= axis_in.tlast;
        end
    end

    // Destination mask extraction on SOF
    always @(posedge clk) begin
        if (reset) begin
            dest_mask_reg <= {NUM_PORT{1'b1}};
            qos_tag_reg   <= 0;
        end else if (axis_in.tvalid && axis_in.tready && sof) begin
            dest_mask_reg <= extract_dest_mask(axis_in.tdata, 1'b1);
            // Extract QoS from VLAN PCP or default
            qos_tag_reg   <= axis_in.tuser[QOS_TAG_WIDTH-1:0];
        end
    end

    // Connect data path
    assign sw_data_out.data         = axis_in.tdata;
    assign sw_data_out.keep         = count_keep_bits(axis_in.tkeep);
    assign sw_data_out.valid        = axis_in.tvalid;
    assign sw_data_out.last         = axis_in.tlast;
    assign sw_data_out.is_bad_frame = axis_in.tuser[0];  // Assuming tuser[0] is error
    assign sw_data_out.id           = pkt_id_counter;
    assign sw_data_out.qos_tag      = qos_tag_reg;

    assign axis_in.tready           = sw_data_out.ready;

    // Connect metadata path
    assign sw_meta_out.dest_port_mask = dest_mask_reg;
    assign sw_meta_out.id             = pkt_id_counter;
    assign sw_meta_out.qos_tag        = qos_tag_reg;
    assign sw_meta_out.vlan_id        = 12'b0;
    assign sw_meta_out.valid          = axis_in.tvalid && sof;

    // Metadata ready (always accept for now)
    // Note: In real implementation, might need backpressure

endmodule

`default_nettype wire