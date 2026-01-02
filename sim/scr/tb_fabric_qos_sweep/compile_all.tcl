# QoS Sweep Test Compilation Script
# Fixed to handle dual include paths and missing directories

set sim_include_path "inc"
set src_include_path "../src/inc"

# Common compilation flags
set vlog_flags "-vopt -sv +acc -incr -source +define+SIM"
set include_flags "+incdir+$sim_include_path +incdir+$src_include_path"

# Helper proc to compile files with existence check
proc safe_vlog {flags include_flags pattern} {
    set files [glob -nocomplain $pattern]
    if {[llength $files] > 0} {
        puts "  Compiling: $pattern ([llength $files] files)"
        vlog {*}$flags {*}$include_flags {*}$files
    } else {
        puts "  Skipping: $pattern (no files found)"
    }
}

puts "=============================================="
puts "  Compiling QoS Sweep Test"
puts "=============================================="

# Compile packages first
puts "\n\[1/8\] Compiling packages..."
vlog {*}$vlog_flags {*}$include_flags "hvl/model_for_verification/classes/fabric_frame_pkg.sv"

# Compile verification infrastructure
puts "\n\[2/8\] Compiling verification infrastructure..."
safe_vlog $vlog_flags $include_flags "hvl/verification/*.sv"
safe_vlog $vlog_flags $include_flags "hvl/model_for_verification/*.sv"

# Compile HVL components (submodules - may not exist)
puts "\n\[3/8\] Compiling HVL submodules..."
safe_vlog $vlog_flags $include_flags "ip/submodule/ethernet_switch_hvl/*.sv"

# Compile HDL components (submodules - may not exist)
puts "\n\[4/8\] Compiling HDL submodules..."
safe_vlog $vlog_flags $include_flags "ip/submodule/ethernet_switch_hdl/*.sv"
safe_vlog $vlog_flags $include_flags "ip/submodule/ethernet_switch_hdl/*/*.sv"
safe_vlog $vlog_flags $include_flags "ip/submodule/ethernet_switch_hdl/*/*/*.sv"

# Compile Xilinx IPs
puts "\n\[5/8\] Compiling Xilinx IP wrappers..."
safe_vlog $vlog_flags $include_flags "ip/xilinx_ips_sim/*.sv"

# Compile testbench
puts "\n\[6/8\] Compiling testbench..."
vlog {*}$vlog_flags {*}$include_flags "tb/fabric/tb_fabric_qos_sweep.sv"

# Compile DUT (FIXED: added switches folder, fixed path)
puts "\n\[7/8\] Compiling DUT..."
set dut_include "+incdir+$src_include_path"

safe_vlog $vlog_flags $dut_include "../src/hdl/interfaces/*.sv"
safe_vlog $vlog_flags $dut_include "../src/hdl/ip/*/*.sv"
safe_vlog $vlog_flags $dut_include "../src/hdl/ip/*/*/*.sv"
safe_vlog $vlog_flags $dut_include "../src/hdl/ip/*/*/*/*.sv"
safe_vlog $vlog_flags $dut_include "../src/hdl/core/*.sv"
safe_vlog $vlog_flags $dut_include "../src/hdl/line_modules/*.sv"
safe_vlog $vlog_flags $dut_include "../src/hdl/switch_ips/*.sv"
safe_vlog $vlog_flags $dut_include "../src/hdl/switches/*.sv"
safe_vlog $vlog_flags $dut_include "../src/hdl/*.sv"

puts "\n\[8/8\] Compilation complete!"
puts "==============================================\n"