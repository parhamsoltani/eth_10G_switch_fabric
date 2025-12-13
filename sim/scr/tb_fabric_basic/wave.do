# ===========================================================================
# Wave configuration for tb_fabric_basic
# ===========================================================================

# Continue on errors (missing signals are non-fatal)
onerror {continue}

# Hardcode the testbench name (no variable needed)
set TB tb_fabric_basic

# ===========================================================================
# Testbench Control Signals
# ===========================================================================
add wave -noupdate -divider "Testbench Control"
add wave -hex -group "TB Signals" /${TB}/sys_clk
add wave -hex -group "TB Signals" /${TB}/sys_reset
add wave -hex -group "TB Signals" /${TB}/reset_done
add wave -unsigned -group "TB Signals" /${TB}/packets_sent
add wave -unsigned -group "TB Signals" /${TB}/packets_recv

# ===========================================================================
# RX Interfaces (Port 0)
# ===========================================================================
add wave -noupdate -divider "RX Interfaces (Port 0)"
add wave -hex -group "rx_data_if[0]" /${TB}/rx_data_if[0]/valid
add wave -hex -group "rx_data_if[0]" /${TB}/rx_data_if[0]/ready
add wave -hex -group "rx_data_if[0]" /${TB}/rx_data_if[0]/data
add wave -hex -group "rx_data_if[0]" /${TB}/rx_data_if[0]/keep
add wave -hex -group "rx_data_if[0]" /${TB}/rx_data_if[0]/last
add wave -hex -group "rx_data_if[0]" /${TB}/rx_data_if[0]/id

add wave -hex -group "rx_meta_if[0]" /${TB}/rx_meta_if[0]/valid
add wave -hex -group "rx_meta_if[0]" /${TB}/rx_meta_if[0]/ready
add wave -hex -group "rx_meta_if[0]" /${TB}/rx_meta_if[0]/dest_port_mask
add wave -hex -group "rx_meta_if[0]" /${TB}/rx_meta_if[0]/qos_tag

# ===========================================================================
# TX Interfaces (Port 0)
# ===========================================================================
add wave -noupdate -divider "TX Interfaces (Port 0)"
add wave -hex -group "tx_data_if[0]" /${TB}/tx_data_if[0]/valid
add wave -hex -group "tx_data_if[0]" /${TB}/tx_data_if[0]/ready
add wave -hex -group "tx_data_if[0]" /${TB}/tx_data_if[0]/data
add wave -hex -group "tx_data_if[0]" /${TB}/tx_data_if[0]/keep
add wave -hex -group "tx_data_if[0]" /${TB}/tx_data_if[0]/last
add wave -hex -group "tx_data_if[0]" /${TB}/tx_data_if[0]/id

# ===========================================================================
# DUT Top-Level Signals
# ===========================================================================
add wave -noupdate -divider "DUT Top-Level"
add wave -hex -group "switch_fabric" /${TB}/dut/clk
add wave -hex -group "switch_fabric" /${TB}/dut/reset

# ===========================================================================
# Ingress Port 0 (if hierarchy exists)
# ===========================================================================
add wave -noupdate -divider "Ingress Port 0"
# Try different possible hierarchies
catch {add wave -hex -group "ingress[0]" /${TB}/dut/gen_ports[0]/ingress_inst/*}
catch {add wave -hex -group "ingress[0]" /${TB}/dut/genblk1[0]/ingress_inst/*}

# ===========================================================================
# Egress Port 0 (if hierarchy exists)
# ===========================================================================
add wave -noupdate -divider "Egress Port 0"
catch {add wave -hex -group "egress[0]" /${TB}/dut/gen_ports[0]/egress_inst/*}
catch {add wave -hex -group "egress[0]" /${TB}/dut/genblk1[0]/egress_inst/*}

# ===========================================================================
# VOQ/XPQ (try different hierarchies)
# ===========================================================================
add wave -noupdate -divider "VOQ/XPQ Internal"
catch {add wave -hex -group "VOQ 0" /${TB}/dut/gen_high_radix/switch_inst/g_voq[0]/voq_i/*}
catch {add wave -hex -group "XPQ 0,0" /${TB}/dut/gen_high_radix/switch_inst/g_xpq_r[0]/g_xpq_c[0]/xpq_i/*}
catch {add wave -hex -group "switch_s" /${TB}/dut/gen_under_s/switch_inst/*}

# ===========================================================================
# Configure wave window
# ===========================================================================
configure wave -namecolwidth 250
configure wave -valuecolwidth 100
configure wave -justifyvalue right
configure wave -signalnamewidth 1
configure wave -timelineunits us

# Zoom to fit
wave zoom full