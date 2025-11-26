onerror {resume}
quietly WaveActivateNextPane {} 0

add wave -noupdate -divider {Clock & Reset}
add wave -noupdate /tb_qos_classifier_unit/clk
add wave -noupdate /tb_qos_classifier_unit/reset

add wave -noupdate -divider {Input Packet}
add wave -noupdate -radix hexadecimal /tb_qos_classifier_unit/pkt_data
add wave -noupdate /tb_qos_classifier_unit/pkt_valid
add wave -noupdate -radix hexadecimal /tb_qos_classifier_unit/dest_mask

add wave -noupdate -divider {QoS Output}
add wave -noupdate -radix unsigned /tb_qos_classifier_unit/qos_tag
add wave -noupdate /tb_qos_classifier_unit/qos_valid

add wave -noupdate -divider {Configuration}
add wave -noupdate -radix unsigned /tb_qos_classifier_unit/mode

TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ns} 0}
configure wave -namecolwidth 300
configure wave -valuecolwidth 100
update
WaveRestoreZoom {0 ns} {5000 ns}