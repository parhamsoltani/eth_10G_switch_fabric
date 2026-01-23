set sim_include_path "inc"
set src_include_path "../src/inc"
set vlog_flags "-vopt -sv +acc -incr -source +define+SIM"
set include_flags "+incdir+$sim_include_path +incdir+$src_include_path"

if {[file exists work]} { vdel -lib work -all }
vlib work
vmap work work

# Compile Xilinx globals and IPs (add if not already handled externally)
vlog "C:/Xilinx/Vivado/2019.1/data/verilog/src/glbl.v"
vlog "C:/Xilinx/Vivado/2019.1/data/ip/xpm/xpm_fifo/hdl/xpm_fifo.sv"
vlog "C:/Xilinx/Vivado/2019.1/data/ip/xpm/xpm_cdc/hdl/xpm_cdc.sv"
vlog "C:/Xilinx/Vivado/2019.1/data/ip/xpm/xpm_memory/hdl/xpm_memory.sv"

# User files
vlog {*}$vlog_flags {*}$include_flags "hvl/model_for_verification/classes/fabric_frame_pkg.sv"
vlog {*}$vlog_flags {*}$include_flags "hvl/model_for_verification/fabric_driver.sv"

# Comment out if .vh is pure header (no modules/packages); otherwise use correct path
# vlog {*}$vlog_flags {*}$include_flags "$src_include_path/implement_options.vh"
vlog {*}$vlog_flags {*}$include_flags "$src_include_path/switch_data_if.sv"
vlog {*}$vlog_flags {*}$include_flags "$src_include_path/switch_metadata_if.sv"

vlog {*}$vlog_flags {*}$include_flags "src/util/sdpram_xpm.sv"
vlog {*}$vlog_flags {*}$include_flags "src/util/delayed_regs.sv"

vlog {*}$vlog_flags {*}$include_flags "src/switch_fabric.sv"
vlog {*}$vlog_flags {*}$include_flags "tb/fabric/tb_wfq.sv"

puts "Compilation complete."