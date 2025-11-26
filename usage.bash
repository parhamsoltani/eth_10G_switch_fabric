cd sim

:: GUI mode (default)
run_sim.bat tb_fabric_basic

:: Batch mode
run_sim.bat tb_qos_classifier_unit batch

:: Stress test
run_sim.bat tb_fabric_qos_stress

:: Unit test
run_sim.bat tb_voq_unit batch