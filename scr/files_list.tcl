# Enhanced source file list for VOQ/XPQ fabric

# Interfaces
../../src/hdl/interfaces/*.sv

# Core modules
../../src/hdl/core/packet_id_manager.sv
../../src/hdl/core/credit_manager.sv
../../src/hdl/core/qos_classifier.sv
../../src/hdl/core/round_robin_arbiter.sv

# Buffers
../../src/hdl/buffers/packet_buffer.sv
../../src/hdl/buffers/voq_buffer.sv

# Arbitration
../../src/hdl/arbitration/crosspoint_arbiter.sv

# Fabric stages
../../src/hdl/fabric/fabric_ingress.sv
../../src/hdl/fabric/fabric_crosspoint.sv
../../src/hdl/fabric/fabric_egress.sv
../../src/hdl/fabric/switch_fabric.sv

# Wrappers
../../src/hdl/wrappers/wrapper_switch_fabric.sv

# Utility modules (reuse existing)
../../src/hdl/ip/delayed_regs/*.sv
../../src/hdl/ip/memories/*/*.sv
../../src/hdl/ip/fifos/*/*.sv

# Include files
../../src/inc/*.vh

# Constraints
../../src/xdc/*.xdc