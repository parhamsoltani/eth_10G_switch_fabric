#═══════════════════════════════════════════════════════════════
#  TIMING CONSTRAINTS FOR SWITCH_FABRIC (156.25 MHz)
#  Vivado 2019.1 Compatible - Zero Critical Warnings
#═══════════════════════════════════════════════════════════════

#───────────────────────────────────────────────────────────────
# PRIMARY CLOCK (156.25 MHz = 6.4 ns period)
#───────────────────────────────────────────────────────────────

create_clock -period 6.400 -name clk -waveform {0.000 3.200} [get_ports clk]

#───────────────────────────────────────────────────────────────
# CLOCK UNCERTAINTY
#───────────────────────────────────────────────────────────────

set_clock_uncertainty -setup 0.100 [get_clocks clk]
set_clock_uncertainty -hold  0.050 [get_clocks clk]

#───────────────────────────────────────────────────────────────
# INPUT CONSTRAINTS (All non-clock/non-reset inputs)
#───────────────────────────────────────────────────────────────

set_input_delay -clock clk -min 0.000 [get_ports -filter {DIRECTION == IN && NAME !~ "clk" && NAME !~ "*reset*"}]
set_input_delay -clock clk -max 3.500 [get_ports -filter {DIRECTION == IN && NAME !~ "clk" && NAME !~ "*reset*"}]

# For simulation/verification mode only - bypass I/O timing
#set_false_path -from [get_ports -filter {DIRECTION == IN}]
#set_false_path -to   [get_ports -filter {DIRECTION == OUT}]

# Match input delay to clock path (eliminates hold violations)
#set_input_delay -clock clk -min 3.400 [get_ports -filter {DIRECTION == IN && NAME !~ "clk" && NAME !~ "*reset*"}]
#set_input_delay -clock clk -max 3.500 [get_ports -filter {DIRECTION == IN && NAME !~ "clk" && NAME !~ "*reset*"}]

#───────────────────────────────────────────────────────────────
# OUTPUT CONSTRAINTS (All outputs)
#───────────────────────────────────────────────────────────────

set_output_delay -clock clk -min -0.500 [get_ports -filter {DIRECTION == OUT}]
set_output_delay -clock clk -max  0.800 [get_ports -filter {DIRECTION == OUT}]

#───────────────────────────────────────────────────────────────
# FALSE PATHS (Asynchronous reset)
#───────────────────────────────────────────────────────────────

set_false_path -from [get_ports -filter {NAME =~ "*reset*"}]

#═══════════════════════════════════════════════════════════════
#  END OF CONSTRAINTS
#═══════════════════════════════════════════════════════════════