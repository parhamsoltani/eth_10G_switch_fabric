#===============================================================================
# Compilation Script for tb_fabric_qos_sweep
#===============================================================================
puts "════════════════════════════════════════════════════════════"
puts "  Compiling: tb_fabric_qos_sweep"
puts "════════════════════════════════════════════════════════════"

set INCLUDE_OPTS "+incdir+../../src/inc +incdir+../inc +define+SIMULATION +define+ENABLE_QOS"

onerror {quit -code 1}

#===============================================================================
# Step 1: Packages & Interfaces
#===============================================================================
puts "\n[1/6] Compiling packages..."
vlog -sv $INCLUDE_OPTS ../hvl/model_for_verification/classes/fabric_frame_pkg.sv

puts "[2/6] Compiling interfaces..."
vlog -sv $INCLUDE_OPTS ../../src/hdl/interfaces/switch_data_if.sv
vlog -sv $INCLUDE_OPTS ../../src/hdl/interfaces/switch_metadata_if.sv

#===============================================================================
# Step 2: IP Components (in dependency order)
#===============================================================================
puts "\n[3/6] Compiling IP components..."

# Basic components
vlog -sv $INCLUDE_OPTS ../../src/hdl/ip/dest_mask_modules/first_non_zero.sv
vlog -sv $INCLUDE_OPTS ../../src/hdl/ip/dest_mask_modules/first_non_zero_no_delay.sv
vlog -sv $INCLUDE_OPTS ../../src/hdl/ip/dest_mask_modules/one_hot_none_zero.sv

# QoS-specific components
vlog -sv $INCLUDE_OPTS ../../src/hdl/ip/combinational_components/first_none_zero_except_k_qos.sv

# Memory components
vlog -sv $INCLUDE_OPTS ../../src/hdl/ip/memories/sdpram_xpm/sdpram_xpm.sv
vlog -sv $INCLUDE_OPTS ../../src/hdl/ip/memories/init_mem/sdpram_init_value.sv

# FIFOs
vlog -sv $INCLUDE_OPTS ../../src/hdl/ip/fifos/simple_fifo/simple_fifo.sv
vlog -sv $INCLUDE_OPTS ../../src/hdl/ip/fifos/dynamic_fifo/linklist_dynamic_fifo.sv
vlog -sv $INCLUDE_OPTS ../../src/hdl/ip/fifos/dynamic_fifo/packet_mode_fifo_array.sv

#===============================================================================
# Step 3: Core QoS Modules
#===============================================================================
puts "\n[4/6] Compiling QoS core modules..."

# Arbiter (needed by scheduler)
vlog -sv $INCLUDE_OPTS ../../src/hdl/core/round_robin_arbiter.sv

# QoS processing
vlog -sv $INCLUDE_OPTS ../../src/hdl/core/qos_classifier.sv
vlog -sv $INCLUDE_OPTS ../../src/hdl/core/qos_scheduler.sv
vlog -sv $INCLUDE_OPTS ../../src/hdl/core/qos_shaper.sv

# Credit management
vlog -sv $INCLUDE_OPTS ../../src/hdl/core/credit_manager.sv

#===============================================================================
# Step 4: Switch Components
#===============================================================================
puts "\n[5/6] Compiling switch components..."

# Buffer modules
vlog -sv $INCLUDE_OPTS ../../src/hdl/buffers/voq_buffer.sv
vlog -sv $INCLUDE_OPTS ../../src/hdl/buffers/xpq_buffer.sv
vlog -sv $INCLUDE_OPTS ../../src/hdl/buffers/packet_buffer.sv

# Switch IPs
vlog -sv $INCLUDE_OPTS ../../src/hdl/switch_ips/dest_finder_row_matching_qos.sv
vlog -sv $INCLUDE_OPTS ../../src/hdl/switch_ips/shared_voq.sv
vlog -sv $INCLUDE_OPTS ../../src/hdl/switch_ips/shared_xpq.sv

# Line modules
vlog -sv $INCLUDE_OPTS ../../src/hdl/line_modules/ingress_line_qos.sv
vlog -sv $INCLUDE_OPTS ../../src/hdl/line_modules/egress_line.sv
vlog -sv $INCLUDE_OPTS ../../src/hdl/line_modules/ingress_line_wrapper.sv

# Fabric components
vlog -sv $INCLUDE_OPTS ../../src/hdl/fabric/fabric_ingress.sv
vlog -sv $INCLUDE_OPTS ../../src/hdl/fabric/fabric_crosspoint.sv
vlog -sv $INCLUDE_OPTS ../../src/hdl/fabric/fabric_egress.sv

# Switch topologies (compile all, instantiation selects)
vlog -sv $INCLUDE_OPTS ../../src/hdl/switches/switch_s.sv
vlog -sv $INCLUDE_OPTS ../../src/hdl/switches/switch_2s.sv
vlog -sv $INCLUDE_OPTS ../../src/hdl/switches/switch_high_radix_matching.sv

# Top-level fabric
vlog -sv $INCLUDE_OPTS ../../src/hdl/switch_fabric.sv

#===============================================================================
# Step 5: Verification Infrastructure
#===============================================================================
puts "\n[6/6] Compiling verification components..."

# QoS monitors
vlog -sv $INCLUDE_OPTS ../hvl/verification/qos_latency_monitor.sv
vlog -sv $INCLUDE_OPTS ../hvl/verification/qos_checker_enhanced.sv
vlog -sv $INCLUDE_OPTS ../hvl/verification/qos_checker_scoreboard.sv

# Traffic generators/monitors
vlog -sv $INCLUDE_OPTS ../hvl/model_for_verification/fabric_driver.sv
vlog -sv $INCLUDE_OPTS ../hvl/model_for_verification/fabric_monitor.sv
vlog -sv $INCLUDE_OPTS ../hvl/model_for_verification/switch_fabric_model_qos.sv

#===============================================================================
# Step 6: Testbench
#===============================================================================
puts "\nCompiling testbench..."
vlog -sv $INCLUDE_OPTS ../tb/fabric/tb_fabric_qos_sweep.sv

puts "════════════════════════════════════════════════════════════"
puts "  ✓ Compilation complete for tb_fabric_qos_sweep"
puts "════════════════════════════════════════════════════════════"
