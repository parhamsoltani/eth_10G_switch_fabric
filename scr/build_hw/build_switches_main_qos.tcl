# QoS-aware build script (extends your build_switches_main.tcl)

# Source standard script first
source [file join $scr_path build_switches_main.tcl]

# Add QoS-specific files
read_verilog -sv [glob $project_path/src/hdl/core/qos_*.sv]
read_verilog -sv [glob $project_path/src/hdl/line_modules/*_qos.sv]
read_verilog -sv [glob $project_path/src/hdl/line_modules/*_wrapper.sv]
read_verilog -sv [glob $project_path/src/hdl/switch_ips/*_qos.sv]
read_verilog -sv [glob $project_path/src/hdl/micro_interface/*_qos_*.sv]

# QoS-specific IP
read_verilog -sv [glob $project_path/src/hdl/ip/combinational_components/*_qos.sv]

puts "QoS-aware design files loaded"