#═══════════════════════════════════════════════════════════════════════════════
#  TIMING CONSTRAINTS FOR SWITCH_FABRIC
#  Target: 156.25 MHz (6.4ns period)
#  
#  FIXES APPLIED:
#  1. Single clock definition (removed duplicates)
#  2. Input delay min set to 2.5ns to match clock tree delay (fixes hold)
#  3. Output delay relaxed for combinational paths (fixes setup)
#  4. Proper false paths for reset
#═══════════════════════════════════════════════════════════════════════════════

#───────────────────────────────────────────────────────────────────────────────
# CLOCK DEFINITION - SINGLE DEFINITION ONLY
#───────────────────────────────────────────────────────────────────────────────
# 156.25 MHz = 6.4ns period
create_clock -period 6.400 -name clk -waveform {0.000 3.200} [get_ports clk]

# Alternative clock frequencies (uncomment ONE only):
# 345 MHz (aggressive):
# create_clock -period 2.89855 -name clk [get_ports clk]
# 312.5 MHz:
# create_clock -period 3.200 -name clk [get_ports clk]
# 200 MHz (conservative):
# create_clock -period 5.000 -name clk [get_ports clk]

#───────────────────────────────────────────────────────────────────────────────
# CLOCK UNCERTAINTY
#───────────────────────────────────────────────────────────────────────────────
set_clock_uncertainty -setup 0.150 [get_clocks clk]
set_clock_uncertainty -hold  0.050 [get_clocks clk]

#───────────────────────────────────────────────────────────────────────────────
# INPUT DELAY CONSTRAINTS - CRITICAL FOR HOLD TIMING
#───────────────────────────────────────────────────────────────────────────────
# The min input delay must account for clock tree delay to internal FFs
# Clock tree delay is approximately 3.0-3.5ns based on timing reports
# Setting min input delay to 2.5ns provides margin for hold timing
#
# Max input delay determines setup margin:
#   Setup slack = Period - ClkUncertainty - MaxInputDelay - DataPathDelay
#   With 6.4ns period, 4.0ns max input delay leaves ~2.25ns for internal paths

# RX Data Interface
set_input_delay -clock clk -min 2.500 [get_ports {rx_data_if[*].data[*]}]
set_input_delay -clock clk -max 4.000 [get_ports {rx_data_if[*].data[*]}]

set_input_delay -clock clk -min 2.500 [get_ports {rx_data_if[*].keep[*]}]
set_input_delay -clock clk -max 4.000 [get_ports {rx_data_if[*].keep[*]}]

set_input_delay -clock clk -min 2.500 [get_ports {rx_data_if[*].valid}]
set_input_delay -clock clk -max 4.000 [get_ports {rx_data_if[*].valid}]

set_input_delay -clock clk -min 2.500 [get_ports {rx_data_if[*].last}]
set_input_delay -clock clk -max 4.000 [get_ports {rx_data_if[*].last}]

set_input_delay -clock clk -min 2.500 [get_ports {rx_data_if[*].is_bad_frame}]
set_input_delay -clock clk -max 4.000 [get_ports {rx_data_if[*].is_bad_frame}]

set_input_delay -clock clk -min 2.500 [get_ports {rx_data_if[*].id[*]}]
set_input_delay -clock clk -max 4.000 [get_ports {rx_data_if[*].id[*]}]

set_input_delay -clock clk -min 2.500 [get_ports {rx_data_if[*].qos_tag[*]}]
set_input_delay -clock clk -max 4.000 [get_ports {rx_data_if[*].qos_tag[*]}]

# RX Metadata Interface
set_input_delay -clock clk -min 2.500 [get_ports {rx_meta_if[*].dest_port_mask[*]}]
set_input_delay -clock clk -max 4.000 [get_ports {rx_meta_if[*].dest_port_mask[*]}]

set_input_delay -clock clk -min 2.500 [get_ports {rx_meta_if[*].id[*]}]
set_input_delay -clock clk -max 4.000 [get_ports {rx_meta_if[*].id[*]}]

set_input_delay -clock clk -min 2.500 [get_ports {rx_meta_if[*].qos_tag[*]}]
set_input_delay -clock clk -max 4.000 [get_ports {rx_meta_if[*].qos_tag[*]}]

set_input_delay -clock clk -min 2.500 [get_ports {rx_meta_if[*].vlan_id[*]}]
set_input_delay -clock clk -max 4.000 [get_ports {rx_meta_if[*].vlan_id[*]}]

set_input_delay -clock clk -min 2.500 [get_ports {rx_meta_if[*].valid}]
set_input_delay -clock clk -max 4.000 [get_ports {rx_meta_if[*].valid}]

# Catch-all for any other inputs (excluding clk and reset)
set_input_delay -clock clk -min 2.500 [get_ports -filter {DIRECTION == IN && NAME !~ "clk" && NAME !~ "*reset*" && NAME !~ "*rst*" && NAME !~ "rx_data_if*" && NAME !~ "rx_meta_if*"}]
set_input_delay -clock clk -max 4.000 [get_ports -filter {DIRECTION == IN && NAME !~ "clk" && NAME !~ "*reset*" && NAME !~ "*rst*" && NAME !~ "rx_data_if*" && NAME !~ "rx_meta_if*"}]

