`timescale 1ns / 1ps
`include "fabric_params.vh"
`include "qos_defines.vh"

module tb_qos_classifier_unit;
    parameter DATA_WIDTH = 512;
    parameter NUM_PORT = 16;
    parameter QOS_TAG_WIDTH = `QOS_TAG_WIDTH;  // 3
    parameter PACKET_ID_WIDTH = 8;

    logic clk, reset;
    logic [DATA_WIDTH-1:0] pkt_data;
    logic [NUM_PORT-1:0] dest_mask;
    logic [PACKET_ID_WIDTH-1:0] pkt_id;
    logic pkt_valid;
    logic [QOS_TAG_WIDTH-1:0] qos_tag;
    logic qos_valid;

    // Config
    logic [15:0] dscp_to_qos [64];
    logic [15:0] port_to_qos [NUM_PORT];
    logic [1:0] mode;  // 0=DSCP, 1=Port, 2=Combined

    // DUT
    qos_classifier #(
        .DATA_WIDTH(DATA_WIDTH),
        .NUM_PORT(NUM_PORT),
        .QOS_TAG_WIDTH(QOS_TAG_WIDTH),
        .PACKET_ID_WIDTH(PACKET_ID_WIDTH)
    ) dut (.*);

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        // Initialize
        reset = 1;
        pkt_valid = 0;
        pkt_data = 0;
        dest_mask = 0;
        pkt_id = 0;
        mode = 0;

        // Setup DSCP mappings (8 levels)
        for (int i = 0; i < 64; i++) dscp_to_qos[i] = `PRIORITY_BACKGROUND;
        dscp_to_qos[46] = `PRIORITY_NETWORK_CONTROL;  // EF → 3'd7
        dscp_to_qos[34] = `PRIORITY_VOICE;            // AF41 → 3'd6
        dscp_to_qos[26] = `PRIORITY_VIDEO;            // AF31 → 3'd5

        // Setup port mappings
        for (int i = 0; i < NUM_PORT; i++) port_to_qos[i] = `PRIORITY_BACKGROUND;
        port_to_qos[0] = `PRIORITY_NETWORK_CONTROL;

        repeat(10) @(posedge clk);
        reset = 0;

        // Test 1: DSCP-based classification
        $display("[TEST 1] DSCP-based QoS classification");
        mode = 0;

        @(posedge clk);
        pkt_valid = 1;
        pkt_data[511:504] = {2'b00, 6'd46};  // DSCP=46 (EF) in ToS byte
        dest_mask = 16'h0002;
        pkt_id = 8'h01;

        @(posedge clk);
        pkt_valid = 0;

        repeat(5) @(posedge clk);

        if (!qos_valid) $error("QoS output not valid");
        if (qos_tag != `PRIORITY_NETWORK_CONTROL)
            $error("Expected NETWORK_CONTROL (%0d), got %0d", `PRIORITY_NETWORK_CONTROL, qos_tag);

        // Test 2: Port-based classification
        $display("[TEST 2] Port-based QoS classification");
        mode = 1;

        @(posedge clk);
        pkt_valid = 1;
        pkt_data = 0;
        dest_mask = 16'h0001;  // Port 0 → NETWORK_CONTROL
        pkt_id = 8'h02;

        @(posedge clk);
        pkt_valid = 0;

        repeat(5) @(posedge clk);

        if (qos_tag != `PRIORITY_NETWORK_CONTROL)
            $error("Port-based: Expected NETWORK_CONTROL, got %0d", qos_tag);

        // Test 3: Combined mode (DSCP + Port)
        $display("[TEST 3] Combined mode (max priority wins)");
        mode = 2;

        @(posedge clk);
        pkt_valid = 1;
        pkt_data[511:504] = {2'b00, 6'd26};  // DSCP=26 (VIDEO=5)
        dest_mask = 16'h0001;  // Port 0 (NETWORK_CONTROL=7)
        pkt_id = 8'h03;

        @(posedge clk);
        pkt_valid = 0;

        repeat(5) @(posedge clk);

        if (qos_tag != `PRIORITY_NETWORK_CONTROL)
            $error("Combined: Expected NETWORK_CONTROL (max of VIDEO+NETWORK_CONTROL), got %0d", qos_tag);

        $display("\nQoS CLASSIFIER UNIT TEST PASSED");
        $finish;
    end

    initial begin
        #50000;
        $error("TIMEOUT");
        $finish;
    end
endmodule