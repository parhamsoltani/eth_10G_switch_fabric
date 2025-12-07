`timescale 1ns / 1ps
// `default_nettype none

`include "fabric_params.vh"

module fabric_ingress #(
    parameter NUM_PORTS     = `NUM_PORTS,
    parameter DATA_WIDTH    = `DATA_WIDTH,
    parameter ID_WIDTH      = `PACKET_ID_WIDTH
)(
    input  logic clk,
    input  logic rst_n,

    // From line modules
    switch_data_if.slave        rx_data_if [NUM_PORTS],
    switch_metadata_if.slave    rx_meta_if [NUM_PORTS],

    // To VOQ stage
    output logic                    voq_wr_valid [NUM_PORTS][NUM_PORTS],
    output logic [DATA_WIDTH-1:0]   voq_wr_data [NUM_PORTS],
    output logic [DATA_WIDTH/8-1:0] voq_wr_keep [NUM_PORTS],
    output logic                    voq_wr_last [NUM_PORTS],
    output logic [ID_WIDTH-1:0]     voq_wr_id [NUM_PORTS],
    output logic                    voq_wr_is_bad [NUM_PORTS],
    output logic [2:0]              voq_wr_qos [NUM_PORTS],
    input  logic                    voq_wr_ready [NUM_PORTS][NUM_PORTS],

    // Packet ID Manager interface
    output logic [NUM_PORTS-1:0]    id_alloc_req,
    input  logic [NUM_PORTS-1:0]    id_alloc_grant,
    input  logic [ID_WIDTH-1:0]     allocated_id [NUM_PORTS]
);

    // State per port
    typedef enum logic [1:0] {
        IDLE,
        WAIT_ID,
        TRANSFER
    } ingress_state_t;

    ingress_state_t state [NUM_PORTS];
    logic [ID_WIDTH-1:0] current_id [NUM_PORTS];
    logic [2:0] current_qos [NUM_PORTS];
    logic [NUM_PORTS-1:0] current_dest_mask [NUM_PORTS];

    genvar g;
    generate
        for (g = 0; g < NUM_PORTS; g++) begin : gen_ingress_port

            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    state[g] <= IDLE;
                    id_alloc_req[g] <= 1'b0;
                    rx_data_if[g].ready <= 1'b0;
                    rx_meta_if[g].ready <= 1'b0;
                end else begin
                    case (state[g])
                        IDLE: begin
                            rx_meta_if[g].ready <= 1'b1;

                            if (rx_data_if[g].valid && rx_meta_if[g].valid) begin
                                // Request packet ID
                                id_alloc_req[g] <= 1'b1;
                                state[g] <= WAIT_ID;
                            end
                        end

                        WAIT_ID: begin
                            if (id_alloc_grant[g]) begin
                                // ID allocated, capture metadata
                                current_id[g] <= allocated_id[g];
                                current_qos[g] <= rx_meta_if[g].qos_tag;
                                current_dest_mask[g] <= rx_meta_if[g].dest_port_mask;

                                id_alloc_req[g] <= 1'b0;
                                rx_data_if[g].ready <= 1'b1;
                                rx_meta_if[g].ready <= 1'b0;
                                state[g] <= TRANSFER;
                            end
                        end

                        TRANSFER: begin
                            // Check if all target VOQs are ready
                            automatic logic all_ready = 1'b1;
                            for (int dst = 0; dst < NUM_PORTS; dst++) begin
                                if (current_dest_mask[g][dst]) begin
                                    all_ready = all_ready && voq_wr_ready[g][dst];
                                end
                            end

                            rx_data_if[g].ready <= all_ready;

                            // Transfer data to VOQs
                            if (rx_data_if[g].valid && all_ready) begin
                                voq_wr_data[g] <= rx_data_if[g].data;
                                voq_wr_keep[g] <= rx_data_if[g].keep;
                                voq_wr_last[g] <= rx_data_if[g].last;
                                voq_wr_id[g] <= current_id[g];
                                voq_wr_is_bad[g] <= rx_data_if[g].is_bad_frame;
                                voq_wr_qos[g] <= current_qos[g];

                                for (int dst = 0; dst < NUM_PORTS; dst++) begin
                                    voq_wr_valid[g][dst] <= current_dest_mask[g][dst];
                                end

                                if (rx_data_if[g].last) begin
                                    state[g] <= IDLE;
                                end
                            end else begin
                                for (int dst = 0; dst < NUM_PORTS; dst++) begin
                                    voq_wr_valid[g][dst] <= 1'b0;
                                end
                            end
                        end
                    endcase
                end
            end

        end
    endgenerate

endmodule

`default_nettype wire