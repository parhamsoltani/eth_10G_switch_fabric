puts "═══════════════════════════════════════════════════════════════"
puts " Compiling: tb_qos_scheduler_unit"
puts "═══════════════════════════════════════════════════════════════"

# Compile dependencies (need both include paths)
puts "→ Compiling round_robin_arbiter.sv..."
vlog -vopt -sv +acc +initreg+0 +initmem+0 -incr -source +define+SIM \
    +incdir+$include_path +incdir+$sim_include_path \
    $project_path/src/hdl/core/round_robin_arbiter.sv

puts "→ Compiling qos_scheduler.sv..."
vlog -vopt -sv +acc +initreg+0 +initmem+0 -incr -source +define+SIM \
    +incdir+$include_path +incdir+$sim_include_path \
    $project_path/src/hdl/core/qos_scheduler.sv

# Compile testbench (FIXED: added +incdir+$include_path)
puts "→ Compiling tb_qos_scheduler_unit.sv..."
vlog -vopt -sv +acc -incr -source +define+SIM \
    +incdir+$sim_include_path +incdir+$include_path \
    tb/unit/tb_qos_scheduler_unit.sv

puts " Compilation complete for tb_qos_scheduler_unit"
puts "═══════════════════════════════════════════════════════════════\n"