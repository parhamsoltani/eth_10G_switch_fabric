# config_generator_scalable.py - Generate parametric port configs (aligned with doc_v2.md)
# Based on des_simple.txt loop and  script example

import os

# Define port sweep
ports = [8, 16, 32, 64, 128]
base_dir = 'configs'

for p in ports:
    config_dir = os.path.join(base_dir, f'port_{p}')
    os.makedirs(config_dir, exist_ok=True)
    
    # Generate implement_options.vh (from des_main_1.txt style)
    with open(os.path.join(config_dir, 'implement_options.vh'), 'w') as f:
        f.write(f'`define NUM_PORT {p}\n')
        f.write(f'`define NUM_PORT_LOG $clog2({p})\n')  # Verilog clog2
        f.write('`define LINE_RATE 10\n')  // Keep other params
        f.write('`define MULTICAST_SUPPORT 1\n')
    
    # Generate timing.xdc (scaled clock from des_main_5.txt)
    with open(os.path.join(config_dir, 'timing.xdc'), 'w') as f:
        period = 3.2 if p <= 32 else 3.52  # Scale for larger ports
        f.write(f'create_clock -period {period} -name clk [get_ports clk]\n')
        f.write('# False paths for FIFOs\n')
        f.write('set_false_path -to [get_pins -hierarchical -filter {NAME =~ */data_sync/D}]\n')  # From des_main_5.txt
    
    # Generate build_switches_main.tcl snippet
    with open(os.path.join(config_dir, 'build_switches_main.tcl'), 'w') as f:
        f.write(f'-device_part_num xcvu9p-flga2577-3-e\n')
        f.write(f'-src_list_file ../files_list.tcl\n')

print('Scalable configs generated for ports:', ports)