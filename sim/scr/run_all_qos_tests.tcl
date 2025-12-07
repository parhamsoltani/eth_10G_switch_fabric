puts "\n"
puts "╔═══════════════════════════════════════════════════════════════════╗"
puts "║                                                                   ║"
puts "║                  QoS SUBSYSTEM TEST SUITE                         ║"
puts "║                  ========================                         ║"
puts "║                                                                   ║"
puts "║  Running all unit and integration tests for QoS modules          ║"
puts "║                                                                   ║"
puts "╚═══════════════════════════════════════════════════════════════════╝\n"

set test_results [dict create]
set total_tests 0
set passed_tests 0
set failed_tests 0

proc run_test {test_name compile_script sim_module} {
    global test_results total_tests passed_tests failed_tests

    puts "\n"
    puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    puts "  Running: $test_name"
    puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    incr total_tests

    # Compile
    if {[catch {do $compile_script} compile_err]} {
        puts "  Compilation FAILED: $compile_err"
        dict set test_results $test_name "COMPILE_FAILED"
        incr failed_tests
        return
    }

    # Simulate
    if {[catch {
        vsim -c -voptargs=+acc work.$sim_module -do "run -all; quit -f"
    } sim_err]} {
        puts "  Simulation FAILED: $sim_err"
        dict set test_results $test_name "SIM_FAILED"
        incr failed_tests
        return
    }

    # Check for errors in transcript
    set transcript_file "transcript"
    if {[file exists $transcript_file]} {
        set fp [open $transcript_file r]
        set content [read $fp]
        close $fp

        if {[regexp {ERROR} $content] || [regexp {FAILED} $content]} {
            puts "  Test FAILED (errors in transcript)"
            dict set test_results $test_name "FAILED"
            incr failed_tests
        } else {
            puts " Test PASSED"
            dict set test_results $test_name "PASSED"
            incr passed_tests
        }
    } else {
        puts " Test PASSED (no errors detected)"
        dict set test_results $test_name "PASSED"
        incr passed_tests
    }
}

# Run unit tests
puts "\n╔═══════════════════════════════════════════════════════════════════╗"
puts "║                         UNIT TESTS                                ║"
puts "╚═══════════════════════════════════════════════════════════════════╝"

run_test "QoS Classifier Unit" \
         "scr/tb_qos_classifier_unit/compile_all.tcl" \
         "tb_qos_classifier_unit"

run_test "QoS Scheduler Unit" \
         "scr/tb_qos_scheduler_unit/compile_all.tcl" \
         "tb_qos_scheduler_unit"

run_test "Round-Robin Arbiter Unit" \
         "scr/tb_round_robin_arbiter_unit/compile_all.tcl" \
         "tb_round_robin_arbiter_unit"

# Run integration tests
puts "\n╔═══════════════════════════════════════════════════════════════════╗"
puts "║                     INTEGRATION TESTS                             ║"
puts "╚═══════════════════════════════════════════════════════════════════╝"

run_test "QoS Manager Integration" \
         "scr/tb_qos_manager_integration/compile_all.tcl" \
         "tb_qos_manager_integration"

# Print final summary
puts "\n\n"
puts "╔═══════════════════════════════════════════════════════════════════╗"
puts "║                                                                   ║"
puts "║                      FINAL TEST SUMMARY                           ║"
puts "║                                                                   ║"
puts "╠═══════════════════════════════════════════════════════════════════╣"
puts [format "║  Total Tests:   %-47d ║" $total_tests]
puts [format "║  Passed:        %-47d ║" $passed_tests]
puts [format "║  Failed:        %-47d ║" $failed_tests]
puts "╠═══════════════════════════════════════════════════════════════════╣"
puts "║                                                                   ║"

dict for {test_name result} $test_results {
    if {$result == "PASSED"} {
        puts [format "║   %-63s ║" $test_name]
    } else {
        puts [format "║    %-63s ║" $test_name]
    }
}

puts "║                                                                   ║"
puts "╠═══════════════════════════════════════════════════════════════════╣"

if {$failed_tests == 0} {
    puts "║                                                                   ║"
    puts "║               ALL TESTS PASSED                             ║"
    puts "║                                                                   ║"
} else {
    puts "║                                                                   ║"
    puts "║                  SOME TESTS FAILED                               ║"
    puts "║                                                                   ║"
}

puts "╚═══════════════════════════════════════════════════════════════════╝\n"

if {$failed_tests > 0} {
    exit 1
} else {
    exit 0
}