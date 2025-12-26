#═══════════════════════════════════════════════════════════════
#  FULL IMPLEMENTATION FLOW (Post-Synthesis)
#═══════════════════════════════════════════════════════════════

set DESIGN "switch_fabric"
set SYNTH_DCP "vivado_build/${DESIGN}_synth.dcp"
set REPORTS_DIR "vivado_build/reports"
set OUT_DIR "vivado_build"

# Create report directories
file mkdir ${REPORTS_DIR}/detailed
file mkdir ${REPORTS_DIR}/impl

puts "\n═══════════════════════════════════════════════════════════════"
puts "  FULL IMPLEMENTATION: Place & Route + Bitstream"
puts "═══════════════════════════════════════════════════════════════\n"

#═══════════════════════════════════════════════════════════════
# STEP 1: Open Synthesized Design
#═══════════════════════════════════════════════════════════════

puts "\[1/8\] Opening synthesized design..."
open_checkpoint $SYNTH_DCP

#═══════════════════════════════════════════════════════════════
# STEP 2: Optimization
#═══════════════════════════════════════════════════════════════

puts "\[2/8\] opt_design (logic optimization)..."
opt_design -directive ExploreWithRemap

report_utilization -file ${REPORTS_DIR}/impl/utilization_opt.rpt
report_timing_summary -max_paths 10 -file ${REPORTS_DIR}/impl/timing_opt.rpt

#═══════════════════════════════════════════════════════════════
# STEP 3: Power Optimization
#═══════════════════════════════════════════════════════════════

puts "\[3/8\] power_opt_design..."
power_opt_design

#═══════════════════════════════════════════════════════════════
# STEP 4: Placement
#═══════════════════════════════════════════════════════════════

puts "\[4/8\] place_design (ExtraPostPlacementOpt)..."
place_design -directive ExtraPostPlacementOpt

report_clock_utilization -file ${REPORTS_DIR}/impl/clock_util.rpt
report_utilization -file ${REPORTS_DIR}/impl/utilization_place.rpt
report_timing_summary -max_paths 10 -file ${REPORTS_DIR}/impl/timing_place.rpt

#═══════════════════════════════════════════════════════════════
# STEP 5: Post-Place Physical Optimization
#═══════════════════════════════════════════════════════════════

puts "\[5/8\] phys_opt_design (AggressiveExplore)..."
phys_opt_design -directive AggressiveExplore

#═══════════════════════════════════════════════════════════════
# STEP 6: Routing
#═══════════════════════════════════════════════════════════════

puts "\[6/8\] route_design (AlternateCLBRouting)..."
route_design -directive AlternateCLBRouting

report_route_status -file ${REPORTS_DIR}/impl/route_status.rpt
report_drc -file ${REPORTS_DIR}/impl/drc.rpt
report_timing_summary -max_paths 100 -file ${REPORTS_DIR}/impl/timing_route.rpt
report_power -file ${REPORTS_DIR}/impl/power.rpt

#═══════════════════════════════════════════════════════════════
# STEP 7: Post-Route Physical Optimization
#═══════════════════════════════════════════════════════════════

puts "\[7/8\] phys_opt_design (post-route)..."
phys_opt_design -directive Explore

#═══════════════════════════════════════════════════════════════
# STEP 8: Final Timing Check
#═══════════════════════════════════════════════════════════════

puts "\[8/8\] Final timing analysis..."

set wns [get_property SLACK [get_timing_paths -max_paths 1 -setup]]
set whs [get_property SLACK [get_timing_paths -max_paths 1 -hold]]

puts "\n═══════════════════════════════════════════════════════════════"
puts "  FINAL TIMING RESULTS"
puts "═══════════════════════════════════════════════════════════════"
puts "  Setup (WNS): $wns ns"
puts "  Hold (WHS):  $whs ns"

set timing_met 1
if {$wns < 0} {
    puts "   SETUP TIMING FAILED"
    set timing_met 0
} else {
    puts "  ✅ Setup timing MET"
}

if {$whs < 0} {
    puts "   HOLD TIMING FAILED"
    set timing_met 0
} else {
    puts "  ✅ Hold timing MET"
}
puts "═══════════════════════════════════════════════════════════════\n"

#═══════════════════════════════════════════════════════════════
# STEP 9: Write Outputs
#═══════════════════════════════════════════════════════════════

write_checkpoint -force ${OUT_DIR}/${DESIGN}_routed.dcp
puts "  ✅ Checkpoint: ${DESIGN}_routed.dcp"

if {$timing_met} {
    puts "\n  Generating bitstream..."
    write_bitstream -force ${OUT_DIR}/${DESIGN}.bit
    puts "  ✅ Bitstream: ${DESIGN}.bit\n"
} else {
    puts "\n  ⚠️  Bitstream skipped (timing violations)\n"
}

#═══════════════════════════════════════════════════════════════
# STEP 10: Detailed Reports
#═══════════════════════════════════════════════════════════════

report_timing -max_paths 100 -nworst 5 -path_type full \
    -file ${REPORTS_DIR}/detailed/timing_full.rpt

report_utilization -hierarchical \
    -file ${REPORTS_DIR}/detailed/utilization_hier.rpt

report_design_analysis -logic_level_distribution -hold \
    -file ${REPORTS_DIR}/detailed/design_analysis.rpt

puts "═══════════════════════════════════════════════════════════════"
puts "  IMPLEMENTATION COMPLETE"
puts "═══════════════════════════════════════════════════════════════"
puts "  Outputs:"
puts "    - Routed DCP:  ${OUT_DIR}/${DESIGN}_routed.dcp"
if {$timing_met} {
    puts "    - Bitstream:   ${OUT_DIR}/${DESIGN}.bit"
}
puts "    - Reports:     ${REPORTS_DIR}/impl/"
puts "    - Detailed:    ${REPORTS_DIR}/detailed/"
puts "═══════════════════════════════════════════════════════════════\n"