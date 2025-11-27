#===============================================================================
# Compilation Script for tb_fabric_qos_stress
#===============================================================================
puts "════════════════════════════════════════════════════════════"
puts "  Compiling: tb_fabric_qos_stress"
puts "════════════════════════════════════════════════════════════"

# Same as tb_fabric_qos_sweep, but with stress test define
set INCLUDE_OPTS "+incdir+../../src/inc +incdir+../inc +define+SIMULATION +define+ENABLE_QOS +define+QOS_STRESS_TEST"

# Source common compilation (reuse above script)
source ../tb_fabric_qos_sweep/compile_all.tcl

# Override testbench compilation
puts "\nCompiling stress testbench..."
vlog -sv $INCLUDE_OPTS ../tb/fabric/tb_fabric_qos_stress.sv

puts "════════════════════════════════════════════════════════════"
puts "  ✓ Compilation complete for tb_fabric_qos_stress"
puts "════════════════════════════════════════════════════════════"
