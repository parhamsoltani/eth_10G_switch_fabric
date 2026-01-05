onerror {resume}
quietly WaveActivateNextPane {} 0

add wave -noupdate -divider {Testbench}
add wave -noupdate /tb_ip_dscp/sys_clk
add wave -noupdate /tb_ip_dscp/sys_reset
add wave -noupdate -radix unsigned /tb_ip_dscp/test_count
add wave -noupdate -radix unsigned /tb_ip_dscp/pass_count
add wave -noupdate -radix unsigned /tb_ip_dscp/fail_count

add wave -noupdate -divider {RX Port 0}
add wave -noupdate /tb_ip_dscp/rx_data_if[0]/valid
add wave -noupdate /tb_ip_dscp/rx_data_if[0]/ready
add wave -noupdate -radix hex /tb_ip_dscp/rx_data_if[0]/data
add wave -noupdate -radix unsigned /tb_ip_dscp/rx_data_if[0]/id

add wave -noupdate -divider {TX Port 1}
add wave -noupdate /tb_ip_dscp/tx_data_if[1]/valid
add wave -noupdate /tb_ip_dscp/tx_data_if[1]/ready
add wave -noupdate /tb_ip_dscp/tx_data_if[1]/last

TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ps} 0}
configure wave -namecolwidth 250
configure wave -valuecolwidth 100
update
WaveRestoreZoom {0 ps} {20 us}
run -all