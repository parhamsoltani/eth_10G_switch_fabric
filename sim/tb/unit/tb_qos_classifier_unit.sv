`timescale 1ns / 1ps
`include "fabric_params.vh"
`include "qos_defines.vh"

module tb_qos_classifier_unit;

    //═══════════════════════════════════════════════════════════════════════════
    // Parameters
    //═══════════════════════════════════════════════════════════════════════════

    parameter QOS_TAG_WIDTH = `QOS_TAG_WIDTH;
    parameter DATA_WIDTH = 512;
    parameter CLK_PERIOD = 10;

    //═══════════════════════════════════════════════════════════════════════════
    // Signals
    //═══════════════════════════════════════════════════════════════════════════

    logic clk;
    logic rst_n;

    // Packet header inputs
    logic [15:0] ethertype;
    logic [2:0]  vlan_pcp;
    logic [7:0]  ip_tos;
    logic [15:0] tcp_src_port;
    logic [15:0] tcp_dst_port;

    // Classification controls
    logic use_vlan_pcp;
    logic use_ip_dscp;
    logic use_port_classify;

    // Output
    logic [QOS_TAG_WIDTH-1:0] qos_tag;

    // Test control
    integer errors;
    integer warnings;
    integer test_num;
    string test_name;

    //═══════════════════════════════════════════════════════════════════════════
    // DUT Instantiation
    //═══════════════════════════════════════════════════════════════════════════

    qos_classifier #(
        .QOS_TAG_WIDTH(QOS_TAG_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .ethertype(ethertype),
        .vlan_pcp(vlan_pcp),
        .ip_tos(ip_tos),
        .tcp_src_port(tcp_src_port),
        .tcp_dst_port(tcp_dst_port),
        .use_vlan_pcp(use_vlan_pcp),
        .use_ip_dscp(use_ip_dscp),
        .use_port_classify(use_port_classify),
        .qos_tag(qos_tag)
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

    task automatic start_test(string name);
        test_num++;
        test_name = name;
        $display("\n╔═══════════════════════════════════════════════════════════════╗");
        $display("║ Test #%0d: %-56s ║", test_num, name);
        $display("╚═══════════════════════════════════════════════════════════════╝");
    endtask

    task automatic end_test();
        $display("");
    endtask

    task automatic init_signals();
        ethertype = 16'h0800;
        vlan_pcp = 3'b000;
        ip_tos = 8'h00;
        tcp_src_port = 16'd0;
        tcp_dst_port = 16'd0;
        use_vlan_pcp = 0;
        use_ip_dscp = 0;
        use_port_classify = 0;
    endtask

    task automatic reset_dut();
        rst_n = 0;
        init_signals();
        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(2) @(posedge clk);
    endtask

    task automatic check_qos(
        input logic [QOS_TAG_WIDTH-1:0] expected_qos,
        input string description
    );
        logic [QOS_TAG_WIDTH-1:0] actual_qos;

        @(posedge clk);
        #1;
        actual_qos = qos_tag;

        if (actual_qos == expected_qos) begin
            $display("  ✓ PASS: %s (QoS=%0d)", description, actual_qos);
        end else begin
            $display("  ✗ ERROR: %s", description);
            $display("    Expected QoS: %0d, Got: %0d", expected_qos, actual_qos);
            errors++;
        end
    endtask

    //═══════════════════════════════════════════════════════════════════════════
    // Test Cases
    //═══════════════════════════════════════════════════════════════════════════

    task automatic test_dscp_classification();
        start_test("DSCP-based QoS Classification");

        use_ip_dscp = 1;
        use_vlan_pcp = 0;
        use_port_classify = 0;

        // EF (Expedited Forwarding) - Voice
        ip_tos = {6'd46, 2'b00};
        check_qos(`PRIORITY_VOICE, "DSCP 46 (EF) → VOICE priority");

        // AF41 - Video
        ip_tos = {6'd34, 2'b00};
        check_qos(`PRIORITY_VIDEO, "DSCP 34 (AF41) → VIDEO priority");

        // AF31 - Critical
        ip_tos = {6'd26, 2'b00};
        check_qos(`PRIORITY_CRITICAL, "DSCP 26 (AF31) → CRITICAL priority");

        // CS0 - Best Effort / Background
        ip_tos = {6'd0, 2'b00};
        check_qos(`PRIORITY_BACKGROUND, "DSCP 0 (CS0/BE) → BACKGROUND priority");

        // CS6 - Network Control
        ip_tos = {6'd48, 2'b00};
        check_qos(`PRIORITY_NETWORK_CONTROL, "DSCP 48 (CS6) → NETWORK_CONTROL priority");

        end_test();
    endtask

    task automatic test_vlan_pcp_classification();
        start_test("VLAN PCP-based QoS Classification (802.1p)");

        use_vlan_pcp = 1;
        use_ip_dscp = 0;
        use_port_classify = 0;

        // PCP 0 - Background
        vlan_pcp = 3'b000;
        check_qos(`PRIORITY_BACKGROUND, "VLAN PCP 0 → BACKGROUND priority");

        // PCP 1 - Background
        vlan_pcp = 3'b001;
        check_qos(`PRIORITY_BACKGROUND, "VLAN PCP 1 → BACKGROUND priority");

        // PCP 2 - Excellent Effort
        vlan_pcp = 3'b010;
        check_qos(`PRIORITY_EXCELLENT, "VLAN PCP 2 → EXCELLENT priority");

        // PCP 3 - Critical Applications
        vlan_pcp = 3'b011;
        check_qos(`PRIORITY_CRITICAL, "VLAN PCP 3 → CRITICAL priority");

        // PCP 7 - Network Control
        vlan_pcp = 3'b111;
        check_qos(`PRIORITY_NETWORK_CONTROL, "VLAN PCP 7 (NC) → NETWORK_CONTROL priority");

        // PCP 6 - Voice
        vlan_pcp = 3'b110;
        check_qos(`PRIORITY_VOICE, "VLAN PCP 6 (VO) → VOICE priority");

        end_test();
    endtask

    task automatic test_port_classification();
        start_test("Port-based QoS Classification");

        use_port_classify = 1;
        use_ip_dscp = 0;
        use_vlan_pcp = 0;

        // SIP - Voice
        tcp_src_port = 16'd5060;
        tcp_dst_port = 16'd0;
        check_qos(`PRIORITY_VOICE, "SIP port 5060 → VOICE priority");

        // RTP - Voice
        tcp_src_port = 16'd20000;
        check_qos(`PRIORITY_VOICE, "RTP port 20000 → VOICE priority");

        tcp_src_port = 16'd16384;
        check_qos(`PRIORITY_VOICE, "RTP port 16384 (min) → VOICE priority");

        tcp_src_port = 16'd32767;
        check_qos(`PRIORITY_VOICE, "RTP port 32767 (max) → VOICE priority");

        // SSH - Critical
        tcp_src_port = 16'd22;
        check_qos(`PRIORITY_CRITICAL, "SSH port 22 → CRITICAL priority");

        // Telnet - Excellent
        tcp_src_port = 16'd23;
        check_qos(`PRIORITY_EXCELLENT, "Telnet port 23 → EXCELLENT priority");

        // HTTP - Standard
        tcp_src_port = 16'd80;
        check_qos(`PRIORITY_STANDARD, "HTTP port 80 → STANDARD priority");

        end_test();
    endtask

    task automatic test_priority_selection();
        start_test("Classification Priority Selection");

        // VLAN PCP should override everything
        use_vlan_pcp = 1;
        use_ip_dscp = 1;
        use_port_classify = 1;

        vlan_pcp = 3'b111;          // Network Control
        ip_tos = {6'd0, 2'b00};     // Best Effort
        tcp_src_port = 16'd80;      // HTTP
        check_qos(`PRIORITY_NETWORK_CONTROL, "VLAN PCP 7 overrides DSCP 0 and HTTP port");

        // DSCP should override port
        use_vlan_pcp = 0;
        use_ip_dscp = 1;
        use_port_classify = 1;

        ip_tos = {6'd46, 2'b00};    // EF (Voice)
        tcp_src_port = 16'd80;      // HTTP
        check_qos(`PRIORITY_VOICE, "DSCP 46 (EF) overrides HTTP port");

        // Port-only
        use_vlan_pcp = 0;
        use_ip_dscp = 0;
        use_port_classify = 1;

        tcp_src_port = 16'd5060;    // SIP
        check_qos(`PRIORITY_VOICE, "Port-only: SIP → VOICE priority");

        // All disabled - should default to STANDARD
        use_vlan_pcp = 0;
        use_ip_dscp = 0;
        use_port_classify = 0;
        check_qos(`PRIORITY_STANDARD, "All disabled → default STANDARD priority");

        end_test();
    endtask

    task automatic test_dynamic_changes();
        start_test("Dynamic Classification Changes");

        use_ip_dscp = 1;
        use_vlan_pcp = 0;
        use_port_classify = 0;

        // Start with high priority
        ip_tos = {6'd46, 2'b00};
        check_qos(`PRIORITY_VOICE, "Initial: DSCP 46 → VOICE");

        // Change to low priority
        ip_tos = {6'd0, 2'b00};
        check_qos(`PRIORITY_BACKGROUND, "Dynamic change: DSCP 0 → BACKGROUND");

        // Change to medium priority
        ip_tos = {6'd26, 2'b00};
        check_qos(`PRIORITY_CRITICAL, "Dynamic change: DSCP 26 → CRITICAL");

        end_test();
    endtask

    task automatic test_edge_cases();
        start_test("Edge Cases and Boundary Conditions");

        use_ip_dscp = 1;
        use_vlan_pcp = 0;
        use_port_classify = 0;

        // Max DSCP value
        ip_tos = {6'd63, 2'b00};
        check_qos(`PRIORITY_STANDARD, "Max DSCP (63) → STANDARD priority (default for unknown)");

        // Port boundary tests
        use_ip_dscp = 0;
        use_port_classify = 1;

        tcp_src_port = 16'd16383;  // Just below RTP range
        check_qos(`PRIORITY_BACKGROUND, "Port 16383 (below RTP) → BACKGROUND priority");

        tcp_src_port = 16'd32768;  // Just above RTP range
        check_qos(`PRIORITY_BACKGROUND, "Port 32768 (above RTP) → BACKGROUND priority");

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
        $display("║          QoS CLASSIFIER UNIT TESTBENCH                            ║");
        $display("║          =============================                            ║");
        $display("║                                                                   ║");
        $display("║  Multi-field classification with RFC 2474 DSCP and 802.1p PCP    ║");
        $display("║                                                                   ║");
        $display("║  Priority Levels (8-level system):                               ║");
        $display("║    0 = BACKGROUND (lowest)                                        ║");
        $display("║    1 = BEST_EFFORT                                                ║");
        $display("║    2 = STANDARD                                                   ║");
        $display("║    3 = EXCELLENT                                                  ║");
        $display("║    4 = CRITICAL                                                   ║");
        $display("║    5 = VIDEO                                                      ║");
        $display("║    6 = VOICE                                                      ║");
        $display("║    7 = NETWORK_CONTROL (highest)                                  ║");
        $display("║                                                                   ║");
        $display("╚═══════════════════════════════════════════════════════════════════╝\n");

        test_num = 0;
        errors = 0;
        warnings = 0;

        reset_dut();

        test_dscp_classification();
        test_vlan_pcp_classification();
        test_port_classification();
        test_priority_selection();
        test_dynamic_changes();
        test_edge_cases();

        #100;

        $display("\n");
        $display("╔═══════════════════════════════════════════════════════════════════╗");
        $display("║                      TEST SUMMARY                                 ║");
        $display("╠═══════════════════════════════════════════════════════════════════╣");
        $display("║  Total Tests: %2d                                                  ║", test_num);
        $display("║  Errors:      %2d                                                  ║", errors);
        $display("║  Warnings:    %2d                                                  ║", warnings);
        $display("╠═══════════════════════════════════════════════════════════════════╣");

        if (errors == 0 && warnings == 0) begin
            $display("║                                                                   ║");
            $display("║              ✓✓✓ ALL TESTS PASSED ✓✓✓                            ║");
            $display("║                                                                   ║");
        end else if (errors == 0) begin
            $display("║                                                                   ║");
            $display("║         ALL TESTS PASSED (with %2d warnings)                      ║", warnings);
            $display("║                                                                   ║");
        end else begin
            $display("║                                                                   ║");
            $display("║                    ✗✗✗ TESTS FAILED ✗✗✗                          ║");
            $display("║                                                                   ║");
        end

        $display("╚═══════════════════════════════════════════════════════════════════╝\n");

        $finish;
    end

    initial begin
        #10ms;
        $display("\n✗✗✗ TIMEOUT ✗✗✗\n");
        $finish;
    end

    initial begin
        $dumpfile("tb_qos_classifier_unit.vcd");
        $dumpvars(0, tb_qos_classifier_unit);
    end

endmodule