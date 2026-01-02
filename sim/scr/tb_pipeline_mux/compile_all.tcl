# compile_all.tcl for tb_pipeline_mux

set project_path ".."
set include_path "$project_path/src/inc"
set sim_include_path "inc"

vlog -sv +acc -incr +define+SIM +incdir+$sim_include_path "tb/pipeline_mux/*.sv"

vlog -sv +acc +initreg+0 +initmem+0 -incr +define+SIM +incdir+$include_path ../src/hdl/ip/delayed_regs/*.sv
vlog -sv +acc +initreg+0 +initmem+0 -incr +define+SIM +incdir+$include_path ../src/hdl/ip/register_replicator/*.sv
vlog -sv +acc +initreg+0 +initmem+0 -incr +define+SIM +incdir+$include_path ../src/hdl/ip/pipeline_mux/*.sv

# Explicit success return
return