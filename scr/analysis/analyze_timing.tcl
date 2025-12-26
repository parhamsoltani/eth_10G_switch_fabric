#!/usr/bin/tclsh
#===============================================================================
# Detailed Timing Analysis for QoS Fabric
# Run from: anywhere (auto-detects paths)
#===============================================================================

set SCRIPT_DIR [file dirname [file normalize [info script]]]
set PROJECT_ROOT [file normalize "$SCRIPT_DIR/../.."]
set DCP_FILE "$PROJECT_ROOT/vivado_build/switch_fabric_routed.dcp"
set REPORT_DIR "$PROJECT_ROOT/vivado_build/reports/detailed"

puts "════════════════════════════════════════════════════════════"
puts "  DETAILED TIMING ANALYSIS"
puts "════════════════════════════════════════════════════════════"
puts "  DCP:     $DCP_FILE"
puts "  Reports: $REPORT_DIR"
puts "════════════════════════════════════════════════════════════"

# Check if DCP exists
if {![file exists $DCP_FILE]} {
    puts "\n ERROR: Routed DCP not found!"
    puts "   Expected: $DCP_FILE"
    puts "   Run vivado_qos_build_2019.tcl first."
    exit 1
}

file mkdir $REPORT_DIR

# Open routed design
puts "\nOpening routed checkpoint..."
open_checkpoint $DCP_FILE

#===============================================================================
# 1. Critical Paths Analysis
#===============================================================================
puts "\n[1/6] Analyzing critical paths..."
report_timing \
    -max_paths 100 \
    -nworst 10 \
    -delay_type max \
    -sort_by slack \
    -input_pins \
    -file $REPORT_DIR/critical_paths.rpt

puts "   Saved: critical_paths.rpt"

#===============================================================================
# 2. QoS-Specific Timing Paths
#===============================================================================
puts "\n[2/6] Analyzing QoS logic timing..."

set qos_classifier_pins [get_pins -quiet -hier -filter {NAME =~ */qos_classifier/*/Q}]
set dest_finder_pins [get_pins -quiet -hier -filter {NAME =~ */dest_finder*/*/D}]

if {[llength $qos_classifier_pins] > 0 && [llength $dest_finder_pins] > 0} {
    set qos_paths [get_timing_paths \
        -from $qos_classifier_pins \
        -to $dest_finder_pins \
        -max_paths 50 \
        -nworst 5]
    
    if {[llength $qos_paths] > 0} {
        report_timing \
            -of_objects $qos_paths \
            -max_paths 50 \
            -file $REPORT_DIR/qos_paths.rpt
        puts "   Found [llength $qos_paths] QoS-related paths"
    } else {
        puts "   No timing paths found between QoS modules"
    }
} else {
    puts "   QoS modules not found (may be disabled)"
}

#===============================================================================
# 3. Clock Domain Crossing Checks
#===============================================================================
puts "\n[3/6] Checking clock domain crossings..."
check_timing \
    -verbose \
    -file $REPORT_DIR/timing_checks.rpt

#===============================================================================
# 4. Hierarchical Utilization
#===============================================================================
puts "\n[4/6] Generating hierarchical utilization..."
report_utilization \
    -hierarchical \
    -hierarchical_depth 3 \
    -file $REPORT_DIR/util_hierarchical.rpt

#===============================================================================
# 5. Timing Summary by Clock
#===============================================================================
puts "\n[5/6] Timing summary per clock domain..."
report_timing_summary \
    -delay_type min_max \
    -report_unconstrained \
    -check_timing_verbose \
    -max_paths 10 \
    -file $REPORT_DIR/timing_summary_detailed.rpt

#===============================================================================
# 6. Datapath Analysis
#===============================================================================
puts "\n[6/6] Analyzing datapath delays..."

set voq_pins [get_pins -quiet -hier -filter {NAME =~ */voq*/data_out*}]
set xpq_pins [get_pins -quiet -hier -filter {NAME =~ */xpq*/data_in*}]

if {[llength $voq_pins] > 0 && [llength $xpq_pins] > 0} {
    set datapath_paths [get_timing_paths \
        -from $voq_pins \
        -to $xpq_pins \
        -max_paths 20]
    
    if {[llength $datapath_paths] > 0} {
        report_timing \
            -of_objects $datapath_paths \
            -file $REPORT_DIR/datapath_timing.rpt
        puts "   Analyzed VOQ→XPQ datapath"
    }
}

#===============================================================================
# Summary
#===============================================================================
puts "\n════════════════════════════════════════════════════════════"
puts "  ANALYSIS COMPLETE"
puts "════════════════════════════════════════════════════════════"
puts "  Reports generated in:"
puts "    $REPORT_DIR"
puts ""
puts "  Key files:"
puts "    - critical_paths.rpt         (100 worst paths)"
puts "    - qos_paths.rpt              (QoS classifier → dest finder)"
puts "    - timing_checks.rpt          (CDC violations)"
puts "    - util_hierarchical.rpt      (per-module resources)"
puts "    - timing_summary_detailed.rpt (all clocks)"
puts "    - datapath_timing.rpt        (VOQ → XPQ)"
puts "════════════════════════════════════════════════════════════"

close_design