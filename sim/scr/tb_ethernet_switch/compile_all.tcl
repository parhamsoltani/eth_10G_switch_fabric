vlog -vopt -sv +acc -incr -source +define+SIM +incdir+$sim_include_path "hvl/model_for_verification/classes/fabric_frame_pkg.sv"
vlog -vopt -sv +acc -incr -source +define+SIM +incdir+$sim_include_path "hvl/model_for_verification/*.sv"
vlog -vopt -sv +acc -incr -source +define+SIM +incdir+$sim_include_path "ip/submodule/ethernet_switch_hvl/*.sv"
vlog -vopt -sv +acc -incr -source +define+SIM +incdir+$sim_include_path "ip/submodule/ethernet_switch_hdl/*.sv"
vlog -vopt -sv +acc -incr -source +define+SIM +incdir+$sim_include_path "ip/submodule/ethernet_switch_hdl/*/*.sv"
vlog -vopt -sv +acc -incr -source +define+SIM +incdir+$sim_include_path "ip/submodule/ethernet_switch_hdl/*/*/*.sv"
vlog -vopt -sv +acc -incr -source +define+SIM +incdir+$sim_include_path "ip/xilinx_ips_sim/*.sv"

vlog -vopt -sv +acc -incr -source +define+SIM +incdir+$sim_include_path +incdir+$include_path "tb/*/*.sv"

# =========================================== model or design be in testbench
vlog -vopt -sv +acc -incr -source +define+SIM +incdir+$include_path "$project_path/src/hdl/*.sv"
vlog -vopt -sv +acc -incr -source +define+SIM +incdir+$include_path "$project_path/src/hdl/*/*.sv"
vlog -vopt -sv +acc -incr -source +define+SIM +incdir+$include_path "$project_path/src/hdl/*/*/*.sv"
vlog -vopt -sv +acc -incr -source +define+SIM +incdir+$include_path "$project_path/src/hdl/*/*/*/*.sv"

# vlog -vopt -sv +acc -incr -source +define+SIM +incdir+$sim_include_path "hvl/model_for_verification/switch_fabric_model/*.sv"
# ===========================================

# vlog -vopt -sv +acc -incr -source +define+SIM +incdir+$include_path "$project_path/src/ip/submodule/*/*.v"

# vlog -vopt -sv +acc +initreg+0 +initmem+0 -incr -source +define+SIM +incdir+$include_path $project_path/out/products/netlist.v