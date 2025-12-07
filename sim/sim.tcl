alias clc ".main clear"
clc

transcript file transcript_#.log

file delete -force *~ *.ucdb vsim.dbg *.vstf *.log work *.mem *.transcript.txt certe_dump.xml *.wlf

exec vlib work
vmap work work

file mkdir scr
file mkdir tb
file mkdir wlf
file mkdir wave

set project_path		".."
set include_path		"$project_path/src/inc"
set sim_include_path	"inc"

set INCLUDE_OPTS "+incdir+inc+$project_path/src/inc +define+SIM"

# Check if memory initialization files exist
set mem_init_path "inc/mem_init"
if {![file exists $mem_init_path] || [llength [glob -nocomplain "$mem_init_path/*.mem"]] == 0} {
    puts ""
    puts "========================================="
    puts "WARNING: Memory initialization files not found!"
    puts "Generating them now..."
    puts "========================================="
    puts ""

    # Run memory generation
    if {[catch {source mem_gen.tcl} result]} {
        puts "ERROR: Memory generation failed: $result"
        puts "Please check mem_gen.tcl"
    } else {
        puts ""
        puts "Memory files generated successfully"
        puts ""
    }
}

# set TB					"tb_voq_unit"
# set TB					"tb_ethernet_switch"
# set TB					"tb_fifo_array"
# set TB					"tb_packet_mode_fifo_array"
# set TB					"tb_pipeline_mux"
set TB					"tb_fabric_basic"

set wlf_save_name		"wlf/vsim.wlf"
set opened_wlf_name		"ref_sim"
set run_time			"200 us"

set compile_error		0

#VOPTARGS_SWITCH
	#"-voptargs=+acc=rnb+<module_name_1>+<module_name_2>+..."
	#"-voptargs=+acc"
	#""
	set VOPTARGS_SWITCH "-voptargs=+acc"

#===============================================================================
#===============================================================================

#========== compile modules
onerror {set compile_error 1}

# XILINX_VIVADO is an environment variable pointing to a (preferably the latest) VIVADO directory
if {[info exists env(XILINX_VIVADO)]} {
    vlog -work work $::env(XILINX_VIVADO)/data/verilog/src/glbl.v
    vlog -work work $::env(XILINX_VIVADO)/data/ip/xpm/xpm_fifo/hdl/xpm_fifo.sv
    vlog -work work $::env(XILINX_VIVADO)/data/ip/xpm/xpm_cdc/hdl/xpm_cdc.sv
    vlog -work work $::env(XILINX_VIVADO)/data/ip/xpm/xpm_memory/hdl/xpm_memory.sv
} else {
    puts "WARNING: XILINX_VIVADO environment variable not set"
    puts "Skipping Xilinx library compilation"
}

do scr/$TB/compile_all.tcl

#========== run simulation

# optimization is required for schematic view
if {$compile_error == 0} {

    # FIXED: Removed -L unisims_ver -L unimacro_ver since they don't exist
    # and aren't needed for pure RTL simulation
    vsim -wlf $wlf_save_name -sv_seed 0 -wlfopt -wlfslim 10000 -wlftlim {500 ms} \
         $VOPTARGS_SWITCH -debugDB \
         $TB work.glbl

    #========== adding signals to wave window
    # default radix (hex without base)
    # radix -hexadecimal -enumnumeric
    radix -hexadecimal -showbase

    # Check if wave.tcl exists before sourcing it
    if {[file exists scr/$TB/wave.tcl]} {
        do scr/$TB/wave.tcl
    } else {
        puts "WARNING: Wave configuration file scr/$TB/wave.tcl not found"
        puts "Adding default signals to waveform..."
        add wave -r sim:/$TB/*
    }

    #############################################

    configure wave -signalnamewidth 1

    configure wave -griddelta 40
    configure wave -gridoffset 0
    configure wave -gridperiod 10

    configure wave -timelineunits us
    configure wave -namecolwidth 200
    configure wave -valuecolwidth 50
    configure wave -justifyvalue right

    #########################################

    # run $run_time
    run -all

} else {
    puts ""
    puts "========================================="
    puts "COMPILATION FAILED"
    puts "========================================="
}