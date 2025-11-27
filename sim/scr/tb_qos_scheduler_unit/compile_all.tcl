#===============================================================================
# Compilation Script for tb_qos_scheduler_unit
#===============================================================================
puts "Compiling: tb_qos_scheduler_unit"

set INCLUDE_OPTS "+incdir+../../src/inc +incdir+../inc +define+SIMULATION +define+ENABLE_QOS"

# Dependencies
vlog -sv $INCLUDE_OPTS ../../src/hdl/core/round_robin_arbiter.sv
vlog -sv $INCLUDE_OPTS ../../src/hdl/core/qos_scheduler.sv

# Testbench
vlog -sv $INCLUDE_OPTS ../tb/unit/tb_qos_scheduler_unit.sv

puts "✓ Compilation complete for tb_qos_scheduler_unit"
