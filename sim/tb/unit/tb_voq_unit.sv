`timescale 1ns / 1ps

module tb_voq_unit;
    parameter DATA_WIDTH     = 64;
    parameter DEPTH_PER_QOS  = 512;
    parameter ID_WIDTH       = 8;
    parameter NUM_QOS_LEVELS = 3;
    parameter KEEP_WIDTH     = DATA_WIDTH/8;

    logic clk, rst_n;
    
    // Write interface
    logic                    wr_valid;
    logic [DATA_WIDTH-1:0]   wr_data;
    logic [KEEP_WIDTH-1:0]   wr_keep;
    logic                    wr_last;
    logic [ID_WIDTH-1:0]     wr_id;
    logic                    wr_is_bad;
    logic [2:0]              wr_qos;
    logic                    wr_ready;

    // Read interface
    logic                    rd_valid;
    logic [DATA_WIDTH-1:0]   rd_data;
    logic [KEEP_WIDTH-1:0]   rd_keep;
    logic                    rd_last;
    logic [ID_WIDTH-1:0]     rd_id;
    logic                    rd_is_bad;
    logic [2:0]              rd_qos;
    logic                    rd_ready;

    // Status
    logic [$clog2(DEPTH_PER_QOS * NUM_QOS_LEVELS + 1)-1:0] occupancy;
    logic                    empty;
    logic                    almost_full;

    voq_buffer #(
        .DATA_WIDTH(DATA_WIDTH),
        .NUM_QOS_LEVELS(NUM_QOS_LEVELS),
        .DEPTH_PER_QOS(DEPTH_PER_QOS),
        .ID_WIDTH(ID_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),

        // Write interface
        .wr_valid(wr_valid),
        .wr_data(wr_data),
        .wr_keep(wr_keep),
        .wr_last(wr_last),
        .wr_id(wr_id),
        .wr_is_bad(wr_is_bad),
        .wr_qos(wr_qos),
        .wr_ready(wr_ready),

        // Read interface
        .rd_valid(rd_valid),
        .rd_data(rd_data),
        .rd_keep(rd_keep),
        .rd_last(rd_last),
        .rd_id(rd_id),
        .rd_is_bad(rd_is_bad),
        .rd_qos(rd_qos),
        .rd_ready(rd_ready),

        // Status
        .occupancy(occupancy),
        .empty(empty),
        .almost_full(almost_full)
    );

    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;

    // Test variables
    int errors = 0;

    // Task to write a packet and wait for FIFO to settle
    task automatic write_packet(
        input logic [DATA_WIDTH-1:0] data,
        input logic [2:0]            qos,
        input logic [ID_WIDTH-1:0]   id = '0,
        input logic                  is_bad = 1'b0
    );
        @(posedge clk);
        wr_valid  = 1;
        wr_data   = data;
        wr_keep   = '1;
        wr_last   = 1;
        wr_id     = id;
        wr_is_bad = is_bad;
        wr_qos    = qos;
        
        // Wait for handshake
        while (!wr_ready) @(posedge clk);
        @(posedge clk);
        
        wr_valid = 0;
        
        // Wait for XPM FIFO to update empty flag (2-3 cycles latency)
        repeat(3) @(posedge clk);
    endtask

    // Task to read a packet - wait for rd_valid first, then consume
    task automatic read_packet(
        output logic [DATA_WIDTH-1:0] data,
        output logic [2:0]            qos,
        output logic                  valid
    );
        int timeout_cnt = 0;
        
        // Wait for data to be available (rd_valid asserted)
        while (!rd_valid && timeout_cnt < 50) begin
            @(posedge clk);
            timeout_cnt++;
        end
        
        if (rd_valid) begin
            // Capture the presented data
            data  = rd_data;
            qos   = rd_qos;
            valid = 1;
            
            // Assert ready to consume
            rd_ready = 1;
            @(posedge clk);
            rd_ready = 0;
            
            // Wait for FIFO to update after read
            repeat(2) @(posedge clk);
        end else begin
            data  = '0;
            qos   = '0;
            valid = 0;
        end
    endtask

    // Main test
    initial begin
        logic [DATA_WIDTH-1:0] read_data;
        logic [2:0]            read_qos;
        logic                  read_valid;

        // Initialize
        rst_n     = 0;
        wr_valid  = 0;
        wr_data   = 0;
        wr_keep   = 0;
        wr_last   = 0;
        wr_id     = 0;
        wr_is_bad = 0;
        wr_qos    = 0;
        rd_ready  = 0;

        repeat(10) @(posedge clk);
        rst_n = 1;
        
        // Wait for XPM FIFO reset to complete
        repeat(10) @(posedge clk);

        //=================================================================
        // Test 1: Basic Write/Read
        //=================================================================
        $display("[%0t] TEST 1: Basic Write/Read", $time);

        // Write packet to QoS 2
        write_packet(64'hDEAD_BEEF_CAFE_BABE, 3'd2);

        // Verify buffer not empty (use occupancy which is more reliable)
        if (occupancy == 0) begin
            $error("Occupancy should be 1 after write, got %0d", occupancy);
            errors++;
        end else begin
            $display("  [PASS] Occupancy = %0d after write", occupancy);
        end

        // Read the packet
        read_packet(read_data, read_qos, read_valid);

        if (!read_valid) begin
            $error("No valid data received");
            errors++;
        end else begin
            if (read_data !== 64'hDEAD_BEEF_CAFE_BABE) begin
                $error("Data mismatch: expected %h, got %h", 64'hDEAD_BEEF_CAFE_BABE, read_data);
                errors++;
            end else begin
                $display("  [PASS] Data match: %h", read_data);
            end

            if (read_qos !== 3'd2) begin
                $error("QoS mismatch: expected 2, got %d", read_qos);
                errors++;
            end else begin
                $display("  [PASS] QoS match: %d", read_qos);
            end
        end

        repeat(5) @(posedge clk);

        //=================================================================
        // Test 2: Priority enforcement (higher QoS index = higher priority)
        //=================================================================
        $display("[%0t] TEST 2: Priority Ordering", $time);

        // Write low priority first (QoS 0)
        write_packet(64'h0000_0000_0000_1111, 3'd0);
        $display("  Wrote low-priority packet (QoS 0): 0x1111, occupancy=%0d", occupancy);

        // Then high priority (QoS 2)
        write_packet(64'h0000_0000_0000_2222, 3'd2);
        $display("  Wrote high-priority packet (QoS 2): 0x2222, occupancy=%0d", occupancy);

        // First read should return high priority (QoS 2)
        read_packet(read_data, read_qos, read_valid);

        if (!read_valid) begin
            $error("No valid data received for priority test");
            errors++;
        end else begin
            if (read_data !== 64'h0000_0000_0000_2222) begin
                $error("Priority violation: expected high-pri 0x2222, got %h (qos=%0d)", read_data, read_qos);
                errors++;
            end else begin
                $display("  [PASS] High priority packet first: %h (QoS %0d)", read_data, read_qos);
            end
        end

        // Second read should return low priority (QoS 0)
        read_packet(read_data, read_qos, read_valid);

        if (!read_valid) begin
            $error("No valid data received for low-priority packet");
            errors++;
        end else begin
            if (read_data !== 64'h0000_0000_0000_1111) begin
                $error("Low-priority data mismatch: expected 0x1111, got %h", read_data);
                errors++;
            end else begin
                $display("  [PASS] Low priority packet second: %h (QoS %0d)", read_data, read_qos);
            end
        end

        repeat(5) @(posedge clk);

        //=================================================================
        // Test 3: Multiple QoS levels
        //=================================================================
        $display("[%0t] TEST 3: All QoS Levels", $time);

        // Write to all 3 QoS levels in order: 1, 0, 2
        write_packet(64'hAAAA_AAAA_AAAA_AAAA, 3'd1);
        write_packet(64'hBBBB_BBBB_BBBB_BBBB, 3'd0);
        write_packet(64'hCCCC_CCCC_CCCC_CCCC, 3'd2);
        
        $display("  Wrote 3 packets to QoS 1,0,2. Occupancy=%0d", occupancy);

        // Should read in priority order: QoS 2, QoS 1, QoS 0
        read_packet(read_data, read_qos, read_valid);
        if (read_qos !== 3'd2 || read_data !== 64'hCCCC_CCCC_CCCC_CCCC) begin
            $error("Expected QoS 2 (0xCCCC...), got QoS %0d (0x%h)", read_qos, read_data);
            errors++;
        end else begin
            $display("  [PASS] First read: QoS %0d, data %h", read_qos, read_data);
        end

        read_packet(read_data, read_qos, read_valid);
        if (read_qos !== 3'd1 || read_data !== 64'hAAAA_AAAA_AAAA_AAAA) begin
            $error("Expected QoS 1 (0xAAAA...), got QoS %0d (0x%h)", read_qos, read_data);
            errors++;
        end else begin
            $display("  [PASS] Second read: QoS %0d, data %h", read_qos, read_data);
        end

        read_packet(read_data, read_qos, read_valid);
        if (read_qos !== 3'd0 || read_data !== 64'hBBBB_BBBB_BBBB_BBBB) begin
            $error("Expected QoS 0 (0xBBBB...), got QoS %0d (0x%h)", read_qos, read_data);
            errors++;
        end else begin
            $display("  [PASS] Third read: QoS %0d, data %h", read_qos, read_data);
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

    // Debug monitor
    initial begin
        $monitor("[%0t] wr_v=%b wr_r=%b rd_v=%b rd_r=%b data=%h qos=%0d empty=%b occ=%0d",
                 $time, wr_valid, wr_ready, rd_valid, rd_ready, rd_data, rd_qos, empty, occupancy);
    end

endmodule

`default_nettype wire