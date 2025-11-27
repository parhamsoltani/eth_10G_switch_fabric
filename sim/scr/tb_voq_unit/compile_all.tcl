#===============================================================================
# Compilation Script for tb_voq_unit
#===============================================================================
puts "Compiling: tb_voq_unit (unit test)"

set INCLUDE_OPTS "+incdir+../../src/inc +incdir+../inc +define+SIMULATION"

# Minimal dependencies for VOQ unit test
vlog -sv $INCLUDE_OPTS ../../src/hdl/ip/fifos/simple_fifo/simple_fifo.sv
vlog -sv $INCLUDE_OPTS ../../src/hdl/ip/memories/sdpram_xpm/sdpram_xpm.sv
vlog -sv $INCLUDE_OPTS ../../src/hdl/ip/fifos/dynamic_fifo/packet_mode_fifo_array.sv
vlog -sv $INCLUDE_OPTS ../../src/hdl/buffers/voq_buffer.sv

# Testbench
vlog -sv $INCLUDE_OPTS ../tb/unit/tb_voq_unit.sv

puts "✓ Compilation complete for tb_voq_unit"
