	alias clc ".main clear"
	clc

	transcript file transcript_#.log
	# transcript file transcript.log

	file delete -force *~ *.ucdb vsim.dbg *.vstf *.log work *.mem *.transcript.txt certe_dump.xml *.wlf

	exec vlib work
	vmap work work
	
	file mkdir scr
	file mkdir tb
	file mkdir wlf
	file mkdir wave
	
	set project_path		".."
	set include_path		"$project_path/src/inc"
	set sim_include_path	"inc"
	
	set TB					"tb_ethernet_switch"
	# set TB					"tb_fifo_array"
	# set TB					"tb_packet_mode_fifo_array"
	# set TB					"tb_pipeline_mux"

	
	set wlf_save_name		"wlf/vsim.wlf"
	set opened_wlf_name		"ref_sim"
	set run_time			"200 us"

	set compile_error		0
	
	#VOPTARGS_SWITCH
		#"-voptargs=+acc=rnb+<module_name_1>+<module_name_2>+..."
		#"-voptargs=+acc"
		#""
		set VOPTARGS_SWITCH "-voptargs=+acc"

	
#	file copy -force $include_path/implement_options.v	include/implement_options.v
#	file copy -force $include_path/macro.v	include/macro.v

	
#===============================================================================
#===============================================================================
	
#========== complile modules
	onerror {set compile_error 1}
	# XILINX_VIVADO is an environment variable pointing to a (preferably the latest) VIVADO directory
	vlog -work work $::env(XILINX_VIVADO)/data/verilog/src/glbl.v
	vlog -work work $::env(XILINX_VIVADO)/data/ip/xpm/xpm_fifo/hdl/xpm_fifo.sv
	vlog -work work $::env(XILINX_VIVADO)/data/ip/xpm/xpm_cdc/hdl/xpm_cdc.sv
	vlog -work work $::env(XILINX_VIVADO)/data/ip/xpm/xpm_memory/hdl/xpm_memory.sv

	do scr/$TB/compile_all.tcl

#	set line_file_list [list "$project_path/" "csa.sv" "csa_tb.sv"]
	
#========== run simulation
	
	# optimization is required for schematic view
	if {$compile_error == 0} {
	
	vsim	-wlf $wlf_save_name -sv_seed 0  -wlfopt -wlfslim 10000 -wlftlim {500 ms}\
			$VOPTARGS_SWITCH -debugDB \
			-L unisims_ver -L unimacro_ver $TB work.glbl

#========== adding signals to wave window
	# default radix (hex without base)
	# radix -hexadecimal -enumnumeric
	radix -hexadecimal -showbase

	do scr/$TB/wave.tcl
	
	
	#############################################

	configure wave -signalnamewidth 1

	configure wave -griddelta 40
	configure wave -gridoffset 0
	configure wave -gridperiod 10
	
	configure wave -timelineunits us
	configure wave -namecolwidth 200
	configure wave -valuecolwidth 50
	configure wave -justifyvalue right

	#########################################

	# run $run_time 
	run -all
	
	}