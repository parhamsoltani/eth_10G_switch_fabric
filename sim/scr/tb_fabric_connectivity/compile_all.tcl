# Reuse pattern from tb_fabric_qos_stress/compile_all.tcl
set sim_include_path "inc"
set src_include_path "../src/inc"
set vlog_flags "-vopt -sv +acc -incr -source +define+SIM"
set include_flags "+incdir+$sim_include_path +incdir+$src_include_path"

# Compile packages
vlog {*}$vlog_flags {*}$include_flags "hvl/model_for_verification/classes/fabric_frame_pkg.sv"

# Compile verification
vlog {*}$vlog_flags {*}$include_flags "hvl/model_for_verification/fabric_driver.sv"
vlog {*}$vlog_flags {*}$include_flags "hvl/model_for_verification/fabric_monitor.sv"

# Compile DUT (reuse from other scripts)
# ... (copy from tb_fabric_qos_stress/compile_all.tcl)

# Compile testbench
vlog {*}$vlog_flags {*}$include_flags "tb/fabric/tb_fabric_connectivity.sv"