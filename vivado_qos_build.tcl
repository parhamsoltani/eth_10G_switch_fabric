#===============================================================================
# Vivado QoS Fabric Synthesis Script
# Usage: vivado -mode batch -source vivado_qos_build.tcl
#===============================================================================

set PROJ_NAME "qos_fabric_10x10g"
set TOP_MODULE "switch_fabric"
set PART "xcku3p-ffvd900-2-i"  ;# Change to your target device

# Paths
set SRC_PATH "./src"
set XDC_PATH "./src/xdc"
set OUT_PATH "./vivado_build"

puts "════════════════════════════════════════════════════════════"
puts "  QoS Ethernet Switch Fabric - Vivado Build"
puts "  Target: $PART"
puts "════════════════════════════════════════════════════════════"

#===============================================================================
# Create Project
#===============================================================================
create_project $PROJ_NAME $OUT_PATH -part $PART -force

#===============================================================================
# Add Sources
#===============================================================================
puts "\n[1/5] Adding RTL sources..."

# Includes (order matters!)
add_files -fileset sources_1 -norecurse [list \
    $SRC_PATH/inc/fabric_params.vh \
    $SRC_PATH/inc/qos_defines.vh \
    $SRC_PATH/inc/implement_options.vh \
]

# Interfaces
add_files -fileset sources_1 [glob $SRC_PATH/hdl/interfaces/*.sv]

# IP components
add_files -fileset sources_1 [glob -nocomplain $SRC_PATH/hdl/ip/**/*.sv]

# Core modules (QoS)
add_files -fileset sources_1 [glob $SRC_PATH/hdl/core/*.sv]

# Buffers
add_files -fileset sources_1 [glob $SRC_PATH/hdl/buffers/*.sv]

# Arbitration
add_files -fileset sources_1 [glob $SRC_PATH/hdl/arbitration/*.sv]

# Switch components
add_files -fileset sources_1 [glob $SRC_PATH/hdl/switches/*.sv]
add_files -fileset sources_1 [glob $SRC_PATH/hdl/switch_ips/*.sv]

# Line modules
add_files -fileset sources_1 [glob $SRC_PATH/hdl/line_modules/*.sv]

# Fabric
add_files -fileset sources_1 [glob $SRC_PATH/hdl/fabric/*.sv]

# Top-level
add_files -fileset sources_1 $SRC_PATH/hdl/switch_fabric.sv

#===============================================================================
# Add Constraints
#===============================================================================
puts "\n[2/5] Adding constraints..."
add_files -fileset constrs_1 -norecurse $XDC_PATH/timing_qos.xdc

#===============================================================================
# Set Top Module
#===============================================================================
set_property top $TOP_MODULE [current_fileset]
update_compile_order -fileset sources_1

#===============================================================================
# Synthesis Settings
#===============================================================================
puts "\n[3/5] Configuring synthesis..."

# Enable QoS
set_property -name {STEPS.SYNTH_DESIGN.ARGS.MORE OPTIONS} \
    -value {-generic ENABLE_QOS=1 -generic QOS_TAG_WIDTH=3} \
    -objects [get_runs synth_1]

# Flatten hierarchy for QoS logic
set_property STEPS.SYNTH_DESIGN.ARGS.FLATTEN_HIERARCHY full [get_runs synth_1]

#===============================================================================
# Run Synthesis
#===============================================================================
puts "\n[4/5] Running synthesis..."
reset_run synth_1
launch_runs synth_1 -jobs 8
wait_on_run synth_1

#===============================================================================
# Reports
#===============================================================================
puts "\n[5/5] Generating reports..."
open_run synth_1 -name synth_1

report_utilization -file $OUT_PATH/utilization_synth.rpt
report_timing_summary -max_paths 10 -file $OUT_PATH/timing_synth.rpt
report_high_fanout_nets -file $OUT_PATH/high_fanout.rpt

# Check for QoS modules
set qos_cells [get_cells -hier -filter {REF_NAME =~ *qos*}]
if {[llength $qos_cells] > 0} {
    puts "\n QoS modules found: [llength $qos_cells] instances"
    puts [get_cells -hier -filter {REF_NAME =~ *qos*}]
} else {
    puts "\n WARNING: No QoS modules found in design!"
}

puts "\n════════════════════════════════════════════════════════════"
puts "  Build complete!"
puts "  Results: $OUT_PATH"
puts "════════════════════════════════════════════════════════════"
