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

set project_path        ".."
set include_path        "$project_path/src/inc"
set sim_include_path    "inc"

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

    if {[catch {source mem_gen.tcl} result]} {
        puts "ERROR: Memory generation failed: $result"
        puts "Please check mem_gen.tcl"
    } else {
        puts ""
        puts "Memory files generated successfully"
        puts ""
    }
}

set TB                  "tb_fabric_basic"
set wlf_save_name       "wlf/vsim.wlf"
set opened_wlf_name     "ref_sim"
set run_time            "200 us"
set compile_error       0
set VOPTARGS_SWITCH     "-voptargs=+acc"

#===============================================================================
# Compile Xilinx libraries
#===============================================================================
puts "\n========================================="
puts "Compiling Xilinx libraries..."
puts "========================================="

if {[info exists env(XILINX_VIVADO)]} {
    if {[catch {vlog -work work $::env(XILINX_VIVADO)/data/verilog/src/glbl.v} err]} {
        puts "ERROR compiling glbl.v: $err"
        set compile_error 1
    }
    if {$compile_error == 0 && [catch {vlog -work work $::env(XILINX_VIVADO)/data/ip/xpm/xpm_fifo/hdl/xpm_fifo.sv} err]} {
        puts "ERROR compiling xpm_fifo.sv: $err"
        set compile_error 1
    }
    if {$compile_error == 0 && [catch {vlog -work work $::env(XILINX_VIVADO)/data/ip/xpm/xpm_cdc/hdl/xpm_cdc.sv} err]} {
        puts "ERROR compiling xpm_cdc.sv: $err"
        set compile_error 1
    }
    if {$compile_error == 0 && [catch {vlog -work work $::env(XILINX_VIVADO)/data/ip/xpm/xpm_memory/hdl/xpm_memory.sv} err]} {
        puts "ERROR compiling xpm_memory.sv: $err"
        set compile_error 1
    }
} else {
    puts "WARNING: XILINX_VIVADO environment variable not set"
    puts "Skipping Xilinx library compilation"
}

#===============================================================================
# Compile design files
#===============================================================================
if {$compile_error == 0} {
    puts "\n========================================="
    puts "Compiling design files..."
    puts "========================================="
    
    if {[file exists "scr/$TB/compile_all.tcl"]} {
        if {[catch {do scr/$TB/compile_all.tcl} err]} {
            puts "ERROR during compilation: $err"
            set compile_error 1
        }
    } else {
        puts "ERROR: Compile script scr/$TB/compile_all.tcl not found"
        set compile_error 1
    }
}

#===============================================================================
# Run simulation
#===============================================================================
if {$compile_error == 0} {

    puts "Starting simulation..."

    # Launch vsim
    vsim -wlf wlf/vsim.wlf -voptargs="+acc" tb_fabric_basic work.glbl

    # Configure radix
    radix -hexadecimal -showbase

    # Load wave configuration with error handling
    if {[file exists "scr/tb_fabric_basic/wave.do"]} {
        puts "Loading wave configuration..."
        onerror {continue}
        catch {do scr/tb_fabric_basic/wave.do}
        onerror {abort}
    } else {
        puts "No wave.do found, adding all signals..."
        add wave -r /tb_fabric_basic/*
    }

    # Configure wave display
    configure wave -signalnamewidth 1
    configure wave -namecolwidth 200
    configure wave -valuecolwidth 80
    configure wave -timelineunits us

    # Run simulation
    run -all

    puts ""
    puts "========================================="
    puts "SIMULATION COMPLETE"
    puts "========================================="
} else {
    puts ""
    puts "========================================="
    puts "COMPILATION FAILED - Simulation not started"
    puts "========================================="
}