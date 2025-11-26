# 1. Unit test (VOQ)
cd sim
TB=tb_voq_unit SIM_MODE=batch vsim -do sim.tcl

# 2. Basic fabric test (GUI)
TB=tb_fabric_basic SIM_MODE=gui vsim -do sim.tcl

# 3. QoS sweep (batch mode)
TB=tb_fabric_qos_sweep SIM_MODE=batch vsim -do sim.tcl

# 4. Stress test with coverage
TB=tb_fabric_qos_stress SIM_MODE=coverage vsim -do sim.tcl

# 5. View coverage report
firefox cov_reports/tb_fabric_qos_stress/index.html