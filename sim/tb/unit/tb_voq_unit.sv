`timescale 1ns / 1ps

module tb_voq_unit;
    parameter DATA_WIDTH = 64;
    parameter DEPTH = 512;
    parameter ID_WIDTH = 8;

    logic clk, reset;
    logic wr_en, rd_en;
    logic [DATA_WIDTH-1:0] wr_data;
    logic [DATA_WIDTH-1:0] rd_data;
    logic [ID_WIDTH-1:0] wr_id, rd_id;
    logic full, empty;
    logic [$clog2(DEPTH):0] count;

    // DUT
    virtual_output_queue #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH),
        .ID_WIDTH(ID_WIDTH)
    ) dut (
        .clk(clk),
        .reset(reset),
        .wr_en(wr_en),
        .wr_data(wr_data),
        .wr_id(wr_id),
        .rd_en(rd_en),
        .rd_data(rd_data),
        .rd_id(rd_id),
        .full(full),
        .empty(empty),
        .count(count)
    );

    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;

    // Test sequence
    initial begin
        reset = 1;
        wr_en = 0;
        rd_en = 0;
        wr_data = 0;
        wr_id = 0;

        repeat(10) @(posedge clk);
        reset = 0;

        // Test 1: Basic write/read
        $display("[TEST 1] Basic write/read");
        @(posedge clk);
        wr_en = 1;
        wr_data = 64'hDEADBEEF_CAFEBABE;
        wr_id = 8'hAA;

        @(posedge clk);
        wr_en = 0;

        if (empty) $error("Queue should not be empty after write");
        if (count != 1) $error("Count should be 1, got %0d", count);

        @(posedge clk);
        rd_en = 1;

        @(posedge clk);
        rd_en = 0;

        if (rd_data != 64'hDEADBEEF_CAFEBABE)
            $error("Read data mismatch: expected %h, got %h", 64'hDEADBEEF_CAFEBABE, rd_data);
        if (rd_id != 8'hAA)
            $error("Read ID mismatch: expected %h, got %h", 8'hAA, rd_id);

        // Test 2: Fill and drain
        $display("[TEST 2] Fill to capacity");
        for (int i = 0; i < DEPTH; i++) begin
            @(posedge clk);
            wr_en = 1;
            wr_data = i;
            wr_id = i[ID_WIDTH-1:0];
        end

        @(posedge clk);
        wr_en = 0;

        if (!full) $error("Queue should be full");
        if (count != DEPTH) $error("Count should be %0d, got %0d", DEPTH, count);

        $display("[TEST 3] Drain queue");
        for (int i = 0; i < DEPTH; i++) begin
            @(posedge clk);
            rd_en = 1;

            @(posedge clk);
            if (rd_data != i) $error("Drain mismatch at %0d: expected %0d, got %0d", i, i, rd_data);
        end

        @(posedge clk);
        rd_en = 0;

        if (!empty) $error("Queue should be empty after drain");

        // Test 4: Simultaneous read/write
        $display("[TEST 4] Simultaneous read/write");
        @(posedge clk);
        wr_en = 1;
        rd_en = 1;
        wr_data = 64'h1234;

        repeat(100) @(posedge clk);

        if (count != 0) $error("Count should remain stable at 0");

        $display("\n✓✓✓ VOQ UNIT TEST PASSED ✓✓✓");
        $finish;
    end

    // Timeout watchdog
    initial begin
        # 100000
        $error("TIMEOUT - test did not complete");
        $finish;
    end
endmodule