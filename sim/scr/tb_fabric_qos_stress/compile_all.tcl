# QoS Stress Test Compilation Script
# Fixed to handle dual include paths and optional directories

set sim_include_path "inc"
set src_include_path "../src/inc"

# Common compilation flags
set vlog_flags "-vopt -sv +acc -incr -source +define+SIM"
set include_flags "+incdir+$sim_include_path +incdir+$src_include_path"

# Helper proc to compile files if they exist
proc compile_if_exists {pattern flags} {
    set files [glob -nocomplain $pattern]
    if {[llength $files] > 0} {
        vlog {*}$flags $pattern
        return 1
    } else {
        puts "INFO: No files matching $pattern, skipping..."
        return 0
    }
}

# Compile packages first
vlog {*}$vlog_flags {*}$include_flags "hvl/model_for_verification/classes/fabric_frame_pkg.sv"

# Compile verification infrastructure
vlog {*}$vlog_flags {*}$include_flags "hvl/verification/*.sv"
vlog {*}$vlog_flags {*}$include_flags "hvl/model_for_verification/*.sv"

# Compile HVL components (optional)
compile_if_exists "ip/submodule/ethernet_switch_hvl/*.sv" "$vlog_flags $include_flags"

# Compile HDL submodule components (optional)
compile_if_exists "ip/submodule/ethernet_switch_hdl/*.sv" "$vlog_flags $include_flags"
compile_if_exists "ip/submodule/ethernet_switch_hdl/*/*.sv" "$vlog_flags $include_flags"
compile_if_exists "ip/submodule/ethernet_switch_hdl/*/*/*.sv" "$vlog_flags $include_flags"

# Compile Xilinx IPs simulation stubs
compile_if_exists "ip/xilinx_ips_sim/*.sv" "$vlog_flags $include_flags"

# Compile testbench
vlog {*}$vlog_flags {*}$include_flags "tb/fabric/tb_fabric_qos_stress.sv"

# Compile DUT - interfaces first
vlog {*}$vlog_flags +incdir+$src_include_path "$project_path/src/hdl/interfaces/*.sv"

# Compile DUT - IP blocks (check each level)
compile_if_exists "$project_path/src/hdl/ip/*/*.sv" "$vlog_flags +incdir+$src_include_path"
compile_if_exists "$project_path/src/hdl/ip/*/*/*.sv" "$vlog_flags +incdir+$src_include_path"
compile_if_exists "$project_path/src/hdl/ip/*/*/*/*.sv" "$vlog_flags +incdir+$src_include_path"

# Compile DUT - core modules
vlog {*}$vlog_flags +incdir+$src_include_path "$project_path/src/hdl/core/*.sv"

# Compile DUT - line modules (optional)
compile_if_exists "$project_path/src/hdl/line_modules/*.sv" "$vlog_flags +incdir+$src_include_path"

# Compile DUT - switch IPs (optional)
compile_if_exists "$project_path/src/hdl/switch_ips/*.sv" "$vlog_flags +incdir+$src_include_path"

# Compile DUT - top level
vlog {*}$vlog_flags +incdir+$src_include_path "$project_path/src/hdl/*.sv"

puts "Compilation complete for tb_fabric_qos_stress"