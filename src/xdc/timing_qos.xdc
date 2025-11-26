# QoS-specific timing constraints
# Automatically sourced when ENABLE_QOS=1

# ============================================================================
# QoS Classification Path Constraints
# ============================================================================

# Relax timing on QoS tag propagation (non-critical data path)
set_multicycle_path -setup 2 -from [get_pins -hierarchical -filter {NAME =~ */qos_classifier/qos_tag_reg*/C}] \
                               -to [get_pins -hierarchical -filter {NAME =~ */ingress_line_qos/qos_tag_o_reg*/D}]

set_multicycle_path -hold 1  -from [get_pins -hierarchical -filter {NAME =~ */qos_classifier/qos_tag_reg*/C}] \
                               -to [get_pins -hierarchical -filter {NAME =~ */ingress_line_qos/qos_tag_o_reg*/D}]

# ============================================================================
# QoS Priority Comparison Paths (Matching Logic)
# ============================================================================

# Tighten timing on priority comparison (critical for fairness)
set_max_delay 1.0 -from [get_pins -hierarchical -filter {NAME =~ */dest_finder_row_matching_qos/buf_qos*_reg*/C}] \
                    -to [get_pins -hierarchical -filter {NAME =~ */dest_finder_row_matching_qos/dest_reg_*_reg*/D}]

# ============================================================================
# QoS Statistics Counters (Relaxed Timing)
# ============================================================================

# Counters can span multiple cycles (updated infrequently)
set_multicycle_path -setup 3 -from [get_pins -hierarchical -filter {NAME =~ */micro_interface_qos/qos_*_count_reg*/C}] \
                               -to [get_pins -hierarchical -filter {NAME =~ */micro_interface_qos/qos_*_count_reg*/D}]

set_multicycle_path -hold 2  -from [get_pins -hierarchical -filter {NAME =~ */micro_interface_qos/qos_*_count_reg*/C}] \
                               -to [get_pins -hierarchical -filter {NAME =~ */micro_interface_qos/qos_*_count_reg*/D}]

# ============================================================================
# False Paths (QoS Enable Control)
# ============================================================================

# QoS enable is quasi-static (set at initialization)
set_false_path -from [get_pins -hierarchical -filter {NAME =~ */micro_interface_qos/qos_enable_reg/C}] \
               -to [get_pins -hierarchical -filter {NAME =~ */dest_finder_row_matching_qos/qos_enable*/D}]

set_false_path -from [get_pins -hierarchical -filter {NAME =~ */micro_interface_qos/use_*_reg/C}] \
               -to [get_pins -hierarchical -filter {NAME =~ */qos_classifier/use_*_reg/D}]

# ============================================================================
# Clock Domain Crossing (if applicable)
# ============================================================================

# If QoS stats cross to slower microprocessor clock
# set_max_delay 10.0 -datapath_only -from [get_clocks sys_clk] -to [get_clocks micro_clk]

puts "QoS-specific timing constraints applied"