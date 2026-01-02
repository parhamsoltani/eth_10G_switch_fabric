`timescale 1ns / 1ps
// `default_nettype none

`include "fabric_params.vh"
`include "qos_defines.vh"

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

    // Combinational signals for next state
    logic [ID_WIDTH:0]   head_ptr_next;
    logic [ID_WIDTH:0]   tail_ptr_next;
    logic [ID_WIDTH:0]   count_next;
    logic [MAX_PORTS-1:0] alloc_grant_next;
    logic [ID_WIDTH-1:0]  allocated_id_next [MAX_PORTS];
    logic [MAX_IDS-1:0]   id_in_use_next;
    logic [ID_WIDTH-1:0]  free_list_next [MAX_IDS];
    
    // Combinational logic to compute next state
    integer i_comb;  // Loop variable declared outside always_comb
    integer alloc_count;
    integer release_count;
    logic [ID_WIDTH:0] alloc_ptr;
    logic [ID_WIDTH:0] release_ptr;
    
    always_comb begin
        // Default: maintain current state
        head_ptr_next = head_ptr;
        tail_ptr_next = tail_ptr;
        count_next = count;
        alloc_grant_next = '0;
        id_in_use_next = id_in_use;
        
        for (i_comb = 0; i_comb < MAX_IDS; i_comb = i_comb + 1) begin
            free_list_next[i_comb] = free_list[i_comb];
        end
        
        for (i_comb = 0; i_comb < MAX_PORTS; i_comb = i_comb + 1) begin
            allocated_id_next[i_comb] = allocated_id[i_comb];
        end

        // Count allocations and releases
        alloc_count = 0;
        release_count = 0;

        // Handle allocations (priority encoded)
        for (i_comb = 0; i_comb < MAX_PORTS; i_comb = i_comb + 1) begin
            if (alloc_req[i_comb] && (count > alloc_count[ID_WIDTH:0])) begin
                alloc_ptr = (head_ptr + alloc_count[ID_WIDTH:0]) % MAX_IDS;

                allocated_id_next[i_comb] = free_list[alloc_ptr];
                alloc_grant_next[i_comb] = 1'b1;
                id_in_use_next[free_list[alloc_ptr]] = 1'b1;

                alloc_count = alloc_count + 1;
            end
        end

        // Handle releases
        for (i_comb = 0; i_comb < MAX_PORTS; i_comb = i_comb + 1) begin
            if (release_req[i_comb]) begin
                release_ptr = (tail_ptr + release_count[ID_WIDTH:0]) % MAX_IDS;

                free_list_next[release_ptr] = release_id[i_comb];
                id_in_use_next[release_id[i_comb]] = 1'b0;

                release_count = release_count + 1;
            end
        end

        // Update pointers
        head_ptr_next = (head_ptr + alloc_count[ID_WIDTH:0]) % MAX_IDS;
        tail_ptr_next = (tail_ptr + release_count[ID_WIDTH:0]) % MAX_IDS;
        count_next = count - alloc_count[ID_WIDTH:0] + release_count[ID_WIDTH:0];
    end

    // Sequential logic - loop variable declared outside
    integer i_seq;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i_seq = 0; i_seq < MAX_IDS; i_seq = i_seq + 1) begin
                free_list[i_seq] <= i_seq[ID_WIDTH-1:0];
            end
            head_ptr <= '0;
            tail_ptr <= MAX_IDS[ID_WIDTH:0];
            count <= MAX_IDS[ID_WIDTH:0];
            id_in_use <= '0;
            alloc_grant <= '0;
            for (i_seq = 0; i_seq < MAX_PORTS; i_seq = i_seq + 1) begin
                allocated_id[i_seq] <= '0;
            end
        end else begin
            for (i_seq = 0; i_seq < MAX_IDS; i_seq = i_seq + 1) begin
                free_list[i_seq] <= free_list_next[i_seq];
            end
            head_ptr <= head_ptr_next;
            tail_ptr <= tail_ptr_next;
            count <= count_next;
            id_in_use <= id_in_use_next;
            alloc_grant <= alloc_grant_next;
            for (i_seq = 0; i_seq < MAX_PORTS; i_seq = i_seq + 1) begin
                allocated_id[i_seq] <= allocated_id_next[i_seq];
            end
        end
    end

    // Assertions for verification
    // synthesis translate_off
    integer i_assert;
    always @(posedge clk) begin
        if (rst_n) begin
            assert (count <= MAX_IDS) else
                $error("ID count overflow: %0d", count);

            for (i_assert = 0; i_assert < MAX_PORTS; i_assert = i_assert + 1) begin
                if (alloc_grant[i_assert]) begin
                    assert (!id_in_use[allocated_id[i_assert]]) else
                        $error("Allocated ID %0d already in use", allocated_id[i_assert]);
                end
            end
        end
    end
    // synthesis translate_on

endmodule

`default_nettype wire