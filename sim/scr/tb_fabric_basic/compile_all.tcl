# ===========================================================================
# QuestaSim Compilation Script for tb_fabric_basic
# ===========================================================================

# Set library name
set LIB_NAME work

# Clean previous compilation
if {[file exists $LIB_NAME]} {
    vdel -lib $LIB_NAME -all
}

# Create work library
vlib $LIB_NAME
vmap work $LIB_NAME

# ===========================================================================
# Set compilation options with BOTH include paths
# ===========================================================================

# Get current directory (should be sim/)
set SIM_DIR [pwd]
set SRC_INC_DIR "${SIM_DIR}/../src/inc"
set SIM_INC_DIR "${SIM_DIR}/inc"

# Use BOTH include directories like the working scripts
set INCLUDE_OPTS "+incdir+${SRC_INC_DIR}+${SIM_INC_DIR} +define+SIMULATION"

puts ""
puts "========================================="
puts "Compiling for tb_fabric_basic..."
puts "========================================="
puts "Source include: $SRC_INC_DIR"
puts "Sim include: $SIM_INC_DIR"
puts "Include options: $INCLUDE_OPTS"
puts ""

# ===========================================================================
# Compile Xilinx libraries
# ===========================================================================

puts "Compiling Xilinx XPM libraries..."
if {[info exists ::env(XILINX_VIVADO)]} {
    vlog -work work $::env(XILINX_VIVADO)/data/verilog/src/glbl.v
    vlog -work work $::env(XILINX_VIVADO)/data/ip/xpm/xpm_fifo/hdl/xpm_fifo.sv
    vlog -work work $::env(XILINX_VIVADO)/data/ip/xpm/xpm_cdc/hdl/xpm_cdc.sv
    vlog -work work $::env(XILINX_VIVADO)/data/ip/xpm/xpm_memory/hdl/xpm_memory.sv
} else {
    puts "ERROR: XILINX_VIVADO not set. Set it to your Vivado install path."
    quit -code 1
}

# ===========================================================================
# Compile packages and interfaces
# ===========================================================================

puts "Compiling packages and interfaces..."

vlog -sv $INCLUDE_OPTS hvl/model_for_verification/classes/fabric_frame_pkg.sv
vlog -sv $INCLUDE_OPTS ../src/hdl/interfaces/switch_data_if.sv
vlog -sv $INCLUDE_OPTS ../src/hdl/interfaces/switch_metadata_if.sv

# ===========================================================================
# Compile core components
# ===========================================================================

puts "Compiling core components..."

vlog -sv $INCLUDE_OPTS ../src/hdl/core/round_robin_arbiter.sv
vlog -sv $INCLUDE_OPTS ../src/hdl/core/qos_scheduler.sv
vlog -sv $INCLUDE_OPTS ../src/hdl/core/qos_classifier.sv

# ===========================================================================
# Compile IP components
# ===========================================================================

puts "Compiling IP components..."

# Destination mask modules
vlog -sv $INCLUDE_OPTS ../src/hdl/ip/dest_mask_modules/first_non_zero.sv
vlog -sv $INCLUDE_OPTS ../src/hdl/ip/dest_mask_modules/first_none_zero_except_k.sv
vlog -sv $INCLUDE_OPTS ../src/hdl/ip/dest_mask_modules/one_hot_none_zero.sv
vlog -sv $INCLUDE_OPTS ../src/hdl/ip/dest_mask_modules/num_non_zero.sv

# ===========================================================================
# Compile delayed registers
# ===========================================================================

puts "Compiling delayed register components..."

vlog -sv $INCLUDE_OPTS ../src/hdl/ip/delayed_regs/delayed_regs.sv

# ===========================================================================
# Compile memory initialization modules
# ===========================================================================

puts "Compiling memory initialization modules..."

vlog -sv $INCLUDE_OPTS ../src/hdl/ip/memories/init_mem/sdpram_init_value.sv
vlog -sv $INCLUDE_OPTS ../src/hdl/ip/memories/init_mem/sdpram_init_value_all_same.sv
vlog -sv $INCLUDE_OPTS ../src/hdl/ip/memories/init_mem/sdpram_init_value_n1_n2.sv

# ===========================================================================
# Compile FIFO init modules
# ===========================================================================

puts "Compiling FIFO initialization modules..."

vlog -sv $INCLUDE_OPTS ../src/hdl/ip/fifos/init_fifo/sync_fifo_init_value.sv

# ===========================================================================
# Compile AXIS FIFO
# ===========================================================================

puts "Compiling AXIS FIFO..."

vlog -sv $INCLUDE_OPTS ../src/hdl/ip/fifos/axis_fifo/axis_fifo.sv

# ===========================================================================
# Compile pipeline memory with barrel shifter
# ===========================================================================

puts "Compiling pipeline memory with barrel shifter..."

vlog -sv $INCLUDE_OPTS ../src/hdl/ip/pipeline_mem/pipeline_mem_with_inout_barrel.sv
vlog -sv $INCLUDE_OPTS ../src/hdl/ip/pipeline_mem/pipeline_mem_with_in_barrel.sv

# ===========================================================================
# Compile FIFO components
# ===========================================================================

puts "Compiling FIFO components..."

vlog -sv $INCLUDE_OPTS ../src/hdl/ip/fifos/simple_fifo/simple_fifo.sv
vlog -sv $INCLUDE_OPTS ../src/hdl/ip/memories/sdpram_xpm/sdpram_xpm.sv
vlog -sv $INCLUDE_OPTS ../src/hdl/ip/fifos/dynamic_fifo/linklist_dynamic_fifo.sv
vlog -sv $INCLUDE_OPTS ../src/hdl/ip/fifos/dynamic_fifo/packet_mode_fifo_array.sv

