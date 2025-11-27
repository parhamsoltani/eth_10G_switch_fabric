cd sim

:: GUI mode (default)
run_sim.bat tb_fabric_basic

:: Batch mode
run_sim.bat tb_qos_classifier_unit batch

:: Stress test
run_sim.bat tb_fabric_qos_stress

:: Unit test
run_sim.bat tb_voq_unit batch

cd sim
run_sim.bat tb_fabric_qos_sweep

cd sim
vsim -do "set TB tb_fabric_qos_sweep; do sim_qos.tcl"

cd sim
vsim -gui
ModelSim> do sim_qos.tcl


cd path\to\your\project
vivado -mode batch -source vivado_qos_build.tcl

vivado -mode tcl
Vivado% source vivado_qos_build.tcl
