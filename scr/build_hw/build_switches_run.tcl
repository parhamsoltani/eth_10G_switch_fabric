
	-top wrapper_switch_fabric
	# -top wrapper_fifo_array 
	# -top wrapper_packet_mode_fifo_array
	# -top wrapper_first_none_zero_except_k
	# -top wrapper_dest_finder_row
	# -top shared_xpq
	# -top wrapper_dest_finder_row_matching
	
	### by using chkpt_file without .dcp file, it will automaticly load from products directory of one step before "from_step"
	# -chkpt_file		../../out/products/route/Default_best_route.dcp
	# -chkpt_file 

# Steps
	#	synth
	#	opt
	#	place
	#	physopt
	#	route
	#	postroutePhysopt
	#	bitgen
	
	-from_step synth
	-to_step postroutePhysopt
	


	
###########################################
### Directives
###########################################


### synth
# -synth_directive RuntimeOptimized AreaOptimized_high AreaOptimized_medium AlternateRoutability AreaMapLargeShiftRegToBRAM AreaMultThresholdDSP FewerCarryChains PerformanceOptimized LogicCompaction PowerOptimized_high PowerOptimized_medium Default

### opt
# -opt_directive Explore ExploreArea ExploreSequentialArea RuntimeOptimized ExploreWithRemap RQS Default

### place
# -place_directive Explore WLDrivenBlockPlacement ExtraNetDelay_high ExtraNetDelay_low AltSpreadLogic_low AltSpreadLogic_medium AltSpreadLogic_high ExtraPostPlacementOpt ExtraTimingOpt SSI_SpreadLogic_high SSI_SpreadLogic_low SSI_SpreadSLLs SSI_BalanceSLLs SSI_BalanceSLRs SSI_HighUtilSLRs RuntimeOptimized Quick Default EarlyBlockPlacement RQS Auto_1 Auto_2 Auto_3

### physopt
# -phys_opt_directive Explore ExploreWithHoldFix AggressiveExplore AlternateReplication AggressiveFanoutOpt AddRetime AlternateFlowWithRetiming RuntimeOptimized ExploreWithAggressiveHoldFix RQS Default

### route
# -route_directive Explore NoTimingRelaxation MoreGlobalIterations HigherDelayCost AdvancedSkewModeling RuntimeOptimized Quick AlternateCLBRouting AggressiveExplore RQS Default
# -route_directive MoreGlobalIterations
### postroutePhysopt
# -postroute_physopt_directive Explore AggressiveExplore AddRetime ExploreWithAggressiveHoldFix RQS Default




###########################################
### Options
###########################################

### synth
-synth_options "-mode out_of_context"

### opt
# -opt_options

### place
# -place_options

### physopt
# -phys_opt_options

### route
# -route_options

### postroutePhysopt
# -postroute_physopt_options "-tcl.post set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]"







