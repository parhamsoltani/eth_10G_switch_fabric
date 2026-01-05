onerror {resume}
quietly WaveActivateNextPane {} 0

add wave -noupdate -divider {Testbench Control}
add wave -noupdate /tb_multicast/sys_clk
add wave -noupdate /tb_multicast/sys_reset
add wave -noupdate -radix unsigned /tb_multicast/packets_sent

add wave -noupdate -divider {Packet Counters}
add wave -noupdate -radix unsigned /tb_multicast/packets_received[0]
add wave -noupdate -radix unsigned /tb_multicast/packets_received[1]
add wave -noupdate -radix unsigned /tb_multicast/packets_received[2]
add wave -noupdate -radix unsigned /tb_multicast/packets_received[3]
add wave -noupdate -radix unsigned /tb_multicast/packets_received[4]

add wave -noupdate -divider {TX Port 0 (Source)}
add wave -noupdate /tb_multicast/rx_data_if[0]/valid
add wave -noupdate /tb_multicast/rx_data_if[0]/ready
add wave -noupdate -radix hex /tb_multicast/rx_data_if[0]/data
add wave -noupdate /tb_multicast/rx_data_if[0]/last
add wave -noupdate -radix unsigned /tb_multicast/rx_data_if[0]/id

add wave -noupdate -divider {TX Metadata Port 0}
add wave -noupdate /tb_multicast/rx_meta_if[0]/valid
add wave -noupdate -radix binary /tb_multicast/rx_meta_if[0]/dest_port_mask

add wave -noupdate -divider {RX Port 1}
add wave -noupdate /tb_multicast/tx_data_if[1]/valid
add wave -noupdate /tb_multicast/tx_data_if[1]/ready
add wave -noupdate /tb_multicast/tx_data_if[1]/last

add wave -noupdate -divider {RX Port 2}
add wave -noupdate /tb_multicast/tx_data_if[2]/valid
add wave -noupdate /tb_multicast/tx_data_if[2]/last

add wave -noupdate -divider {RX Port 3}
add wave -noupdate /tb_multicast/tx_data_if[3]/valid
add wave -noupdate /tb_multicast/tx_data_if[3]/last

TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ps} 0}
configure wave -namecolwidth 300
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
update
WaveRestoreZoom {0 ps} {50 us}

run -all