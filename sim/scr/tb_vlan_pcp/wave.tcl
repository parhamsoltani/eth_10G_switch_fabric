onerror {resume}
quietly WaveActivateNextPane {} 0

add wave -noupdate -divider {Testbench Control}
add wave -noupdate /tb_vlan_pcp/sys_clk
add wave -noupdate /tb_vlan_pcp/sys_reset
add wave -noupdate -radix unsigned /tb_vlan_pcp/test_vectors_sent
add wave -noupdate -radix unsigned /tb_vlan_pcp/test_vectors_passed
add wave -noupdate -radix unsigned /tb_vlan_pcp/test_vectors_failed

add wave -noupdate -divider {RX Port 0 (Ingress)}
add wave -noupdate /tb_vlan_pcp/rx_data_if[0]/valid
add wave -noupdate /tb_vlan_pcp/rx_data_if[0]/ready
add wave -noupdate -radix hex /tb_vlan_pcp/rx_data_if[0]/data
add wave -noupdate -radix unsigned /tb_vlan_pcp/rx_data_if[0]/keep
add wave -noupdate /tb_vlan_pcp/rx_data_if[0]/last
add wave -noupdate -radix unsigned /tb_vlan_pcp/rx_data_if[0]/id

add wave -noupdate -divider {RX Metadata Port 0}
add wave -noupdate /tb_vlan_pcp/rx_meta_if[0]/valid
add wave -noupdate /tb_vlan_pcp/rx_meta_if[0]/ready
add wave -noupdate -radix binary /tb_vlan_pcp/rx_meta_if[0]/dest_port_mask
add wave -noupdate -radix unsigned /tb_vlan_pcp/rx_meta_if[0]/qos_tag
add wave -noupdate -radix unsigned /tb_vlan_pcp/rx_meta_if[0]/vlan_id

add wave -noupdate -divider {TX Port 1 (Egress)}
add wave -noupdate /tb_vlan_pcp/tx_data_if[1]/valid
add wave -noupdate /tb_vlan_pcp/tx_data_if[1]/ready
add wave -noupdate -radix hex /tb_vlan_pcp/tx_data_if[1]/data
add wave -noupdate -radix unsigned /tb_vlan_pcp/tx_data_if[1]/keep
add wave -noupdate /tb_vlan_pcp/tx_data_if[1]/last

TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 250
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {0 ps} {10 us}

run -all    