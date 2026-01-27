# pin_constraints.xdc
# KU3P Board (xc3u3p-ffvd900-2-i) - ADJUST WITH YOUR BOARD PINS

#===============================================================================
# CLOCK & RESET
#===============================================================================
create_clock -period 6.400 -name clk -waveform {0.000 3.200} [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
set_property PACKAGE_PIN AK13 [get_ports clk]        # Bank 65, HR Bank

set_property IOSTANDARD LVCMOS33 [get_ports reset_n]
set_property PACKAGE_PIN AK14 [get_ports reset_n]    # Bank 65, HR Bank

#===============================================================================
# USER LEDs (4-bit)
#===============================================================================
set_property IOSTANDARD LVCMOS33 [get_ports {user_led[*]}]
set_property PACKAGE_PIN AE12 [get_ports {user_led[0]}]  # Bank 65
set_property PACKAGE_PIN AF12 [get_ports {user_led[1]}]  # Bank 65
set_property PACKAGE_PIN AF13 [get_ports {user_led[2]}]  # Bank 65
set_property PACKAGE_PIN AG13 [get_ports {user_led[3]}]  # Bank 65

#===============================================================================
# uif_addr[15:0] - 16 ports
#===============================================================================
set_property IOSTANDARD LVCMOS33 [get_ports {uif_addr[*]}]
set_property PACKAGE_PIN AB10 [get_ports {uif_addr[0]}]   # Bank 65
set_property PACKAGE_PIN AB11 [get_ports {uif_addr[1]}]   # Bank 65
set_property PACKAGE_PIN AC10 [get_ports {uif_addr[2]}]   # Bank 65
set_property PACKAGE_PIN AC11 [get_ports {uif_addr[3]}]   # Bank 65
set_property PACKAGE_PIN AD10 [get_ports {uif_addr[4]}]   # Bank 65
set_property PACKAGE_PIN AD11 [get_ports {uif_addr[5]}]   # Bank 65
set_property PACKAGE_PIN AE10 [get_ports {uif_addr[6]}]   # Bank 65
set_property PACKAGE_PIN AE11 [get_ports {uif_addr[7]}]   # Bank 65
set_property PACKAGE_PIN AF10 [get_ports {uif_addr[8]}]   # Bank 65
set_property PACKAGE_PIN AF11 [get_ports {uif_addr[9]}]   # Bank 65
set_property PACKAGE_PIN AG10 [get_ports {uif_addr[10]}]  # Bank 65
set_property PACKAGE_PIN AG11 [get_ports {uif_addr[11]}]  # Bank 65
set_property PACKAGE_PIN AH10 [get_ports {uif_addr[12]}]  # Bank 65
set_property PACKAGE_PIN AH11 [get_ports {uif_addr[13]}]  # Bank 65
set_property PACKAGE_PIN AJ10 [get_ports {uif_addr[14]}]  # Bank 65
set_property PACKAGE_PIN AJ11 [get_ports {uif_addr[15]}]  # Bank 65

#===============================================================================
# uif_wr_data[31:0] - 32 ports
#===============================================================================
set_property IOSTANDARD LVCMOS33 [get_ports {uif_wr_data[*]}]
# Assign pins in Bank 66 for the remaining 32 ports
set_property PACKAGE_PIN Y10  [get_ports {uif_wr_data[0]}]   # Bank 66
set_property PACKAGE_PIN Y11  [get_ports {uif_wr_data[1]}]   # Bank 66
set_property PACKAGE_PIN AA10 [get_ports {uif_wr_data[2]}]   # Bank 66
set_property PACKAGE_PIN AA11 [get_ports {uif_wr_data[3]}]   # Bank 66
set_property PACKAGE_PIN AB8  [get_ports {uif_wr_data[4]}]   # Bank 66
set_property PACKAGE_PIN AB9  [get_ports {uif_wr_data[5]}]   # Bank 66
set_property PACKAGE_PIN AC8  [get_ports {uif_wr_data[6]}]   # Bank 66
set_property PACKAGE_PIN AC9  [get_ports {uif_wr_data[7]}]   # Bank 66
set_property PACKAGE_PIN AD8  [get_ports {uif_wr_data[8]}]   # Bank 66
set_property PACKAGE_PIN AD9  [get_ports {uif_wr_data[9]}]   # Bank 66
set_property PACKAGE_PIN AE8  [get_ports {uif_wr_data[10]}]  # Bank 66
set_property PACKAGE_PIN AE9  [get_ports {uif_wr_data[11]}]  # Bank 66
set_property PACKAGE_PIN AF8  [get_ports {uif_wr_data[12]}]  # Bank 66
set_property PACKAGE_PIN AF9  [get_ports {uif_wr_data[13]}]  # Bank 66
set_property PACKAGE_PIN AG8  [get_ports {uif_wr_data[14]}]  # Bank 66
set_property PACKAGE_PIN AG9  [get_ports {uif_wr_data[15]}]  # Bank 66
set_property PACKAGE_PIN AH8  [get_ports {uif_wr_data[16]}]  # Bank 66
set_property PACKAGE_PIN AH9  [get_ports {uif_wr_data[17]}]  # Bank 66
set_property PACKAGE_PIN AJ8  [get_ports {uif_wr_data[18]}]  # Bank 66
set_property PACKAGE_PIN AJ9  [get_ports {uif_wr_data[19]}]  # Bank 66
set_property PACKAGE_PIN AK8  [get_ports {uif_wr_data[20]}]  # Bank 66
set_property PACKAGE_PIN AK9  [get_ports {uif_wr_data[21]}]  # Bank 66
set_property PACKAGE_PIN Y12  [get_ports {uif_wr_data[22]}]  # Bank 66
set_property PACKAGE_PIN Y13  [get_ports {uif_wr_data[23]}]  # Bank 66
set_property PACKAGE_PIN AA12 [get_ports {uif_wr_data[24]}]  # Bank 66
set_property PACKAGE_PIN AA13 [get_ports {uif_wr_data[25]}]  # Bank 66
set_property PACKAGE_PIN AB12 [get_ports {uif_wr_data[26]}]  # Bank 66
set_property PACKAGE_PIN AB13 [get_ports {uif_wr_data[27]}]  # Bank 66
set_property PACKAGE_PIN AC12 [get_ports {uif_wr_data[28]}]  # Bank 66
set_property PACKAGE_PIN AC13 [get_ports {uif_wr_data[29]}]  # Bank 66
set_property PACKAGE_PIN AD12 [get_ports {uif_wr_data[30]}]  # Bank 66
set_property PACKAGE_PIN AD13 [get_ports {uif_wr_data[31]}]  # Bank 66

#===============================================================================
# uif_rd_data[31:0] - 32 ports
#===============================================================================
set_property IOSTANDARD LVCMOS33 [get_ports {uif_rd_data[*]}]
# Assign pins in Bank 67
set_property PACKAGE_PIN W10  [get_ports {uif_rd_data[0]}]   # Bank 67
set_property PACKAGE_PIN W11  [get_ports {uif_rd_data[1]}]   # Bank 67
set_property PACKAGE_PIN Y8   [get_ports {uif_rd_data[2]}]   # Bank 67
set_property PACKAGE_PIN Y9   [get_ports {uif_rd_data[3]}]   # Bank 67
set_property PACKAGE_PIN AA8  [get_ports {uif_rd_data[4]}]   # Bank 67
set_property PACKAGE_PIN AA9  [get_ports {uif_rd_data[5]}]   # Bank 67
set_property PACKAGE_PIN AB6  [get_ports {uif_rd_data[6]}]   # Bank 67
set_property PACKAGE_PIN AB7  [get_ports {uif_rd_data[7]}]   # Bank 67
set_property PACKAGE_PIN AC6  [get_ports {uif_rd_data[8]}]   # Bank 67
set_property PACKAGE_PIN AC7  [get_ports {uif_rd_data[9]}]   # Bank 67
set_property PACKAGE_PIN AD6  [get_ports {uif_rd_data[10]}]  # Bank 67
set_property PACKAGE_PIN AD7  [get_ports {uif_rd_data[11]}]  # Bank 67
set_property PACKAGE_PIN AE6  [get_ports {uif_rd_data[12]}]  # Bank 67
set_property PACKAGE_PIN AE7  [get_ports {uif_rd_data[13]}]  # Bank 67
set_property PACKAGE_PIN AF6  [get_ports {uif_rd_data[14]}]  # Bank 67
set_property PACKAGE_PIN AF7  [get_ports {uif_rd_data[15]}]  # Bank 67
set_property PACKAGE_PIN AG6  [get_ports {uif_rd_data[16]}]  # Bank 67
set_property PACKAGE_PIN AG7  [get_ports {uif_rd_data[17]}]  # Bank 67
set_property PACKAGE_PIN AH6  [get_ports {uif_rd_data[18]}]  # Bank 67
set_property PACKAGE_PIN AH7  [get_ports {uif_rd_data[19]}]  # Bank 67
set_property PACKAGE_PIN AJ6  [get_ports {uif_rd_data[20]}]  # Bank 67
set_property PACKAGE_PIN AJ7  [get_ports {uif_rd_data[21]}]  # Bank 67
set_property PACKAGE_PIN AK6  [get_ports {uif_rd_data[22]}]  # Bank 67
set_property PACKAGE_PIN AK7  [get_ports {uif_rd_data[23]}]  # Bank 67
set_property PACKAGE_PIN W12  [get_ports {uif_rd_data[24]}]  # Bank 67
set_property PACKAGE_PIN W13  [get_ports {uif_rd_data[25]}]  # Bank 67
set_property PACKAGE_PIN Y14  [get_ports {uif_rd_data[26]}]  # Bank 67
set_property PACKAGE_PIN Y15  [get_ports {uif_rd_data[27]}]  # Bank 67
set_property PACKAGE_PIN AA14 [get_ports {uif_rd_data[28]}]  # Bank 67
set_property PACKAGE_PIN AA15 [get_ports {uif_rd_data[29]}]  # Bank 67
set_property PACKAGE_PIN AB14 [get_ports {uif_rd_data[30]}]  # Bank 67
set_property PACKAGE_PIN AB15 [get_ports {uif_rd_data[31]}]  # Bank 67

#===============================================================================
# Control Signals (4 ports)
#===============================================================================
set_property IOSTANDARD LVCMOS33 [get_ports uif_wr_en]
set_property PACKAGE_PIN AC14 [get_ports uif_wr_en]  # Bank 67

set_property IOSTANDARD LVCMOS33 [get_ports uif_rd_en]
set_property PACKAGE_PIN AD14 [get_ports uif_rd_en]  # Bank 67

#===============================================================================
# OPTIONAL: DRC Override for Testing (Remove for production)
#===============================================================================
# Uncomment these lines if you want to bypass DRC checks temporarily:
# set_property SEVERITY {Warning} [get_drc_checks NSTD-1]
# set_property SEVERITY {Warning} [get_drc_checks UCIO-1]