# ==============================================================================
# Compilation Script for tb_ethernet_switch
# ==============================================================================

puts "================================================================================"
puts "  Compiling Ethernet Switch Testbench"
puts "================================================================================"

# ===========================================================================
# 1. Environment and Path Setup
# ===========================================================================

set SIM_DIR [pwd]
set SRC_INC_DIR [file normalize "${SIM_DIR}/../src/inc"]
set SIM_INC_DIR [file normalize "${SIM_DIR}/inc"]
set PROJECT_SRC_DIR [file normalize "${SIM_DIR}/../src"]

# CRITICAL FIX: Build include options as a proper Tcl list
# Each element must be a separate list item for proper argument expansion
set INCLUDE_OPTS [list \
    "+incdir+${SRC_INC_DIR}" \
    "+incdir+${SIM_INC_DIR}" \
    "+define+SIMULATION" \
    "+define+SIM" \
]

puts "DEBUG: SIM_DIR = $SIM_DIR"
puts "DEBUG: SRC_INC_DIR = $SRC_INC_DIR"
puts "DEBUG: SIM_INC_DIR = $SIM_INC_DIR"
puts "DEBUG: INCLUDE_OPTS = $INCLUDE_OPTS"
puts ""

# Initialize error flag
set compile_error 0

# ==============================================================================
# Helper procedure for vlog with proper argument expansion
# ==============================================================================
proc compile_sv {files {description ""}} {
    global INCLUDE_OPTS compile_error
    
    if {$description ne ""} {
        puts "  Compiling: $description"
    }
    
    # Use {*} to expand the list into individual arguments
    if {[catch {
        vlog -reportprogress 300 -vopt -sv +acc -incr {*}$INCLUDE_OPTS {*}$files
    } result]} {
        puts "ERROR: Compilation failed for $description"
        puts $result
        return 1
    }
    return 0
}

# ==============================================================================
# Step 2: Compile Packages
# ==============================================================================
puts ""
puts "Compiling fabric_frame_pkg..."
if {[compile_sv hvl/model_for_verification/classes/fabric_frame_pkg.sv "fabric_frame_pkg"]} {
    set compile_error 1
    return
}
puts "Package compiled"


# After compiling fabric_frame_pkg, add:

# Compile Ethernet frame package
puts "Compiling ethernet_frame_pkg..."
if {[file exists hvl/model_for_verification/classes/ethernet_frame_class.sv]} {
    compile_sv hvl/model_for_verification/classes/ethernet_frame_class.sv "ethernet_frame_pkg"
}

# Compile verification components
puts "Compiling verification components..."
set verif_components {
    hvl/model_for_verification/axi_driver.sv
    hvl/model_for_verification/monitor.sv
    hvl/model_for_verification/switch_model.sv
    hvl/model_for_verification/ethernet_switch_wrapper.sv
    hvl/verification/score_board.sv
}

foreach comp $verif_components {
    if {[file exists $comp]} {
        compile_sv $comp [file tail $comp]
    }
}

# ==============================================================================
# Step 3: Compile Verification Infrastructure
# ==============================================================================
puts ""
puts "Compiling verification infrastructure..."
set verif_files [list \
    hvl/model_for_verification/fabric_driver.sv \
    hvl/model_for_verification/fabric_monitor.sv \
    hvl/model_for_verification/switch_fabric_model_qos.sv \
]
if {[compile_sv $verif_files "verification infrastructure"]} {
    set compile_error 1
    return
}
puts "Verification infrastructure compiled"

# ==============================================================================
# Step 4: Compile ILA IPs
# ==============================================================================
puts ""
puts "Compiling ILA IPs..."
if {[compile_sv ip/xilinx_ips_sim/ila_ips.sv "ILA IPs"]} {
    set compile_error 1
    return
}
puts "ILA IPs compiled"

# ==============================================================================
# Step 5: Compile Testbenches
# ==============================================================================
puts ""
puts "Compiling testbenches..."

# Basic testbenches
puts "Basic testbenches..."
set basic_tb_files [list \
    tb/dfifo/tb_fifo_array.sv \
    tb/dfifo/tb_packet_mode_fifo_array.sv \
    tb/pipeline_mux/tb_pipeline_mux.sv \
]
if {[compile_sv $basic_tb_files "basic testbenches"]} {
    set compile_error 1
    return
}
puts "Basic testbenches compiled"

# Fabric testbenches
puts "Fabric testbenches..."
compile_sv tb/fabric/tb_fabric_basic.sv "tb_fabric_basic"

# QoS fabric testbenches (non-fatal errors allowed)
puts "QoS fabric testbenches..."
set qos_files {
    tb/fabric/tb_fabric_qos_complete.sv
    tb/fabric/tb_fabric_qos_enhanced.sv
    tb/fabric/tb_fabric_qos_stress.sv
    tb/fabric/tb_fabric_qos_sweep.sv
}

