`timescale 1ns / 1ps
`include "fabric_params.vh"
`include "qos_defines.vh"

module tb_qos_manager_integration;

    //═══════════════════════════════════════════════════════════════════════════
    // Parameters
    //═══════════════════════════════════════════════════════════════════════════

    parameter NUM_INPUTS = 8;
    parameter DATA_WIDTH = 512;
    parameter QOS_TAG_WIDTH = `QOS_TAG_WIDTH;
    parameter QOS_LEVELS = `QOS_LEVELS;
    parameter ENABLE_AGING = 1;
    parameter AGING_THRESHOLD = 50;
    parameter CLK_PERIOD = 10;  // 100 MHz

    //═══════════════════════════════════════════════════════════════════════════
    // Signals
    //═══════════════════════════════════════════════════════════════════════════

    // Clock and reset
    logic clk;
    logic rst_n;

    // Packet header inputs
    logic [15:0] ethertype [NUM_INPUTS];
    logic [2:0]  vlan_pcp [NUM_INPUTS];
    logic [7:0]  ip_tos [NUM_INPUTS];
    logic [15:0] tcp_src_port [NUM_INPUTS];
    logic [15:0] tcp_dst_port [NUM_INPUTS];

    // Classification controls
    logic use_vlan_pcp;
    logic use_ip_dscp;
    logic use_port_classify;

    // Scheduling interface
    logic [NUM_INPUTS-1:0] request;
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
    integer classifier_hits [QOS_LEVELS];

    //═══════════════════════════════════════════════════════════════════════════
    // Internal Signals (QoS tags from classifiers)
    //═══════════════════════════════════════════════════════════════════════════

    logic [QOS_TAG_WIDTH-1:0] qos_tag [NUM_INPUTS];

    //═══════════════════════════════════════════════════════════════════════════
    // DUT: Multiple Classifiers + QoS Scheduler
    //═══════════════════════════════════════════════════════════════════════════

    // Generate classifiers for each input
    genvar i;
    generate
        for (i = 0; i < NUM_INPUTS; i++) begin : gen_classifiers
            qos_classifier #(
                .QOS_TAG_WIDTH(QOS_TAG_WIDTH),
                .DATA_WIDTH(DATA_WIDTH)
            ) classifier (
                .clk(clk),
                .rst_n(rst_n),
                .ethertype(ethertype[i]),
                .vlan_pcp(vlan_pcp[i]),
                .ip_tos(ip_tos[i]),
                .tcp_src_port(tcp_src_port[i]),
                .tcp_dst_port(tcp_dst_port[i]),
                .use_vlan_pcp(use_vlan_pcp),
                .use_ip_dscp(use_ip_dscp),
                .use_port_classify(use_port_classify),
                .qos_tag(qos_tag[i])
            );
        end
    endgenerate

    // QoS Scheduler
    qos_scheduler #(
        .NUM_INPUTS(NUM_INPUTS),
        .QOS_LEVELS(QOS_LEVELS),
        .QOS_TAG_WIDTH(QOS_TAG_WIDTH),
        .ENABLE_AGING(ENABLE_AGING),
        .AGING_THRESHOLD(AGING_THRESHOLD)
    ) scheduler (
        .clk(clk),
        .reset(~rst_n),
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

    // Initialize all signals
    task automatic init_signals();
        request = '0;
        use_vlan_pcp = 0;
        use_ip_dscp = 1;  // Default: DSCP-based
        use_port_classify = 0;

        for (int j = 0; j < NUM_INPUTS; j++) begin
            ethertype[j] = 16'h0800;  // IPv4
            vlan_pcp[j] = 3'b000;
            ip_tos[j] = 8'h00;
            tcp_src_port[j] = 16'd0;
            tcp_dst_port[j] = 16'd0;
        end
    endtask

    // Reset DUT
    task automatic reset_dut();
        rst_n = 0;
        init_signals();
        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);
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
            $display(" Test #%0d PASSED: %s", test_num, test_name);
        end else begin
            $display(" Test #%0d FAILED: %s (%0d errors)", test_num, test_name, errors);
        end
        $display("");
    endtask

    // Set packet classification for an input
    task automatic set_packet_class(
        input int idx,
        input logic [QOS_TAG_WIDTH-1:0] priority_type,
        input string method = "dscp"
    );
        case (method)
            "dscp": begin
                // Map priority to DSCP value
                case (priority_type)
                    `PRIORITY_NETWORK_CONTROL: ip_tos[idx] = {6'd48, 2'b00};  // CS6
                    `PRIORITY_VOICE:           ip_tos[idx] = {6'd46, 2'b00};  // EF
                    `PRIORITY_VIDEO:           ip_tos[idx] = {6'd34, 2'b00};  // AF41
                    `PRIORITY_CRITICAL:        ip_tos[idx] = {6'd26, 2'b00};  // AF31
                    `PRIORITY_EXCELLENT:       ip_tos[idx] = {6'd18, 2'b00};  // AF21
                    `PRIORITY_STANDARD:        ip_tos[idx] = {6'd10, 2'b00};  // AF11
                    `PRIORITY_BULK:            ip_tos[idx] = {6'd2, 2'b00};   // CS1
                    default:                   ip_tos[idx] = {6'd0, 2'b00};   // BE
                endcase
            end

            "vlan": begin
                // Map priority to VLAN PCP
                vlan_pcp[idx] = priority_type[2:0];
            end

            "port": begin
                // Map priority to well-known ports
                case (priority_type)
                    `PRIORITY_VOICE, `PRIORITY_VIDEO: tcp_src_port[idx] = 16'd5060;  // SIP
                    `PRIORITY_CRITICAL: tcp_src_port[idx] = 16'd22;    // SSH
                    default:            tcp_src_port[idx] = 16'd80;    // HTTP
                endcase
            end
        endcase
    endtask

    // Apply requests
    task automatic apply_requests(input logic [NUM_INPUTS-1:0] req_vec);
        request = req_vec;
        @(posedge clk);
    endtask

    // Wait cycles
    task automatic wait_cycles(input integer cycles);
        repeat(cycles) @(posedge clk);
    endtask

    //═══════════════════════════════════════════════════════════════════════════
    // Statistics Collection
    //═══════════════════════════════════════════════════════════════════════════

    always @(posedge clk) begin
        if (rst_n) begin
            total_cycles++;

            // Track grants by input
            if (grant_valid) begin
                for (int j = 0; j < NUM_INPUTS; j++) begin
                    if (grant[j]) begin
                        total_grants[j]++;
                        if (qos_tag[j] < QOS_LEVELS) begin
                            priority_grants[qos_tag[j]]++;
                        end
                    end
                end
            end

            // Track classification distribution
            for (int j = 0; j < NUM_INPUTS; j++) begin
                if (request[j] && qos_tag[j] < QOS_LEVELS) begin
                    classifier_hits[qos_tag[j]]++;
                end
            end
        end
    end

    // Print statistics
    task automatic print_statistics();
        real avg_grant, avg_class;

        $display("\n╔═══════════════════════════════════════════════════════════════════╗");
        $display("║ INTEGRATION STATISTICS                                            ║");
        $display("╠═══════════════════════════════════════════════════════════════════╣");
        $display("║ Total Cycles: %-51d ║", total_cycles);
        $display("╠═══════════════════════════════════════════════════════════════════╣");
        $display("║ Grants by Input:                                                  ║");

        for (int j = 0; j < NUM_INPUTS; j++) begin
            if (total_cycles > 0) begin
                avg_grant = (real'(total_grants[j]) / real'(total_cycles)) * 100.0;
                $display("║   Input[%0d]: %5d grants (%5.2f%%)                                 ║",
                         j, total_grants[j], avg_grant);
            end
        end

        $display("╠═══════════════════════════════════════════════════════════════════╣");
        $display("║ Grants by Priority Level:                                         ║");

        for (int p = 0; p < QOS_LEVELS; p++) begin
            if (total_cycles > 0) begin
                avg_grant = (real'(priority_grants[p]) / real'(total_cycles)) * 100.0;
                $display("║   Priority[%0d]: %5d grants (%5.2f%%)                             ║",
                         p, priority_grants[p], avg_grant);
            end
        end

        $display("╠═══════════════════════════════════════════════════════════════════╣");
        $display("║ Classification Distribution:                                      ║");

        for (int p = 0; p < QOS_LEVELS; p++) begin
            if (total_cycles > 0) begin
                avg_class = (real'(classifier_hits[p]) / real'(total_cycles)) * 100.0;
                $display("║   Priority[%0d]: %5d classifications (%5.2f%%)                    ║",
                         p, classifier_hits[p], avg_class);
            end
        end

        $display("╚═══════════════════════════════════════════════════════════════════╝\n");
    endtask

    // Reset statistics
    task automatic reset_statistics();
        for (int j = 0; j < NUM_INPUTS; j++) total_grants[j] = 0;
        for (int p = 0; p < QOS_LEVELS; p++) begin
            priority_grants[p] = 0;
            classifier_hits[p] = 0;
        end
        total_cycles = 0;
    endtask

    //═══════════════════════════════════════════════════════════════════════════
    // Test Cases
    //═══════════════════════════════════════════════════════════════════════════

    // Test 1: End-to-end DSCP-based QoS
    task automatic test_e2e_dscp_qos();
        start_test("End-to-End DSCP-based QoS");

        use_ip_dscp = 1;
        use_vlan_pcp = 0;
        use_port_classify = 0;

        // Setup: Mix of priorities
        set_packet_class(0, `PRIORITY_NETWORK_CONTROL, "dscp");  // Highest
        set_packet_class(1, `PRIORITY_VOICE, "dscp");
        set_packet_class(2, `PRIORITY_VIDEO, "dscp");
        set_packet_class(3, `PRIORITY_BACKGROUND, "dscp");       // Lowest

        // All request simultaneously
        request = 8'b0000_1111;
        wait_cycles(2);

        // Verify highest priority wins
        @(posedge clk);
        #1;
        if (!grant[0]) begin
            $display("   ERROR: Network Control (highest) not granted first");
            $display("    Grant: %b, QoS tags: %0d %0d %0d %0d",
                     grant, qos_tag[0], qos_tag[1], qos_tag[2], qos_tag[3]);
            errors++;
        end else begin
            $display("   Network Control (priority 7) granted correctly");
        end

        // Remove highest, verify next wins
        request = 8'b0000_1110;
        wait_cycles(2);

        @(posedge clk);
        #1;
        if (!grant[1]) begin
            $display("   ERROR: Voice (next highest) not granted");
            errors++;
        end else begin
            $display("   Voice (priority 6) granted correctly");
        end

        end_test();
    endtask

    // Test 2: Mixed classification methods
    task automatic test_mixed_classification();
        start_test("Mixed Classification Methods");

        // Enable all methods (VLAN > DSCP > Port priority)
        use_vlan_pcp = 1;
        use_ip_dscp = 1;
        use_port_classify = 1;

        // Input 0: VLAN PCP 7 (should win)
        vlan_pcp[0] = 3'b111;           // HIGH
        ip_tos[0] = {6'd0, 2'b00};      // LOW DSCP
        tcp_src_port[0] = 16'd80;       // LOW port

        // Input 1: DSCP only (medium)
        vlan_pcp[1] = 3'b000;
        ip_tos[1] = {6'd26, 2'b00};     // AF31 (medium)
        tcp_src_port[1] = 16'd80;

        // Input 2: Port only (low)
        vlan_pcp[2] = 3'b000;
        ip_tos[2] = {6'd0, 2'b00};
        tcp_src_port[2] = 16'd80;       // HTTP

        request = 8'b0000_0111;
        wait_cycles(3);

        @(posedge clk);
        #1;

        // VLAN should win (highest priority method)
        if (!grant[0]) begin
            $display("   ERROR: VLAN classification didn't take priority");
            $display("    QoS: [0]=%0d [1]=%0d [2]=%0d", qos_tag[0], qos_tag[1], qos_tag[2]);
            errors++;
        end else begin
            $display("   VLAN PCP 7 correctly prioritized over DSCP and port");
        end

        end_test();
    endtask

    // Test 3: Round-robin fairness within priority
    task automatic test_rr_fairness();
        start_test("Round-Robin Fairness Within Priority");

        reset_statistics();
        use_ip_dscp = 1;
        use_vlan_pcp = 0;
        use_port_classify = 0;

        // All inputs at same priority
        for (int j = 0; j < 4; j++) begin
            set_packet_class(j, `PRIORITY_STANDARD, "dscp");
        end

        request = 8'b0000_1111;
        wait_cycles(100);  // Run for 100 cycles

        // Check fairness (each should get ~25 grants)
        int min_grants = 1000, max_grants = 0;
        for (int j = 0; j < 4; j++) begin
            if (total_grants[j] < min_grants) min_grants = total_grants[j];
            if (total_grants[j] > max_grants) max_grants = total_grants[j];
        end

        real fairness_ratio = real'(max_grants) / real'(min_grants);

        if (fairness_ratio > 2.0) begin
            $display("   ERROR: Unfair scheduling detected");
            $display("    Grant distribution: %0d %0d %0d %0d",
                     total_grants[0], total_grants[1], total_grants[2], total_grants[3]);
            errors++;
        end else begin
            $display("   Fair round-robin scheduling (ratio: %.2f)", fairness_ratio);
        end

        end_test();
    endtask

    // Test 4: Priority inversion prevention
    task automatic test_priority_inversion();
        start_test("Priority Inversion Prevention");

        use_ip_dscp = 1;
        use_vlan_pcp = 0;
        use_port_classify = 0;

        // Low priority constantly requesting
        set_packet_class(7, `PRIORITY_BACKGROUND, "dscp");
        request[7] = 1'b1;

        wait_cycles(10);

        // High priority arrives
        set_packet_class(0, `PRIORITY_NETWORK_CONTROL, "dscp");
        request[0] = 1'b1;

        // Next cycle should grant high priority
        @(posedge clk);
        #1;

        if (!grant[0]) begin
            $display("   ERROR: Priority inversion - low priority served over high");
            errors++;
        end else begin
            $display("   High priority correctly preempted low priority");
        end

        end_test();
    endtask

    // Test 5: Dynamic priority changes
    task automatic test_dynamic_priority();
        start_test("Dynamic Priority Changes");

        use_ip_dscp = 1;

        // Start: Input 0 is high, Input 1 is low
        set_packet_class(0, `PRIORITY_VOICE, "dscp");
        set_packet_class(1, `PRIORITY_BACKGROUND, "dscp");
        request = 8'b0000_0011;

        wait_cycles(5);

        // Swap priorities
        set_packet_class(0, `PRIORITY_BACKGROUND, "dscp");
        set_packet_class(1, `PRIORITY_VOICE, "dscp");

        wait_cycles(3);

        @(posedge clk);
        #1;

        // Should now serve input 1
        if (!grant[1]) begin
            $display("   ERROR: Dynamic priority change not reflected");
            $display("    QoS: [0]=%0d [1]=%0d", qos_tag[0], qos_tag[1]);
            errors++;
        end else begin
            $display("   Dynamic priority change handled correctly");
        end

        end_test();
    endtask

    // Test 6: Aging mechanism integration
    task automatic test_aging_integration();
        start_test("Aging Mechanism Integration");

        if (!ENABLE_AGING) begin
            $display("  ⓘ Aging disabled, skipping test");
            end_test();
            return;
        end

        use_ip_dscp = 1;

        // High priority continuously requesting
        set_packet_class(0, `PRIORITY_NETWORK_CONTROL, "dscp");
        request[0] = 1'b1;

        // Low priority also requesting (will age)
        set_packet_class(7, `PRIORITY_BACKGROUND, "dscp");
        request[7] = 1'b1;

        int low_grant_count = 0;

        // Run past aging threshold
        for (int cycle = 0; cycle < AGING_THRESHOLD * 3; cycle++) begin
            @(posedge clk);
            #1;
            if (grant[7]) low_grant_count++;
        end

        if (low_grant_count == 0) begin
            $display("   ERROR: Aging failed - low priority starved");
            errors++;
        end else begin
            $display("   Aging prevented starvation (%0d grants to low priority)", low_grant_count);
        end

        end_test();
    endtask

    // Test 7: Stress test - random traffic
    task automatic test_random_traffic();
        start_test("Stress Test - Random Traffic Mix");

        reset_statistics();
        use_ip_dscp = 1;
        use_vlan_pcp = 0;
        use_port_classify = 0;

        int cycles = 500;

        for (int cycle = 0; cycle < cycles; cycle++) begin
            // Randomize requests
            request = $random;

            // Randomize priorities
            for (int j = 0; j < NUM_INPUTS; j++) begin
                int rand_pri = $random % QOS_LEVELS;
                set_packet_class(j, rand_pri, "dscp");
            end

            @(posedge clk);
            #1;

            // Verify grant properties
            if (grant_valid) begin
                int grant_count = $countones(grant);
                if (grant_count != 1) begin
                    $display("   ERROR: Grant not one-hot at cycle %0d", cycle);
                    errors++;
                    break;
                end

                if ((grant & request) == 0) begin
                    $display("   ERROR: Grant without request at cycle %0d", cycle);
                    errors++;
                    break;
                end
            end
        end

        $display("   Random stress test completed: %0d cycles", cycles);
        print_statistics();

        end_test();
    endtask

    // Test 8: All priority levels
    task automatic test_all_priority_levels();
        start_test("All 8 Priority Levels");

        use_ip_dscp = 1;

        // Assign each input a different priority
        for (int j = 0; j < QOS_LEVELS; j++) begin
            set_packet_class(j, j[QOS_TAG_WIDTH-1:0], "dscp");
        end

        request = 8'b1111_1111;
        wait_cycles(2);

        // Verify they're served in priority order (7 down to 0)
        for (int expected_pri = QOS_LEVELS-1; expected_pri >= 0; expected_pri--) begin
            @(posedge clk);
            #1;

            if (!grant_valid) begin
                $display("   ERROR: No grant for priority %0d", expected_pri);
                errors++;
                break;
            end

            // Find which input got the grant
            int granted_input = -1;
            for (int j = 0; j < NUM_INPUTS; j++) begin
                if (grant[j]) granted_input = j;
            end

            if (granted_input == -1) begin
                $display("   ERROR: Invalid grant state");
                errors++;
                break;
            end

            if (qos_tag[granted_input] != expected_pri) begin
                $display("   ERROR: Expected priority %0d, got %0d",
                         expected_pri, qos_tag[granted_input]);
                errors++;
            end else begin
                $display("   Priority %0d served correctly", expected_pri);
            end

            // Remove this request
            request[granted_input] = 1'b0;
        end

        end_test();
    endtask

    // Test 9: Bursty traffic patterns
    task automatic test_bursty_traffic();
        start_test("Bursty Traffic Patterns");

        use_ip_dscp = 1;

        // High priority bursts
        set_packet_class(0, `PRIORITY_VOICE, "dscp");
        set_packet_class(1, `PRIORITY_VIDEO, "dscp");

        // Background constant
        set_packet_class(7, `PRIORITY_BACKGROUND, "dscp");
        request[7] = 1'b1;

        // Burst pattern
        for (int burst = 0; burst < 5; burst++) begin
            // Burst on
            request[0] = 1'b1;
            request[1] = 1'b1;
            wait_cycles(10);

            // Burst off
            request[0] = 1'b0;
            request[1] = 1'b0;
            wait_cycles(20);
        end

        // Verify background got service during idle periods
        if (total_grants[7] == 0) begin
            $display("   ERROR: Background never served during bursts");
            errors++;
        end else begin
            $display("   Bursty traffic handled correctly (%0d background grants)",
                     total_grants[7]);
        end

        end_test();
    endtask

    // Test 10: Full system integration
    task automatic test_full_integration();
        start_test("Full System Integration Test");

        reset_statistics();

        // Realistic traffic mix
        use_ip_dscp = 1;
        use_vlan_pcp = 0;
        use_port_classify = 1;

        // VoIP (high priority, bursty)
        set_packet_class(0, `PRIORITY_VOICE, "port");
        set_packet_class(1, `PRIORITY_VOICE, "port");

        // Video (medium-high priority, steady)
        set_packet_class(2, `PRIORITY_VIDEO, "dscp");
        set_packet_class(3, `PRIORITY_VIDEO, "dscp");

        // Best effort (bulk)
        set_packet_class(4, `PRIORITY_BULK, "dscp");
        set_packet_class(5, `PRIORITY_BULK, "dscp");
        set_packet_class(6, `PRIORITY_BULK, "dscp");
        set_packet_class(7, `PRIORITY_BULK, "dscp");

        // Run realistic pattern
        for (int time_slot = 0; time_slot < 200; time_slot++) begin
            // VoIP bursts every 20 cycles
            if (time_slot % 20 == 0) begin
                request[0] = 1'b1;
                request[1] = 1'b1;
            end else if (time_slot % 20 == 5) begin
                request[0] = 1'b0;
                request[1] = 1'b0;
            end

            // Video constant
            request[2] = 1'b1;
            request[3] = 1'b1;

            // Bulk always requesting
            request[7:4] = 4'b1111;

            @(posedge clk);
        end

        // Verify QoS guarantees
        real voice_bw = real'(priority_grants[`PRIORITY_VOICE]) / real'(total_cycles);
        real video_bw = real'(priority_grants[`PRIORITY_VIDEO]) / real'(total_cycles);
        real bulk_bw = real'(priority_grants[`PRIORITY_BULK]) / real'(total_cycles);

        $display("  Bandwidth allocation:");
        $display("    Voice: %.1f%%", voice_bw * 100.0);
        $display("    Video: %.1f%%", video_bw * 100.0);
        $display("    Bulk:  %.1f%%", bulk_bw * 100.0);

        // Voice should get priority when active
        if (voice_bw < 0.05) begin  // Should get ~5-10% when bursty
            $display("  WARNING: Voice priority may be too low");
            warnings++;
        end

        print_statistics();

        end_test();
    endtask

    //═══════════════════════════════════════════════════════════════════════════
    // Main Test Sequence
    //═══════════════════════════════════════════════════════════════════════════

    initial begin
        $timeformat(-9, 2, " ns", 10);

        $display("\n");
        $display("╔═══════════════════════════════════════════════════════════════════╗");
        $display("║                                                                   ║");
        $display("║          QoS MANAGER INTEGRATION TESTBENCH                        ║");
        $display("║          =================================                        ║");
        $display("║                                                                   ║");
        $display("║  Full system test: Classifier + Scheduler integration            ║");
        $display("║                                                                   ║");
        $display("║  Parameters:                                                      ║");
        $display("║    - NUM_INPUTS:      %2d                                         ║", NUM_INPUTS);
        $display("║    - QOS_LEVELS:      %2d                                         ║", QOS_LEVELS);
        $display("║    - ENABLE_AGING:    %2d                                         ║", ENABLE_AGING);
        $display("║    - AGING_THRESHOLD: %3d                                        ║", AGING_THRESHOLD);
        $display("║                                                                   ║");
        $display("╚═══════════════════════════════════════════════════════════════════╝\n");

        // Initialize
        test_num = 0;
        errors = 0;
        warnings = 0;
        reset_statistics();

        rst_n = 0;
        init_signals();
        #100;

        // Run all tests
        test_e2e_dscp_qos();
        test_mixed_classification();
        test_rr_fairness();
        test_priority_inversion();
        test_dynamic_priority();
        test_aging_integration();
        test_random_traffic();
        test_all_priority_levels();
        test_bursty_traffic();
        test_full_integration();

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
            $display("║               ALL INTEGRATION TESTS PASSED                 ║");
            $display("║                                                                   ║");
        end else if (errors == 0) begin
            $display("║                                                                   ║");
            $display("║         ALL TESTS PASSED (with %2d warnings)                      ║", warnings);
            $display("║                                                                   ║");
        end else begin
            $display("║                                                                   ║");
            $display("║                    SOME TESTS FAILED                       ║");
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
        $display("\n TIMEOUT: Simulation exceeded 100ms \n");
        $finish;
    end

    //═══════════════════════════════════════════════════════════════════════════
    // Waveform Dumping
    //═══════════════════════════════════════════════════════════════════════════

    initial begin
        $dumpfile("tb_qos_manager_integration.vcd");
        $dumpvars(0, tb_qos_manager_integration);
    end

endmodule