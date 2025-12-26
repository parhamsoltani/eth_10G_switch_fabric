puts "═══════════════════════════════════════════════════════════════"
puts " Compiling: tb_qos_classifier_unit"
puts "═══════════════════════════════════════════════════════════════"

# Compile DUT (needs both include paths for qos_defines.vh)
puts "→ Compiling qos_classifier.sv..."
vlog -vopt -sv +acc +initreg+0 +initmem+0 -incr -source +define+SIM \
    +incdir+$include_path +incdir+$sim_include_path \
    $project_path/src/hdl/core/qos_classifier.sv

# Compile testbench (NEEDS BOTH INCLUDE PATHS!)
puts "→ Compiling tb_qos_classifier_unit.sv..."
vlog -vopt -sv +acc -incr -source +define+SIM \
    +incdir+$include_path +incdir+$sim_include_path \
    tb/unit/tb_qos_classifier_unit.sv

puts " Compilation complete for tb_qos_classifier_unit"
puts "═══════════════════════════════════════════════════════════════\n"