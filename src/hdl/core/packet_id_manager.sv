`timescale 1ns / 1ps
// `default_nettype none

`include "fabric_params.vh"

module packet_id_manager #(
    parameter ID_WIDTH   = `PACKET_ID_WIDTH,
    parameter MAX_PORTS  = `NUM_PORTS,
    parameter MAX_IDS    = 2**ID_WIDTH
)(
    input  logic clk,
    input  logic rst_n,

    // ID allocation interface (per port)
    input  logic [MAX_PORTS-1:0]        alloc_req,
    output logic [MAX_PORTS-1:0]        alloc_grant,
    output logic [ID_WIDTH-1:0]         allocated_id [MAX_PORTS],

    // ID release interface (per port)
    input  logic [MAX_PORTS-1:0]        release_req,
    input  logic [ID_WIDTH-1:0]         release_id [MAX_PORTS],

    // Status
    output logic [ID_WIDTH:0]           free_id_count
);

    // Free list implemented as FIFO
    logic [ID_WIDTH-1:0] free_list [MAX_IDS];
    logic [ID_WIDTH:0]   head_ptr;
    logic [ID_WIDTH:0]   tail_ptr;
    logic [ID_WIDTH:0]   count;

    logic [MAX_IDS-1:0]  id_in_use;  // Bitmap for debugging

    assign free_id_count = count;

    // Priority encoder for allocation requests
    logic [MAX_PORTS-1:0] grant_mask;
    logic [$clog2(MAX_PORTS)-1:0] grant_encode [MAX_PORTS];

    integer i, j;

    // Initialize free list
    initial begin
        for (i = 0; i < MAX_IDS; i = i + 1) begin
            free_list[i] = i;
        end
        head_ptr = 0;
        tail_ptr = MAX_IDS;
        count = MAX_IDS;
        id_in_use = '0;
    end

    // Allocation logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < MAX_IDS; i = i + 1) begin
                free_list[i] <= i;
            end
            head_ptr <= 0;
            tail_ptr <= MAX_IDS;
            count <= MAX_IDS;
            id_in_use <= '0;
            alloc_grant <= '0;
        end else begin
            alloc_grant <= '0;

            // Handle allocations (priority encoded)
            automatic int alloc_count = 0;
            for (i = 0; i < MAX_PORTS; i = i + 1) begin
                if (alloc_req[i] && (count > alloc_count)) begin
                    automatic logic [ID_WIDTH:0] alloc_ptr;
                    alloc_ptr = (head_ptr + alloc_count) % MAX_IDS;

                    allocated_id[i] <= free_list[alloc_ptr];
                    alloc_grant[i] <= 1'b1;
                    id_in_use[free_list[alloc_ptr]] <= 1'b1;

                    alloc_count = alloc_count + 1;
                end
            end

            // Handle releases
            automatic int release_count = 0;
            for (i = 0; i < MAX_PORTS; i = i + 1) begin
                if (release_req[i]) begin
                    automatic logic [ID_WIDTH:0] release_ptr;
                    release_ptr = (tail_ptr + release_count) % MAX_IDS;

                    free_list[release_ptr] <= release_id[i];
                    id_in_use[release_id[i]] <= 1'b0;

                    release_count = release_count + 1;
                end
            end

            // Update pointers
            head_ptr <= (head_ptr + alloc_count) % MAX_IDS;
            tail_ptr <= (tail_ptr + release_count) % MAX_IDS;
            count <= count - alloc_count + release_count;
        end
    end

    // Assertions for verification
    // synthesis translate_off
    always @(posedge clk) begin
        if (rst_n) begin
            assert (count <= MAX_IDS) else
                $error("ID count overflow: %0d", count);

            for (i = 0; i < MAX_PORTS; i = i + 1) begin
                if (alloc_grant[i]) begin
                    assert (!id_in_use[allocated_id[i]]) else
                        $error("Allocated ID %0d already in use", allocated_id[i]);
                end
            end
        end
    end
    // synthesis translate_on

endmodule

`default_nettype wire