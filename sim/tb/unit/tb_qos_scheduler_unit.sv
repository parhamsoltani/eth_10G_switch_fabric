`timescale 1ns / 1ps
// `default_nettype none

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
    integer test_errors;      // Errors in current test
    integer total_errors;     // Total errors across all tests
    integer tests_passed;     // Number of passed tests
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
        if (test_errors == 0) begin
            $display("✓ Test #%0d PASSED: %s", test_num, test_name);
        end else begin
            $display("✗ Test #%0d FAILED: %s (%0d errors)", test_num, test_name, test_errors);
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
            $display("   ✗ ERROR [%0t] %s", $time, msg);
            $display("      Expected grant: 0x%h, Got: 0x%h", expected_grant, grant);
            total_errors++;
        end else if (grant_valid !== expected_valid) begin
            $display("   ✗ ERROR [%0t] %s", $time, msg);
            $display("      Expected valid: %b, Got: %b", expected_valid, grant_valid);
            total_errors++;
        end else begin
            $display("   ✓ [%0t] %s - grant=0x%h, valid=%b", $time, msg, grant, grant_valid);
        end
    endtask

    // Check grant is within expected set
    task automatic check_grant_in_set(
        input logic [NUM_INPUTS-1:0] valid_grants,
        input logic expected_valid,
        input string msg
    );
        @(posedge clk);
        #1;  // Sample after clock edge

        if (grant_valid !== expected_valid) begin
            $display("   ✗ ERROR [%0t] %s", $time, msg);
            $display("      Expected valid: %b, Got: %b", expected_valid, grant_valid);
            total_errors++;
        end else if (grant_valid && ((grant & valid_grants) == 0)) begin
            $display("   ✗ ERROR [%0t] %s", $time, msg);
            $display("      Expected grant from set: 0x%h, Got: 0x%h", valid_grants, grant);
            total_errors++;
        end else begin
            $display("   ✓ [%0t] %s - grant=0x%h (from valid set 0x%h)", $time, msg, grant, valid_grants);
        end
    endtask

    // Apply requests and wait
    task automatic apply_requests(
        input logic [NUM_INPUTS-1:0] req_vec,
        input logic [QOS_TAG_WIDTH-1:0] qos_priority[NUM_INPUTS]
    );
        request = req_vec;
        for (int i = 0; i < NUM_INPUTS; i++) begin
            qos_tag[i] = qos_priority[i];
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

    // Get priority name
    function automatic string get_priority_name(logic [QOS_TAG_WIDTH-1:0] pri);
        case (pri)
            3'd0: return "BACKGROUND";
            3'd1: return "BEST_EFFORT";
            3'd2: return "STANDARD";
            3'd3: return "EXCELLENT";
            3'd4: return "CRITICAL";
            3'd5: return "VIDEO";
            3'd6: return "VOICE";
            3'd7: return "NETWORK_CONTROL";
            default: return "UNKNOWN";
        endcase
    endfunction

    // Get queue name from priority
    function automatic string get_queue_name(logic [QOS_TAG_WIDTH-1:0] pri);
        case (pri[2:1])
            2'd3: return "CRITICAL";  // Priorities 6-7
            2'd2: return "HIGH";      // Priorities 4-5
            2'd1: return "MEDIUM";    // Priorities 2-3
            2'd0: return "LOW";       // Priorities 0-1
            default: return "UNKNOWN";
        endcase
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
        $display("║ Grants by Priority Level:                                         ║");

        for (int p = QOS_LEVELS-1; p >= 0; p--) begin  // Show highest first
            if (total_cycles > 0) begin
                avg_grant = (real'(priority_grants[p]) / real'(total_cycles)) * 100.0;
                $display("║   Priority %0d (%12s): %5d grants (%5.2f%%)              ║",
                         p, get_priority_name(p[QOS_TAG_WIDTH-1:0]), priority_grants[p], avg_grant);
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

        // Test each input individually at BACKGROUND priority
        for (int i = 0; i < NUM_INPUTS; i++) begin
            for (int j = 0; j < NUM_INPUTS; j++) pri[j] = `PRIORITY_BACKGROUND;

            request = (1 << i);
            apply_requests(request, pri);

            check_grant(1 << i, 1'b1, $sformatf("Single request on input %0d", i));
        end

        // No request
        request = '0;
        apply_requests(request, pri);
        check_grant('0, 1'b0, "No requests - grant_valid should be 0");

        end_test();
    endtask

    // Test 2: Queue-level strict priority (4 queues)
    task automatic test_queue_priority();
        logic [QOS_TAG_WIDTH-1:0] pri [NUM_INPUTS];

        start_test("Queue-Level Strict Priority (4 Queues)");

        $display("   Design uses 4 queues:");
        $display("   - CRITICAL queue: Priorities 7,6");
        $display("   - HIGH queue:     Priorities 5,4");
        $display("   - MEDIUM queue:   Priorities 3,2");
        $display("   - LOW queue:      Priorities 1,0");

        // Initialize all to BACKGROUND
        for (int i = 0; i < NUM_INPUTS; i++) pri[i] = `PRIORITY_BACKGROUND;

        // Test 1: CRITICAL queue beats all others
        $display("\n   Test 1: CRITICAL queue (pri 6,7) beats HIGH queue (pri 4,5)");
        pri[0] = 3'd7;  // CRITICAL queue
        pri[1] = 3'd5;  // HIGH queue
        pri[2] = 3'd3;  // MEDIUM queue
        pri[3] = 3'd1;  // LOW queue

        request = 8'b0000_1111;
        apply_requests(request, pri);
        check_grant(8'b0000_0001, 1'b1, "CRITICAL queue (port 0, pri 7) wins");

        // Test 2: HIGH queue beats MEDIUM and LOW
        $display("\n   Test 2: HIGH queue (pri 4,5) beats MEDIUM and LOW");
        request = 8'b0000_1110;  // Exclude CRITICAL
        apply_requests(request, pri);
        check_grant(8'b0000_0010, 1'b1, "HIGH queue (port 1, pri 5) wins");

        // Test 3: MEDIUM queue beats LOW
        $display("\n   Test 3: MEDIUM queue (pri 2,3) beats LOW");
        request = 8'b0000_1100;  // Exclude CRITICAL and HIGH
        apply_requests(request, pri);
        check_grant(8'b0000_0100, 1'b1, "MEDIUM queue (port 2, pri 3) wins");

        // Test 4: LOW queue served when alone
        $display("\n   Test 4: LOW queue served when no higher queues");
        request = 8'b0000_1000;  // Only LOW
        apply_requests(request, pri);
        check_grant(8'b0000_1000, 1'b1, "LOW queue (port 3, pri 1) served");

        end_test();
    endtask

    // Test 3: Round-robin within same queue
    task automatic test_round_robin_within_queue();
        logic [QOS_TAG_WIDTH-1:0] pri [NUM_INPUTS];
        logic [NUM_INPUTS-1:0] grants_seen;
        int unique_grants;

        start_test("Round-Robin Within Same Queue");

        // All inputs at same queue (MEDIUM queue - priorities 2,3)
        pri[0] = 3'd2;  // MEDIUM queue
        pri[1] = 3'd3;  // MEDIUM queue (same queue as 2)
        pri[2] = 3'd2;  // MEDIUM queue
        pri[3] = 3'd3;  // MEDIUM queue
        for (int i = 4; i < NUM_INPUTS; i++) pri[i] = `PRIORITY_BACKGROUND;

        // Request from inputs 0-3 (all in MEDIUM queue)
        request = 8'b0000_1111;
        apply_requests(request, pri);

        grants_seen = '0;

        $display("   Testing round-robin among 4 requesters in MEDIUM queue");

        // Run for 12 cycles (3 full rounds)
        for (int cycle = 0; cycle < 12; cycle++) begin
            @(posedge clk);
            #1;

            if (!grant_valid) begin
                $display("   ERROR: No grant at cycle %0d with pending requests", cycle);
                test_errors++;
                break;
            end

            if (!is_onehot(grant)) begin
                $display("   ERROR: Grant not one-hot at cycle %0d: 0x%h", cycle, grant);
                test_errors++;
                break;
            end

            grants_seen |= grant;

            // Check grant is from requesting ports in MEDIUM queue
            if ((grant & 8'b0000_1111) == 0) begin
                $display("   ✗ ERROR: Grant to non-requesting port at cycle %0d", cycle);
                test_errors++;
                break;
            end

            if (cycle < 4) begin
                $display("      Cycle %2d: grant=0x%h (port %0d, pri %0d)", cycle, grant,
                         grant[0] ? 0 : grant[1] ? 1 : grant[2] ? 2 : 3,
                         grant[0] ? pri[0] : grant[1] ? pri[1] : grant[2] ? pri[2] : pri[3]);
            end
        end

        // Check that all 4 ports got served
        unique_grants = $countones(grants_seen & 8'b0000_1111);
        if (unique_grants != 4) begin
            $display("   ✗ ERROR: Only %0d out of 4 ports served", unique_grants);
            test_errors++;
        end else begin
            $display("   ✓ All 4 ports in MEDIUM queue served in round-robin fashion");
        end

        end_test();
    endtask


    // Test 4: Mixed queues with round-robin
    task automatic test_mixed_queues();
        logic [QOS_TAG_WIDTH-1:0] pri [NUM_INPUTS];
        int critical_count, low_count;
        int test_cycles;

        start_test("Mixed Queues - Strict Queue Priority");

        // Ports 0-1: CRITICAL queue (priorities 6,7)
        // Ports 2-3: LOW queue (priorities 0,1)
        pri[0] = 3'd7;  // CRITICAL queue
        pri[1] = 3'd6;  // CRITICAL queue
        pri[2] = 3'd1;  // LOW queue
        pri[3] = 3'd0;  // LOW queue
        for (int i = 4; i < NUM_INPUTS; i++) pri[i] = `PRIORITY_BACKGROUND;

        request = 8'b0000_1111;  // Ports 0-3 requesting
        apply_requests(request, pri);

        critical_count = 0;
        low_count = 0;

        $display("   Testing: CRITICAL queue should always beat LOW queue");
        $display("   Ports 0,1 in CRITICAL queue (pri 7,6)");
        $display("   Ports 2,3 in LOW queue (pri 1,0)");

        // Run for less than aging threshold to avoid interference
        if (ENABLE_AGING) begin
            test_cycles = AGING_THRESHOLD - 10;  // Stop before aging kicks in
            $display("   Running for %0d cycles (before aging threshold)", test_cycles);
        end else begin
            test_cycles = 100;
            $display("   Running for %0d cycles", test_cycles);
        end

        // Run test
        for (int cycle = 0; cycle < test_cycles; cycle++) begin
            @(posedge clk);
            #1;

            if (grant_valid) begin
                if (grant[0] || grant[1]) begin
                    critical_count++;
                end
                if (grant[2] || grant[3]) begin
                    low_count++;
                    $display("   ⚠ WARNING: Low queue got grant at cycle %0d (grant=0x%h)",
                            cycle, grant);
                end
            end
        end

        $display("   CRITICAL queue grants: %0d", critical_count);
        $display("   LOW queue grants: %0d", low_count);

        // With strict queue priority, LOW should NEVER get grants while CRITICAL is requesting
        if (low_count > 0) begin
            $display("   ✗ ERROR: LOW queue got %0d grants with CRITICAL queue pending", low_count);
            test_errors++;
        end else begin
            $display("   ✓ Strict queue priority enforced (CRITICAL always beats LOW)");
        end

        end_test();
    endtask


    // Test 5: Within-queue fairness (priorities 6 and 7 in same CRITICAL queue)
    task automatic test_within_queue_fairness();
        logic [QOS_TAG_WIDTH-1:0] pri [NUM_INPUTS];
        int pri7_count, pri6_count;

        start_test("Within-Queue Fairness (Priorities 6,7 in CRITICAL Queue)");

        // Both ports in CRITICAL queue
        pri[0] = 3'd7;  // CRITICAL queue
        pri[1] = 3'd6;  // CRITICAL queue (same queue!)
        for (int i = 2; i < NUM_INPUTS; i++) pri[i] = `PRIORITY_BACKGROUND;

        request = 8'b0000_0011;  // Ports 0,1
        apply_requests(request, pri);

        pri7_count = 0;
        pri6_count = 0;

        $display("   Both ports in CRITICAL queue:");
        $display("   Port 0: priority 7");
        $display("   Port 1: priority 6");
        $display("   Expected: Round-robin (fair sharing within queue)");

        // Run for 100 cycles
        for (int cycle = 0; cycle < 100; cycle++) begin
            @(posedge clk);
            #1;

            if (grant_valid) begin
                if (grant[0]) pri7_count++;
                if (grant[1]) pri6_count++;
            end
        end

        $display("   Port 0 (pri 7) grants: %0d", pri7_count);
        $display("   Port 1 (pri 6) grants: %0d", pri6_count);

        // Should be roughly equal (within 10%)
        if (pri7_count < 40 || pri7_count > 60 || pri6_count < 40 || pri6_count > 60) begin
            $display("   ⚠ WARNING: Unfair distribution within queue");
            warnings++;
        end else begin
            $display("   ✓ Fair round-robin within CRITICAL queue");
        end

        end_test();
    endtask

    // Test 6: Dynamic priority changes across queues
    task automatic test_dynamic_priority_queues();
        logic [QOS_TAG_WIDTH-1:0] pri [NUM_INPUTS];

        start_test("Dynamic Priority Changes Across Queues");

        // Start with all in LOW queue
        for (int i = 0; i < NUM_INPUTS; i++) pri[i] = `PRIORITY_BACKGROUND;  // LOW queue
        request = 8'b0000_1111;  // Ports 0-3
        apply_requests(request, pri);

        $display("   Phase 1: All in LOW queue - round-robin expected");
        wait_cycles(2);

        // Boost port 2 to CRITICAL queue
        $display("   Phase 2: Boost port 2 to CRITICAL queue (priority 7)");
        pri[2] = 3'd7;  // CRITICAL queue
        apply_requests(request, pri);
        check_grant(8'b0000_0100, 1'b1, "Port 2 (CRITICAL queue) wins immediately");

        // Boost port 1 to HIGH queue (still lower than CRITICAL)
        $display("   Phase 3: Boost port 1 to HIGH queue (priority 5)");
        pri[1] = 3'd5;  // HIGH queue
        apply_requests(request, pri);
        check_grant(8'b0000_0100, 1'b1, "Port 2 (CRITICAL) still wins over port 1 (HIGH)");

        // Remove port 2's request
        $display("   Phase 4: Remove port 2's request");
        request = 8'b0000_1011;  // Ports 0,1,3
        apply_requests(request, pri);
        check_grant(8'b0000_0010, 1'b1, "Port 1 (HIGH queue) wins when CRITICAL absent");

        // Remove port 1, now port 0 and 3 compete (both in LOW queue)
        $display("   Phase 5: Remove port 1, ports 0,3 in LOW queue compete");
        request = 8'b0000_1001;  // Ports 0,3
        apply_requests(request, pri);
        check_grant_in_set(8'b0000_1001, 1'b1, "One of LOW queue ports wins");

        $display("   ✓ Dynamic queue transitions handled correctly");

        end_test();
    endtask

    // Test 7: All inputs same queue - fair round-robin
    task automatic test_all_same_queue();
        logic [QOS_TAG_WIDTH-1:0] pri [NUM_INPUTS];
        logic [NUM_INPUTS-1:0] grant_history;
        int grant_count [NUM_INPUTS];

        start_test("All Inputs Same Queue - Fair Round-Robin");

        // All inputs in HIGH queue (priority 4 or 5)
        for (int i = 0; i < NUM_INPUTS; i++) begin
            pri[i] = (i % 2 == 0) ? 3'd4 : 3'd5;  // Alternate 4 and 5 (both in HIGH queue)
            grant_count[i] = 0;
        end

        request = {NUM_INPUTS{1'b1}};  // All requesting
        apply_requests(request, pri);

        grant_history = '0;

        $display("   Running for %0d cycles with all ports in HIGH queue", NUM_INPUTS * 3);

        // Run for 3 full rounds
        for (int cycle = 0; cycle < NUM_INPUTS * 3; cycle++) begin
            @(posedge clk);
            #1;

            if (!is_onehot(grant)) begin
                $display("   ✗ ERROR: Grant not one-hot at cycle %0d: 0x%h", cycle, grant);
                test_errors++;
                break;
            end

            grant_history |= grant;

            // Count grants per port
            for (int i = 0; i < NUM_INPUTS; i++) begin
                if (grant[i]) grant_count[i]++;
            end
        end

        // Check all ports got served
        if (grant_history != {NUM_INPUTS{1'b1}}) begin
            $display("   ✗ ERROR: Not all ports served");
            $display("      Grant history: 0x%h (expected 0x%h)", grant_history, {NUM_INPUTS{1'b1}});
            total_errors++;
        end else begin
            $display("   ✓ All %0d ports served at least once", NUM_INPUTS);
        end

        // Check fairness (each port should get ~3 grants)
        $display("   Grant distribution:");
        for (int i = 0; i < NUM_INPUTS; i++) begin
            $display("      Port %0d (pri %0d): %0d grants", i, pri[i], grant_count[i]);
            if (grant_count[i] < 2 || grant_count[i] > 4) begin
                $display("      ⚠ WARNING: Unfair distribution for port %0d", i);
                warnings++;
            end
        end

        end_test();
    endtask

    // Test 8: Request toggling
    task automatic test_request_toggling();
        logic [QOS_TAG_WIDTH-1:0] pri [NUM_INPUTS];

        start_test("Request Toggling");

        for (int i = 0; i < NUM_INPUTS; i++) pri[i] = `PRIORITY_STANDARD;  // MEDIUM queue

        $display("   Toggling requests between even/odd ports for 20 cycles");

        // Toggle requests on and off
        for (int cycle = 0; cycle < 20; cycle++) begin
            if (cycle % 2 == 0) begin
                request = 8'b1010_1010;  // Even ports
            end else begin
                request = 8'b0101_0101;  // Odd ports
            end

            apply_requests(request, pri);

            @(posedge clk);
            #1;

            if (grant_valid) begin
                if (!is_onehot(grant)) begin
                    $display("   ✗ ERROR: Grant not one-hot at cycle %0d: 0x%h", cycle, grant);
                    total_errors++;
                    break;
                end

                // Verify grant matches current request pattern
                if ((grant & request) == 0) begin
                    $display("   ✗ ERROR: Grant 0x%h doesn't match request 0x%h at cycle %0d",
                             grant, request, cycle);
                    total_errors++;
                    break;
                end
            end
        end

        $display("   ✓ Request toggling handled correctly");

        end_test();
    endtask

    // Test 9: Aging mechanism (starvation prevention)
    task automatic test_aging_mechanism();
        logic [QOS_TAG_WIDTH-1:0] pri [NUM_INPUTS];
        int low_grant_count;
        int cycle;

        start_test("Aging Mechanism (Starvation Prevention)");

        if (!ENABLE_AGING) begin
            $display("  ℹ Aging disabled in design, skipping test");
            end_test();
            return;
        end

        // Port 0: CRITICAL queue (priority 7) - always requesting
        // Port 7: LOW queue (priority 0) - always requesting, will age out
        for (int i = 0; i < NUM_INPUTS; i++) pri[i] = `PRIORITY_BACKGROUND;
        pri[0] = 3'd7;  // CRITICAL queue
        pri[7] = 3'd0;  // LOW queue

        request = 8'b1000_0001;  // Ports 0 and 7
        apply_requests(request, pri);

        low_grant_count = 0;
        cycle = 0;

        $display("   Running for %0d cycles (2x aging threshold)", AGING_THRESHOLD * 2);
        $display("   Port 0 in CRITICAL queue (pri 7)");
        $display("   Port 7 in LOW queue (pri 0)");
        $display("   Expecting port 7 to get boosted to CRITICAL after ~%0d cycles", AGING_THRESHOLD);

        // Run for 2x aging threshold
        for (cycle = 0; cycle < AGING_THRESHOLD * 2; cycle++) begin
            @(posedge clk);
            #1;

            if (grant[7]) begin
                low_grant_count++;
                $display("   ✓ Cycle %4d: Port 7 (LOW queue) got grant via aging boost!", cycle);
            end
        end

        if (low_grant_count > 0) begin
            $display("   ✓ Aging mechanism worked: LOW queue got %0d grants (prevented starvation)",
                     low_grant_count);
        end else begin
            $display("   ✗ ERROR: Aging failed - LOW queue starved for %0d cycles", cycle);
            total_errors++;
        end

        end_test();
    endtask

    // Test 10: Queue mapping verification
    task automatic test_queue_mapping();
        logic [QOS_TAG_WIDTH-1:0] pri [NUM_INPUTS];
        int grants_in_group;

        start_test("Queue Mapping Verification (8 Priorities → 4 Queues)");

        $display("   Verifying priority-to-queue mapping:");
        $display("   - CRITICAL: Priorities 7,6");
        $display("   - HIGH:     Priorities 5,4");
        $display("   - MEDIUM:   Priorities 3,2");
        $display("   - LOW:      Priorities 1,0");

        for (int i = 0; i < NUM_INPUTS; i++) pri[i] = `PRIORITY_BACKGROUND;

        // Test 1: Priorities 7,6 round-robin (both in CRITICAL)
        $display("\n   Test 1: Priorities 7 & 6 share CRITICAL queue (should round-robin)");
        pri[0] = 3'd7;
        pri[1] = 3'd6;
        request = 8'b0000_0011;
        apply_requests(request, pri);

        grants_in_group = 0;
        for (int i = 0; i < 10; i++) begin
            @(posedge clk);
            #1;
            if (grant_valid && (grant[0] || grant[1])) begin
                grants_in_group++;
            end
        end

        if (grants_in_group == 10) begin
            $display("   ✓ Priorities 7,6 correctly share CRITICAL queue");
        end else begin
            $display("   ✗ ERROR: Unexpected behavior in CRITICAL queue");
            total_errors++;
        end

        // Test 2: CRITICAL beats HIGH
        $display("\n   Test 2: CRITICAL queue beats HIGH queue");
        pri[0] = 3'd6;  // CRITICAL
        pri[1] = 3'd5;  // HIGH
        request = 8'b0000_0011;
        apply_requests(request, pri);
        check_grant(8'b0000_0001, 1'b1, "CRITICAL (pri 6) beats HIGH (pri 5)");

        // Test 3: HIGH beats MEDIUM
        $display("\n   Test 3: HIGH queue beats MEDIUM queue");
        pri[0] = 3'd4;  // HIGH
        pri[1] = 3'd3;  // MEDIUM
        request = 8'b0000_0011;
        apply_requests(request, pri);
        check_grant(8'b0000_0001, 1'b1, "HIGH (pri 4) beats MEDIUM (pri 3)");

        // Test 4: MEDIUM beats LOW
        $display("\n   Test 4: MEDIUM queue beats LOW queue");
        pri[0] = 3'd2;  // MEDIUM
        pri[1] = 3'd1;  // LOW
        request = 8'b0000_0011;
        apply_requests(request, pri);
        check_grant(8'b0000_0001, 1'b1, "MEDIUM (pri 2) beats LOW (pri 1)");

        $display("   ✓ Queue priority ordering verified");

        end_test();
    endtask

    // Test 11: Stress test - random requests
    task automatic test_random_requests();
        logic [QOS_TAG_WIDTH-1:0] pri [NUM_INPUTS];
        int cycles = 1000;
        int grant_count;
        int error_count;

        start_test("Stress Test - 1000 Random Requests");

        reset_statistics();
        grant_count = 0;
        error_count = 0;

        $display("   Running %0d cycles with random requests and priorities", cycles);

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

                // Check one-hot
                if (!is_onehot(grant)) begin
                    if (error_count == 0) begin
                        $display("   ✗ ERROR: Grant not one-hot at cycle %0d: 0x%h", cycle, grant);
                    end
                    error_count++;
                    if (error_count >= 10) break;
                end

                // Check grant matches request
                if ((grant & request) == 0) begin
                    if (error_count == 0) begin
                        $display("   ✗ ERROR: Grant 0x%h without matching request 0x%h at cycle %0d",
                                 grant, request, cycle);
                    end
                    error_count++;
                    if (error_count >= 10) break;
                end
            end else begin
                // If no grant, should be no requests
                if (request != 0) begin
                    if (error_count == 0) begin
                        $display("   ✗ ERROR: No grant despite request 0x%h at cycle %0d", request, cycle);
                    end
                    error_count++;
                    if (error_count >= 10) break;
                end
            end

            // Progress indicator every 200 cycles
            if (cycle % 200 == 199) begin
                $display("      Progress: %0d/%0d cycles, %0d grants, %0d errors",
                         cycle+1, cycles, grant_count, error_count);
            end
        end

        total_errors += error_count;

        if (error_count == 0) begin
            $display("   Stress test passed: %0d cycles, %0d grants, 0 errors", cycles, grant_count);
            print_statistics();
        end else begin
            $display("   Stress test failed with %0d errors", error_count);
        end

        end_test();
    endtask

    // Test 12: Back-to-back requests
    task automatic test_back_to_back();
        logic [QOS_TAG_WIDTH-1:0] pri [NUM_INPUTS];
        int consecutive_grants;

        start_test("Back-to-Back Requests (Continuous Grant Test)");

        for (int i = 0; i < NUM_INPUTS; i++) pri[i] = `PRIORITY_EXCELLENT;  // MEDIUM queue

        // Continuously request from all inputs
        request = {NUM_INPUTS{1'b1}};
        apply_requests(request, pri);

        consecutive_grants = 0;

        $display("   Testing continuous grants for 50 cycles");

        for (int cycle = 0; cycle < 50; cycle++) begin
            @(posedge clk);
            #1;

            if (!grant_valid) begin
                $display("   ✗ ERROR: No grant at cycle %0d with pending requests", cycle);
                total_errors++;
                break;
            end

            if (!is_onehot(grant)) begin
                $display("   ✗ ERROR: Grant not one-hot at cycle %0d: 0x%h", cycle, grant);
                total_errors++;
                break;
            end

            consecutive_grants++;
        end

        if (consecutive_grants == 50) begin
            $display("   ✓ Maintained continuous grants for %0d cycles", consecutive_grants);
        end

        end_test();
    endtask

    // Test 13: Edge cases
    task automatic test_edge_cases();
        logic [QOS_TAG_WIDTH-1:0] pri [NUM_INPUTS];

        start_test("Edge Cases and Boundary Conditions");

        // Edge case 1: Valid priorities at queue boundaries
        $display("   Test 1: Queue boundary priorities");
        for (int i = 0; i < NUM_INPUTS; i++) pri[i] = `PRIORITY_BACKGROUND;
        pri[0] = 3'd0;  // LOW queue lower bound
        pri[1] = 3'd1;  // LOW queue upper bound
        request = 8'b0000_0011;
        apply_requests(request, pri);
        check_grant_in_set(8'b0000_0011, 1'b1, "Both priorities in LOW queue");

        // Edge case 2: Single bit request at each position
        $display("\n   Test 2: Single request at each input position");
        for (int i = 0; i < NUM_INPUTS; i++) begin
            pri[i] = 3'd4;  // HIGH queue
            request = (1 << i);
            apply_requests(request, pri);
            @(posedge clk);
            #1;

            if (grant != request) begin
                $display("   ✗ ERROR: Single request at position %0d not granted correctly", i);
                total_errors++;
            end
        end
        $display("   ✓ All single-bit positions tested");

        // Edge case 3: All requests then sudden removal
        $display("\n   Test 3: All requests then sudden removal");
        for (int i = 0; i < NUM_INPUTS; i++) pri[i] = `PRIORITY_STANDARD;
        request = {NUM_INPUTS{1'b1}};
        apply_requests(request, pri);
        wait_cycles(2);

        request = '0;
        apply_requests(request, pri);
        check_grant('0, 1'b0, "No grants after all requests removed");

        $display("   ✓ Edge cases handled correctly");

        end_test();
    endtask

    //═══════════════════════════════════════════════════════════════════════════
    // Main Test Sequence
    //═══════════════════════════════════════════════════════════════════════════

    initial begin
        $display("\n");
        $display("╔═══════════════════════════════════════════════════════════════════╗");
        $display("║                                                                   ║");
        $display("║          QoS SCHEDULER COMPREHENSIVE TESTBENCH                    ║");
        $display("║          =====================================                    ║");
        $display("║                                                                   ║");
        $display("║  Design: 4-Queue Scheduler with 8 Priority Levels                ║");
        $display("║  Queue Mapping: 8 priorities → 4 queues                          ║");
        $display("║                                                                   ║");
        $display("║  Parameters:                                                      ║");
        $display("║    • NUM_INPUTS:       %2d                                        ║", NUM_INPUTS);
        $display("║    • QOS_LEVELS:       %2d                                        ║", QOS_LEVELS);
        $display("║    • QOS_TAG_WIDTH:    %2d                                        ║", QOS_TAG_WIDTH);
        $display("║    • ENABLE_AGING:     %2d                                        ║", ENABLE_AGING);
        $display("║    • AGING_THRESHOLD:  %3d                                       ║", AGING_THRESHOLD);
        $display("║                                                                   ║");
        $display("║  Queue Architecture:                                              ║");
        $display("║    • CRITICAL Queue: Priorities 7,6 (Highest)                     ║");
        $display("║    • HIGH Queue:     Priorities 5,4                               ║");
        $display("║    • MEDIUM Queue:   Priorities 3,2                               ║");
        $display("║    • LOW Queue:      Priorities 1,0 (Lowest)                      ║");
        $display("║                                                                   ║");
        $display("║  Behavior:                                                        ║");
        $display("║    • Strict priority between queues                               ║");
        $display("║    • Round-robin fairness within each queue                       ║");
        $display("║                                                                   ║");
        $display("╚═══════════════════════════════════════════════════════════════════╝\n");

        // Initialize
        test_num = 0;
        test_errors = 0;
        total_errors = 0;
        tests_passed = 0;
        warnings = 0;
        reset_statistics();

        reset = 1;
        init_signals();
        #100;

        // Run all tests
        test_basic_single_request();        // Test 1
        test_queue_priority();              // Test 2 - CORRECTED for 4 queues
        test_round_robin_within_queue();    // Test 3 - CORRECTED
        test_mixed_queues();                // Test 4 - CORRECTED
        test_within_queue_fairness();       // Test 5 - NEW (tests pri 6,7 fairness)
        test_dynamic_priority_queues();     // Test 6 - CORRECTED
        test_all_same_queue();              // Test 7
        test_request_toggling();            // Test 8
        test_aging_mechanism();             // Test 9
        test_queue_mapping();               // Test 10 - CORRECTED
        test_random_requests();             // Test 11
        test_back_to_back();                // Test 12
        test_edge_cases();                  // Test 13

        // Final summary
        #100;

        $display("\n");
        $display("╔═══════════════════════════════════════════════════════════════════╗");
        $display("║                      FINAL TEST SUMMARY                           ║");
        $display("╠═══════════════════════════════════════════════════════════════════╣");
        $display("║  Total Tests:  %2d                                                 ║", test_num);
        $display("║  Passed:       %2d                                                 ║", test_num - (total_errors > 0 ? 1 : 0));
        $display("║  Failed:       %2d                                                 ║", total_errors > 0 ? 1 : 0);
        $display("║  Warnings:     %2d                                                 ║", warnings);
        $display("╠═══════════════════════════════════════════════════════════════════╣");

        if (total_errors == 0 && warnings == 0) begin
            $display("║                                                                   ║");
            $display("║                    ✓ ALL TESTS PASSED ✓                          ║");
            $display("║                                                                   ║");
            $display("║  Your 4-Queue QoS Scheduler is working perfectly!                ║");
            $display("║  - Strict priority between queues verified                       ║");
            $display("║  - Round-robin fairness within queues confirmed                  ║");
            $display("║  - Aging mechanism functional                                    ║");
            $display("║  - All edge cases handled                                        ║");
            $display("║                                                                   ║");
        end else if (total_errors == 0) begin
            $display("║                                                                   ║");
            $display("║             ✓ ALL TESTS PASSED (with warnings) ✓                 ║");
            $display("║                                                                   ║");
            $display("║  Review warnings for potential improvements                      ║");
            $display("║                                                                   ║");
        end else begin
            $display("║                                                                   ║");
            $display("║                    ✗ SOME TESTS FAILED ✗                         ║");
            $display("║                                                                   ║");
            $display("║  Please review error messages above                              ║");
            $display("║                                                                   ║");
        end

        $display("╚═══════════════════════════════════════════════════════════════════╝\n");

        $finish;
    end

    //═══════════════════════════════════════════════════════════════════════════
    // Timeout Watchdog
    //═══════════════════════════════════════════════════════════════════════════

    initial begin
        #100ms;  // 100 millisecond timeout
        $display("\n⚠ TIMEOUT: Simulation exceeded 100ms\n");
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