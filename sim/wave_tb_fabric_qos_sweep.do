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
add wave -noupdate /tb_fabric_qos_sweep/QOS_LEVELS

# Input Interfaces (Port 0)
add wave -noupdate -divider {Port 0 - Input}
add wave -noupdate -radix hexadecimal /tb_fabric_qos_sweep/rx_data_if[0]/data
add wave -noupdate /tb_fabric_qos_sweep/rx_data_if[0]/valid
add wave -noupdate /tb_fabric_qos_sweep/rx_data_if[0]/ready
add wave -noupdate /tb_fabric_qos_sweep/rx_data_if[0]/last
add wave -noupdate -radix unsigned /tb_fabric_qos_sweep/rx_meta_if[0]/qos_tag

# QoS Classifier (Port 0)
add wave -noupdate -divider {QoS Classifier - Port 0}
add wave -noupdate -radix unsigned /tb_fabric_qos_sweep/dut/gen_qos_classifier[0]/u_qos_classifier/qos_tag
add wave -noupdate /tb_fabric_qos_sweep/dut/gen_qos_classifier[0]/u_qos_classifier/qos_valid

# VOQ (Port 0→1)
add wave -noupdate -divider {VOQ [0→1]}
add wave -noupdate -radix unsigned /tb_fabric_qos_sweep/dut/gen_voq[0][1]/u_voq/count
add wave -noupdate /tb_fabric_qos_sweep/dut/gen_voq[0][1]/u_voq/full
add wave -noupdate /tb_fabric_qos_sweep/dut/gen_voq[0][1]/u_voq/empty

# Scheduler (Port 1)
add wave -noupdate -divider {Scheduler - Port 1}
add wave -noupdate -radix unsigned /tb_fabric_qos_sweep/dut/gen_qos_scheduler[1]/u_scheduler/current_qos
add wave -noupdate /tb_fabric_qos_sweep/dut/gen_qos_scheduler[1]/u_scheduler/grant

# Output (Port 1)
add wave -noupdate -divider {Port 1 - Output}
add wave -noupdate -radix hexadecimal /tb_fabric_qos_sweep/tx_data_if[1]/data
add wave -noupdate /tb_fabric_qos_sweep/tx_data_if[1]/valid
add wave -noupdate /tb_fabric_qos_sweep/tx_data_if[1]/last

# Scoreboard
add wave -noupdate -divider {Scoreboard}
add wave -noupdate -radix unsigned /tb_fabric_qos_sweep/u_scoreboard/packets_sent
add wave -noupdate -radix unsigned /tb_fabric_qos_sweep/u_scoreboard/packets_recv
add wave -noupdate -radix unsigned /tb_fabric_qos_sweep/u_scoreboard/priority_violations

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