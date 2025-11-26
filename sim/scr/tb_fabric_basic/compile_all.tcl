puts "Compiling for tb_fabric_basic..."

set INCLUDE_OPTS "+incdir+../../src/inc +incdir+../inc +define+SIMULATION"

# Packages & interfaces (compile ONCE, in order)
vlog -sv $INCLUDE_OPTS ../hvl/model_for_verification/classes/fabric_frame_pkg.sv
vlog -sv $INCLUDE_OPTS ../../src/hdl/interfaces/switch_data_if.sv
vlog -sv $INCLUDE_OPTS ../../src/hdl/interfaces/switch_metadata_if.sv

# Compile round-robin arbiter before qos_scheduler
vlog -sv $INCLUDE_OPTS ../../src/hdl/core/round_robin_arbiter.sv
vlog -sv $INCLUDE_OPTS ../../src/hdl/core/qos_scheduler.sv

# IP components (minimal set for basic test)
vlog -sv $INCLUDE_OPTS ../../src/hdl/ip/dest_mask_modules/first_non_zero.sv
vlog -sv $INCLUDE_OPTS ../../src/hdl/ip/fifos/simple_fifo/simple_fifo.sv
vlog -sv $INCLUDE_OPTS ../../src/hdl/ip/memories/sdpram_xpm/sdpram_xpm.sv
vlog -sv $INCLUDE_OPTS ../../src/hdl/ip/fifos/dynamic_fifo/packet_mode_fifo_array.sv

# Switch fabric (without QoS)
vlog -sv $INCLUDE_OPTS ../../src/hdl/switch_fabric.sv

# Verification infrastructure
vlog -sv $INCLUDE_OPTS ../hvl/model_for_verification/fabric_driver.sv
vlog -sv $INCLUDE_OPTS ../hvl/model_for_verification/fabric_monitor.sv