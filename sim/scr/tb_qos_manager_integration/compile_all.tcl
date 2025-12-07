puts "═══════════════════════════════════════════════════════════════"
puts " Compiling: tb_qos_manager_integration"
puts "═══════════════════════════════════════════════════════════════"

# Compile dependencies (need both include paths)
puts "→ Compiling round_robin_arbiter.sv..."
vlog -vopt -sv +acc +initreg+0 +initmem+0 -incr -source +define+SIM \
    +incdir+$include_path +incdir+$sim_include_path \
    $project_path/src/hdl/core/round_robin_arbiter.sv

puts "→ Compiling qos_classifier.sv..."
vlog -vopt -sv +acc +initreg+0 +initmem+0 -incr -source +define+SIM \
    +incdir+$include_path +incdir+$sim_include_path \
    $project_path/src/hdl/core/qos_classifier.sv

puts "→ Compiling qos_scheduler.sv..."
vlog -vopt -sv +acc +initreg+0 +initmem+0 -incr -source +define+SIM \
    +incdir+$include_path +incdir+$sim_include_path \
    $project_path/src/hdl/core/qos_scheduler.sv

# Compile testbench
puts "→ Compiling tb_qos_manager_integration.sv..."
vlog -vopt -sv +acc -incr -source +define+SIM +incdir+$sim_include_path \
    tb/integration/tb_qos_manager_integration.sv

puts " Compilation complete for tb_qos_manager_integration"
puts "═══════════════════════════════════════════════════════════════\n"