# QoS-specific waveforms (extends your tb_ethernet_switch/wave.tcl)

add wave -hex -group "tb signals" sim:/$TB/*

add wave -noupdate -divider "QoS Checker"
add wave -hex -group "qos_check" sim:/$TB/qos_check/*

add wave -noupdate -divider "Switch Fabric"
add wave -hex -group "switch fabric" sim:/$TB/dut/*

# VOQ with QoS (follows your gen_ports pattern)
add wave -noupdate -divider "VOQ Port 0"
add wave -hex -group "voq[0]" sim:/$TB/dut/gen_high_radix/switch_inst/g_voq[0]/voq_i/*
add wave -hex -group "voq[0] p2c[0]" sim:/$TB/dut/gen_high_radix/switch_inst/g_voq[0]/voq_i/gen_p2c[0]/p2c/*

# XPQ with QoS
add wave -noupdate -divider "XPQ (0,0)"
add wave -hex -group "xpq(0,0)" sim:/$TB/dut/gen_high_radix/switch_inst/g_xpq_r[0]/g_xpq_c[0]/xpq_i/*

# Cell2Packet with QoS
add wave -noupdate -divider "Cell2Packet Col 0"
add wave -hex -group "c2p[0]" sim:/$TB/dut/gen_high_radix/switch_inst/g_cell2pkt_col[0]/u_cell2pkt_c/gen_c2p[0]/c2p/*