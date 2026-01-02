onerror {resume}
quietly WaveActivateNextPane {} 0

# Clock & Reset
add wave -noupdate -divider {Clock & Reset}
add wave -noupdate /tb_fabric_qos_sweep/sys_clk
add wave -noupdate /tb_fabric_qos_sweep/sys_reset

# Configuration
add wave -noupdate -divider {Configuration}
add wave -noupdate /tb_fabric_qos_sweep/NUM_PORT
add wave -noupdate /tb_fabric_qos_sweep/S
add wave -noupdate /tb_fabric_qos_sweep/ENABLE_QOS
add wave -noupdate /tb_fabric_qos_sweep/QOS_TAG_WIDTH

# Statistics
add wave -noupdate -divider {Statistics}
add wave -noupdate -radix unsigned /tb_fabric_qos_sweep/packets_sent
add wave -noupdate -radix unsigned /tb_fabric_qos_sweep/packets_received
add wave -noupdate -radix unsigned /tb_fabric_qos_sweep/global_pkt_id

# Input Interfaces (Port 0)
add wave -noupdate -divider {Port 0 - Input (rx_data_if)}
add wave -noupdate -radix hexadecimal /tb_fabric_qos_sweep/rx_data_if[0]/data
add wave -noupdate /tb_fabric_qos_sweep/rx_data_if[0]/valid
add wave -noupdate /tb_fabric_qos_sweep/rx_data_if[0]/ready
add wave -noupdate /tb_fabric_qos_sweep/rx_data_if[0]/last
add wave -noupdate -radix unsigned /tb_fabric_qos_sweep/rx_data_if[0]/id
add wave -noupdate -radix unsigned /tb_fabric_qos_sweep/rx_data_if[0]/keep

# Input Metadata (Port 0)
add wave -noupdate -divider {Port 0 - Metadata (rx_meta_if)}
add wave -noupdate /tb_fabric_qos_sweep/rx_meta_if[0]/valid
add wave -noupdate /tb_fabric_qos_sweep/rx_meta_if[0]/ready
add wave -noupdate -radix hexadecimal /tb_fabric_qos_sweep/rx_meta_if[0]/dest_port_mask
add wave -noupdate -radix unsigned /tb_fabric_qos_sweep/rx_meta_if[0]/qos_tag
add wave -noupdate -radix unsigned /tb_fabric_qos_sweep/rx_meta_if[0]/id

# Output Interfaces (Port 0)
add wave -noupdate -divider {Port 0 - Output (tx_data_if)}
add wave -noupdate -radix hexadecimal /tb_fabric_qos_sweep/tx_data_if[0]/data
add wave -noupdate /tb_fabric_qos_sweep/tx_data_if[0]/valid
add wave -noupdate /tb_fabric_qos_sweep/tx_data_if[0]/ready
add wave -noupdate /tb_fabric_qos_sweep/tx_data_if[0]/last
add wave -noupdate -radix unsigned /tb_fabric_qos_sweep/tx_data_if[0]/id

# Output Interfaces (Port 1)
add wave -noupdate -divider {Port 1 - Output (tx_data_if)}
add wave -noupdate -radix hexadecimal /tb_fabric_qos_sweep/tx_data_if[1]/data
add wave -noupdate /tb_fabric_qos_sweep/tx_data_if[1]/valid
add wave -noupdate /tb_fabric_qos_sweep/tx_data_if[1]/ready
add wave -noupdate /tb_fabric_qos_sweep/tx_data_if[1]/last
add wave -noupdate -radix unsigned /tb_fabric_qos_sweep/tx_data_if[1]/id

# DUT Internal - Ingress Line QoS (if accessible)
add wave -noupdate -divider {DUT - Ingress QoS}
add wave -noupdate -radix unsigned /tb_fabric_qos_sweep/dut/gen_ingress[0]/u_ingress/qos_tag_o
add wave -noupdate /tb_fabric_qos_sweep/dut/gen_ingress[0]/u_ingress/data_valid_o

# Driver/Monitor Status
add wave -noupdate -divider {Driver Port 0}
add wave -noupdate /tb_fabric_qos_sweep/gen_port_agents[0]/u_driver/frame

add wave -noupdate -divider {Monitor Port 0}
add wave -noupdate /tb_fabric_qos_sweep/gen_port_agents[0]/u_monitor/frame_started

add wave -noupdate -divider {Monitor Port 1}
add wave -noupdate /tb_fabric_qos_sweep/gen_port_agents[1]/u_monitor/frame_started

TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 350
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
WaveRestoreZoom {0 ns} {10000 ns}