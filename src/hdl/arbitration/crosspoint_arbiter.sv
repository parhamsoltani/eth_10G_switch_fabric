`timescale 1ns / 1ps
// `default_nettype none

`include "fabric_params.vh"

module crosspoint_arbiter #(
    parameter NUM_SOURCES = `NUM_PORTS
)(
    input  logic clk,
    input  logic rst_n,

    // Requests from each source VOQ
    input  logic [NUM_SOURCES-1:0]  request,
    input  logic [2:0]              request_qos [NUM_SOURCES],

    // Grant (one-hot)
    output logic [NUM_SOURCES-1:0]  grant,
    output logic [$clog2(NUM_SOURCES)-1:0] grant_id,
    output logic                    grant_valid
);

    // Separate requests by QoS level
    logic [NUM_SOURCES-1:0] prio0_req;
    logic [NUM_SOURCES-1:0] prio1_req;
    logic [NUM_SOURCES-1:0] prio2_req;

    always_comb begin
        for (int i = 0; i < NUM_SOURCES; i++) begin
            prio0_req[i] = request[i] && (request_qos[i] == `PRIORITY_HIGH);
            prio1_req[i] = request[i] && (request_qos[i] == `PRIORITY_MEDIUM);
            prio2_req[i] = request[i] && (request_qos[i] == `PRIORITY_LOW);
        end
    end

    // Level 1: QoS Priority Selection
    logic [NUM_SOURCES-1:0] selected_requests;

    always_comb begin
        if (|prio0_req)
            selected_requests = prio0_req;
        else if (|prio1_req)
            selected_requests = prio1_req;
        else
            selected_requests = prio2_req;
    end

    // Level 2: Round-robin among selected priority
    round_robin_arbiter #(
        .NUM_REQUESTERS(NUM_SOURCES)
    ) rr_arb (
        .clk(clk),
        .rst_n(rst_n),
        .request(selected_requests),
        .grant(grant),
        .grant_id(grant_id),
        .grant_valid(grant_valid)
    );

endmodule

`default_nettype wire