puts "═══════════════════════════════════════════════════════════════"
puts " Compiling: tb_voq_unit"
puts "═══════════════════════════════════════════════════════════════"

# Compile dependencies (need both include paths)
puts "→ Compiling simple_fifo.sv..."
vlog -vopt -sv +acc +initreg+0 +initmem+0 -incr -source +define+SIM \
    +incdir+$include_path +incdir+$sim_include_path \
    $project_path/src/hdl/ip/fifos/simple_fifo/simple_fifo.sv

puts "→ Compiling sdpram_xpm.sv..."
vlog -vopt -sv +acc +initreg+0 +initmem+0 -incr -source +define+SIM \
    +incdir+$include_path +incdir+$sim_include_path \
    $project_path/src/hdl/ip/memories/sdpram_xpm/sdpram_xpm.sv

puts "→ Compiling packet_mode_fifo_array.sv..."
vlog -vopt -sv +acc +initreg+0 +initmem+0 -incr -source +define+SIM \
    +incdir+$include_path +incdir+$sim_include_path \
    $project_path/src/hdl/ip/fifos/dynamic_fifo/packet_mode_fifo_array.sv

puts "→ Compiling packet_buffer.sv..."
vlog -vopt -sv +acc +initreg+0 +initmem+0 -incr -source +define+SIM \
    +incdir+$include_path +incdir+$sim_include_path \
    $project_path/src/hdl/buffers/packet_buffer.sv

puts "→ Compiling voq_buffer.sv..."
vlog -vopt -sv +acc +initreg+0 +initmem+0 -incr -source +define+SIM \
    +incdir+$include_path +incdir+$sim_include_path \
    $project_path/src/hdl/buffers/voq_buffer.sv

# Compile testbench
puts "→ Compiling tb_voq_unit.sv..."
vlog -vopt -sv +acc -incr -source +define+SIM +incdir+$sim_include_path \
    tb/unit/tb_voq_unit.sv

puts " Compilation complete for tb_voq_unit"
puts "═══════════════════════════════════════════════════════════════\n"