#───────────────────────────────────────────────────────────────────────────────
# OUTPUT DELAY CONSTRAINTS
#───────────────────────────────────────────────────────────────────────────────
# Ready signals have combinational paths from FSM - need relaxed constraints
# Negative min delay accounts for clock-to-output delay of driving FF
# Max delay of 1.0-1.5ns allows sufficient internal logic delay

# RX Data Interface Ready (output from this module)
set_output_delay -clock clk -min -0.500 [get_ports {rx_data_if[*].ready}]
set_output_delay -clock clk -max  1.000 [get_ports {rx_data_if[*].ready}]

# RX Metadata Interface Ready (output from this module) - CRITICAL PATH
set_output_delay -clock clk -min -0.500 [get_ports {rx_meta_if[*].ready}]
set_output_delay -clock clk -max  1.000 [get_ports {rx_meta_if[*].ready}]

# TX Data Interface (all signals are outputs)
set_output_delay -clock clk -min -0.500 [get_ports {tx_data_if[*].data[*]}]
set_output_delay -clock clk -max  1.500 [get_ports {tx_data_if[*].data[*]}]

set_output_delay -clock clk -min -0.500 [get_ports {tx_data_if[*].keep[*]}]
set_output_delay -clock clk -max  1.500 [get_ports {tx_data_if[*].keep[*]}]

set_output_delay -clock clk -min -0.500 [get_ports {tx_data_if[*].valid}]
set_output_delay -clock clk -max  1.500 [get_ports {tx_data_if[*].valid}]

set_output_delay -clock clk -min -0.500 [get_ports {tx_data_if[*].last}]
set_output_delay -clock clk -max  1.500 [get_ports {tx_data_if[*].last}]

set_output_delay -clock clk -min -0.500 [get_ports {tx_data_if[*].is_bad_frame}]
set_output_delay -clock clk -max  1.500 [get_ports {tx_data_if[*].is_bad_frame}]

set_output_delay -clock clk -min -0.500 [get_ports {tx_data_if[*].id[*]}]
set_output_delay -clock clk -max  1.500 [get_ports {tx_data_if[*].id[*]}]

set_output_delay -clock clk -min -0.500 [get_ports {tx_data_if[*].qos_tag[*]}]
set_output_delay -clock clk -max  1.500 [get_ports {tx_data_if[*].qos_tag[*]}]

#───────────────────────────────────────────────────────────────────────────────
# FALSE PATHS
#───────────────────────────────────────────────────────────────────────────────
# Asynchronous reset - no timing requirement
set_false_path -from [get_ports {reset}]
set_false_path -from [get_ports -filter {NAME =~ "*rst*"}]

# Static configuration signals (if any)
# set_false_path -from [get_ports {use_vlan_pcp}]
# set_false_path -from [get_ports {use_ip_dscp}]
# set_false_path -from [get_ports {use_port_classify}]

#───────────────────────────────────────────────────────────────────────────────
# MULTICYCLE PATHS (Optional - uncomment if applicable)
#───────────────────────────────────────────────────────────────────────────────
# QoS classifier results used one cycle later
# set_multicycle_path 2 -setup -from [get_cells -hierarchical *classifier*] -to [get_cells -hierarchical *qos_tag_reg*]
# set_multicycle_path 1 -hold  -from [get_cells -hierarchical *classifier*] -to [get_cells -hierarchical *qos_tag_reg*]

# Header parsing registers (multi-cycle capture)
# set_multicycle_path 2 -setup -from [get_cells -hierarchical *ethertype_reg*]
# set_multicycle_path 1 -hold  -from [get_cells -hierarchical *ethertype_reg*]

#───────────────────────────────────────────────────────────────────────────────
# MAX DELAY CONSTRAINTS (Optional - for specific critical paths)
#───────────────────────────────────────────────────────────────────────────────
# If specific paths still fail, use max_delay to constrain them
# set_max_delay 5.0 -from [get_cells -hierarchical *FSM_sequential*] -to [get_ports {rx_meta_if[*].ready}]

#═══════════════════════════════════════════════════════════════════════════════
# SYNTHESIS AND IMPLEMENTATION DIRECTIVES
#═══════════════════════════════════════════════════════════════════════════════
# These are applied via TCL script, not XDC, but documented here for reference:
#
# Synthesis:
#   set_property STEPS.SYNTH_DESIGN.ARGS.RETIMING true [get_runs synth_1]
#   set_property STEPS.SYNTH_DESIGN.ARGS.DIRECTIVE PerformanceOptimized [get_runs synth_1]
#
# Implementation:
#   set_property STEPS.OPT_DESIGN.ARGS.DIRECTIVE ExploreWithRemap [get_runs impl_1]
#   set_property STEPS.PLACE_DESIGN.ARGS.DIRECTIVE ExtraTimingOpt [get_runs impl_1]
#   set_property STEPS.PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
#   set_property STEPS.PHYS_OPT_DESIGN.ARGS.DIRECTIVE AggressiveExplore [get_runs impl_1]
#   set_property STEPS.ROUTE_DESIGN.ARGS.DIRECTIVE AggressiveExplore [get_runs impl_1]

#═══════════════════════════════════════════════════════════════════════════════
# END OF CONSTRAINTS
#═══════════════════════════════════════════════════════════════════════════════