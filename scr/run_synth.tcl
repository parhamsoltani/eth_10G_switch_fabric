#═══════════════════════════════════════════════════════════════════════════════
# Synthesis and Implementation Script for Switch Fabric
# Optimized for timing closure
#═══════════════════════════════════════════════════════════════════════════════

# Set project parameters
set project_name "switch_fabric"
set part_number "xcvu9p-flga2104-2L-e"  ;# Adjust to your target part

#───────────────────────────────────────────────────────────────────────────────
# Synthesis Settings
#───────────────────────────────────────────────────────────────────────────────
set_property STEPS.SYNTH_DESIGN.ARGS.RETIMING true [get_runs synth_1]
set_property STEPS.SYNTH_DESIGN.ARGS.DIRECTIVE PerformanceOptimized [get_runs synth_1]
set_property STEPS.SYNTH_DESIGN.ARGS.FLATTEN_HIERARCHY rebuilt [get_runs synth_1]
set_property STEPS.SYNTH_DESIGN.ARGS.FSM_EXTRACTION one_hot [get_runs synth_1]
set_property STEPS.SYNTH_DESIGN.ARGS.KEEP_EQUIVALENT_REGISTERS true [get_runs synth_1]
set_property STEPS.SYNTH_DESIGN.ARGS.RESOURCE_SHARING off [get_runs synth_1]
set_property STEPS.SYNTH_DESIGN.ARGS.NO_LC true [get_runs synth_1]

#───────────────────────────────────────────────────────────────────────────────
# Implementation Settings - Aggressive Timing Optimization
#───────────────────────────────────────────────────────────────────────────────
# Optimization
set_property STEPS.OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
set_property STEPS.OPT_DESIGN.ARGS.DIRECTIVE ExploreWithRemap [get_runs impl_1]

# Placement
set_property STEPS.PLACE_DESIGN.ARGS.DIRECTIVE ExtraTimingOpt [get_runs impl_1]

# Physical Optimization (enabled)
set_property STEPS.PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
set_property STEPS.PHYS_OPT_DESIGN.ARGS.DIRECTIVE AggressiveExplore [get_runs impl_1]

# Routing
set_property STEPS.ROUTE_DESIGN.ARGS.DIRECTIVE AggressiveExplore [get_runs impl_1]

# Post-Route Physical Optimization (enabled)
set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.ARGS.DIRECTIVE AggressiveExplore [get_runs impl_1]

#───────────────────────────────────────────────────────────────────────────────
# Additional Performance Settings
#───────────────────────────────────────────────────────────────────────────────
# Enable more aggressive timing-driven placement
set_property STEPS.PLACE_DESIGN.ARGS.TIMING_SUMMARY true [get_runs impl_1]

#───────────────────────────────────────────────────────────────────────────────
# Run Synthesis
#───────────────────────────────────────────────────────────────────────────────
puts "Starting synthesis..."
launch_runs synth_1 -jobs 8
wait_on_run synth_1

# Check synthesis status
if {[get_property STATUS [get_runs synth_1]] != "synth_design Complete!"} {
    puts "ERROR: Synthesis failed!"
    exit 1
}

puts "Synthesis completed successfully."

#───────────────────────────────────────────────────────────────────────────────
# Run Implementation
#───────────────────────────────────────────────────────────────────────────────
puts "Starting implementation..."
launch_runs impl_1 -jobs 8
wait_on_run impl_1

# Check implementation status
if {[get_property STATUS [get_runs impl_1]] != "route_design Complete!"} {
    puts "WARNING: Implementation may have issues."
}

#───────────────────────────────────────────────────────────────────────────────
# Generate Reports
#───────────────────────────────────────────────────────────────────────────────
open_run impl_1

# Timing Summary
report_timing_summary -delay_type min_max -report_unconstrained -check_timing_verbose \
    -max_paths 100 -input_pins -routable_nets -file timing_summary.rpt

# Timing Report (worst paths)
report_timing -delay_type max -sort_by slack -max_paths 50 -file timing_setup.rpt
report_timing -delay_type min -sort_by slack -max_paths 50 -file timing_hold.rpt

# Utilization
report_utilization -file utilization.rpt

# Clock Networks
report_clock_networks -file clock_networks.rpt
report_clock_utilization -file clock_utilization.rpt

puts "═══════════════════════════════════════════════════════════"
puts " Implementation Complete"
puts " Check timing_summary.rpt for timing closure status"
puts "═══════════════════════════════════════════════════════════"