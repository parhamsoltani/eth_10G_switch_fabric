#!/usr/bin/tclsh
####################################################################################
# Vivado Timing Analysis Script for QoS Fabric
# Analyzes critical paths, slack distribution, and QoS-specific timing
####################################################################################

set REPORT_DIR "../../out/timing_analysis"
file mkdir $REPORT_DIR

proc analyze_timing {checkpoint_file output_prefix} {
    global REPORT_DIR

    puts "\n=========================================="
    puts "Analyzing: $checkpoint_file"
    puts "=========================================="

    # Open checkpoint
    if {![file exists $checkpoint_file]} {
        puts "ERROR: Checkpoint not found: $checkpoint_file"
        return
    }

    open_checkpoint $checkpoint_file

    # Generate comprehensive timing reports
    set rpt_dir "$REPORT_DIR/$output_prefix"
    file mkdir $rpt_dir

    # 1. Overall timing summary
    report_timing_summary \
        -delay_type min_max \
        -report_unconstrained \
        -check_timing_verbose \
        -max_paths 100 \
        -input_pins \
        -routable_nets \
        -file "$rpt_dir/timing_summary.rpt"

    # 2. Setup timing (worst paths)
    report_timing \
        -setup \
        -max_paths 50 \
        -nworst 5 \
        -unique_pins \
        -path_type summary \
        -file "$rpt_dir/timing_setup_worst.rpt"

    # 3. Hold timing
    report_timing \
        -hold \
        -max_paths 50 \
        -file "$rpt_dir/timing_hold.rpt"

    # 4. QoS-specific paths (if QoS enabled)
    set qos_paths [get_timing_paths \
        -from [get_pins -hierarchical -filter {NAME =~ */qos_classifier/*}] \
        -to [get_pins -hierarchical -filter {NAME =~ */dest_finder_row_matching_qos/*}] \
        -max_paths 20]

    if {[llength $qos_paths] > 0} {
        puts "Found [llength $qos_paths] QoS-related timing paths"
        report_timing \
            -of_objects $qos_paths \
            -max_paths 20 \
            -file "$rpt_dir/timing_qos_paths.rpt"
    } else {
        puts "No QoS paths found (QoS likely disabled)"
    }

    # 5. Datapath analysis
    report_timing \
        -from [get_pins -hierarchical -filter {NAME =~ */main_mem/*/C}] \
        -to [get_pins -hierarchical -filter {NAME =~ */xpq*/*/D}] \
        -max_paths 20 \
        -file "$rpt_dir/timing_datapath.rpt"

    # 6. Clock interaction (if multi-clock)
    set clocks [get_clocks]
    if {[llength $clocks] > 1} {
        check_timing -verbose -file "$rpt_dir/timing_clock_interaction.rpt"
    }

    # 7. Extract WNS/WHS/WPWS
    set wns [get_property SLACK [get_timing_paths -setup -max_paths 1]]
    set whs [get_property SLACK [get_timing_paths -hold -max_paths 1]]

    puts "\nTiming Results:"
    puts "  WNS (setup): $wns ns"
    puts "  WHS (hold):  $whs ns"

    # 8. Generate slack histogram
    set slack_histogram [dict create]
    foreach path [get_timing_paths -setup -max_paths 1000] {
        set slack [get_property SLACK $path]
        set bin [expr {int(floor($slack / 0.1)) * 0.1}]  ;# 100ps bins
        dict incr slack_histogram $bin
    }

    set hist_file [open "$rpt_dir/slack_histogram.csv" w]
    puts $hist_file "Slack_Bin_ns,Path_Count"
    foreach {bin count} [lsort -real [dict keys $slack_histogram]] {
        puts $hist_file "$bin,[dict get $slack_histogram $bin]"
    }
    close $hist_file

    puts "Slack histogram saved to slack_histogram.csv"

    # 9. Resource utilization correlation
    report_utilization -file "$rpt_dir/utilization.rpt"

    # 10. Power estimation (if design is fully routed)
    if {[get_property PROGRESS [current_design]] == "100%"} {
        report_power \
            -advisory \
            -file "$rpt_dir/power_estimate.rpt"
    }

    close_design
    puts "Timing analysis complete for $output_prefix\n"
}

####################################################################################
# Main Execution
####################################################################################

# Analyze multiple checkpoints (from config sweep)
set checkpoint_dir "../../out/products"
set checkpoints [glob -nocomplain "$checkpoint_dir/*/route.dcp"]

if {[llength $checkpoints] == 0} {
    puts "ERROR: No checkpoints found in $checkpoint_dir"
    puts "Run builds first: make qos-build"
    exit 1
}

foreach chkpt $checkpoints {
    # Extract config ID from path (e.g., "out/products/config_003/route.dcp")
    regexp {config_(\d+)} $chkpt -> cfg_id

    analyze_timing $chkpt "config_$cfg_id"
}

# Generate comparative summary
puts "\n=========================================="
puts "Generating comparative summary..."
puts "=========================================="

set summary_file "$REPORT_DIR/summary.csv"
set fh [open $summary_file w]
puts $fh "Config_ID,WNS_ns,WHS_ns,LUT,FF,BRAM,Freq_MHz,QoS_Enabled"

foreach chkpt $checkpoints {
    regexp {config_(\d+)} $chkpt -> cfg_id

    # Parse timing summary
    set timing_rpt "$REPORT_DIR/config_$cfg_id/timing_summary.rpt"
    if {[file exists $timing_rpt]} {
        set rpt_text [read [open $timing_rpt r]]

        regexp {WNS\(ns\)\s+([-\d.]+)} $rpt_text -> wns
        regexp {WHS\(ns\)\s+([-\d.]+)} $rpt_text -> whs

        # Parse utilization
        set util_rpt "$REPORT_DIR/config_$cfg_id/utilization.rpt"
        if {[file exists $util_rpt]} {
            set util_text [read [open $util_rpt r]]

            regexp {CLB LUTs\*?\s+\|\s+(\d+)} $util_text -> lut
            regexp {CLB Registers\s+\|\s+(\d+)} $util_text -> ff
            regexp {Block RAM Tile\s+\|\s+(\d+)} $util_text -> bram

            # Compute achieved frequency
            set clk_period [expr {$wns > 0 ? 2.8985 : 2.8985 - $wns}]  ;# Adjust based on timing
            set freq_mhz [expr {1000.0 / $clk_period}]

            # Check QoS enable (from meta.json)
            set meta_file "../../scr/save_configs/config_generator/configs/$cfg_id/meta.json"
            set qos_enabled 0
            if {[file exists $meta_file]} {
                set meta [json::json2dict [read [open $meta_file r]]]
                set qos_enabled [dict get $meta qos_enabled]
            }

            puts $fh "$cfg_id,$wns,$whs,$lut,$ff,$bram,$freq_mhz,$qos_enabled"
        }
    }
}

close $fh
puts "Summary saved to: $summary_file"

puts "\n=========================================="
puts "Timing analysis complete!"
puts "Results in: $REPORT_DIR"
puts "=========================================="