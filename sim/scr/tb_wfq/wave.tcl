onerror {resume}
quietly WaveActivateNextPane {} 0

add wave -noupdate -divider {Testbench}
add wave -noupdate /tb_wfq/sys_clk
add wave -noupdate -radix unsigned /tb_wfq/packets_sent_p7
add wave -noupdate -radix unsigned /tb_wfq/packets_sent_p0
add wave -noupdate -radix unsigned /tb_wfq/packets_recv_p7
add wave -noupdate -radix unsigned /tb_wfq/packets_recv_p0

add wave -noupdate -divider {RX Port 1}
add wave -noupdate /tb_wfq/tx_data_if[1]/valid
add wave -noupdate /tb_wfq/tx_data_if[1]/ready
add wave -noupdate /tb_wfq/tx_data_if[1]/last
add wave -noupdate -radix unsigned /tb_wfq/tx_data_if[1]/id

TreeUpdate [SetDefaultTree]
configure wave -namecolwidth 300
update
WaveRestoreZoom {0 ps} {50 us}

run -all