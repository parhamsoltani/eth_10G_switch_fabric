# Wave configuration for tb_fabric_qos
# This file is loaded AFTER vsim starts

# Testbench signals
add wave -noupdate -divider "Testbench"
add wave -hex -group "tb signals" sim:/tb_fabric_qos/*

# Clock and Reset
add wave -noupdate -divider "Clock/Reset"
add wave sim:/tb_fabric_qos/clk
add wave sim:/tb_fabric_qos/rst_n

# QoS Checker
add wave -noupdate -divider "QoS Checker"
catch {add wave -hex -group "qos_check" sim:/tb_fabric_qos/qos_check/*}

# Scoreboard
add wave -noupdate -divider "Scoreboard"
catch {add wave -hex -group "scoreboard" sim:/tb_fabric_qos/scoreboard/*}

# Switch Fabric DUT
add wave -noupdate -divider "Switch Fabric"
catch {add wave -hex -group "switch fabric" sim:/tb_fabric_qos/dut/*}

# RX Data Interfaces (first 4 ports)
add wave -noupdate -divider "RX Data Interfaces"
for {set i 0} {$i < 4} {incr i} {
    catch {add wave -hex -group "rx_data\[$i\]" sim:/tb_fabric_qos/rx_data_if\[$i\]/*}
}

# RX Metadata Interfaces (first 4 ports)
add wave -noupdate -divider "RX Metadata Interfaces"
for {set i 0} {$i < 4} {incr i} {
    catch {add wave -hex -group "rx_meta\[$i\]" sim:/tb_fabric_qos/rx_meta_if\[$i\]/*}
}

# TX Data Interfaces (first 4 ports)
add wave -noupdate -divider "TX Data Interfaces"
for {set i 0} {$i < 4} {incr i} {
    catch {add wave -hex -group "tx_data\[$i\]" sim:/tb_fabric_qos/tx_data_if\[$i\]/*}
}

# Internal switch components (wrap in catch in case hierarchy differs)
add wave -noupdate -divider "VOQ Port 0"
catch {add wave -hex -group "voq\[0\]" sim:/tb_fabric_qos/dut/gen_high_radix/switch_inst/g_voq\[0\]/voq_i/*}

add wave -noupdate -divider "XPQ (0,0)"
catch {add wave -hex -group "xpq(0,0)" sim:/tb_fabric_qos/dut/gen_high_radix/switch_inst/g_xpq_r\[0\]/g_xpq_c\[0\]/xpq_i/*}