set sim_include_path "inc"
set src_include_path "../src/inc"
set vlog_flags "-vopt -sv +acc -incr -source +define+SIM"
set include_flags "+incdir+$sim_include_path +incdir+$src_include_path"

if {[file exists work]} { vdel -lib work -all }
vlib work

# Verification infrastructure
vlog {*}$vlog_flags {*}$include_flags "hvl/model_for_verification/classes/fabric_frame_pkg.sv"
vlog {*}$vlog_flags {*}$include_flags "hvl/model_for_verification/fabric_driver.sv"
vlog {*}$vlog_flags {*}$include_flags "hvl/model_for_verification/fabric_monitor.sv"

# Interfaces
vlog {*}$vlog_flags {*}$include_flags "inc/implement_options.vh"
vlog {*}$vlog_flags {*}$include_flags "inc/switch_data_if.sv"
vlog {*}$vlog_flags {*}$include_flags "inc/switch_metadata_if.sv"

# Utilities
vlog {*}$vlog_flags {*}$include_flags "src/util/sdpram_xpm.sv"
vlog {*}$vlog_flags {*}$include_flags "src/util/delayed_regs.sv"

# DUT
vlog {*}$vlog_flags {*}$include_flags "src/switch_fabric.sv"

# Testbench
vlog {*}$vlog_flags {*}$include_flags "tb/fabric/tb_multicast.sv"

puts "Compilation complete. Run: vsim -do wave.tcl tb_multicast"