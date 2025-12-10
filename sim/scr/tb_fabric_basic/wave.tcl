add wave -hex -group "tb signals" sim:/$TB/sys_clk
add wave -hex -group "tb signals" sim:/$TB/sys_reset
add wave -hex -group "tb signals" sim:/$TB/packets_sent
add wave -hex -group "tb signals" sim:/$TB/packets_recv

add wave -noupdate -divider "RX Interfaces (Port 0 example)"
add wave -hex -group "rx_data_if[0]" sim:/$TB/rx_data_if[0]/*
add wave -hex -group "rx_meta_if[0]" sim:/$TB/rx_meta_if[0]/*

add wave -noupdate -divider "TX Interfaces (Port 0 example)"
add wave -hex -group "tx_data_if[0]" sim:/$TB/tx_data_if[0]/*

add wave -noupdate -divider "DUT Top-Level"
add wave -hex -group "switch_fabric" sim:/$TB/dut/*

add wave -noupdate -divider "Ingress Port 0"
add wave -hex -group "ingress[0]" sim:/$TB/dut/gen_ports[0]/ingress_inst/*

add wave -noupdate -divider "Egress Port 0"
add wave -hex -group "egress[0]" sim:/$TB/dut/gen_ports[0]/egress_inst/*

# Add more as needed, e.g., VOQ/XPQ from your log
add wave -hex -group "VOQ Example" sim:/$TB/dut/gen_high_radix/switch_inst/g_voq[0]/voq_i/*
add wave -hex -group "XPQ Example" sim:/$TB/dut/gen_high_radix/switch_inst/g_xpq_r[0]/g_xpq_c[0]/xpq_i/*