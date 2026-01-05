onerror {resume}
quietly WaveActivateNextPane {} 0

add wave -noupdate -divider {Testbench}
add wave -noupdate /tb_reset/sys_clk
add wave -noupdate /tb_reset/sys_reset
add wave -noupdate -radix unsigned /tb_reset/test_phase
add wave -noupdate -radix unsigned /tb_reset/packets_before_reset
add wave -noupdate -radix unsigned /tb_reset/packets_after_reset

add wave -noupdate -divider {RX Port 1}
add wave -noupdate /tb_reset/tx_data_if[1]/valid
add wave -noupdate /tb_reset/tx_data_if[1]/ready
add wave -noupdate /tb_reset/tx_data_if[1]/last
add wave -noupdate -radix unsigned /tb_reset/tx_data_if[1]/id

TreeUpdate [SetDefaultTree]
configure wave -namecolwidth 300
update
WaveRestoreZoom {0 ps} {30 us}

run -all