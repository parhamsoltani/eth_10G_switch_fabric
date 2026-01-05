# VLAN PCP Test Compilation Script
set sim_include_path "inc"
set src_include_path "../src/inc"
set vlog_flags "-vopt -sv +acc -incr -source +define+SIM"
set include_flags "+incdir+$sim_include_path +incdir+$src_include_path"

# Clean previous compilation
if {[file exists work]} {
    vdel -lib work -all
}
vlib work

# Compile verification infrastructure
vlog {*}$vlog_flags {*}$include_flags "hvl/model_for_verification/classes/fabric_frame_pkg.sv"
vlog {*}$vlog_flags {*}$include_flags "hvl/model_for_verification/fabric_driver.sv"
vlog {*}$vlog_flags {*}$include_flags "hvl/model_for_verification/fabric_monitor.sv"

# Compile DUT RTL files
vlog {*}$vlog_flags {*}$include_flags "inc/implement_options.vh"
vlog {*}$vlog_flags {*}$include_flags "inc/switch_data_if.sv"
vlog {*}$vlog_flags {*}$include_flags "inc/switch_metadata_if.sv"

# Compile utility modules
vlog {*}$vlog_flags {*}$include_flags "src/util/sdpram_xpm.sv"
vlog {*}$vlog_flags {*}$include_flags "src/util/delayed_regs.sv"

# Compile DUT core
vlog {*}$vlog_flags {*}$include_flags "src/switch_fabric.sv"

# Compile testbench
vlog {*}$vlog_flags {*}$include_flags "tb/fabric/tb_vlan_pcp.sv"

puts "Compilation complete. Use 'vsim -do wave.tcl tb_vlan_pcp' to run."