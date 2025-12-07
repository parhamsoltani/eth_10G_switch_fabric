# QoS Stress Test Compilation Script
# Fixed to handle dual include paths

set sim_include_path "inc"
set src_include_path "../src/inc"

# Common compilation flags
set vlog_flags "-vopt -sv +acc -incr -source +define+SIM"
set include_flags "+incdir+$sim_include_path +incdir+$src_include_path"

# Compile packages first
vlog {*}$vlog_flags {*}$include_flags "hvl/model_for_verification/classes/fabric_frame_pkg.sv"

# Compile verification infrastructure
vlog {*}$vlog_flags {*}$include_flags "hvl/verification/*.sv"
vlog {*}$vlog_flags {*}$include_flags "hvl/model_for_verification/*.sv"

# Compile HVL components
vlog {*}$vlog_flags {*}$include_flags "ip/submodule/ethernet_switch_hvl/*.sv"

# Compile HDL components
vlog {*}$vlog_flags {*}$include_flags "ip/submodule/ethernet_switch_hdl/*.sv"
vlog {*}$vlog_flags {*}$include_flags "ip/submodule/ethernet_switch_hdl/*/*.sv"
vlog {*}$vlog_flags {*}$include_flags "ip/submodule/ethernet_switch_hdl/*/*/*.sv"

# Compile Xilinx IPs
vlog {*}$vlog_flags {*}$include_flags "ip/xilinx_ips_sim/*.sv"

# Compile testbench
vlog {*}$vlog_flags {*}$include_flags "tb/fabric/tb_fabric_qos_stress.sv"

# Compile DUT
vlog {*}$vlog_flags +incdir+$src_include_path "$project_path/src/hdl/interfaces/*.sv"
vlog {*}$vlog_flags +incdir+$src_include_path "$project_path/src/hdl/ip/*/*.sv"
vlog {*}$vlog_flags +incdir+$src_include_path "$project_path/src/hdl/ip/*/*/*.sv"
vlog {*}$vlog_flags +incdir+$src_include_path "$project_path/src/hdl/ip/*/*/*/*.sv"
vlog {*}$vlog_flags +incdir+$src_include_path "$project_path/src/hdl/core/*.sv"
vlog {*}$vlog_flags +incdir+$src_include_path "$project_path/src/hdl/line_modules/*.sv"
vlog {*}$vlog_flags +incdir+$src_include_path "$project_path/src/hdl/switch_ips/*.sv"
vlog {*}$vlog_flags +incdir+$src_include_path "$project_path/src/hdl/*.sv"