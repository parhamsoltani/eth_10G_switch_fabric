`timescale 1ns/1ps
// `default_nettype none

module packet_mode_fifo_array_model #(
    parameter WIDTH             = 13,
    parameter NUM_FIFO          = 32,
    parameter NUM_IN            = 32,
    parameter META_READ_LATENCY = 1,
    parameter DATA_READ_LATENCY = 1,
    parameter META_DATA_WIDTH   = 3,

    parameter NUM_FIFO_LOG      = (NUM_FIFO == 1) ? 1 : $clog2(NUM_FIFO),
    parameter NUM_IN_LOG        = (NUM_IN   == 1) ? 1 : $clog2(NUM_IN)
)(
    input  wire                             clk,
    input  wire                             reset,
    input  wire                             push,
    input  wire                             push_last,
    input  wire [WIDTH-1:0]                 push_data,
    input  wire [NUM_FIFO-1:0]              push_fifo_id,
    input  wire [NUM_IN_LOG-1:0]            push_in_id,
    input  wire [META_DATA_WIDTH-1:0]       push_metadata,

    input  wire                             pop,
    input  wire [NUM_FIFO_LOG-1:0]          pop_id,

    output wire [WIDTH-1:0]                 pop_data,
    output wire [META_DATA_WIDTH-1:0]       pop_metadata,
    output wire                             pop_last
);

    localparam MAX_LATENCY = DATA_READ_LATENCY > META_READ_LATENCY ? DATA_READ_LATENCY : META_READ_LATENCY;

    // ----------------------------- Types -----------------------------
    typedef struct packed {
        logic [WIDTH-1:0]           data;
        logic [META_DATA_WIDTH-1:0] meta;
        logic                       last;
    } flit_t;

    // ------------------------ Internal State -------------------------
    flit_t 	flit_q     [NUM_IN][NUM_FIFO][$];   // flat queue storage: input × output
    int     in_numbers_fifo [NUM_FIFO][$];     // each FIFO tracks order of input IDs
    reg     sof              [NUM_IN];         // start-of-frame tracker per input

    flit_t  pop_pipe         [0:MAX_LATENCY]; // latency pipe
    flit_t  active_flit;

    int     current_in_id    [NUM_FIFO];       // selected input source during pop
    reg     has_active_pkt   [NUM_FIFO];       // if current_in_id[pop_id] is valid

	flit_t flit;

	int in_id;

	int num_flit 	= 0;
	int num_packet	= 0;
    int num_flit_per_q   [NUM_FIFO];
    int num_packet_per_q [NUM_FIFO];

    // ------------------------- Push Logic ----------------------------
    // ------------------------- Push Logic ----------------------------
    always @(posedge clk) begin
        if (push) begin
            flit = '{data: push_data, meta: push_metadata, last: push_last};

            // Loop through all FIFOs and check if the corresponding push_fifo_id bit is set
            for (int fifo_idx = 0; fifo_idx < NUM_FIFO; fifo_idx++) begin
                if (push_fifo_id[fifo_idx]) begin
                    // If new packet (SOF = 1), enqueue input id into the target FIFO
                    if (sof[push_in_id]) begin
                        in_numbers_fifo[fifo_idx].push_back(push_in_id);
                        num_packet += 1;
                        num_packet_per_q[fifo_idx] += 1;

                        sof[push_in_id] <= 1'b0; // now in a packet
                    end

                    // Push flit to the (in_id, fifo_id) queue
                    flit_q[push_in_id][fifo_idx].push_back(flit);
                    num_flit += 1;
                    num_flit_per_q[fifo_idx] += 1;
                end
            end

            // If this was the last flit in the packet, reset SOF
            if (push_last) begin
                sof[push_in_id] <= 1'b1;
            end
        end
    end


    // -------------------------- Pop Logic ----------------------------
    always @(posedge clk) begin
        if (pop) begin


            // Start of new packet: pop source ID from fifo
            if (!has_active_pkt[pop_id] && in_numbers_fifo[pop_id].size() > 0) begin
                current_in_id[pop_id]  = in_numbers_fifo[pop_id].pop_front();
                num_packet -= 1;
                num_packet_per_q[pop_id] -= 1;

                has_active_pkt[pop_id] = 1'b1;
            end

            // Continue reading from current input’s queue
            in_id = current_in_id[pop_id];
            if (has_active_pkt[pop_id] && flit_q[in_id][pop_id].size() > 0) begin
                active_flit = flit_q[in_id][pop_id].pop_front();
				num_flit -=1;
                num_flit_per_q[pop_id] -= 1;

                // If this is the last flit, clear packet state
                if (active_flit.last) begin
                    has_active_pkt[pop_id] = 1'b0;
                end
            end else begin
                $display("WARNING: @time = %0t, in model, pop from empty fifo[%0d]!, in this fifo: num packet = %0d, num flit = %0d, in_numbers_fifo.size = %0d, has_active_pkt = %0b",
                        $time, pop_id, num_packet_per_q[pop_id], num_flit_per_q[pop_id], in_numbers_fifo[pop_id].size(), has_active_pkt[pop_id]);
            end

            // Load first stage of pipe
            pop_pipe[0] = active_flit;

        end
		for (int i=0; i<MAX_LATENCY; ++i) begin
			pop_pipe[i+1] <= pop_pipe[i];
		end
    end


    always @(posedge clk) begin
        if (reset) begin
            for (int i = 0; i < NUM_IN; i++) begin
                sof[i] = 1'b1;
                for (int j = 0; j < NUM_FIFO; j++) begin
                    flit_q[i][j].delete();
                end
            end
            for (int i = 0; i < NUM_FIFO; i++) begin
                in_numbers_fifo[i].delete();
                num_flit_per_q[i]   = 0;
                num_packet_per_q[i] = 0;
                has_active_pkt[i] = 1'b0;
                current_in_id[i]  = 0;
            end
            num_flit   = 0;
            num_packet = 0;
        end
    end

    // ------------------------- Assign Outputs ------------------------
    assign pop_data     = pop_pipe[DATA_READ_LATENCY].data;
    assign pop_metadata = pop_pipe[META_READ_LATENCY].meta;
    assign pop_last     = pop_pipe[META_READ_LATENCY].last;

    // -------------------------- Init Block ---------------------------
    initial begin
        for (int i = 0; i < NUM_IN; i++) begin
            sof[i] = 1'b1;  // inputs are ready to begin packet
        end
        for (int i = 0; i < NUM_FIFO; i++) begin
            has_active_pkt[i] = 1'b0;
            current_in_id[i]  = 0;
            num_flit_per_q[i]   = 0;
            num_packet_per_q[i] = 0;

        end
    end

endmodule



`default_nettype wire