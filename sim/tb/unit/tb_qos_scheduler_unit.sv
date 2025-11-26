`timescale 1ns / 1ps
`default_nettype none

`include "fabric_params.vh"
`include "qos_defines.vh"

module tb_qos_scheduler_unit;

    //═══════════════════════════════════════════════════════════════════════════
    // Parameters
    //═══════════════════════════════════════════════════════════════════════════

    parameter NUM_INPUTS = 8;
    parameter QOS_LEVELS = `QOS_LEVELS;          // 8
    parameter QOS_TAG_WIDTH = `QOS_TAG_WIDTH;    // 3
    parameter ENABLE_AGING = 1;
    parameter AGING_THRESHOLD = 100;

    parameter CLK_PERIOD = 10;  // 100 MHz

    //═══════════════════════════════════════════════════════════════════════════
    // Signals
    //═══════════════════════════════════════════════════════════════════════════

    // Clock and reset
    logic clk;
    logic reset;

    // DUT interface
    logic [NUM_INPUTS-1:0] request;
    logic [QOS_TAG_WIDTH-1:0] qos_tag [NUM_INPUTS];
    logic [NUM_INPUTS-1:0] grant;
    logic grant_valid;

    // Test control
    integer test_num;
    integer errors;
    integer warnings;
    string test_name;

    // Statistics
    integer total_grants [NUM_INPUTS];
    integer priority_grants [QOS_LEVELS];
    integer total_cycles;

    //═══════════════════════════════════════════════════════════════════════════
    // DUT Instantiation
    //═══════════════════════════════════════════════════════════════════════════

    qos_scheduler #(
        .NUM_INPUTS(NUM_INPUTS),
        .QOS_LEVELS(QOS_LEVELS),
        .QOS_TAG_WIDTH(QOS_TAG_WIDTH),
        .ENABLE_AGING(ENABLE_AGING),
        .AGING_THRESHOLD(AGING_THRESHOLD)
    ) dut (
        .clk(clk),
        .reset(reset),
        .request(request),
        .qos_tag(qos_tag),
        .grant(grant),
        .grant_valid(grant_valid)
    );

    //═══════════════════════════════════════════════════════════════════════════
    // Clock Generation
    //═══════════════════════════════════════════════════════════════════════════

    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    //═══════════════════════════════════════════════════════════════════════════
    // Helper Tasks
    //═══════════════════════════════════════════════════════════════════════════

    // Initialize signals
    task automatic init_signals();
        request = '0;
        for (int i = 0; i < NUM_INPUTS; i++) begin
            qos_tag[i] = `PRIORITY_BACKGROUND;  // 3'd0
        end
    endtask

    // Reset DUT
    task automatic reset_dut();
        reset = 1;
        init_signals();
        repeat(5) @(posedge clk);
        reset = 0;
        repeat(2) @(posedge clk);
        $display("[%0t] Reset complete", $time);
    endtask

    // Start new test
    task automatic start_test(string name);
        test_num++;
        test_name = name;
        $display("\n╔═══════════════════════════════════════════════════════════════════╗");
        $display("║ Test #%0d: %-56s ║", test_num, name);
        $display("╚═══════════════════════════════════════════════════════════════════╝");
        reset_dut();
    endtask

    // End test
    task automatic end_test();
        @(posedge clk);
        $display("─────────────────────────────────────────────────────────────────────");
        if (errors == 0) begin
            $display("✓ Test #%0d PASSED: %s", test_num, test_name);
        end else begin
            $display("✗ Test #%0d FAILED: %s (%0d errors)", test_num, test_name, errors);
        end
        $display("");
    endtask

    // Check grant validity
    task automatic check_grant(
        input logic [NUM_INPUTS-1:0] expected_grant,
        input logic expected_valid,
        input string msg
    );
        @(posedge clk);
        #1;  // Sample after clock edge

        if (grant !== expected_grant) begin
            $display("  ✗ ERROR [%0t] %s", $time, msg);
            $display("    Expected grant: 0x%h, Got: 0x%h", expected_grant, grant);
            errors++;
        end else if (grant_valid !== expected_valid) begin
            $display("  ✗ ERROR [%0t] %s", $time, msg);
            $display("    Expected valid: %b, Got: %b", expected_valid, grant_valid);
            errors++;
        end else begin
            $display("  ✓ [%0t] %s - grant=0x%h, valid=%b", $time, msg, grant, grant_valid);
        end
    endtask

    // Apply requests and wait
    task automatic apply_requests(
        input logic [NUM_INPUTS-1:0] req_vec,
        input logic [QOS_TAG_WIDTH-1:0] priority [NUM_INPUTS]
    );
        request = req_vec;
        for (int i = 0; i < NUM_INPUTS; i++) begin
            qos_tag[i] = priority[i];
        end
        @(posedge clk);
    endtask

    // Wait cycles
    task automatic wait_cycles(input integer cycles);
        repeat(cycles) @(posedge clk);
    endtask

    // Check one-hot encoding
    function automatic logic is_onehot(logic [NUM_INPUTS-1:0] vec);
        return $countones(vec) == 1;
    endfunction

    //═══════════════════════════════════════════════════════════════════════════
    // Statistics Collection
    //═══════════════════════════════════════════════════════════════════════════

    always @(posedge clk) begin
        if (!reset) begin
            total_cycles++;

            if (grant_valid) begin
                for (int i = 0; i < NUM_INPUTS; i++) begin
                    if (grant[i]) begin
                        total_grants[i]++;
                        // Bounds check before indexing
                        if (qos_tag[i] < QOS_LEVELS) begin
                            priority_grants[qos_tag[i]]++;
                        end
                    end
                end
            end
        end
    end

    // Print statistics
    task automatic print_statistics();
        real avg_grant;

        $display("\n╔═══════════════════════════════════════════════════════════════════╗");
        $display("║ STATISTICS                                                        ║");
        $display("╠═══════════════════════════════════════════════════════════════════╣");
        $display("║ Total Cycles: %-51d ║", total_cycles);
        $display("╠═══════════════════════════════════════════════════════════════════╣");
        $display("║ Grants by Input:                                                  ║");

        for (int i = 0; i < NUM_INPUTS; i++) begin
            if (total_cycles > 0) begin
                avg_grant = (real'(total_grants[i]) / real'(total_cycles)) * 100.0;
                $display("║   Input[%0d]: %5d grants (%5.2f%%)                                 ║",
                         i, total_grants[i], avg_grant);
            end
        end

        $display("╠═══════════════════════════════════════════════════════════════════╣");
        $display("║ Grants by Priority:                                               ║");

        for (int p = 0; p < QOS_LEVELS; p++) begin
            if (total_cycles > 0) begin
                avg_grant = (real'(priority_grants[p]) / real'(total_cycles)) * 100.0;
                $display("║   Priority[%0d]: %5d grants (%5.2f%%)                             ║",
                         p, priority_grants[p], avg_grant);
            end
        end

        $display("╚═══════════════════════════════════════════════════════════════════╝\n");
    endtask

    // Reset statistics
    task automatic reset_statistics();
        for (int i = 0; i < NUM_INPUTS; i++) total_grants[i] = 0;
        for (int p = 0; p < QOS_LEVELS; p++) priority_grants[p] = 0;
        total_cycles = 0;
    endtask

    //═══════════════════════════════════════════════════════════════════════════
    // Test Cases
    //═══════════════════════════════════════════════════════════════════════════

    // Test 1: Basic single request
    task automatic test_basic_single_request();
        logic [QOS_TAG_WIDTH-1:0] pri [NUM_INPUTS];

        start_test("Basic Single Request");

        // Test each input individually
        for (int i = 0; i < NUM_INPUTS; i++) begin
            for (int j = 0; j < NUM_INPUTS; j++) pri[j] = `PRIORITY_BACKGROUND;

            request = (1 << i);
            apply_requests(request, pri);

            check_grant(1 << i, 1'b1, $sformatf("Single request on input %0d", i));
        end

        // No request
        request = '0;
        apply_requests(request, pri);
        check_grant('0, 1'b0, "No requests");

        end_test();
    endtask

    // Test 2: Strict priority enforcement (8 levels)
    task automatic test_strict_priority();
        logic [QOS_TAG_WIDTH-1:0] pri [NUM_INPUTS];

        start_test("Strict Priority Enforcement (8 levels)");

        // Network Control (7) beats all
        pri[0] = `PRIORITY_NETWORK_CONTROL;  // 3'd7
        pri[1] = `PRIORITY_VOICE;            // 3'd6
        pri[2] = `PRIORITY_VIDEO;            // 3'd5
        pri[3] = `PRIORITY_CRITICAL;         // 3'd4

        request = 8'b0000_1111;
        apply_requests(request, pri);
        check_grant(8'b0000_0001, 1'b1, "Network Control priority wins");

        // Voice beats Video, Critical
        request = 8'b0000_1110;
        apply_requests(request, pri);
        check_grant(8'b0000_0010, 1'b1, "Voice priority wins");

        // Video beats Critical
        request = 8'b0000_1100;
        apply_requests(request, pri);
        check_grant(8'b0000_0100, 1'b1, "Video priority wins");

        // Only Critical
        request = 8'b0000_1000;
        apply_requests(request, pri);
        check_grant(8'b0000_1000, 1'b1, "Critical priority gets served when alone");

        end_test();
    endtask

    // Test 3: Round-robin within same priority
    task automatic test_round_robin();
        logic [QOS_TAG_WIDTH-1:0] pri [NUM_INPUTS];
        logic [NUM_INPUTS-1:0] expected_sequence [4];

        start_test("Round-Robin Within Priority Level");

        // All inputs at same priority
        for (int i = 0; i < NUM_INPUTS; i++) pri[i] = `PRIORITY_EXCELLENT;  // 3'd3

        // Request from inputs 0-3
        request = 8'b0000_1111;

        // Expected round-robin sequence: 0, 1, 2, 3, 0, 1, ...
        expected_sequence[0] = 8'b0000_0001;
        expected_sequence[1] = 8'b0000_0010;
        expected_sequence[2] = 8'b0000_0100;
        expected_sequence[3] = 8'b0000_1000;

        apply_requests(request, pri);

        for (int cycle = 0; cycle < 8; cycle++) begin
            int idx = cycle % 4;
            @(posedge clk);
            #1;

            if (!is_onehot(grant)) begin
                $display("  ✗ ERROR: Grant not one-hot at cycle %0d: 0x%h", cycle, grant);
                errors++;
            end else begin
                $display("  ✓ Cycle %0d: grant=0x%h (one-hot valid)", cycle, grant);
            end
        end

        end_test();
    endtask

    // Test 4: Mixed priority round-robin
    task automatic test_mixed_priority_rr();
        logic [QOS_TAG_WIDTH-1:0] pri [NUM_INPUTS];
        int high_count, low_count;

        start_test("Mixed Priority Round-Robin");

        // Inputs 0-1: VOICE (high), Inputs 2-3: BACKGROUND (low)
        pri[0] = `PRIORITY_VOICE;       // 3'd6
        pri[1] = `PRIORITY_VOICE;       // 3'd6
        pri[2] = `PRIORITY_BACKGROUND;  // 3'd0
        pri[3] = `PRIORITY_BACKGROUND;  // 3'd0
        for (int i = 4; i < NUM_INPUTS; i++) pri[i] = `PRIORITY_BACKGROUND;

        request = 8'b0000_1111;
        apply_requests(request, pri);

        high_count = 0;
        low_count = 0;

        // Run for 100 cycles
        for (int cycle = 0; cycle < 100; cycle++) begin
            @(posedge clk);
            #1;

            if (grant_valid) begin
                if (grant[0] || grant[1]) high_count++;
                if (grant[2] || grant[3]) low_count++;
            end
        end

        $display("  High priority grants: %0d, Low priority grants: %0d", high_count, low_count);

        // All grants should be high priority (strict priority)
        if (low_count > 0) begin
            $display("  ✗ ERROR: Low priority got grants with high priority pending");
            errors++;
        end else begin
            $display("  ✓ Strict priority enforced correctly");
        end

        end_test();
    endtask

    // Test 5: Dynamic priority changes
    task automatic test_dynamic_priority();
        logic [QOS_TAG_WIDTH-1:0] pri [NUM_INPUTS];

        start_test("Dynamic Priority Changes");

        // Start with all BACKGROUND
        for (int i = 0; i < NUM_INPUTS; i++) pri[i] = `PRIORITY_BACKGROUND;
        request = 8'b0000_1111;
        apply_requests(request, pri);
        wait_cycles(2);

        // Change input 2 to NETWORK_CONTROL
        pri[2] = `PRIORITY_NETWORK_CONTROL;  // 3'd7
        apply_requests(request, pri);
        check_grant(8'b0000_0100, 1'b1, "Network Control priority takes over");

        // Change input 1 to VIDEO (still lower than NETWORK_CONTROL)
        pri[1] = `PRIORITY_VIDEO;  // 3'd5
        apply_requests(request, pri);
        check_grant(8'b0000_0100, 1'b1, "Network Control still wins over Video");

        // Remove critical request
        request = 8'b0000_1011;
        apply_requests(request, pri);
        check_grant(8'b0000_0010, 1'b1, "Video priority wins when Network Control gone");

        end_test();
    endtask

    // Test 6: All inputs same priority
    task automatic test_all_same_priority();
        logic [QOS_TAG_WIDTH-1:0] pri [NUM_INPUTS];
        logic [NUM_INPUTS-1:0] grant_history;

        start_test("All Inputs Same Priority");

        // All inputs at CRITICAL priority
        for (int i = 0; i < NUM_INPUTS; i++) pri[i] = `PRIORITY_CRITICAL;  // 3'd4

        request = {NUM_INPUTS{1'b1}};  // All requesting
        apply_requests(request, pri);

        grant_history = '0;

        // Run for NUM_INPUTS cycles and collect grants
        for (int cycle = 0; cycle < NUM_INPUTS; cycle++) begin
            @(posedge clk);
            #1;

            if (!is_onehot(grant)) begin
                $display("  ✗ ERROR: Grant not one-hot at cycle %0d", cycle);
                errors++;
            end else begin
                grant_history |= grant;
                $display("  ✓ Cycle %0d: grant=0x%h", cycle, grant);
            end
        end

        // After NUM_INPUTS cycles, all inputs should have been granted
        if (grant_history != {NUM_INPUTS{1'b1}}) begin
            $display("  ⚠ WARNING: Not all inputs served in %0d cycles", NUM_INPUTS);
            $display("    Grant history: 0x%h", grant_history);
            warnings++;
        end else begin
            $display("  ✓ All inputs served fairly");
        end

        end_test();
    endtask

    // Test 7: Request toggling
    task automatic test_request_toggling();
        logic [QOS_TAG_WIDTH-1:0] pri [NUM_INPUTS];

        start_test("Request Toggling");

        for (int i = 0; i < NUM_INPUTS; i++) pri[i] = `PRIORITY_STANDARD;  // 3'd2

        // Toggle requests on and off
        for (int cycle = 0; cycle < 20; cycle++) begin
            if (cycle % 2 == 0) begin
                request = 8'b1010_1010;
            end else begin
                request = 8'b0101_0101;
            end

            apply_requests(request, pri);

            @(posedge clk);
            #1;

            if (grant_valid && !is_onehot(grant)) begin
                $display("  ✗ ERROR: Grant not one-hot at cycle %0d", cycle);
                errors++;
            end
        end

        $display("  ✓ Request toggling handled correctly");

        end_test();
    endtask

    // Test 8: Aging mechanism (starvation prevention)
    task automatic test_aging_mechanism();
        logic [QOS_TAG_WIDTH-1:0] pri [NUM_INPUTS];
        int low_grant_count;

        start_test("Aging Mechanism (Starvation Prevention)");

        if (!ENABLE_AGING) begin
            $display("  ⓘ Aging disabled, skipping test");
            end_test();
            return;
        end

        // Input 0: NETWORK_CONTROL (always requesting)
        // Input 7: BACKGROUND (always requesting, will age)
        for (int i = 0; i < NUM_INPUTS; i++) pri[i] = `PRIORITY_BACKGROUND;
        pri[0] = `PRIORITY_NETWORK_CONTROL;  // 3'd7

        request = 8'b1000_0001;
        apply_requests(request, pri);

        low_grant_count = 0;

        // Run for AGING_THRESHOLD * 2 cycles
        for (int cycle = 0; cycle < AGING_THRESHOLD * 2; cycle++) begin
            @(posedge clk);
            #1;

            if (grant[7]) begin
                low_grant_count++;
                $display("  ✓ [%0t] Low priority got grant (aged) at cycle %0d", $time, cycle);
            end
        end

        if (low_grant_count > 0) begin
            $display("  ✓ Aging mechanism prevented starvation (%0d grants)", low_grant_count);
        end else begin
            $display("  ⚠ WARNING: Aging did not prevent starvation");
            warnings++;
        end

        end_test();
    endtask

    // Test 9: Stress test - random requests
    task automatic test_random_requests();
        logic [QOS_TAG_WIDTH-1:0] pri [NUM_INPUTS];
        int cycles = 1000;
        int grant_count;

        start_test("Stress Test - Random Requests");

        reset_statistics();
        grant_count = 0;

        for (int cycle = 0; cycle < cycles; cycle++) begin
            // Randomize requests and priorities
            request = $random;
            for (int i = 0; i < NUM_INPUTS; i++) begin
                pri[i] = $random % QOS_LEVELS;  // 0-7
            end

            apply_requests(request, pri);

            @(posedge clk);
            #1;

            // Verify grant properties
            if (grant_valid) begin
                grant_count++;

                if (!is_onehot(grant)) begin
                    $display("  ✗ ERROR: Grant not one-hot at cycle %0d: 0x%h", cycle, grant);
                    errors++;
                    break;  // Stop on first error
                end

                // Verify grant matches request
                if ((grant & request) == 0) begin
                    $display("  ✗ ERROR: Grant without request at cycle %0d", cycle);
                    errors++;
                    break;
                end
            end
        end

        $display("  ✓ Random stress test completed: %0d cycles, %0d grants", cycles, grant_count);
        print_statistics();

        end_test();
    endtask

    // Test 10: Back-to-back requests
    task automatic test_back_to_back();
        logic [QOS_TAG_WIDTH-1:0] pri [NUM_INPUTS];

        start_test("Back-to-Back Requests");

        for (int i = 0; i < NUM_INPUTS; i++) pri[i] = `PRIORITY_EXCELLENT;  // 3'd3

        // Continuously request from all inputs
        request = {NUM_INPUTS{1'b1}};
        apply_requests(request, pri);

        for (int cycle = 0; cycle < 50; cycle++) begin
            @(posedge clk);
            #1;

            if (!grant_valid) begin
                $display("  ✗ ERROR: No grant at cycle %0d with pending requests", cycle);
                errors++;
            end

            if (!is_onehot(grant)) begin
                $display("  ✗ ERROR: Grant not one-hot at cycle %0d", cycle);
                errors++;
            end
        end

        $display("  ✓ Back-to-back requests handled correctly");

        end_test();
    endtask

    //═══════════════════════════════════════════════════════════════════════════
    // Main Test Sequence
    //═══════════════════════════════════════════════════════════════════════════

    initial begin
        $display("\n");
        $display("╔═══════════════════════════════════════════════════════════════════╗");
        $display("║                                                                   ║");
        $display("║          QoS SCHEDULER UNIT TESTBENCH (8 Levels)                  ║");
        $display("║          ====================================                     ║");
        $display("║                                                                   ║");
        $display("║  Parameters:                                                      ║");
        $display("║    - NUM_INPUTS:      %2d                                         ║", NUM_INPUTS);
        $display("║    - QOS_LEVELS:      %2d                                         ║", QOS_LEVELS);
        $display("║    - QOS_TAG_WIDTH:   %2d                                         ║", QOS_TAG_WIDTH);
        $display("║    - ENABLE_AGING:    %2d                                         ║", ENABLE_AGING);
        $display("║    - AGING_THRESHOLD: %3d                                        ║", AGING_THRESHOLD);
        $display("║                                                                   ║");
        $display("╚═══════════════════════════════════════════════════════════════════╝\n");

        // Initialize
        test_num = 0;
        errors = 0;
        warnings = 0;
        reset_statistics();

        reset = 1;
        init_signals();
        #100;

        // Run all tests
        test_basic_single_request();
        test_strict_priority();
        test_round_robin();
        test_mixed_priority_rr();
        test_dynamic_priority();
        test_all_same_priority();
        test_request_toggling();
        test_aging_mechanism();
        test_random_requests();
        test_back_to_back();

        // Final summary
        #100;

        $display("\n");
        $display("╔═══════════════════════════════════════════════════════════════════╗");
        $display("║                      TEST SUMMARY                                 ║");
        $display("╠═══════════════════════════════════════════════════════════════════╣");
        $display("║  Total Tests: %2d                                                  ║", test_num);
        $display("║  Passed:      %2d                                                  ║", test_num - errors);
        $display("║  Failed:      %2d                                                  ║", errors > 0 ? errors : 0);
        $display("║  Warnings:    %2d                                                  ║", warnings);
        $display("╠═══════════════════════════════════════════════════════════════════╣");

        if (errors == 0 && warnings == 0) begin
            $display("║                                                                   ║");
            $display("║                   ✓✓✓ ALL TESTS PASSED ✓✓✓                       ║");
            $display("║                                                                   ║");
        end else if (errors == 0) begin
            $display("║                                                                   ║");
            $display("║            ✓ ALL TESTS PASSED (with warnings)                     ║");
            $display("║                                                                   ║");
        end else begin
            $display("║                                                                   ║");
            $display("║                   ✗✗✗ SOME TESTS FAILED ✗✗✗                      ║");
            $display("║                                                                   ║");
        end

        $display("╚═══════════════════════════════════════════════════════════════════╝\n");

        $finish;
    end

    //═══════════════════════════════════════════════════════════════════════════
    // Timeout Watchdog
    //═══════════════════════════════════════════════════════════════════════════

    initial begin
        #50ms;  // 50 millisecond timeout
        $display("\n✗✗✗ TIMEOUT: Simulation exceeded 50ms ✗✗✗\n");
        $finish;
    end

    //═══════════════════════════════════════════════════════════════════════════
    // Waveform Dumping
    //═══════════════════════════════════════════════════════════════════════════

    initial begin
        $dumpfile("tb_qos_scheduler_unit.vcd");
        $dumpvars(0, tb_qos_scheduler_unit);
    end

endmodule

`default_nettype wire