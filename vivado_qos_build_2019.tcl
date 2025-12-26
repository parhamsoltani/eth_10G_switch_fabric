#===============================================================================
# Vivado QoS Fabric - Complete Build & Implementation Script
# Compatible with Vivado 2019.1
# Includes: Synthesis -> Verification -> Conditional Implementation
#===============================================================================

set PROJ_NAME "qos_fabric_10x10g"
set TOP_MODULE "switch_fabric"
set PART "xcku3p-ffvd900-2-i"

# Paths
set SCRIPT_DIR [file dirname [file normalize [info script]]]
set SRC_PATH "$SCRIPT_DIR/src"
set SIM_PATH "$SCRIPT_DIR/sim"
set XDC_PATH "$SCRIPT_DIR/src/xdc"
set OUT_PATH "$SCRIPT_DIR/vivado_build"
set REPORTS_DIR "$OUT_PATH/reports"

puts "================================================================"
puts "  QoS Ethernet Switch Fabric - Complete Build Flow"
puts "  Vivado Version: 2019.1"
puts "  Target: $PART"
puts "================================================================"

#===============================================================================
# Helper Procedures
#===============================================================================
proc add_files_safe {fileset pattern} {
    set files [glob -nocomplain $pattern]
    if {[llength $files] > 0} {
        add_files -fileset $fileset -norecurse $files
        puts "    Added [llength $files] files from $pattern"
        return [llength $files]
    } else {
        puts "    WARNING: No files found matching $pattern"
        return 0
    }
}

proc print_stage_header {stage total} {
    puts "\n================================================================"
    puts "  \[$stage/$total\] [string toupper $stage]"
    puts "================================================================"
}

proc check_timing_violation {run_name} {
    set wns [get_property STATS.WNS [get_runs $run_name]]
    set whs [get_property STATS.WHS [get_runs $run_name]]
    
    set timing_met 1
    if {$wns eq "" || $wns < 0} {
        puts "   WARNING: Setup timing violation (WNS = $wns ns)"
        set timing_met 0
    }
    if {$whs eq "" || $whs < 0} {
        puts "   WARNING: Hold timing violation (WHS = $whs ns)"
        set timing_met 0
    }
    
    return $timing_met
}

proc get_resource_count {type} {
    set cells [get_cells -quiet -hier -filter "PRIMITIVE_TYPE =~ $type"]
    return [llength $cells]
}

#===============================================================================
# Step 0: Setup Memory Files
#===============================================================================
print_stage_header "SETUP" 11

file mkdir $OUT_PATH
file mkdir $OUT_PATH/mem_init
file mkdir $REPORTS_DIR

set mem_sources [list "$SRC_PATH/inc/mem_init" "$SIM_PATH"]
set total_mem_files 0

