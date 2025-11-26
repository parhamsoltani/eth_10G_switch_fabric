	add wave -hex -group "tb signals"		sim:/$TB/*
	add wave -hex -group "uut signals"		sim:/$TB/uut/*
	add wave -hex -group "packet_mode_fifo_array"		sim:/$TB/uut/packet_mode_mem_controller/*
	add wave -hex -group "model signals"	sim:/$TB/model/*