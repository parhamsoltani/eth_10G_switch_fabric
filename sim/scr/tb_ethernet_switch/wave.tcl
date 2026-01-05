add wave -hex -group "tb signals"	sim:/$TB/*

# add wave -noupdate -divider ethernet_switch
# add wave -hex -group "ethernet switch"	sim:/$TB/u_ethernet_switch/*

# add wave -noupdate -divider ethernet_switch_line_0
# add wave -hex -group "internal signals"	sim:/$TB/u_ethernet_switch/gen_ethernet_line[0]/u_ethernet_line/*
# add wave -hex -group "metadata extractor"	sim:/$TB/u_ethernet_switch/gen_ethernet_line[0]/u_ethernet_line/u_metadata_extractor/*
# add wave -hex -group "header extractor"	sim:/$TB/u_ethernet_switch/gen_ethernet_line[0]/u_ethernet_line/u_metadata_extractor/u_header_extractor/*
# add wave -hex -group "mac to port"	sim:/$TB/u_ethernet_switch/gen_ethernet_line[0]/u_ethernet_line/u_metadata_extractor/u_mac_to_port/*

# add wave -hex -group "rx_axis in"	sim:/$TB/u_ethernet_switch/gen_ethernet_line[0]/u_ethernet_line/rx_axis/*
# add wave -hex -group "rx_axis_sys_sync"	sim:/$TB/u_ethernet_switch/gen_ethernet_line[0]/u_ethernet_line/rx_axis_sys_sync/*
# add wave -hex -group "rx_axis_gearboxed"	sim:/$TB/u_ethernet_switch/gen_ethernet_line[0]/u_ethernet_line/rx_axis_gearboxed/*
# add wave -hex -group "sw_rx_data_if"	sim:/$TB/u_ethernet_switch/gen_ethernet_line[0]/u_ethernet_line/sw_rx_data_if/*
# add wave -hex -group "sw_rx_meta_if"	sim:/$TB/u_ethernet_switch/gen_ethernet_line[0]/u_ethernet_line/sw_rx_meta_if/*

# add wave -hex -group "sw_tx_data_if"	sim:/$TB/u_ethernet_switch/gen_ethernet_line[0]/u_ethernet_line/sw_tx_data_if/*
# add wave -hex -group "tx_axis_gearboxed"	sim:/$TB/u_ethernet_switch/gen_ethernet_line[0]/u_ethernet_line/tx_axis_gearboxed/*
# add wave -hex -group "tx_axis_sys_sync"	sim:/$TB/u_ethernet_switch/gen_ethernet_line[0]/u_ethernet_line/tx_axis_sys_sync/*
# add wave -hex -group "tx_axis"	sim:/$TB/u_ethernet_switch/gen_ethernet_line[0]/u_ethernet_line/tx_axis/*

# add wave -noupdate -divider switch_fabric_wrapper
# add wave -hex -group "switch fabric wrapper"	sim:/$TB/u_dut/*

add wave -noupdate -divider switch_fabric
add wave -hex -group "switch fabric"	sim:/$TB/u_dut/fabric_core/*
add wave -hex -group "port 0 ingress"	sim:/$TB/u_dut/fabric_core/gen_ingress_ports[0]/gen_qos_ingress/ingress_inst/*
add wave -hex -group "port 0 egress"	sim:/$TB/u_dut/fabric_core/gen_egress_ports[0]/egress_inst/*

add wave -noupdate -divider switch_core
add wave -hex -group "switch_inst"	sim:/$TB/u_dut/fabric_core/gen_under_s/gen_qos_switch/switch_inst/*

add wave -noupdate -divider switch_components
add wave -hex -group "col dest_finder 0"	sim:/$TB/u_dut/fabric_core/gen_under_s/gen_qos_switch/switch_inst/g_col_df[0]/col_dest_finder_inst/*
add wave -hex -group "col dest_finder 1"	sim:/$TB/u_dut/fabric_core/gen_under_s/gen_qos_switch/switch_inst/g_col_df[1]/col_dest_finder_inst/*
add wave -hex -group "row dest_finder 0"	sim:/$TB/u_dut/fabric_core/gen_under_s/gen_qos_switch/switch_inst/g_row_df_pair[0]/u_row_df_match/*
add wave -hex -group "row dest_finder 1"	sim:/$TB/u_dut/fabric_core/gen_under_s/gen_qos_switch/switch_inst/g_row_df_pair[1]/u_row_df_match/*
add wave -hex -group "voq 0"	sim:/$TB/u_dut/fabric_core/gen_under_s/gen_qos_switch/switch_inst/g_voq[0]/voq_i/*
add wave -hex -group "voq 1"	sim:/$TB/u_dut/fabric_core/gen_under_s/gen_qos_switch/switch_inst/g_voq[1]/voq_i/*
add wave -hex -group "xpq(0,0)"	sim:/$TB/u_dut/fabric_core/gen_under_s/gen_qos_switch/switch_inst/g_xpq_r[0]/g_xpq_c[0]/xpq_i/*
add wave -hex -group "xpq(0,1)"	sim:/$TB/u_dut/fabric_core/gen_under_s/gen_qos_switch/switch_inst/g_xpq_r[0]/g_xpq_c[1]/xpq_i/*
add wave -hex -group "xpq(1,0)"	sim:/$TB/u_dut/fabric_core/gen_under_s/gen_qos_switch/switch_inst/g_xpq_r[1]/g_xpq_c[0]/xpq_i/*
add wave -hex -group "xpq(1,1)"	sim:/$TB/u_dut/fabric_core/gen_under_s/gen_qos_switch/switch_inst/g_xpq_r[1]/g_xpq_c[1]/xpq_i/*

add wave -noupdate -divider port_0
add wave -hex -group "p2c[0]"	sim:/$TB/u_dut/fabric_core/gen_under_s/gen_qos_switch/switch_inst/g_voq[0]/voq_i/gen_p2c[0]/p2c/*
add wave -hex -group "c2p[0]"	sim:/$TB/u_dut/fabric_core/gen_under_s/gen_qos_switch/switch_inst/g_cell2pkt_col[0]/u_cell2pkt_c/gen_c2p[0]/c2p/*
add wave -hex -group "fabric if port(0) rx data"	sim:/$TB/u_dut/fabric_core/rx_data_if[0]/*
add wave -hex -group "fabric if port(0) rx meta"	sim:/$TB/u_dut/fabric_core/rx_meta_if[0]/*
add wave -hex -group "fabric if port(0) tx"	sim:/$TB/u_dut/fabric_core/tx_data_if[0]/*

add wave -noupdate -divider port_1
add wave -hex -group "p2c[1]"	sim:/$TB/u_dut/fabric_core/gen_under_s/gen_qos_switch/switch_inst/g_voq[0]/voq_i/gen_p2c[1]/p2c/*
add wave -hex -group "c2p[1]"	sim:/$TB/u_dut/fabric_core/gen_under_s/gen_qos_switch/switch_inst/g_cell2pkt_col[0]/u_cell2pkt_c/gen_c2p[1]/c2p/*
add wave -hex -group "fabric if port(1) rx data"	sim:/$TB/u_dut/fabric_core/rx_data_if[1]/*
add wave -hex -group "fabric if port(1) rx meta"	sim:/$TB/u_dut/fabric_core/rx_meta_if[1]/*
add wave -hex -group "fabric if port(1) tx"	sim:/$TB/u_dut/fabric_core/tx_data_if[1]/*

add wave -noupdate -divider port_2
add wave -hex -group "p2c[2]"	sim:/$TB/u_dut/fabric_core/gen_under_s/gen_qos_switch/switch_inst/g_voq[0]/voq_i/gen_p2c[2]/p2c/*
add wave -hex -group "c2p[2]"	sim:/$TB/u_dut/fabric_core/gen_under_s/gen_qos_switch/switch_inst/g_cell2pkt_col[0]/u_cell2pkt_c/gen_c2p[2]/c2p/*
add wave -hex -group "fabric if port(2) rx data"	sim:/$TB/u_dut/fabric_core/rx_data_if[2]/*
add wave -hex -group "fabric if port(2) rx meta"	sim:/$TB/u_dut/fabric_core/rx_meta_if[2]/*
add wave -hex -group "fabric if port(2) tx"	sim:/$TB/u_dut/fabric_core/tx_data_if[2]/*

add wave -noupdate -divider port_3
add wave -hex -group "p2c[3]"	sim:/$TB/u_dut/fabric_core/gen_under_s/gen_qos_switch/switch_inst/g_voq[0]/voq_i/gen_p2c[3]/p2c/*
add wave -hex -group "c2p[3]"	sim:/$TB/u_dut/fabric_core/gen_under_s/gen_qos_switch/switch_inst/g_cell2pkt_col[0]/u_cell2pkt_c/gen_c2p[3]/c2p/*
add wave -hex -group "fabric if port(3) rx data"	sim:/$TB/u_dut/fabric_core/rx_data_if[3]/*
add wave -hex -group "fabric if port(3) rx meta"	sim:/$TB/u_dut/fabric_core/rx_meta_if[3]/*
add wave -hex -group "fabric if port(3) tx"	sim:/$TB/u_dut/fabric_core/tx_data_if[3]/*

add wave -noupdate -divider port_4
add wave -hex -group "p2c[4]"	sim:/$TB/u_dut/fabric_core/gen_under_s/gen_qos_switch/switch_inst/g_voq[0]/voq_i/gen_p2c[4]/p2c/*
add wave -hex -group "c2p[4]"	sim:/$TB/u_dut/fabric_core/gen_under_s/gen_qos_switch/switch_inst/g_cell2pkt_col[0]/u_cell2pkt_c/gen_c2p[4]/c2p/*
add wave -hex -group "fabric if port(4) rx data"	sim:/$TB/u_dut/fabric_core/rx_data_if[4]/*
add wave -hex -group "fabric if port(4) rx meta"	sim:/$TB/u_dut/fabric_core/rx_meta_if[4]/*
add wave -hex -group "fabric if port(4) tx"	sim:/$TB/u_dut/fabric_core/tx_data_if[4]/*

add wave -noupdate -divider port_5
add wave -hex -group "p2c[5]"	sim:/$TB/u_dut/fabric_core/gen_under_s/gen_qos_switch/switch_inst/g_voq[0]/voq_i/gen_p2c[5]/p2c/*
add wave -hex -group "c2p[5]"	sim:/$TB/u_dut/fabric_core/gen_under_s/gen_qos_switch/switch_inst/g_cell2pkt_col[0]/u_cell2pkt_c/gen_c2p[5]/c2p/*
add wave -hex -group "fabric if port(5) rx data"	sim:/$TB/u_dut/fabric_core/rx_data_if[5]/*
add wave -hex -group "fabric if port(5) rx meta"	sim:/$TB/u_dut/fabric_core/rx_meta_if[5]/*
add wave -hex -group "fabric if port(5) tx"	sim:/$TB/u_dut/fabric_core/tx_data_if[5]/*

add wave -noupdate -divider port_6
add wave -hex -group "p2c[6]"	sim:/$TB/u_dut/fabric_core/gen_under_s/gen_qos_switch/switch_inst/g_voq[0]/voq_i/gen_p2c[6]/p2c/*
add wave -hex -group "c2p[6]"	sim:/$TB/u_dut/fabric_core/gen_under_s/gen_qos_switch/switch_inst/g_cell2pkt_col[0]/u_cell2pkt_c/gen_c2p[6]/c2p/*
add wave -hex -group "fabric if port(6) rx data"	sim:/$TB/u_dut/fabric_core/rx_data_if[6]/*
add wave -hex -group "fabric if port(6) rx meta"	sim:/$TB/u_dut/fabric_core/rx_meta_if[6]/*
add wave -hex -group "fabric if port(6) tx"	sim:/$TB/u_dut/fabric_core/tx_data_if[6]/*

add wave -noupdate -divider port_7
add wave -hex -group "p2c[7]"	sim:/$TB/u_dut/fabric_core/gen_under_s/gen_qos_switch/switch_inst/g_voq[0]/voq_i/gen_p2c[7]/p2c/*
add wave -hex -group "c2p[7]"	sim:/$TB/u_dut/fabric_core/gen_under_s/gen_qos_switch/switch_inst/g_cell2pkt_col[0]/u_cell2pkt_c/gen_c2p[7]/c2p/*
add wave -hex -group "fabric if port(7) rx data"	sim:/$TB/u_dut/fabric_core/rx_data_if[7]/*
add wave -hex -group "fabric if port(7) rx meta"	sim:/$TB/u_dut/fabric_core/rx_meta_if[7]/*
add wave -hex -group "fabric if port(7) tx"	sim:/$TB/u_dut/fabric_core/tx_data_if[7]/*

add wave -noupdate -divider port_8
add wave -hex -group "p2c[8]"	sim:/$TB/u_dut/fabric_core/gen_under_s/gen_qos_switch/switch_inst/g_voq[0]/voq_i/gen_p2c[8]/p2c/*
add wave -hex -group "c2p[8]"	sim:/$TB/u_dut/fabric_core/gen_under_s/gen_qos_switch/switch_inst/g_cell2pkt_col[0]/u_cell2pkt_c/gen_c2p[8]/c2p/*
add wave -hex -group "fabric if port(8) rx data"	sim:/$TB/u_dut/fabric_core/rx_data_if[8]/*
add wave -hex -group "fabric if port(8) rx meta"	sim:/$TB/u_dut/fabric_core/rx_meta_if[8]/*
add wave -hex -group "fabric if port(8) tx"	sim:/$TB/u_dut/fabric_core/tx_data_if[8]/*

add wave -noupdate -divider port_9
add wave -hex -group "p2c[9]"	sim:/$TB/u_dut/fabric_core/gen_under_s/gen_qos_switch/switch_inst/g_voq[0]/voq_i/gen_p2c[9]/p2c/*
add wave -hex -group "c2p[9]"	sim:/$TB/u_dut/fabric_core/gen_under_s/gen_qos_switch/switch_inst/g_cell2pkt_col[0]/u_cell2pkt_c/gen_c2p[9]/c2p/*
add wave -hex -group "fabric if port(9) rx data"	sim:/$TB/u_dut/fabric_core/rx_data_if[9]/*
add wave -hex -group "fabric if port(9) rx meta"	sim:/$TB/u_dut/fabric_core/rx_meta_if[9]/*
add wave -hex -group "fabric if port(9) tx"	sim:/$TB/u_dut/fabric_core/tx_data_if[9]/*

add wave -noupdate -divider ingress_qos
add wave -hex -group "ingress 0 qos classifier"	sim:/$TB/u_dut/fabric_core/gen_ingress_ports[0]/gen_qos_ingress/ingress_inst/u_classifier/*
add wave -hex -group "ingress 0 input queue"	sim:/$TB/u_dut/fabric_core/gen_ingress_ports[0]/gen_qos_ingress/ingress_inst/u_input_queue/*

add wave -noupdate -divider internal_signals
add wave -hex -group "data_rx"	sim:/$TB/u_dut/fabric_core/data_rx
add wave -hex -group "keep_rx"	sim:/$TB/u_dut/fabric_core/keep_rx
add wave -hex -group "valid_rx"	sim:/$TB/u_dut/fabric_core/valid_rx
add wave -hex -group "last_rx"	sim:/$TB/u_dut/fabric_core/last_rx
add wave -hex -group "dest_mask_rx"	sim:/$TB/u_dut/fabric_core/dest_mask_rx
add wave -hex -group "qos_tag_rx"	sim:/$TB/u_dut/fabric_core/qos_tag_rx
add wave -hex -group "rd_en_rx"	sim:/$TB/u_dut/fabric_core/rd_en_rx
add wave -hex -group "data_tx"	sim:/$TB/u_dut/fabric_core/data_tx
add wave -hex -group "valid_tx"	sim:/$TB/u_dut/fabric_core/valid_tx
add wave -hex -group "last_tx"	sim:/$TB/u_dut/fabric_core/last_tx
add wave -hex -group "qos_tag_tx"	sim:/$TB/u_dut/fabric_core/qos_tag_tx