foreach qos_file $qos_files {
    if {[file exists $qos_file]} {
        if {![compile_sv $qos_file [file tail $qos_file]]} {
            puts "  [file tail $qos_file] compiled"
        } else {
            puts "  [file tail $qos_file] skipped (errors)"
        }
    }
}

# Unit testbenches
puts "Unit testbenches..."
set unit_files {
    tb/unit/tb_qos_classifier_unit.sv
    tb/unit/tb_qos_scheduler_unit.sv
    tb/unit/tb_voq_unit.sv
}

foreach unit_file $unit_files {
    if {[file exists $unit_file]} {
        if {![compile_sv $unit_file [file tail $unit_file]]} {
            puts "  [file tail $unit_file] compiled"
        } else {
            puts "  [file tail $unit_file] skipped (errors)"
        }
    }
}

# Ethernet switch testbench components
puts "Ethernet switch testbench..."
if {[file exists tb/ethernet_switch/generator_frame.sv]} {
    if {![compile_sv tb/ethernet_switch/generator_frame.sv "generator_frame.sv"]} {
        puts "  generator_frame.sv compiled"
    } else {
        puts "  generator_frame.sv has issues (continuing)"
    }
}

if {[file exists tb/ethernet_switch/tb_ethernet_switch.sv]} {
    if {![compile_sv tb/ethernet_switch/tb_ethernet_switch.sv "tb_ethernet_switch.sv"]} {
        puts "  tb_ethernet_switch.sv compiled"
    } else {
        puts "  tb_ethernet_switch.sv has issues"
    }
}

# ==============================================================================
# Step 6: Compile Top-Level Design
# ==============================================================================
puts ""
puts "Compiling top-level design..."
set top_files [list \
    $PROJECT_SRC_DIR/hdl/switch_fabric.sv \
    $PROJECT_SRC_DIR/hdl/switch_fabric_qos_wrapper.sv \
]
compile_sv $top_files "top-level design"

# ==============================================================================
# Step 7: Compile Core Modules
# ==============================================================================
puts ""
puts "Compiling core modules..."
set core_dirs {
    arbitration
    buffers
    core
    fabric
    interfaces
    line_modules
    micro_interface
}

foreach dir $core_dirs {
    set files [glob -nocomplain $PROJECT_SRC_DIR/hdl/$dir/*.sv]
    if {[llength $files] > 0} {
        puts "  • $dir..."
        compile_sv $files $dir
    }
}

# ==============================================================================
# Step 8: Compile Switch IPs and Wrappers
# ==============================================================================
puts ""
puts "Compiling switch IPs and wrappers..."
set switch_dirs {
    switch_ips
    switches
    wrappers
}

foreach dir $switch_dirs {
    set files [glob -nocomplain $PROJECT_SRC_DIR/hdl/$dir/*.sv]
    if {[llength $files] > 0} {
        puts "  • $dir..."
        compile_sv $files $dir
    }
}

# ==============================================================================
# Step 9: Compile IP Components
# ==============================================================================
puts ""
puts "Compiling IP components..."

# Combinational components
set comb_files [glob -nocomplain $PROJECT_SRC_DIR/hdl/ip/combinational_components/*.sv]
if {[llength $comb_files] > 0} {
    puts "  • Combinational components..."
    compile_sv $comb_files "combinational_components"
}

# Other IP subdirectories
set ip_subdirs {
    delayed_regs
    dest_mask_modules
    pipeline_mem
    pipeline_mux
    register_replicator
}

foreach subdir $ip_subdirs {
    set files [glob -nocomplain $PROJECT_SRC_DIR/hdl/ip/$subdir/*.sv]
    if {[llength $files] > 0} {
        puts "  • $subdir..."
        compile_sv $files $subdir
    }
}

# FIFOs
puts "  FIFO components..."
set fifo_subdirs {
    fifos/axis_fifo
    fifos/dynamic_fifo
    fifos/init_fifo
    fifos/simple_fifo
}

foreach subdir $fifo_subdirs {
    set files [glob -nocomplain $PROJECT_SRC_DIR/hdl/ip/$subdir/*.sv]
    if {[llength $files] > 0} {
        compile_sv $files "fifos/$subdir"
    }
}

# Memories
puts "  Memory components..."
set mem_subdirs {
    memories/init_mem
    memories/sdpram_xpm
}

foreach subdir $mem_subdirs {
    set files [glob -nocomplain $PROJECT_SRC_DIR/hdl/ip/$subdir/*.sv]
    if {[llength $files] > 0} {
        compile_sv $files "memories/$subdir"
    }
}

# ==============================================================================
# Summary
# ==============================================================================
puts ""
puts "================================================================================"
if {$compile_error == 0} {
    puts " Compilation Complete (check for warnings above)"
} else {
    puts " Compilation had CRITICAL ERRORS"
}
puts "================================================================================"
puts ""