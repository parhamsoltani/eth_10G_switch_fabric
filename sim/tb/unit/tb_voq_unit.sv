`timescale 1ns / 1ps

module tb_voq_unit;
    parameter DATA_WIDTH = 64;
    parameter DEPTH_PER_QOS = 512;
    parameter ID_WIDTH = 8;
    parameter NUM_QOS = 3;

    logic clk, rst_n;
    logic wr_en, rd_en;
    logic [DATA_WIDTH-1:0] wr_data;
    logic [DATA_WIDTH-1:0] rd_data;
    logic [$clog2(NUM_QOS)-1:0] wr_qos, rd_qos;
    logic rd_valid;
    logic [NUM_QOS-1:0] empty;
    logic [NUM_QOS-1:0] full;

    voq_buffer #(
        .DATA_WIDTH(DATA_WIDTH),
        .NUM_QOS(NUM_QOS),
        .DEPTH_PER_QOS(DEPTH_PER_QOS),
        .ID_WIDTH(ID_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),

        // Write interface
        .wr_en(wr_en),
        .wr_data(wr_data),
        .wr_qos(wr_qos),

        // Read interface
        .rd_en(rd_en),
        .rd_valid(rd_valid),
        .rd_data(rd_data),
        .rd_qos(rd_qos),

        // Status
        .empty(empty),
        .full(full)
    );

    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;

    // Test variables
    logic [DATA_WIDTH-1:0] expected_data;
    logic [$clog2(NUM_QOS)-1:0] expected_qos;
    int errors = 0;

    // Task to write a packet and wait for commit
    task automatic write_packet(
        input logic [DATA_WIDTH-1:0] data,
        input logic [$clog2(NUM_QOS)-1:0] qos
    );
        @(posedge clk);
        wr_en = 1;
        wr_data = data;
        wr_qos = qos;
        
        @(posedge clk);
        wr_en = 0;
        
        // Wait for packet to be committed (WR_IDLE -> WR_COMMIT -> WR_IDLE)
        repeat(3) @(posedge clk);
    endtask

    // Task to read a packet and wait for valid data
    task automatic read_packet(
        output logic [DATA_WIDTH-1:0] data,
        output logic [$clog2(NUM_QOS)-1:0] qos,
        output logic valid
    );
        int timeout_cnt;
        
        // Assert read enable
        rd_en = 1;
        timeout_cnt = 0;
        
        // Wait for rd_valid to be asserted
        while (!rd_valid && timeout_cnt < 20) begin
            @(posedge clk);
            timeout_cnt++;
        end
        
        if (rd_valid) begin
            data = rd_data;
            qos = rd_qos;
            valid = 1;
            @(posedge clk);  // Consume the data
        end else begin
            data = '0;
            qos = '0;
            valid = 0;
        end
        
        rd_en = 0;
        @(posedge clk);
    endtask

    // Main test
    initial begin
        logic [DATA_WIDTH-1:0] read_data;
        logic [$clog2(NUM_QOS)-1:0] read_qos;
        logic read_valid;

        rst_n = 0;
        wr_en = 0;
        rd_en = 0;
        wr_data = 0;
        wr_qos = 0;

        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);

        //=================================================================
        // Test 1: Write to different QoS levels
        //=================================================================
        $display("[%0t] TEST 1: Multi-QoS Write/Read", $time);

        // Write high priority packet (QoS 0 = highest priority)
        write_packet(64'hDEAD_BEEF_CAFE_BABE, 2'b00);

        // Check that high-priority queue is not empty
        if (empty[0]) begin
            $error("High-priority queue should not be empty after write");
            errors++;
        end else begin
            $display("  [PASS] High-priority queue not empty");
        end

        // Read the packet
        read_packet(read_data, read_qos, read_valid);

        if (!read_valid) begin
            $error("No valid data received");
            errors++;
        end else begin
            if (read_data != 64'hDEAD_BEEF_CAFE_BABE) begin
                $error("Data mismatch: expected %h, got %h", 64'hDEAD_BEEF_CAFE_BABE, read_data);
                errors++;
            end else begin
                $display("  [PASS] Data match: %h", read_data);
            end

            if (read_qos != 2'b00) begin
                $error("QoS mismatch: expected 0, got %d", read_qos);
                errors++;
            end else begin
                $display("  [PASS] QoS match: %d", read_qos);
            end
        end

        repeat(5) @(posedge clk);

        //=================================================================
        // Test 2: Priority enforcement
        //=================================================================
        $display("[%0t] TEST 2: Priority Ordering", $time);

        // Write low priority first (QoS 2)
        write_packet(64'h0000_0000_0000_1111, 2'b10);
        $display("  Wrote low-priority packet: 0x1111");

        // Then high priority (QoS 0)
        write_packet(64'h0000_0000_0000_2222, 2'b00);
        $display("  Wrote high-priority packet: 0x2222");

        // Read should return high priority first (strict priority)
        read_packet(read_data, read_qos, read_valid);

        if (!read_valid) begin
            $error("No valid data received for priority test");
            errors++;
        end else begin
            if (read_data != 64'h0000_0000_0000_2222) begin
                $error("Priority violation: expected high-pri data 0x2222, got %h", read_data);
                errors++;
            end else begin
                $display("  [PASS] High priority packet received first: %h", read_data);
            end

            if (read_qos != 2'b00) begin
                $error("Expected QoS 0, got %d", read_qos);
                errors++;
            end
        end

        // Now read the low priority packet
        read_packet(read_data, read_qos, read_valid);

        if (!read_valid) begin
            $error("No valid data received for low-priority packet");
            errors++;
        end else begin
            if (read_data != 64'h0000_0000_0000_1111) begin
                $error("Low-priority data mismatch: expected 0x1111, got %h", read_data);
                errors++;
            end else begin
                $display("  [PASS] Low priority packet received second: %h", read_data);
            end

            if (read_qos != 2'b10) begin
                $error("Expected QoS 2, got %d", read_qos);
                errors++;
            end
        end

        repeat(5) @(posedge clk);

        //=================================================================
        // Test Summary
        //=================================================================
        $display("\n════════════════════════════════════════════════════════");
        if (errors == 0) begin
            $display(" VOQ UNIT TEST PASSED ");
        end else begin
            $display(" VOQ UNIT TEST FAILED - %0d errors", errors);
        end
        $display("════════════════════════════════════════════════════════\n");

        $finish;
    end

    // Timeout watchdog
    initial begin
        #100000;
        $error("TIMEOUT - test did not complete");
        $finish;
    end

    // Debug: monitor state changes
    initial begin
        $monitor("[%0t] wr_en=%b rd_en=%b rd_valid=%b rd_data=%h rd_qos=%d empty={%b,%b,%b}",
                 $time, wr_en, rd_en, rd_valid, rd_data, rd_qos, 
                 empty[0], empty[1], empty[2]);
    end

endmodule

`default_nettype wire