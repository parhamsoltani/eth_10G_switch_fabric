# sim/sim_qos.tcl - QoS Simulation Runner with CSV Export Support

alias clc ".main clear"
clc

transcript file transcript_qos.log

file delete -force *~ *.ucdb vsim.dbg *.vstf *.log work/*.transcript.txt certe_dump.xml

# Create work library if needed
if {![file exists work]} {
    exec vlib work
}
vmap work work

file mkdir scr
file mkdir tb
file mkdir wlf
file mkdir wave
file mkdir logs
file mkdir results

set project_path        ".."
set include_path        "$project_path/src/inc"
set sim_include_path    "inc"

# Select testbench from environment or default
if {[info exists env(TB)]} {
    set TB $env(TB)
} elseif {[info exists TB]} {
    # TB already set
} else {
    set TB "tb_fabric_basic"
}

# Simulation mode
if {[info exists env(SIM_MODE)]} {
    set SIM_MODE $env(SIM_MODE)
} else {
    set SIM_MODE "gui"
}

set wlf_save_name       "wlf/${TB}.wlf"
set run_time            "500 us"
set compile_error       0
set VOPTARGS_SWITCH     "-voptargs=+acc"

puts "════════════════════════════════════════════════════════════"
puts "  QoS Switch Fabric Simulation"
puts "  Testbench: $TB"
puts "  Mode: $SIM_MODE"
puts "════════════════════════════════════════════════════════════"

# Common includes
set INCLUDE_OPTS [list +incdir+$include_path +incdir+$sim_include_path +define+SIMULATION]

#===============================================================================
# Compile Xilinx libraries
#===============================================================================
puts "\n\[1/4\] Compiling Xilinx primitives..."

set has_xilinx 0
if {[info exists env(XILINX_VIVADO)]} {
    set has_xilinx 1
    if {[catch {vlog -work work $::env(XILINX_VIVADO)/data/verilog/src/glbl.v} err]} {
        puts "ERROR: Failed to compile glbl.v: $err"
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
# Compile design files using test-specific script
#===============================================================================
if {$compile_error == 0} {
    puts "\n\[2/4\] Compiling design files..."

    set compile_script "scr/$TB/compile_all.tcl"
    if {[file exists $compile_script]} {
        puts "  Using: $compile_script"
        if {[catch {source $compile_script} err]} {
            puts "ERROR during compilation: $err"
            set compile_error 1
        }
    } else {
        # Try generic fabric basic compile script
        set generic_script "scr/tb_fabric_basic/compile_all.tcl"
        if {[file exists $generic_script]} {
            puts "  Using generic: $generic_script"
            if {[catch {source $generic_script} err]} {
                puts "ERROR during compilation: $err"
                set compile_error 1
            }
        } else {
            puts "ERROR: No compile script found for $TB"
            set compile_error 1
        }
    }
}

#===============================================================================
# Compile testbench
#===============================================================================
if {$compile_error == 0} {
    puts "\n\[3/4\] Compiling testbench: $TB"

    set TB_FILE ""
    foreach search_path {fabric unit integration ethernet_switch dfifo pipeline_mux} {
        set candidate "tb/${search_path}/${TB}.sv"
        if {[file exists $candidate]} {
            set TB_FILE $candidate
            break
        }
    }

    if {$TB_FILE == ""} {
        puts "ERROR: Testbench file not found for $TB"
        puts "  Searched: tb/fabric/, tb/unit/, tb/integration/, etc."
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

    # Suppress non-fatal errors
    onerror {continue}

    # Launch simulator
    if {$has_xilinx} {
        vsim -wlf $wlf_save_name -sv_seed 0 -wlfopt -wlfslim 10000 -wlftlim {500 ms} \
             $VOPTARGS_SWITCH -debugDB \
             $TB work.glbl
    } else {
        vsim -wlf $wlf_save_name -sv_seed 0 -wlfopt -wlfslim 10000 -wlftlim {500 ms} \
             $VOPTARGS_SWITCH -debugDB $TB
    }

    # Load wave configuration (GUI mode only)
    if {$SIM_MODE != "batch"} {
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
    }

    radix -hexadecimal -showbase

    # Run simulation
    if {$SIM_MODE == "batch"} {
        run -all
        
        puts "\n════════════════════════════════════════════════════════════"
        puts "  SIMULATION COMPLETE (batch mode)"
        puts "  Testbench: $TB"
        puts "════════════════════════════════════════════════════════════"
        
        quit -f
    } else {
        run $run_time
        
        puts "\n════════════════════════════════════════════════════════════"
        puts "  SIMULATION COMPLETE (GUI mode)"
        puts "  Testbench: $TB"
        puts "  Use 'run -all' to continue or 'quit' to exit"
        puts "════════════════════════════════════════════════════════════"
    }

} else {
    puts "\n════════════════════════════════════════════════════════════"
    puts "  COMPILATION FAILED - Check errors above"
    puts "════════════════════════════════════════════════════════════"
    
    if {$SIM_MODE == "batch"} {
        quit -f -code 1
    }
}

puts "\n"


# ═══════════════════════════════════════════════════════════════
# AUTO-EXIT FOR BATCH MODE
# ═══════════════════════════════════════════════════════════════
if {$SIM_MODE == "batch"} {
    puts "\n════════════════════════════════════════════════════════════"
    puts "  Batch mode - auto-exiting"
    puts "════════════════════════════════════════════════════════════"
    quit -sim
    quit -f
}