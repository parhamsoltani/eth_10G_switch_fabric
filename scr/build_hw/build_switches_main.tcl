	# +quit
	
	-output_dir     ../../out
	-hist_dir		../../out/hw_history
	-strict_check_chkpt_filename
	-tcl_hooks_dir	./tcl_hooks

	# -device_part_num xcku3p-ffvb676-2-e
	# -device_part_num xcvu3p-ffvc1517-1-i
	# -device_part_num xcvu3p-ffvc1517-3-e
	# -device_part_num xcku15p-ffve1517-2-e 
	# -device_part_num xc7k325tffg900-2
	# -device_part_num xcvu9p-flga2577-3-e 
	# -device_part_num xcvp1802-lsvc4072-3HP-e-S
	# -device_part_num xcvu13p-flga2577-3-e



	-device_part_num xcvu9p-flga2577-3-e 
	
	# -src_dir_list ../../src 
	-src_list_file ../files_list.tcl

	### use <-report> to create history from out reports and exit before run
	# -report

	### the below switch updates history even even if the last step is not bitgen 
	-update_hist

	### use the <-objectiveFunc "resource"> switch to find directive that minimize "resource" # valid resources: bram, lutram, dsp, clb, lut, reg, uram
	#-objectiveFunc "lutram"

	### use the below switch to disable sweeping over directives
	-disable_directive_sweep

	### use the below switch to export netlist after run
	# -export_netlist

	### use the below switches to create vivado project after run
	# -project_dir_name ../../prj/swich
	# -createPrj

	### use <-createPrj_and_exit> to create project and exit before run
	# -createPrj_and_exit
	
	-setfiletype_toSV

	# -rdchkpt_inc route.dcp

