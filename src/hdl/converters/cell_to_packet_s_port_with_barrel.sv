`default_nettype none

module cell_to_packet_s_port_with_barrel #(
    parameter S = 10,
    parameter W_MINI = 64,
    parameter START_OF_CELL_DELAY = 7,
    parameter KEEP_WIDTH = $clog2(W_MINI/8 + 1),
    parameter S_LOG = $clog2(S),
    parameter META_DATA_WIDTH = S + KEEP_WIDTH + 1 + S_LOG
)(
    input  wire                         clk,
    input  wire                         start_of_cell_i,
    input  wire [META_DATA_WIDTH-1:0]   metadata_i,
    input  wire                         last_cell_i,
    input  wire [S_LOG-1:0]             barrel_sel,
    input  wire [W_MINI-1:0]            data_i [S],

    output reg  [W_MINI-1:0]            data_tx [S],
    output reg  [KEEP_WIDTH-1:0]        keep_tx [S],
    output reg                          valid_tx [S],
    output reg                          is_bad_frame_tx [S],
    output reg                          last_tx [S]
);

    // Barrel shifter for data alignment
    reg [W_MINI-1:0] shifted_data [S];

    always_comb begin
        for (int i = 0; i < S; i++) begin
            shifted_data[i] = data_i[(i + barrel_sel) % S];
        end
    end

    // Metadata extraction
    wire [S-1:0] cell_valid = metadata_i[META_DATA_WIDTH-1 -: S];
    wire [KEEP_WIDTH-1:0] last_keep = metadata_i[KEEP_WIDTH+1+S_LOG-1 -: KEEP_WIDTH];
    wire is_bad = metadata_i[1+S_LOG];
    wire [S_LOG-1:0] last_idx = metadata_i[S_LOG-1:0];

    // Output generation
    always_ff @(posedge clk) begin
        for (int i = 0; i < S; i++) begin
            data_tx[i] <= shifted_data[i];
            valid_tx[i] <= start_of_cell_i && cell_valid[i];
            is_bad_frame_tx[i] <= is_bad && (i == last_idx);
            last_tx[i] <= last_cell_i && (i == last_idx);
            keep_tx[i] <= (i == last_idx) ? last_keep : {KEEP_WIDTH{1'b1}};
        end
    end

endmodule