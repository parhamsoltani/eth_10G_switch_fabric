`timescale 1ns / 1ps

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
    integer tests_failed;     // Number of failed tests
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
        test_errors = 0;
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
            tests_passed++;
            $display(" Test #%0d PASSED: %s", test_num, test_name);
        end else begin
            tests_failed++;
            total_errors += test_errors;
            $display(" Test #%0d FAILED: %s (%0d errors)", test_num, test_name, test_errors);
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
            $display("    ERROR [%0t] %s", $time, msg);
            $display("      Expected grant: 0x%h, Got: 0x%h", expected_grant, grant);
            test_errors++;
        end else if (grant_valid !== expected_valid) begin
            $display("    ERROR [%0t] %s", $time, msg);
            $display("      Expected valid: %b, Got: %b", expected_valid, grant_valid);
            test_errors++;
        end else begin
            $display("    [%0t] %s - grant=0x%h, valid=%b", $time, msg, grant, grant_valid);
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
            $display("    ERROR [%0t] %s", $time, msg);
            $display("      Expected valid: %b, Got: %b", expected_valid, grant_valid);
            test_errors++;
        end else if (grant_valid && ((grant & valid_grants) == 0)) begin
            $display("    ERROR [%0t] %s", $time, msg);
            $display("      Expected grant from set: 0x%h, Got: 0x%h", valid_grants, grant);
            test_errors++;
        end else begin
            $display("    [%0t] %s - grant=0x%h (from valid set 0x%h)", $time, msg, grant, valid_grants);
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

    // Get granted port index
    function automatic int get_granted_port();
        for (int i = 0; i < NUM_INPUTS; i++) begin
            if (grant[i]) return i;
        end
        return -1;
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
            3'd7: return "NETWORK_CTRL";
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

        for (int p = QOS_LEVELS-1; p >= 0; p--) begin
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

    // Test 2: Strict Priority - All 8 Levels
    task automatic test_strict_priority_all_levels();
        logic [QOS_TAG_WIDTH-1:0] pri [NUM_INPUTS];

        start_test("Strict Priority - All 8 Levels");

        $display("   Design uses 8 STRICT priority levels:");
        $display("   Priority 7 > 6 > 5 > 4 > 3 > 2 > 1 > 0");
        $display("   Higher priority ALWAYS wins (no grouping into queues)");

        // Assign each port a unique priority
        for (int i = 0; i < NUM_INPUTS; i++) begin
            pri[i] = i[2:0];  // Port 0=pri0, Port 1=pri1, ... Port 7=pri7
        end

        // Test: All ports request, highest priority should always win
        request = 8'hFF;
        apply_requests(request, pri);

        $display("\n   All 8 ports requesting with unique priorities:");
        
        // Priority 7 (port 7) should win
        check_grant(8'b1000_0000, 1'b1, "Priority 7 (port 7) wins");

        // Remove port 7, priority 6 should win
        request = 8'b0111_1111;
        apply_requests(request, pri);
        check_grant(8'b0100_0000, 1'b1, "Priority 6 (port 6) wins");

        // Remove port 6, priority 5 should win
        request = 8'b0011_1111;
        apply_requests(request, pri);
        check_grant(8'b0010_0000, 1'b1, "Priority 5 (port 5) wins");

        // Continue for remaining priorities
        request = 8'b0001_1111;
        apply_requests(request, pri);
        check_grant(8'b0001_0000, 1'b1, "Priority 4 (port 4) wins");

        request = 8'b0000_1111;
        apply_requests(request, pri);
        check_grant(8'b0000_1000, 1'b1, "Priority 3 (port 3) wins");

        request = 8'b0000_0111;
        apply_requests(request, pri);
        check_grant(8'b0000_0100, 1'b1, "Priority 2 (port 2) wins");

        request = 8'b0000_0011;
        apply_requests(request, pri);
        check_grant(8'b0000_0010, 1'b1, "Priority 1 (port 1) wins");

        request = 8'b0000_0001;
        apply_requests(request, pri);
        check_grant(8'b0000_0001, 1'b1, "Priority 0 (port 0) wins when alone");

        end_test();
    endtask

    // Test 3: Round-robin within SAME priority level
    task automatic test_round_robin_same_priority();
        logic [QOS_TAG_WIDTH-1:0] pri [NUM_INPUTS];
        logic [NUM_INPUTS-1:0] grants_seen;
        int port_grants [4];
        int unique_grants;

        start_test("Round-Robin Within SAME Priority Level");

        $display("   Ports 0-3 all at priority 5 (same level)");
        $display("   Should see fair round-robin among them");

        // All 4 ports at SAME priority level 5
        pri[0] = 3'd5;
        pri[1] = 3'd5;
        pri[2] = 3'd5;
        pri[3] = 3'd5;
        for (int i = 4; i < NUM_INPUTS; i++) pri[i] = `PRIORITY_BACKGROUND;

        // Request from inputs 0-3
        request = 8'b0000_1111;
        apply_requests(request, pri);

        grants_seen = '0;
        for (int i = 0; i < 4; i++) port_grants[i] = 0;

        // Run for 12 cycles (3 full rounds)
        for (int cycle = 0; cycle < 12; cycle++) begin
            @(posedge clk);
            #1;

            if (!grant_valid) begin
                $display("    ERROR: No grant at cycle %0d with pending requests", cycle);
                test_errors++;
                break;
            end

            if (!is_onehot(grant)) begin
                $display("    ERROR: Grant not one-hot at cycle %0d: 0x%h", cycle, grant);
                test_errors++;
                break;
            end

            grants_seen |= grant;

            // Count grants per port
            for (int i = 0; i < 4; i++) begin
                if (grant[i]) port_grants[i]++;
            end

            if (cycle < 4) begin
                $display("      Cycle %2d: grant=0x%h (port %0d)", cycle, grant, get_granted_port());
            end
        end

        // Check that all 4 ports got served
        unique_grants = $countones(grants_seen & 8'b0000_1111);
        if (unique_grants != 4) begin
            $display("    ERROR: Only %0d out of 4 ports served", unique_grants);
            test_errors++;
        end else begin
            $display("    All 4 ports served in round-robin fashion");
            $display("    Grant distribution: P0=%0d, P1=%0d, P2=%0d, P3=%0d",
                     port_grants[0], port_grants[1], port_grants[2], port_grants[3]);
        end

        end_test();
    endtask

    // Test 4: Strict priority between adjacent levels (6 vs 7)
    task automatic test_adjacent_priority_levels();
        logic [QOS_TAG_WIDTH-1:0] pri [NUM_INPUTS];
        int pri7_count, pri6_count;
        int test_cycles;

        start_test("Strict Priority Between Adjacent Levels (6 vs 7)");

        $display("   Port 0: priority 7 (highest)");
        $display("   Port 1: priority 6");
        $display("   Priority 7 should ALWAYS win (no fair sharing between levels)");

        pri[0] = 3'd7;
        pri[1] = 3'd6;
        for (int i = 2; i < NUM_INPUTS; i++) pri[i] = `PRIORITY_BACKGROUND;

        request = 8'b0000_0011;  // Ports 0,1
        apply_requests(request, pri);

        pri7_count = 0;
        pri6_count = 0;

        // Run for cycles before aging kicks in
        if (ENABLE_AGING) begin
            test_cycles = AGING_THRESHOLD - 10;
        end else begin
            test_cycles = 50;
        end

        $display("   Running for %0d cycles (before aging threshold)", test_cycles);

        for (int cycle = 0; cycle < test_cycles; cycle++) begin
            @(posedge clk);
            #1;

            if (grant_valid) begin
                if (grant[0]) pri7_count++;
                if (grant[1]) pri6_count++;
            end
        end

        $display("   Port 0 (pri 7) grants: %0d", pri7_count);
        $display("   Port 1 (pri 6) grants: %0d", pri6_count);

        // Priority 7 should get ALL grants (strict priority)
        if (pri6_count > 0) begin
            $display("    ERROR: Priority 6 got %0d grants while priority 7 was pending", pri6_count);
            test_errors++;
        end else begin
            $display("    Strict priority enforced: Priority 7 always wins");
        end

        end_test();
    endtask

    // Test 5: Mixed priorities - highest always wins
    task automatic test_mixed_priorities();
        logic [QOS_TAG_WIDTH-1:0] pri [NUM_INPUTS];
        int highest_count, other_count;
        int test_cycles;

        start_test("Mixed Priorities - Highest Always Wins");

        // Ports with various priorities
        pri[0] = 3'd7;  // Highest
        pri[1] = 3'd5;
        pri[2] = 3'd3;
        pri[3] = 3'd0;  // Lowest
        for (int i = 4; i < NUM_INPUTS; i++) pri[i] = `PRIORITY_BACKGROUND;

        request = 8'b0000_1111;  // Ports 0-3 requesting
        apply_requests(request, pri);

        highest_count = 0;
        other_count = 0;

        if (ENABLE_AGING) begin
            test_cycles = AGING_THRESHOLD - 10;
        end else begin
            test_cycles = 100;
        end

        $display("   Testing: Port 0 (pri 7) should always win over ports 1-3");
        $display("   Running for %0d cycles", test_cycles);

        for (int cycle = 0; cycle < test_cycles; cycle++) begin
            @(posedge clk);
            #1;

            if (grant_valid) begin
                if (grant[0]) begin
                    highest_count++;
                end else begin
                    other_count++;
                    if (other_count <= 3) begin
                        $display("    WARNING: Non-highest priority got grant at cycle %0d (grant=0x%h)",
                                cycle, grant);
                    end
                end
            end
        end

        $display("   Highest priority (port 0) grants: %0d", highest_count);
        $display("   Other ports grants: %0d", other_count);

        if (other_count > 0) begin
            $display("    ERROR: Lower priority ports got %0d grants while highest pending", other_count);
            test_errors++;
        end else begin
            $display("    Strict priority enforced correctly");
        end

        end_test();
    endtask

    // Test 6: Dynamic priority changes
    task automatic test_dynamic_priority_changes();
        logic [QOS_TAG_WIDTH-1:0] pri [NUM_INPUTS];

        start_test("Dynamic Priority Changes");

        for (int i = 0; i < NUM_INPUTS; i++) pri[i] = `PRIORITY_BACKGROUND;

        // Start with port 0 at priority 3, port 1 at priority 5
        pri[0] = 3'd3;
        pri[1] = 3'd5;
        request = 8'b0000_0011;
        apply_requests(request, pri);

        $display("   Phase 1: Port 0 (pri 3) vs Port 1 (pri 5)");
        check_grant(8'b0000_0010, 1'b1, "Port 1 (pri 5) wins");

        // Boost port 0 to priority 7
        $display("   Phase 2: Boost port 0 to priority 7");
        pri[0] = 3'd7;
        apply_requests(request, pri);
        check_grant(8'b0000_0001, 1'b1, "Port 0 (pri 7) now wins");

        // Lower port 0 back to priority 2
        $display("   Phase 3: Lower port 0 to priority 2");
        pri[0] = 3'd2;
        apply_requests(request, pri);
        check_grant(8'b0000_0010, 1'b1, "Port 1 (pri 5) wins again");

        // Both at same priority - should round-robin
        $display("   Phase 4: Both at priority 4 (round-robin expected)");
        pri[0] = 3'd4;
        pri[1] = 3'd4;
        apply_requests(request, pri);
        check_grant_in_set(8'b0000_0011, 1'b1, "One of equal-priority ports wins");

        end_test();
    endtask

    // Test 7: All inputs same priority - fair round-robin
    task automatic test_all_same_priority();
        logic [QOS_TAG_WIDTH-1:0] pri [NUM_INPUTS];
        logic [NUM_INPUTS-1:0] grant_history;
        int grant_count [NUM_INPUTS];

        start_test("All Inputs Same Priority - Fair Round-Robin");

        // All inputs at priority 4
        for (int i = 0; i < NUM_INPUTS; i++) begin
            pri[i] = 3'd4;
            grant_count[i] = 0;
        end

        request = {NUM_INPUTS{1'b1}};  // All requesting
        apply_requests(request, pri);

        grant_history = '0;

        $display("   Running for %0d cycles with all ports at priority 4", NUM_INPUTS * 3);

        // Run for 3 full rounds
        for (int cycle = 0; cycle < NUM_INPUTS * 3; cycle++) begin
            @(posedge clk);
            #1;

            if (!grant_valid) begin
                $display("    ERROR: No grant at cycle %0d with pending requests", cycle);
                test_errors++;
                break;
            end

            if (!is_onehot(grant)) begin
                $display("    ERROR: Grant not one-hot at cycle %0d: 0x%h", cycle, grant);
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
            $display("    ERROR: Not all ports served");
            $display("      Grant history: 0x%h (expected 0x%h)", grant_history, {NUM_INPUTS{1'b1}});
            test_errors++;
        end else begin
            $display("    All %0d ports served at least once", NUM_INPUTS);
        end

        // Check fairness
        $display("   Grant distribution:");
        for (int i = 0; i < NUM_INPUTS; i++) begin
            $display("      Port %0d: %0d grants", i, grant_count[i]);
            if (grant_count[i] < 2 || grant_count[i] > 4) begin
                $display("       WARNING: Unfair distribution for port %0d", i);
                warnings++;
            end
        end

        end_test();
    endtask

    // Test 8: Request toggling
    task automatic test_request_toggling();
        logic [QOS_TAG_WIDTH-1:0] pri [NUM_INPUTS];

        start_test("Request Toggling");

        for (int i = 0; i < NUM_INPUTS; i++) pri[i] = `PRIORITY_STANDARD;

        $display("   Toggling requests between even/odd ports for 20 cycles");

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
                    $display("    ERROR: Grant not one-hot at cycle %0d: 0x%h", cycle, grant);
                    test_errors++;
                    break;
                end

                if ((grant & request) == 0) begin
                    $display("    ERROR: Grant 0x%h doesn't match request 0x%h at cycle %0d",
                             grant, request, cycle);
                    test_errors++;
                    break;
                end
            end
        end

        if (test_errors == 0) begin
            $display("    Request toggling handled correctly");
        end

        end_test();
    endtask

    // Test 9: Aging mechanism (starvation prevention)
    task automatic test_aging_mechanism();
        logic [QOS_TAG_WIDTH-1:0] pri [NUM_INPUTS];
        int low_grant_count;
        int cycle;

        start_test("Aging Mechanism (Starvation Prevention)");

        if (!ENABLE_AGING) begin
            $display("   INFO: Aging disabled in design, skipping test");
            tests_passed++;
            return;
        end

        // Port 0: priority 7 - always requesting
        // Port 7: priority 0 - always requesting, will age out
        for (int i = 0; i < NUM_INPUTS; i++) pri[i] = `PRIORITY_BACKGROUND;
        pri[0] = 3'd7;
        pri[7] = 3'd0;

        request = 8'b1000_0001;  // Ports 0 and 7
        apply_requests(request, pri);

        low_grant_count = 0;
        cycle = 0;

        $display("   Running for %0d cycles (2x aging threshold)", AGING_THRESHOLD * 2);
        $display("   Port 0: priority 7 (highest)");
        $display("   Port 7: priority 0 (lowest)");
        $display("   Expecting port 7 to get boosted after ~%0d cycles", AGING_THRESHOLD);

        for (cycle = 0; cycle < AGING_THRESHOLD * 2; cycle++) begin
            @(posedge clk);
            #1;

            if (grant[7]) begin
                low_grant_count++;
                if (low_grant_count == 1) begin
                    $display("    Cycle %4d: Port 7 (priority 0) got grant via aging boost!", cycle);
                end
            end
        end

        if (low_grant_count > 0) begin
            $display("    Aging mechanism worked: Priority 0 port got %0d grants", low_grant_count);
        end else begin
            $display("    ERROR: Aging failed - priority 0 port starved for %0d cycles", cycle);
            test_errors++;
        end

        end_test();
    endtask

    // Test 10: Priority level boundary tests
    task automatic test_priority_boundaries();
        logic [QOS_TAG_WIDTH-1:0] pri [NUM_INPUTS];

        start_test("Priority Level Boundary Tests");

        for (int i = 0; i < NUM_INPUTS; i++) pri[i] = `PRIORITY_BACKGROUND;

        // Test each adjacent priority pair
        $display("   Testing each adjacent priority pair:");

        for (int high_pri = 7; high_pri >= 1; high_pri--) begin
            int low_pri = high_pri - 1;
            
            pri[0] = high_pri[2:0];
            pri[1] = low_pri[2:0];
            request = 8'b0000_0011;
            apply_requests(request, pri);

            @(posedge clk);
            #1;

            if (grant != 8'b0000_0001) begin
                $display("    ERROR: Priority %0d should beat priority %0d, got grant=0x%h",
                         high_pri, low_pri, grant);
                test_errors++;
            end else begin
                $display("    Priority %0d > Priority %0d: OK", high_pri, low_pri);
            end
        end

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
                pri[i] = $random % QOS_LEVELS;
            end

            apply_requests(request, pri);

            @(posedge clk);
            #1;

            if (grant_valid) begin
                grant_count++;

                // Check one-hot
                if (!is_onehot(grant)) begin
                    if (error_count == 0) begin
                        $display("    ERROR: Grant not one-hot at cycle %0d: 0x%h", cycle, grant);
                    end
                    error_count++;
                    if (error_count >= 10) break;
                end

                // Check grant matches request
                if ((grant & request) == 0) begin
                    if (error_count == 0) begin
                        $display("    ERROR: Grant 0x%h without matching request 0x%h at cycle %0d",
                                 grant, request, cycle);
                    end
                    error_count++;
                    if (error_count >= 10) break;
                end
            end else begin
                // If no grant, should be no requests
                if (request != 0) begin
                    if (error_count == 0) begin
                        $display("    ERROR: No grant despite request 0x%h at cycle %0d", request, cycle);
                    end
                    error_count++;
                    if (error_count >= 10) break;
                end
            end

            // Progress indicator
            if (cycle % 200 == 199) begin
                $display("      Progress: %0d/%0d cycles, %0d grants, %0d errors",
                         cycle+1, cycles, grant_count, error_count);
            end
        end

        test_errors += error_count;

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

        for (int i = 0; i < NUM_INPUTS; i++) pri[i] = `PRIORITY_EXCELLENT;

        request = {NUM_INPUTS{1'b1}};
        apply_requests(request, pri);

        consecutive_grants = 0;

        $display("   Testing continuous grants for 50 cycles");

        for (int cycle = 0; cycle < 50; cycle++) begin
            @(posedge clk);
            #1;

            if (!grant_valid) begin
                $display("    ERROR: No grant at cycle %0d with pending requests", cycle);
                test_errors++;
                break;
            end

            if (!is_onehot(grant)) begin
                $display("    ERROR: Grant not one-hot at cycle %0d: 0x%h", cycle, grant);
                test_errors++;
                break;
            end

            consecutive_grants++;
        end

        if (consecutive_grants == 50) begin
            $display("    Maintained continuous grants for %0d cycles", consecutive_grants);
        end

        end_test();
    endtask

    // Test 13: Edge cases
    task automatic test_edge_cases();
        logic [QOS_TAG_WIDTH-1:0] pri [NUM_INPUTS];

        start_test("Edge Cases and Boundary Conditions");

        // Edge case 1: Highest and lowest priority only
        $display("   Test 1: Extreme priority difference (7 vs 0)");
        for (int i = 0; i < NUM_INPUTS; i++) pri[i] = `PRIORITY_BACKGROUND;
        pri[0] = 3'd7;
        pri[7] = 3'd0;
        request = 8'b1000_0001;
        apply_requests(request, pri);
        check_grant(8'b0000_0001, 1'b1, "Priority 7 beats priority 0");

        // Edge case 2: Single bit request at each position
        $display("\n   Test 2: Single request at each input position");
        for (int i = 0; i < NUM_INPUTS; i++) begin
            pri[i] = 3'd4;
            request = (1 << i);
            apply_requests(request, pri);
            @(posedge clk);
            #1;

            if (grant != request) begin
                $display("    ERROR: Single request at position %0d not granted correctly", i);
                test_errors++;
            end
        end
        $display("    All single-bit positions tested");

        // Edge case 3: All requests then sudden removal
        $display("\n   Test 3: All requests then sudden removal");
        for (int i = 0; i < NUM_INPUTS; i++) pri[i] = `PRIORITY_STANDARD;
        request = {NUM_INPUTS{1'b1}};
        apply_requests(request, pri);
        wait_cycles(2);

        request = '0;
        apply_requests(request, pri);
        check_grant('0, 1'b0, "No grants after all requests removed");

        if (test_errors == 0) begin
            $display("    Edge cases handled correctly");
        end

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
        $display("║  Design: 8-Level Strict Priority Scheduler                        ║");
        $display("║                                                                   ║");
        $display("║  Parameters:                                                      ║");
        $display("║    • NUM_INPUTS:       %2d                                        ║", NUM_INPUTS);
        $display("║    • QOS_LEVELS:       %2d                                        ║", QOS_LEVELS);
        $display("║    • QOS_TAG_WIDTH:    %2d                                        ║", QOS_TAG_WIDTH);
        $display("║    • ENABLE_AGING:     %2d                                        ║", ENABLE_AGING);
        $display("║    • AGING_THRESHOLD:  %3d                                       ║", AGING_THRESHOLD);
        $display("║                                                                   ║");
        $display("║  Behavior:                                                        ║");
        $display("║    • Priority 7 > 6 > 5 > 4 > 3 > 2 > 1 > 0 (strict ordering)     ║");
        $display("║    • Round-robin fairness ONLY within SAME priority level         ║");
        $display("║    • Aging boosts starved requests to highest priority            ║");
        $display("║                                                                   ║");
        $display("╚═══════════════════════════════════════════════════════════════════╝\n");

        // Initialize
        test_num = 0;
        test_errors = 0;
        total_errors = 0;
        tests_passed = 0;
        tests_failed = 0;
        warnings = 0;
        reset_statistics();

        reset = 1;
        init_signals();
        #100;

        // Run all tests
        test_basic_single_request();           // Test 1
        test_strict_priority_all_levels();     // Test 2 - All 8 levels strict
        test_round_robin_same_priority();      // Test 3 - RR within SAME level
        test_adjacent_priority_levels();       // Test 4 - 6 vs 7 strict
        test_mixed_priorities();               // Test 5 - Multiple levels
        test_dynamic_priority_changes();       // Test 6
        test_all_same_priority();              // Test 7
        test_request_toggling();               // Test 8
        test_aging_mechanism();                // Test 9
        test_priority_boundaries();            // Test 10 - All adjacent pairs
        test_random_requests();                // Test 11
        test_back_to_back();                   // Test 12
        test_edge_cases();                     // Test 13

        // Final summary
        #100;

        $display("\n");
        $display("╔═══════════════════════════════════════════════════════════════════╗");
        $display("║                      FINAL TEST SUMMARY                           ║");
        $display("╠═══════════════════════════════════════════════════════════════════╣");
        $display("║  Total Tests:  %2d                                                 ║", test_num);
        $display("║  Passed:       %2d                                                 ║", tests_passed);
        $display("║  Failed:       %2d                                                 ║", tests_failed);
        $display("║  Warnings:     %2d                                                 ║", warnings);
        $display("╠═══════════════════════════════════════════════════════════════════╣");

        if (tests_failed == 0 && warnings == 0) begin
            $display("║                                                                   ║");
            $display("║                     ✓ ALL TESTS PASSED ✓                          ║");
            $display("║                                                                   ║");
            $display("║  Your 8-Level QoS Scheduler is working perfectly!                 ║");
            $display("║  - Strict priority between all 8 levels verified                  ║");
            $display("║  - Round-robin fairness within same level confirmed               ║");
            $display("║  - Aging mechanism functional                                     ║");
            $display("║  - All edge cases handled                                         ║");
            $display("║                                                                   ║");
        end else if (tests_failed == 0) begin
            $display("║                                                                   ║");
            $display("║              ✓ ALL TESTS PASSED (with warnings) ✓                 ║");
            $display("║                                                                   ║");
            $display("║  Review warnings for potential improvements                       ║");
            $display("║                                                                   ║");
        end else begin
            $display("║                                                                   ║");
            $display("║                     ✗ SOME TESTS FAILED ✗                         ║");
            $display("║                                                                   ║");
            $display("║  Please review error messages above                               ║");
            $display("║                                                                   ║");
        end

        $display("╚═══════════════════════════════════════════════════════════════════╝\n");

        $finish;
    end

    //═══════════════════════════════════════════════════════════════════════════
    // Timeout Watchdog
    //═══════════════════════════════════════════════════════════════════════════

    initial begin
        #100ms;
        $display("\n ERROR: TIMEOUT - Simulation exceeded 100ms\n");
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