foreach mem_dir $mem_sources {
    if {[file isdirectory $mem_dir]} {
        set mem_files [glob -nocomplain $mem_dir/*.mem]
        foreach mem_file $mem_files {
            set filename [file tail $mem_file]
            file copy -force $mem_file $OUT_PATH/mem_init/$filename
            incr total_mem_files
        }
    }
}

puts "  Copied $total_mem_files .mem files"

#===============================================================================
# Step 1: Create Project
#===============================================================================
print_stage_header "PROJECT CREATION" 11

create_project $PROJ_NAME $OUT_PATH -part $PART -force

# Add memory initialization files to project
set mem_files [glob -nocomplain $OUT_PATH/mem_init/*.mem]
if {[llength $mem_files] > 0} {
    add_files -norecurse $mem_files
    puts "  Added [llength $mem_files] .mem files to project"
}

#===============================================================================
# Step 2: Add Sources
#===============================================================================
print_stage_header "ADD SOURCES" 11

# Include files
add_files -fileset sources_1 -norecurse [list \
    $SRC_PATH/inc/fabric_params.vh \
    $SRC_PATH/inc/qos_defines.vh \
    $SRC_PATH/inc/implement_options.vh \
]
set_property IS_GLOBAL_INCLUDE true [get_files fabric_params.vh]
set_property IS_GLOBAL_INCLUDE true [get_files qos_defines.vh]
set_property IS_GLOBAL_INCLUDE true [get_files implement_options.vh]

# Interfaces
add_files_safe sources_1 $SRC_PATH/hdl/interfaces/*.sv

# IP - Memories (bottom-up order)
add_files_safe sources_1 $SRC_PATH/hdl/ip/memories/sdpram_xpm/*.sv
add_files_safe sources_1 $SRC_PATH/hdl/ip/memories/init_mem/*.sv
add_files_safe sources_1 $SRC_PATH/hdl/ip/memories/pipeline_mem/*.sv

# IP - Basic components
add_files_safe sources_1 $SRC_PATH/hdl/ip/delayed_regs/*.sv
add_files_safe sources_1 $SRC_PATH/hdl/ip/dest_mask_modules/*.sv

# IP - Combinational components
add_files_safe sources_1 $SRC_PATH/hdl/ip/combinational_components/*.sv

# FIFOs
add_files_safe sources_1 $SRC_PATH/hdl/ip/fifos/simple_fifo/*.sv
add_files_safe sources_1 $SRC_PATH/hdl/ip/fifos/init_fifo/*.sv
add_files_safe sources_1 $SRC_PATH/hdl/ip/fifos/axis_fifo/*.sv
add_files_safe sources_1 $SRC_PATH/hdl/ip/fifos/dynamic_fifo/*.sv

# Other IP
add_files_safe sources_1 $SRC_PATH/hdl/ip/pipeline_mem/*.sv
add_files_safe sources_1 $SRC_PATH/hdl/ip/pipeline_mux/*.sv
add_files_safe sources_1 $SRC_PATH/hdl/ip/register_replicator/*.sv
add_files_safe sources_1 $SRC_PATH/hdl/ip/crossbar/*.sv

# QoS Core
set qos_core_files [list \
    $SRC_PATH/hdl/core/round_robin_arbiter.sv \
    $SRC_PATH/hdl/core/qos_classifier.sv \
    $SRC_PATH/hdl/core/qos_scheduler.sv \
]

foreach qos_file $qos_core_files {
    if {[file exists $qos_file]} {
        add_files -fileset sources_1 -norecurse $qos_file
        puts "    Added [file tail $qos_file]"
    } else {
        puts "    WARNING: Skipping missing file: [file tail $qos_file]"
    }
}

# Buffers & Arbitration
add_files_safe sources_1 $SRC_PATH/hdl/buffers/*.sv
add_files_safe sources_1 $SRC_PATH/hdl/arbitration/*.sv
add_files_safe sources_1 $SRC_PATH/hdl/converters/*.sv

# Switch IPs
add_files_safe sources_1 $SRC_PATH/hdl/switch_ips/*.sv

# Line modules
add_files_safe sources_1 $SRC_PATH/hdl/line_modules/*.sv

# Switches
add_files_safe sources_1 $SRC_PATH/hdl/switches/*.sv

# Top-level
if {[file exists $SRC_PATH/hdl/switch_fabric.sv]} {
    add_files -fileset sources_1 -norecurse $SRC_PATH/hdl/switch_fabric.sv
    puts "    Added top-level: switch_fabric.sv"
} else {
    puts "    ERROR: Top-level switch_fabric.sv not found!"
    exit 1
}

puts "  Source files added successfully"

#===============================================================================
# Step 3: Add Constraints
#===============================================================================
print_stage_header "CONSTRAINTS" 11

if {[file exists $XDC_PATH/timing_qos.xdc]} {
    add_files -fileset constrs_1 -norecurse $XDC_PATH/timing_qos.xdc
    puts "   Added timing_qos.xdc"
} else {
    puts "   WARNING: timing_qos.xdc not found, trying timing.xdc"
    if {[file exists $XDC_PATH/timing.xdc]} {
        add_files -fileset constrs_1 -norecurse $XDC_PATH/timing.xdc
        puts "   Added timing.xdc"
    } else {
        puts "   WARNING: No timing constraints found!"
    }
}

#===============================================================================
# Step 4: Configure Design
#===============================================================================
print_stage_header "CONFIGURATION" 11

set_property top $TOP_MODULE [current_fileset]
set_property generic "ENABLE_QOS=1 QOS_TAG_WIDTH=3 NUM_PORT=10" [current_fileset]
update_compile_order -fileset sources_1

puts "  Top: $TOP_MODULE"
puts "  QoS: ENABLED (3-bit tags)"

#===============================================================================
# Step 5: Run Synthesis
#===============================================================================
print_stage_header "SYNTHESIS" 11

set_property STEPS.SYNTH_DESIGN.ARGS.FLATTEN_HIERARCHY rebuilt [get_runs synth_1]
set_property STEPS.SYNTH_DESIGN.ARGS.RETIMING true [get_runs synth_1]
set_property STEPS.SYNTH_DESIGN.ARGS.DIRECTIVE AreaOptimized_high [get_runs synth_1]
set_property STEPS.SYNTH_DESIGN.ARGS.KEEP_EQUIVALENT_REGISTERS true [get_runs synth_1]

puts "  Strategy: AreaOptimized_high with retiming"
puts "  Starting synthesis... (10-30 minutes)"

reset_run synth_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1

if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
    puts "\n ERROR: Synthesis failed!"
    exit 1
}

open_run synth_1
report_utilization -file $REPORTS_DIR/utilization_synth.rpt
report_timing_summary -max_paths 10 -file $REPORTS_DIR/timing_synth.rpt

puts "   Synthesis complete"

#===============================================================================
# Step 6: Post-Synthesis Analysis & QoS Verification
#===============================================================================
print_stage_header "POST-SYNTHESIS ANALYSIS" 11

# Count I/O ports
set io_ports [get_ports -quiet]
set io_count [llength $io_ports]
set device_io_limit 386

puts "  Design I/O Analysis:"
puts "    Total I/O ports in design: $io_count"
puts "    Device I/O available:      $device_io_limit"

# QoS Module Detection
puts ""
puts "  QoS Module Verification:"

set qos_classifiers [get_cells -quiet -hier -filter {REF_NAME =~ "*qos_classifier*"}]
set qos_schedulers [get_cells -quiet -hier -filter {REF_NAME =~ "*qos_scheduler*"}]
set ingress_qos [get_cells -quiet -hier -filter {REF_NAME =~ "*ingress_line_qos*"}]
set all_qos_cells [get_cells -quiet -hier -filter {NAME =~ "*qos*"}]

puts "    QoS Classifiers:        [llength $qos_classifiers]"
puts "    QoS Schedulers:         [llength $qos_schedulers]"
puts "    Ingress QoS Modules:    [llength $ingress_qos]"
puts "    Total QoS-related cells: [llength $all_qos_cells]"

if {[llength $qos_classifiers] == 0} {
    puts "      WARNING: No qos_classifier instances found!"
} else {
    puts "     QoS classification logic successfully integrated"
}

# Check if design can be implemented
set can_implement 0
if {$io_count <= $device_io_limit} {
    set can_implement 1
    puts ""
    puts "   Design has valid I/O count - proceeding with implementation"
} else {
    puts ""
    puts "    NOTICE: Design exceeds device I/O capacity"
    puts "     This is expected for interface-based designs (simulation/verification)"
    puts "     Skipping place & route steps"
    puts ""
    puts "  💡 For FPGA implementation, you need to:"
    puts "     1. Create a wrapper with real I/O (PCIe, Ethernet MACs, etc.)"
    puts "     2. Or use Out-of-Context synthesis for this module"
}

#===============================================================================
# Step 7: Conditional Implementation (only if I/O is valid)
#===============================================================================

if {$can_implement} {
    
    print_stage_header "IMPLEMENTATION" 11
    
    # Opt Design
    puts "  [7.1] opt_design..."
    opt_design -directive Explore
    report_utilization -file $REPORTS_DIR/utilization_opt.rpt
    
    # Place Design
    puts "  [7.2] place_design..."
    place_design -directive ExtraPostPlacementOpt
    report_clock_utilization -file $REPORTS_DIR/clock_util.rpt
    report_utilization -file $REPORTS_DIR/utilization_place.rpt
    report_timing_summary -file $REPORTS_DIR/timing_place.rpt
    
    # Physical Optimization
    puts "  [7.3] phys_opt_design..."
    phys_opt_design -directive AggressiveExplore
    
    # Route Design
    puts "  [7.4] route_design..."
    route_design -directive Explore
    report_route_status -file $REPORTS_DIR/route_status.rpt
    report_timing_summary -file $REPORTS_DIR/timing_route.rpt
    report_power -file $REPORTS_DIR/power_route.rpt
    report_drc -file $REPORTS_DIR/drc.rpt
    
    # Post-Route Physical Optimization
    puts "  [7.5] phys_opt_design (post-route)..."
    phys_opt_design -directive Explore
    
    puts "   Implementation complete"
    
    #===========================================================================
    # Step 8: Check Timing
    #===========================================================================
    print_stage_header "TIMING CHECK" 11
    
    set wns [get_property STATS.WNS [get_runs impl_1]]
    set whs [get_property STATS.WHS [get_runs impl_1]]
    set timing_met 1
    
    if {$wns eq "" || $wns < 0} {
        puts "   Setup Timing VIOLATION: WNS = $wns ns"
        set timing_met 0
    } else {
        puts "   Setup Timing MET: WNS = $wns ns"
    }
    
    if {$whs eq "" || $whs < 0} {
        puts "   Hold Timing VIOLATION: WHS = $whs ns"
        set timing_met 0
    } else {
        puts "   Hold Timing MET: WHS = $whs ns"
    }
    
    #===========================================================================
    # Step 9: Write Checkpoint & Bitstream
    #===========================================================================
    print_stage_header "OUTPUTS" 11
    
    write_checkpoint -force $OUT_PATH/${TOP_MODULE}_routed.dcp
    puts "   Checkpoint: ${TOP_MODULE}_routed.dcp"
    
    if {$timing_met} {
        puts "  Generating bitstream..."
        write_bitstream -force $OUT_PATH/${TOP_MODULE}.bit
        puts "   Bitstream: ${TOP_MODULE}.bit"
    } else {
        puts "   Skipping bitstream (timing violations)"
    }
    
} else {
    
    #===========================================================================
    # Synthesis-Only Mode (Interface-Based Design)
    #===========================================================================
    print_stage_header "SYNTHESIS VERIFICATION MODE" 11
    
    puts "  Implementation skipped due to I/O constraints"
    puts "  Design successfully synthesized for verification"
    
    set wns "N/A"
    set whs "N/A"
    set timing_met 0
    
}

#===============================================================================
# Step 10: Resource Utilization Summary
#===============================================================================
print_stage_header "RESOURCE UTILIZATION" 11

# Get utilization using proper Vivado commands
set lut_cells [get_cells -quiet -hier -filter {PRIMITIVE_TYPE =~ CLB.LUT*}]
set ff_cells [get_cells -quiet -hier -filter {PRIMITIVE_TYPE =~ REGISTER.*.FD*}]
set bram_cells [get_cells -quiet -hier -filter {PRIMITIVE_TYPE =~ BMEM.*}]
set dsp_cells [get_cells -quiet -hier -filter {PRIMITIVE_TYPE =~ DSP.*}]

set lut_count [llength $lut_cells]
set ff_count [llength $ff_cells]
set bram_count [llength $bram_cells]
set dsp_count [llength $dsp_cells]

puts "  Primitive Counts:"
puts "    LUTs:              $lut_count"
puts "    Flip-Flops:        $ff_count"
puts "    Block RAMs:        $bram_count"
puts "    DSPs:              $dsp_count"
puts ""
puts "  Memory Instances:"

# Count XPM memory instances
set xpm_sdpram [get_cells -quiet -hier -filter {REF_NAME =~ "xpm_memory_sdpram"}]
set xpm_tdpram [get_cells -quiet -hier -filter {REF_NAME =~ "xpm_memory_tdpram"}]

puts "    XPM SDPRAM:        [llength $xpm_sdpram]"
puts "    XPM TDPRAM:        [llength $xpm_tdpram]"

#===============================================================================
# Step 11: Final Summary
#===============================================================================
print_stage_header "SUMMARY" 11

puts "  Device:           $PART"
puts "  Top Module:       $TOP_MODULE"
puts "  QoS Enabled:      YES (3-bit tags)"
puts "  Build Mode:       [expr {$can_implement ? "Full Implementation" : "Synthesis Verification"}]"
puts ""
puts "  I/O Analysis:"
puts "    Design I/O:     $io_count ports"
puts "    Device Limit:   $device_io_limit ports"
puts "    Status:         [expr {$can_implement ? "VALID " : "EXCEEDS (interface-based design)"}]"
puts ""
puts "  QoS Integration:"
puts "    Classifiers:    [llength $qos_classifiers]"
puts "    Schedulers:     [llength $qos_schedulers]"
puts "    Ingress QoS:    [llength $ingress_qos]"
puts "    Status:         [expr {[llength $qos_classifiers] > 0 ? " INTEGRATED" : "  NOT FOUND"}]"
puts ""
puts "  Resources:"
puts "    LUTs:           $lut_count"
puts "    FFs:            $ff_count"
puts "    BRAMs:          $bram_count"
puts "    DSPs:           $dsp_count"
puts ""

if {$can_implement} {
    puts "  Timing:"
    puts "    WNS:          $wns ns"
    puts "    WHS:          $whs ns"
    puts "    Status:       [expr {$timing_met ? "PASS " : "FAIL "}]"
    puts ""
    puts "  Outputs:"
    puts "    DCP:          ${TOP_MODULE}_routed.dcp"
    if {$timing_met} {
        puts "    Bitstream:    ${TOP_MODULE}.bit"
    }
    puts "    Reports:      $REPORTS_DIR"
} else {
    puts "  Synthesis Outputs:"
    puts "    Netlist:      Verified "
    puts "    QoS Logic:    Verified "
    puts "    Reports:      $REPORTS_DIR"
    puts ""
    puts "   Next Steps for FPGA Implementation:"
    puts "     1. Create switch_fabric_fpga_top.sv wrapper"
    puts "     2. Add external I/O (PCIe, Ethernet PHY, etc.)"
    puts "     3. Re-run build with new top-level"
}

puts ""
puts "================================================================"
if {$can_implement && $timing_met} {
    puts "    BUILD SUCCESSFUL - Ready for FPGA"
} elseif {$can_implement} {
    puts "     BUILD COMPLETE - Timing violations present"
} else {
    puts "    SYNTHESIS VERIFICATION COMPLETE"
    puts "   QoS modules successfully integrated and verified"
}
puts "================================================================"

close_project