# Compilation script for tb_fabric_qos testbench
# This file should contain ONLY vlog commands, not wave commands

puts "  Compiling tb_fabric_qos design files..."

#===============================================================================
# Package files (must be compiled first)
#===============================================================================
vlog -sv {*}$INCLUDE_OPTS hvl/model_for_verification/classes/fabric_frame_pkg.sv

#===============================================================================
# Interfaces
#===============================================================================
vlog -sv {*}$INCLUDE_OPTS ../src/hdl/interfaces/switch_data_if.sv
vlog -sv {*}$INCLUDE_OPTS ../src/hdl/interfaces/switch_metadata_if.sv

#===============================================================================
# IP blocks - Dest mask modules
#===============================================================================
vlog -sv {*}$INCLUDE_OPTS ../src/hdl/ip/dest_mask_modules/first_non_zero.sv
vlog -sv {*}$INCLUDE_OPTS ../src/hdl/ip/dest_mask_modules/first_non_zero_no_delay.sv
vlog -sv {*}$INCLUDE_OPTS ../src/hdl/ip/dest_mask_modules/first_none_zero_except_k.sv
vlog -sv {*}$INCLUDE_OPTS ../src/hdl/ip/dest_mask_modules/num_non_zero.sv
vlog -sv {*}$INCLUDE_OPTS ../src/hdl/ip/dest_mask_modules/num_non_zero_no_delay.sv

#===============================================================================
# IP blocks - Memories
#===============================================================================
vlog -sv {*}$INCLUDE_OPTS ../src/hdl/ip/memories/sdpram_xpm/sdpram_xpm.sv
vlog -sv {*}$INCLUDE_OPTS ../src/hdl/ip/memories/init_mem/sdpram_init_value.sv
vlog -sv {*}$INCLUDE_OPTS ../src/hdl/ip/memories/init_mem/sdpram_init_value_all_same.sv
vlog -sv {*}$INCLUDE_OPTS ../src/hdl/ip/memories/init_mem/sdpram_init_value_n1_n2.sv

#===============================================================================
# IP blocks - FIFOs
#===============================================================================
vlog -sv {*}$INCLUDE_OPTS ../src/hdl/ip/fifos/simple_fifo/simple_fifo.sv
vlog -sv {*}$INCLUDE_OPTS ../src/hdl/ip/fifos/init_fifo/sync_fifo_init_value.sv
vlog -sv {*}$INCLUDE_OPTS ../src/hdl/ip/fifos/axis_fifo/axis_fifo.sv
vlog -sv {*}$INCLUDE_OPTS ../src/hdl/ip/fifos/dynamic_fifo/linklist_dynamic_fifo.sv
vlog -sv {*}$INCLUDE_OPTS ../src/hdl/ip/fifos/dynamic_fifo/packet_mode_fifo_array.sv
vlog -sv {*}$INCLUDE_OPTS ../src/hdl/ip/fifos/dynamic_fifo/packet_mode_fifo_array_multicast.sv

#===============================================================================
# IP blocks - Pipeline
#===============================================================================
vlog -sv {*}$INCLUDE_OPTS ../src/hdl/ip/pipeline_mem/barrel_shifter.sv
vlog -sv {*}$INCLUDE_OPTS ../src/hdl/ip/pipeline_mem/pipeline_mem.sv
vlog -sv {*}$INCLUDE_OPTS ../src/hdl/ip/pipeline_mem/pipeline_mem_with_inout_barrel.sv
vlog -sv {*}$INCLUDE_OPTS ../src/hdl/ip/pipeline_mux/mux_tile.sv
vlog -sv {*}$INCLUDE_OPTS ../src/hdl/ip/pipeline_mux/pipeline_mux.sv
vlog -sv {*}$INCLUDE_OPTS ../src/hdl/ip/delayed_regs/delayed_regs.sv

#===============================================================================
# Core modules
#===============================================================================
vlog -sv {*}$INCLUDE_OPTS ../src/hdl/core/qos_classifier.sv
vlog -sv {*}$INCLUDE_OPTS ../src/hdl/core/qos_scheduler.sv
vlog -sv {*}$INCLUDE_OPTS ../src/hdl/core/round_robin_arbiter.sv

#===============================================================================
# Line modules
#===============================================================================
vlog -sv {*}$INCLUDE_OPTS ../src/hdl/line_modules/packet_to_cell.sv
vlog -sv {*}$INCLUDE_OPTS ../src/hdl/line_modules/cell_to_packet.sv
vlog -sv {*}$INCLUDE_OPTS ../src/hdl/line_modules/ingress_switch.sv
vlog -sv {*}$INCLUDE_OPTS ../src/hdl/line_modules/egress_switch.sv
vlog -sv {*}$INCLUDE_OPTS ../src/hdl/line_modules/ingress_line.sv
vlog -sv {*}$INCLUDE_OPTS ../src/hdl/line_modules/ingress_line_qos.sv
vlog -sv {*}$INCLUDE_OPTS ../src/hdl/line_modules/egress_line.sv

#===============================================================================
# Switch IPs
#===============================================================================
vlog -sv {*}$INCLUDE_OPTS ../src/hdl/switch_ips/dest_finder_s.sv
vlog -sv {*}$INCLUDE_OPTS ../src/hdl/switch_ips/dest_finder_row.sv
vlog -sv {*}$INCLUDE_OPTS ../src/hdl/switch_ips/dest_finder_col.sv
vlog -sv {*}$INCLUDE_OPTS ../src/hdl/switch_ips/shared_voq.sv
vlog -sv {*}$INCLUDE_OPTS ../src/hdl/switch_ips/shared_xpq.sv
vlog -sv {*}$INCLUDE_OPTS ../src/hdl/switch_ips/row_mux.sv
vlog -sv {*}$INCLUDE_OPTS ../src/hdl/switch_ips/col_pipeline_mux.sv
vlog -sv {*}$INCLUDE_OPTS ../src/hdl/switch_ips/cell_to_packet_s_port_with_barrel.sv

#===============================================================================
# Switches
#===============================================================================
vlog -sv {*}$INCLUDE_OPTS ../src/hdl/switches/switch_s.sv
vlog -sv {*}$INCLUDE_OPTS ../src/hdl/switches/switch_high_radix.sv

#===============================================================================
# Top level
#===============================================================================
vlog -sv {*}$INCLUDE_OPTS ../src/hdl/switch_fabric.sv

#===============================================================================
# Verification components
#===============================================================================
vlog -sv {*}$INCLUDE_OPTS hvl/verification/fabric_scoreboard.sv
vlog -sv {*}$INCLUDE_OPTS hvl/verification/qos_checker.sv

puts "  tb_fabric_qos compilation complete"