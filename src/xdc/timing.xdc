	
	# micro_clk: 66.71114 MHz
	# create_clock -period 14.99 -name micro_clk [get_ports micro_clk]
	
	# sysclok = 345 MHz
	create_clock -period 2.89855 -name clk [get_ports clk] 

	# # sysclok = 410 MHz
	# create_clock -period 2.43902 -name clk [get_ports clk] 

	# sysclok = 312.5 MHz
	# create_clock -period 3.2 -name clk [get_ports clk] 

	# sysclok = 324.6753246753247 MHz
	# create_clock -period 3.08 -name clk [get_ports clk] 

	# sysclok =  MHz
	# create_clock -period 3.52 -name clk [get_ports clk] 

	# 72/25
	# create_clock -period 2.88 -name clk [get_ports clk] 



	create_clock -period 2.6182 -name clk [get_ports clk] 


	# set_false_path -to [get_pins -hierarchical -filter {NAME =~ */data_sync/D}]
	# 
	# set_false_path -from [get_pins {xpm_fifo_async_inst_gtx/xpm_fifo_base_inst/rdp_inst/count_value_i_reg[?]/C}] -to [get_pins {xpm_fifo_async_inst_gtx/xpm_fifo_base_inst/gen_pntr_pf_rc.rpw_rc_reg/reg_out_i_reg[?]/D}]
	# set_false_path -from [get_pins {xpm_fifo_async_inst_gtx/xpm_fifo_base_inst/wrp_inst/count_value_i_reg[?]/C}] -to [get_pins {xpm_fifo_async_inst_gtx/xpm_fifo_base_inst/gen_pntr_pf_rc.wpr_rc_reg/reg_out_i_reg[?]/D}]
	# 
	# set_false_path -from [get_pins {coding[?].xpm_fifo_async_inst_gtx/xpm_fifo_base_inst/rdp_inst/count_value_i_reg[?]/C}] -to [get_pins {coding[?].xpm_fifo_async_inst_gtx/xpm_fifo_base_inst/gen_pntr_pf_rc.rpw_rc_reg/reg_out_i_reg[?]/D}]
	# set_false_path -from [get_pins {coding[?].xpm_fifo_async_inst_gtx/xpm_fifo_base_inst/wrp_inst/count_value_i_reg[?]/C}] -to [get_pins {coding[?].xpm_fifo_async_inst_gtx/xpm_fifo_base_inst/gen_pntr_pf_rc.wpr_rc_reg/reg_out_i_reg[?]/D}]
