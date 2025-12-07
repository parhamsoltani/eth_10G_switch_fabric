`timescale 1ns / 1ps
// `default_nettype none

module tb_voq_unit;
    parameter DATA_WIDTH = 64;
    parameter DEPTH_PER_QOS = 512;
    parameter ID_WIDTH = 8;
    parameter NUM_QOS_LEVELS = 3;

    logic clk, rst_n;
    logic wr_en, rd_en;
    logic [DATA_WIDTH-1:0] wr_data;
    logic [DATA_WIDTH-1:0] rd_data;
    logic [ID_WIDTH-1:0] wr_id, rd_id;
    logic [2:0] wr_qos, rd_qos;
    logic wr_ready, rd_valid;
    logic [10:0] occupancy [NUM_QOS_LEVELS];
    logic empty [NUM_QOS_LEVELS];
    logic almost_full [NUM_QOS_LEVELS];

    // FIXED: Changed from virtual_output_queue to voq_buffer (actual module name)
    voq_buffer #(
        .DATA_WIDTH(DATA_WIDTH),
        .ID_WIDTH(ID_WIDTH),
        .DEPTH_PER_QOS(DEPTH_PER_QOS),
        .MAX_PACKET_SIZE(512),
        .NUM_QOS_LEVELS(NUM_QOS_LEVELS)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),

        .wr_valid(wr_en),
        .wr_data(wr_data),
        .wr_keep('1),  // All bytes valid
        .wr_last(1'b1),  // Single-beat packets for simplicity
        .wr_id(wr_id),
        .wr_is_bad(1'b0),
        .wr_qos(wr_qos),
        .wr_ready(wr_ready),

        .rd_valid(rd_valid),
        .rd_data(rd_data),
        .rd_keep(),
        .rd_last(),
        .rd_id(rd_id),
        .rd_is_bad(),
        .rd_qos(rd_qos),
        .rd_ready(rd_en),

        .occupancy(occupancy),
        .empty(empty),
        .almost_full(almost_full)
    );

    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;

    // Reset sequence
    initial begin
        rst_n = 0;
        wr_en = 0;
        rd_en = 0;
        wr_data = 0;
        wr_id = 0;
        wr_qos = 0;

        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(10) @(posedge clk);

        // Test 1: Write to different QoS levels
        $display("[%0t] TEST 1: Multi-QoS Write/Read", $time);

        // Write high priority
        @(posedge clk);
        wr_en = 1;
        wr_data = 64'hDEAD_BEEF_CAFE_BABE;
        wr_id = 8'hAA;
        wr_qos = 3'b000;  // High priority

        @(posedge clk);
        wr_en = 0;

        if (empty[0]) $error("High-priority queue should not be empty");

        // Read high priority
        @(posedge clk);
        rd_en = 1;

        @(posedge clk);
        rd_en = 0;

        repeat(3) @(posedge clk);  // Account for pipeline latency

        if (rd_data != 64'hDEAD_BEEF_CAFE_BABE) begin
            $error("Data mismatch: expected %h, got %h", 64'hDEAD_BEEF_CAFE_BABE, rd_data);
        end

        if (rd_qos != 3'b000) begin
            $error("QoS mismatch: expected 0, got %d", rd_qos);
        end

        // Test 2: Priority enforcement
        $display("[%0t] TEST 2: Priority Ordering", $time);

        // Write low priority first
        @(posedge clk);
        wr_en = 1;
        wr_qos = 3'b010;  // Low
        wr_data = 64'h1111;

        @(posedge clk);
        wr_en = 0;

        // Then high priority
        @(posedge clk);
        wr_en = 1;
        wr_qos = 3'b000;  // High
        wr_data = 64'h2222;

        @(posedge clk);
        wr_en = 0;

        // Read should return high priority first
        @(posedge clk);
        rd_en = 1;

        repeat(4) @(posedge clk);

        if (rd_data != 64'h2222) begin
            $error("Priority violation: expected high-pri data 0x2222, got %h", rd_data);
        end

        rd_en = 0;

        $display("\n VOQ UNIT TEST PASSED ");
        $finish;
    end

    // Timeout watchdog
    initial begin
        #100000;
        $error("TIMEOUT - test did not complete");
        $finish;
    end
endmodule

`default_nettype wire
