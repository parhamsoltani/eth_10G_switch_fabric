alias clc ".main clear"
clc

transcript file transcript_qos.log

file delete -force *~ *.ucdb vsim.dbg *.vstf *.log *.mem *.transcript.txt certe_dump.xml *.wlf

exec vlib work
vmap work work

file mkdir scr
file mkdir tb
file mkdir wlf
file mkdir wave

set project_path        ".."
set include_path        "$project_path/src/inc"
set sim_include_path    "inc"

# Select testbench (override with environment variable if set)
if {[info exists env(TB)]} {
    set TB $env(TB)
} else {
    # Default testbenches - uncomment one:
    # set TB "tb_fabric_basic"
    # set TB "tb_fabric_qos_sweep"
    # set TB "tb_fabric_qos_stress"
    # set TB "tb_voq_unit"
    set TB "tb_qos_classifier_unit"
    # set TB "tb_qos_scheduler_unit"
}

set wlf_save_name       "wlf/${TB}.wlf"
set run_time            "500 us"
set compile_error       0

# Optimization arguments
set VOPTARGS_SWITCH "-voptargs=+acc"

puts "════════════════════════════════════════════════════════════"
puts "  QoS Switch Fabric Simulation"
puts "  Testbench: $TB"
puts "════════════════════════════════════════════════════════════"

#===============================================================================
# Compile Xilinx libraries
#===============================================================================
puts "\n[1/4] Compiling Xilinx primitives..."
onerror {set compile_error 1}

if {[info exists env(XILINX_VIVADO)]} {
    vlog -work work $::env(XILINX_VIVADO)/data/verilog/src/glbl.v
    vlog -work work $::env(XILINX_VIVADO)/data/ip/xpm/xpm_fifo/hdl/xpm_fifo.sv
    vlog -work work $::env(XILINX_VIVADO)/data/ip/xpm/xpm_cdc/hdl/xpm_cdc.sv
    vlog -work work $::env(XILINX_VIVADO)/data/ip/xpm/xpm_memory/hdl/xpm_memory.sv
} else {
    puts "WARNING: XILINX_VIVADO not set, skipping Xilinx libraries"
}

#===============================================================================
# Compile design files (based on testbench type)
#===============================================================================
puts "\n[2/4] Compiling design files..."

# Common includes
set INCLUDE_OPTS "+incdir+$include_path +incdir+$sim_include_path +define+SIMULATION"

# Determine compile script based on testbench
if {[file exists "scr/$TB/compile_all.tcl"]} {
    # Use testbench-specific compile script
    puts "  Using scr/$TB/compile_all.tcl"
    do scr/$TB/compile_all.tcl
} else {
    # Generic QoS fabric compilation order
    puts "  Using generic QoS compilation order"

    # Packages
    vlog -sv $INCLUDE_OPTS tb/ethernet_switch/generator_frame.sv
    vlog -sv $INCLUDE_OPTS hvl/model_for_verification/classes/fabric_frame_pkg.sv

    # Interfaces
    vlog -sv $INCLUDE_OPTS ../src/hdl/interfaces/switch_data_if.sv
    vlog -sv $INCLUDE_OPTS ../src/hdl/interfaces/switch_metadata_if.sv

    # IP components
    vlog -sv $INCLUDE_OPTS ../src/hdl/ip/dest_mask_modules/first_non_zero.sv
    vlog -sv $INCLUDE_OPTS ../src/hdl/ip/dest_mask_modules/first_non_zero_no_delay.sv
    vlog -sv $INCLUDE_OPTS ../src/hdl/ip/combinational_components/first_none_zero_except_k_qos.sv
    vlog -sv $INCLUDE_OPTS ../src/hdl/ip/fifos/simple_fifo/simple_fifo.sv
    vlog -sv $INCLUDE_OPTS ../src/hdl/ip/memories/sdpram_xpm/sdpram_xpm.sv

    # Core modules
    vlog -sv $INCLUDE_OPTS ../src/hdl/core/qos_classifier.sv
    vlog -sv $INCLUDE_OPTS ../src/hdl/core/qos_shaper.sv
    vlog -sv $INCLUDE_OPTS ../src/hdl/ip/fifos/dynamic_fifo/packet_mode_fifo_array.sv
    vlog -sv $INCLUDE_OPTS ../src/hdl/switch_ips/des_finder_row_matching_qos.sv

    # Top-level fabric (if needed)
    if {$TB != "tb_voq_unit" && $TB != "tb_qos_classifier_unit" && $TB != "tb_qos_scheduler_unit"} {
        vlog -sv $INCLUDE_OPTS ../src/hdl/switch_fabric.sv
    }

    # Verification infrastructure
    if {[string match "*qos*" $TB]} {
        vlog -sv $INCLUDE_OPTS hvl/verification/qos_latency_monitor.sv
        vlog -sv $INCLUDE_OPTS hvl/verification/qos_checker_scoreboard.sv
        vlog -sv $INCLUDE_OPTS hvl/model_for_verification/switch_fabric_model_qos.sv
    }
}

#===============================================================================
# Compile testbench
#===============================================================================
# Compile testbench
puts "\n[3/4] Compiling testbench: $TB"

# Find testbench file
set TB_FILE ""
foreach search_path {fabric unit ethernet_switch dfifo pipeline_mux} {
    if {[file exists "tb/${search_path}/${TB}.sv"]} {
        set TB_FILE "tb/${search_path}/${TB}.sv"
        break
    }
}

if {$TB_FILE == ""} {
    puts "ERROR: Testbench file not found for $TB"
    puts "  Searched: tb/fabric/, tb/unit/, tb/ethernet_switch/"
    set compile_error 1
} else {
    vlog -sv $INCLUDE_OPTS $TB_FILE
}

#===============================================================================
# Run simulation
#===============================================================================
if {$compile_error == 0} {
    puts "\n[4/4] Starting simulation..."

    # Optimize design
    vopt +acc $TB -o ${TB}_opt

    # Launch simulator
    if {[info exists env(XILINX_VIVADO)]} {
        vsim -wlf $wlf_save_name -sv_seed 0 -wlfopt -wlfslim 10000 -wlftlim {500 ms} \
             $VOPTARGS_SWITCH -debugDB \
             -L unisims_ver -L unimacro_ver ${TB}_opt work.glbl
    } else {
        vsim -wlf $wlf_save_name -sv_seed 0 -wlfopt -wlfslim 10000 -wlftlim {500 ms} \
             $VOPTARGS_SWITCH -debugDB ${TB}_opt
    }

    # Load wave configuration
    if {[file exists "scr/$TB/wave.tcl"]} {
        puts "  Loading wave config: scr/$TB/wave.tcl"
        do scr/$TB/wave.tcl
    } elseif {[file exists "wave_${TB}.do"]} {
        puts "  Loading wave config: wave_${TB}.do"
        do wave_${TB}.do
    } else {
        puts "  No wave config found - using defaults"
        add wave -r /*
    }

    # Wave window configuration
    configure wave -signalnamewidth 1
    configure wave -griddelta 40
    configure wave -gridoffset 0
    configure wave -gridperiod 10
    configure wave -timelineunits us
    configure wave -namecolwidth 250
    configure wave -valuecolwidth 80
    configure wave -justifyvalue right

    # Run simulation
    radix -hexadecimal -showbase

    if {[info exists env(SIM_MODE)] && $env(SIM_MODE) == "batch"} {
        run -all
        quit -f
    } else {
        run $run_time
    }

} else {
    puts "\nCOMPILATION FAILED"
    quit -code 1
}
