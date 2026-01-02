puts "═══════════════════════════════════════════════════════════════"
puts " Compiling: tb_qos_manager_integration"
puts "═══════════════════════════════════════════════════════════════"

# Note: Don't use vdel -all here as it removes Xilinx glbl module
# The -incr flag has been removed to force recompilation

# Compile dependencies
puts "→ Compiling round_robin_arbiter.sv..."
vlog -vopt -sv +acc +initreg+0 +initmem+0 -source +define+SIM \
    +incdir+$include_path +incdir+$sim_include_path \
    $project_path/src/hdl/core/round_robin_arbiter.sv

puts "→ Compiling qos_classifier.sv..."
vlog -vopt -sv +acc +initreg+0 +initmem+0 -source +define+SIM \
    +incdir+$include_path +incdir+$sim_include_path \
    $project_path/src/hdl/core/qos_classifier.sv

puts "→ Compiling qos_scheduler.sv..."
vlog -vopt -sv +acc +initreg+0 +initmem+0 -source +define+SIM \
    +incdir+$include_path +incdir+$sim_include_path \
    $project_path/src/hdl/core/qos_scheduler.sv

# Compile testbench - FIXED: Added +incdir+$include_path
puts "→ Compiling tb_qos_manager_integration.sv..."
vlog -vopt -sv +acc -source +define+SIM \
    +incdir+$include_path +incdir+$sim_include_path \
    tb/integration/tb_qos_manager_integration.sv

puts " Compilation complete for tb_qos_manager_integration"
puts "═══════════════════════════════════════════════════════════════\n"

puts "═══════════════════════════════════════════════════════════════"
puts " Running: tb_qos_manager_integration"
puts "═══════════════════════════════════════════════════════════════"

# Force fresh optimization with -novopt or let vsim re-optimize
vsim -voptargs="+acc" tb_qos_manager_integration work.glbl

run -all

puts "═══════════════════════════════════════════════════════════════"
puts " Simulation complete for tb_qos_manager_integration"
puts "═══════════════════════════════════════════════════════════════\n"