`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Scoreboard Module - Compares expected vs actual frames
//////////////////////////////////////////////////////////////////////////////////

`include "sim_options.vh"
`include "implement_options.vh"

module score_board #(
    parameter NUM_PORT = 4
)(
    input wire sys_clk,
    input wire sys_reset,
    
    // Mailboxes for frame comparison (generic mailbox)
    mailbox actual_mailbox [NUM_PORT],
    mailbox expected_mailbox [NUM_PORT],
    
    // End of simulation signal
    input wire end_of_sim
);

    // Local frame info structure (same as monitor/switch_model)
    typedef struct {
        byte data[];
        int size;
        int port_id;
        time timestamp;
        bit has_error;
    } frame_info_t;

    //==========================================================================
    // Statistics
    //==========================================================================
    int total_expected = 0;
    int total_received = 0;
    int total_matched = 0;
    int total_mismatched = 0;
    int total_missing = 0;
    
    // Per-port statistics
    int port_expected [NUM_PORT];
    int port_received [NUM_PORT];
    int port_matched [NUM_PORT];
    int port_mismatched [NUM_PORT];
    
    // Test result
    bit test_pass = 1;

    //==========================================================================
    // Initialize Statistics
    //==========================================================================
    initial begin
        for (int i = 0; i < NUM_PORT; i++) begin
            port_expected[i] = 0;
            port_received[i] = 0;
            port_matched[i] = 0;
            port_mismatched[i] = 0;
        end
    end

    //==========================================================================
    // Compare Two Frames
    //==========================================================================
    function automatic bit compare_frames(input frame_info_t actual, input frame_info_t expected);
        int i;
        if (actual.size != expected.size) begin
            `ifdef DEBUG_SCOREBOARD
            $display("  Size mismatch: actual=%0d, expected=%0d", actual.size, expected.size);
            `endif
            return 0;
        end
        
        for (i = 0; i < actual.size; i++) begin
            if (actual.data[i] !== expected.data[i]) begin
                `ifdef DEBUG_SCOREBOARD
                $display("  Data mismatch at byte %0d: actual=0x%02x, expected=0x%02x", 
                         i, actual.data[i], expected.data[i]);
                `endif
                return 0;
            end
        end
        
        return 1;
    endfunction

    //==========================================================================
    // Print Frame Difference for Debugging
    //==========================================================================
    function automatic void print_frame_diff(input frame_info_t actual, input frame_info_t expected);
        int max_size;
        int diff_count;
        int i;
        
        max_size = (actual.size > expected.size) ? actual.size : expected.size;
        diff_count = 0;
        
        $display("  Frame comparison (showing first 10 differences):");
        $display("  Actual size: %0d, Expected size: %0d", actual.size, expected.size);
        
        for (i = 0; i < max_size && diff_count < 10; i++) begin
            if (i >= actual.size) begin
                $display("    Byte[%0d]: actual=N/A, expected=0x%02x", i, expected.data[i]);
                diff_count++;
            end else if (i >= expected.size) begin
                $display("    Byte[%0d]: actual=0x%02x, expected=N/A", i, actual.data[i]);
                diff_count++;
            end else if (actual.data[i] !== expected.data[i]) begin
                $display("    Byte[%0d]: actual=0x%02x, expected=0x%02x", 
                         i, actual.data[i], expected.data[i]);
                diff_count++;
            end
        end
    endfunction

    //==========================================================================
    // Print Final Statistics
    //==========================================================================
    function void print_statistics();
        int p;
        $display("");
        $display("================================================================================");
        $display("                         SCOREBOARD FINAL STATISTICS                           ");
        $display("================================================================================");
        $display("");
        $display("  Per-Port Statistics:");
        $display("  +------+----------+----------+---------+------------+");
        $display("  | Port | Expected | Received | Matched | Mismatched |");
        $display("  +------+----------+----------+---------+------------+");
        for (p = 0; p < NUM_PORT; p++) begin
            $display("  | %4d | %8d | %8d | %7d | %10d |", 
                     p, port_expected[p], port_received[p], port_matched[p], port_mismatched[p]);
        end
        $display("  +------+----------+----------+---------+------------+");
        $display("");
        $display("  Summary:");
        $display("  +----------------------+----------+");
        $display("  | Metric               |    Count |");
        $display("  +----------------------+----------+");
        $display("  | Total Expected       | %8d |", total_expected);
        $display("  | Total Received       | %8d |", total_received);
        $display("  | Total Matched        | %8d |", total_matched);
        $display("  | Total Mismatched     | %8d |", total_mismatched);
        $display("  | Total Missing        | %8d |", total_missing);
        $display("  +----------------------+----------+");
        $display("");
        $display("================================================================================");
        if (test_pass && total_matched > 0) begin
            $display("                         *** TEST PASSED ***                                   ");
        end else if (total_matched == 0 && total_received == 0) begin
            $display("                    *** TEST INCONCLUSIVE (No Frames) ***                      ");
        end else begin
            $display("                         *** TEST FAILED ***                                   ");
        end
        $display("================================================================================");
        $display("");
    endfunction

    //==========================================================================
    // Comparison Process for Each Port
    //==========================================================================
    generate
        for (genvar p = 0; p < NUM_PORT; p++) begin : gen_port_compare
            
            initial begin
                frame_info_t actual_frame;
                frame_info_t expected_frame;
                
                // Wait for reset to complete
                wait (!sys_reset);
                repeat (100) @(posedge sys_clk);
                
                forever begin
                    // Check for end of simulation
                    if (end_of_sim) break;
                    
                    // Wait for actual frame from DUT
                    if (actual_mailbox[p] != null) begin
                        if (actual_mailbox[p].try_get(actual_frame)) begin
                            port_received[p]++;
                            total_received++;
                            
                            `ifdef DEBUG_SCOREBOARD
                            $display("[%0t] SCOREBOARD[%0d]: Received actual frame, size=%0d", 
                                     $time, p, actual_frame.size);
                            `endif
                            
                            // Try to get expected frame
                            if (expected_mailbox[p] != null) begin
                                if (expected_mailbox[p].try_get(expected_frame)) begin
                                    port_expected[p]++;
                                    total_expected++;
                                    
                                    // Compare frames
                                    if (compare_frames(actual_frame, expected_frame)) begin
                                        port_matched[p]++;
                                        total_matched++;
                                        `ifdef DEBUG_SCOREBOARD
                                        $display("[%0t] SCOREBOARD[%0d]: Frame MATCHED", $time, p);
                                        `endif
                                    end else begin
                                        port_mismatched[p]++;
                                        total_mismatched++;
                                        test_pass = 0;
                                        $warning("[%0t] SCOREBOARD[%0d]: Frame MISMATCH!", $time, p);
                                        print_frame_diff(actual_frame, expected_frame);
                                    end
                                end else begin
                                    // No expected frame - unexpected actual frame
                                    port_mismatched[p]++;
                                    total_mismatched++;
                                    test_pass = 0;
                                    $warning("[%0t] SCOREBOARD[%0d]: Unexpected frame received (size=%0d)!", 
                                             $time, p, actual_frame.size);
                                end
                            end
                        end
                    end
                    
                    // Small delay to avoid busy loop
                    @(posedge sys_clk);
                end
            end
            
        end
    endgenerate

    //==========================================================================
    // End of Simulation - Check for Missing Frames and Print Statistics
    //==========================================================================
    always @(posedge end_of_sim) begin
        frame_info_t remaining_frame;
        int p;
        
        // Wait a bit for any remaining frames to be processed
        repeat (1000) @(posedge sys_clk);
        
        // Check for remaining expected frames (missing from DUT output)
        for (p = 0; p < NUM_PORT; p++) begin
            if (expected_mailbox[p] != null) begin
                while (expected_mailbox[p].try_get(remaining_frame)) begin
                    total_missing++;
                    test_pass = 0;
                    $warning("[SCOREBOARD] Missing frame on port %0d, expected size=%0d", 
                             p, remaining_frame.size);
                end
            end
        end
        
        // Print final statistics
        print_statistics();
    end

endmodule