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

# Select testbench
if {[info exists env(TB)]} {
    set TB $env(TB)
} else {
    set TB "tb_qos_classifier_unit"
}

set wlf_save_name       "wlf/${TB}.wlf"
set run_time            "500 us"
set compile_error       0
set VOPTARGS_SWITCH     "-voptargs=+acc"

puts "════════════════════════════════════════════════════════════"
puts "  QoS Switch Fabric Simulation"
puts "  Testbench: $TB"
puts "════════════════════════════════════════════════════════════"

# Common includes - Using list instead of string
set INCLUDE_OPTS [list +incdir+$include_path +incdir+$sim_include_path +define+SIMULATION]

#===============================================================================
# Compile Xilinx libraries
#===============================================================================
puts "\n\[1/4\] Compiling Xilinx primitives..."

set has_xilinx 0
if {[info exists env(XILINX_VIVADO)]} {
    set has_xilinx 1
    if {[catch {vlog -work work $::env(XILINX_VIVADO)/data/verilog/src/glbl.v} err]} {
        puts "ERROR: Failed to compile glbl.v"
        set compile_error 1
    }
    if {$compile_error == 0} {
        catch {vlog -work work $::env(XILINX_VIVADO)/data/ip/xpm/xpm_fifo/hdl/xpm_fifo.sv}
        catch {vlog -work work $::env(XILINX_VIVADO)/data/ip/xpm/xpm_cdc/hdl/xpm_cdc.sv}
        catch {vlog -work work $::env(XILINX_VIVADO)/data/ip/xpm/xpm_memory/hdl/xpm_memory.sv}
    }
} else {
    puts "WARNING: XILINX_VIVADO not set, skipping Xilinx libraries"
}

#===============================================================================
# Compile design files
#===============================================================================
if {$compile_error == 0} {
    puts "\n\[2/4\] Compiling design files..."

    if {[file exists "scr/$TB/compile_all.tcl"]} {
        puts "  Using scr/$TB/compile_all.tcl"
        if {[catch {do scr/$TB/compile_all.tcl} err]} {
            puts "ERROR during design compilation: $err"
            set compile_error 1
        }
    } else {
        puts "  Using generic QoS compilation order"
        
        # Wrap each compilation in catch to detect errors
        set files_to_compile {
            "hvl/model_for_verification/classes/fabric_frame_pkg.sv"
            "../src/hdl/interfaces/switch_data_if.sv"
            "../src/hdl/interfaces/switch_metadata_if.sv"
            "../src/hdl/ip/dest_mask_modules/first_non_zero.sv"
            "../src/hdl/ip/dest_mask_modules/first_non_zero_no_delay.sv"
            "../src/hdl/ip/fifos/simple_fifo/simple_fifo.sv"
            "../src/hdl/ip/memories/sdpram_xpm/sdpram_xpm.sv"
            "../src/hdl/core/qos_classifier.sv"
        }
        
        foreach f $files_to_compile {
            if {[file exists $f]} {
                if {[catch {eval vlog -sv $INCLUDE_OPTS $f} err]} {
                    puts "ERROR compiling $f: $err"
                    set compile_error 1
                    break
                }
            } else {
                puts "WARNING: File not found: $f"
            }
        }
    }
}

#===============================================================================
# Compile testbench
#===============================================================================
if {$compile_error == 0} {
    puts "\n\[3/4\] Compiling testbench: $TB"

    set TB_FILE ""
    foreach search_path {fabric unit ethernet_switch dfifo pipeline_mux} {
        if {[file exists "tb/${search_path}/${TB}.sv"]} {
            set TB_FILE "tb/${search_path}/${TB}.sv"
            break
        }
    }

    if {$TB_FILE == ""} {
        puts "ERROR: Testbench file not found for $TB"
        puts "  Searched: tb/fabric/, tb/unit/, tb/ethernet_switch/, tb/dfifo/, tb/pipeline_mux/"
        set compile_error 1
    } else {
        puts "  Found: $TB_FILE"
        if {[catch {eval vlog -sv $INCLUDE_OPTS $TB_FILE} err]} {
            puts "ERROR compiling testbench: $err"
            set compile_error 1
        }
    }
}

#===============================================================================
# Run simulation
#===============================================================================
if {$compile_error == 0} {
    puts "\n\[4/4\] Starting simulation..."

    # Suppress non-fatal errors during simulation
    onerror {continue}

    # Launch simulator (without unisims_ver/unimacro_ver if they don't exist)
    if {$has_xilinx} {
        vsim -wlf $wlf_save_name -sv_seed 0 -wlfopt -wlfslim 10000 -wlftlim {500 ms} \
             $VOPTARGS_SWITCH -debugDB \
             $TB work.glbl
    } else {
        vsim -wlf $wlf_save_name -sv_seed 0 -wlfopt -wlfslim 10000 -wlftlim {500 ms} \
             $VOPTARGS_SWITCH -debugDB $TB
    }

    # Load wave configuration
    if {[file exists "scr/$TB/wave.tcl"]} {
        puts "  Loading wave config: scr/$TB/wave.tcl"
        catch {do scr/$TB/wave.tcl}
    } elseif {[file exists "wave_${TB}.do"]} {
        puts "  Loading wave config: wave_${TB}.do"
        catch {do wave_${TB}.do}
    } else {
        puts "  No wave config found - using defaults"
        catch {add wave -r /*}
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

    radix -hexadecimal -showbase

    # Run simulation
    if {[info exists env(SIM_MODE)] && $env(SIM_MODE) == "batch"} {
        run -all
        puts "\n════════════════════════════════════════════════════════════"
        puts "  SIMULATION COMPLETE (batch mode)"
        puts "════════════════════════════════════════════════════════════"
        quit -f
    } else {
        run $run_time
        puts "\n════════════════════════════════════════════════════════════"
        puts "  SIMULATION COMPLETE"
        puts "════════════════════════════════════════════════════════════"
    }

} else {
    puts "\n════════════════════════════════════════════════════════════"
    puts "  COMPILATION FAILED - Check errors above"
    puts "════════════════════════════════════════════════════════════"
}