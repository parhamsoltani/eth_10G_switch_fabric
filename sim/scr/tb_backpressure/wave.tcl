onerror {resume}
quietly WaveActivateNextPane {} 0

add wave -noupdate -divider {Testbench}
add wave -noupdate /tb_backpressure/sys_clk
add wave -noupdate /tb_backpressure/sys_reset
add wave -noupdate -radix unsigned /tb_backpressure/packets_sent
add wave -noupdate -radix unsigned /tb_backpressure/packets_received
add wave -noupdate -radix unsigned /tb_backpressure/backpressure_cycles

add wave -noupdate -divider {TX Port 0}
add wave -noupdate /tb_backpressure/rx_data_if[0]/valid
add wave -noupdate /tb_backpressure/rx_data_if[0]/ready
add wave -noupdate /tb_backpressure/rx_data_if[0]/last

add wave -noupdate -divider {RX Port 1 (with backpressure)}
add wave -noupdate /tb_backpressure/tx_data_if[1]/valid
add wave -noupdate /tb_backpressure/tx_data_if[1]/ready
add wave -noupdate /tb_backpressure/tx_data_if[1]/last
add wave -noupdate -radix unsigned /tb_backpressure/tx_data_if[1]/id

TreeUpdate [SetDefaultTree]
configure wave -namecolwidth 300
configure wave -valuecolwidth 100
update
WaveRestoreZoom {0 ps} {20 us}

run -all