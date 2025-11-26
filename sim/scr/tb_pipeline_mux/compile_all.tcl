	vlog -vopt -sv	+acc -incr -source +define+SIM +incdir+$sim_include_path "tb/pipeline_mux/*.sv"
	

	vlog -vopt -sv	+acc +initreg+0 +initmem+0 -incr -source +define+SIM +incdir+$include_path $project_path/src/hdl/wrappers/*.sv
	vlog -vopt -sv	+acc +initreg+0 +initmem+0 -incr -source +define+SIM +incdir+$include_path $project_path/src/hdl/ip/*/*.sv
	vlog -vopt -sv	+acc +initreg+0 +initmem+0 -incr -source +define+SIM +incdir+$include_path $project_path/src/hdl/ip/*/*/*.sv