# ===========================================================================
# Compile buffer modules
# ===========================================================================

puts "Compiling buffer modules..."

vlog -sv $INCLUDE_OPTS ../src/hdl/buffers/voq_buffer.sv
vlog -sv $INCLUDE_OPTS ../src/hdl/buffers/xpq_buffer.sv

# ===========================================================================
# Compile arbitration modules
# ===========================================================================

puts "Compiling arbitration modules..."

vlog -sv $INCLUDE_OPTS ../src/hdl/arbitration/voq_arbiter.sv
vlog -sv $INCLUDE_OPTS ../src/hdl/arbitration/egress_arbiter.sv


# ===========================================================================
# Compile switch_ips (needed by switches)
# ===========================================================================

puts "Compiling switch IPs..."

vlog -sv $INCLUDE_OPTS ../src/hdl/switch_ips/dest_finder_s.sv
vlog -sv $INCLUDE_OPTS ../src/hdl/switch_ips/shared_voq.sv
vlog -sv $INCLUDE_OPTS ../src/hdl/switch_ips/shared_xpq.sv
vlog -sv $INCLUDE_OPTS ../src/hdl/switch_ips/dest_finder_row.sv
vlog -sv $INCLUDE_OPTS ../src/hdl/switch_ips/dest_finder_col.sv
vlog -sv $INCLUDE_OPTS ../src/hdl/switch_ips/row_mux.sv
vlog -sv $INCLUDE_OPTS ../src/hdl/switch_ips/col_pipeline_mux.sv
vlog -sv $INCLUDE_OPTS ../src/hdl/switch_ips/dest_finder_row_matching.sv
vlog -sv $INCLUDE_OPTS ../src/hdl/switch_ips/dest_finder_row_matching_qos.sv
vlog -sv $INCLUDE_OPTS ../src/hdl/switch_ips/cell_to_packet_s_port_with_barrel.sv

# ===========================================================================
# Compile additional IP components needed by switches
# ===========================================================================

puts "Compiling additional IP components..."

vlog -sv $INCLUDE_OPTS ../src/hdl/ip/pipeline_mux/mux_tile.sv
vlog -sv $INCLUDE_OPTS ../src/hdl/ip/pipeline_mux/pipeline_mux.sv
vlog -sv $INCLUDE_OPTS ../src/hdl/ip/pipeline_mem/barrel_shifter.sv
vlog -sv $INCLUDE_OPTS ../src/hdl/ip/pipeline_mem/pipeline_mem.sv
vlog -sv $INCLUDE_OPTS ../src/hdl/ip/dest_mask_modules/first_non_zero_after_k.sv
vlog -sv $INCLUDE_OPTS ../src/hdl/ip/dest_mask_modules/first_non_zero_no_delay.sv

# ===========================================================================
# Compile switch modules
# ===========================================================================

puts "Compiling switch modules..."

vlog -sv $INCLUDE_OPTS ../src/hdl/switches/switch_s.sv
vlog -sv $INCLUDE_OPTS ../src/hdl/switches/switch_2s.sv
vlog -sv $INCLUDE_OPTS ../src/hdl/switches/switch_high_radix_matching.sv

# ===========================================================================
# Compile line modules
# ===========================================================================

puts "Compiling line modules..."

vlog -sv $INCLUDE_OPTS ../src/hdl/line_modules/packet_to_cell.sv
vlog -sv $INCLUDE_OPTS ../src/hdl/line_modules/cell_to_packet.sv
vlog -sv $INCLUDE_OPTS ../src/hdl/line_modules/ingress_line.sv
vlog -sv $INCLUDE_OPTS ../src/hdl/line_modules/ingress_line_qos.sv
vlog -sv $INCLUDE_OPTS ../src/hdl/line_modules/ingress_switch.sv
vlog -sv $INCLUDE_OPTS ../src/hdl/line_modules/egress_line.sv
vlog -sv $INCLUDE_OPTS ../src/hdl/line_modules/egress_switch.sv


# ===========================================================================
# Compile fabric modules
# ===========================================================================

puts "Compiling fabric modules..."

vlog -sv $INCLUDE_OPTS ../src/hdl/fabric/fabric_ingress.sv
vlog -sv $INCLUDE_OPTS ../src/hdl/fabric/fabric_crosspoint.sv
vlog -sv $INCLUDE_OPTS ../src/hdl/fabric/fabric_egress.sv

# ===========================================================================
# Compile top-level switch fabric
# ===========================================================================

puts "Compiling top-level switch fabric..."

vlog -sv $INCLUDE_OPTS ../src/hdl/switch_fabric.sv

# ===========================================================================
# Compile verification components
# ===========================================================================

puts "Compiling verification components..."

vlog -sv $INCLUDE_OPTS hvl/model_for_verification/fabric_driver.sv
vlog -sv $INCLUDE_OPTS hvl/model_for_verification/fabric_monitor.sv

# ===========================================================================
# Compile testbench
# ===========================================================================

puts "Compiling testbench..."

vlog -sv $INCLUDE_OPTS tb/fabric/tb_fabric_basic.sv

# ===========================================================================
# Report completion
# ===========================================================================

puts ""
puts "========================================="
puts "COMPILATION COMPLETE - NO ERRORS!"
puts "========================================="
puts ""

# ===========================================================================
# Launch simulation
# ===========================================================================

puts "Starting simulation..."

vsim -voptargs="+acc" -wlf wlf/vsim.wlf tb_fabric_basic work.glbl

# Add waves (if wave.do exists)
if {[file exists "scr/tb_fabric_basic/wave.do"]} {
    do scr/tb_fabric_basic/wave.do
}

# Run simulation
run -all

puts ""
puts "========================================="
puts "SIMULATION COMPLETE"
puts "========================================="