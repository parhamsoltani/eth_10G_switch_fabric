# QoS-aware build targets

.PHONY: qos-gen qos-build qos-sim qos-analyze qos-clean

# Generate QoS configurations
qos-gen:
	@echo "Generating QoS configurations..."
	python3 scr/save_configs/config_generator/config_generator_qos.py

# Build all QoS configs
qos-build: qos-gen
	@echo "Building QoS configurations..."
	python3 scr/build_hw/build_qos_sweep.py --max-workers 4

# Run QoS testbench
qos-sim:
	@cd sim && vsim -do "set TB tb_fabric_qos_sweep; do sim.tcl"

# Analyze QoS performance
qos-analyze:
	@python3 scr/analysis/qos_performance_analyzer.py

# Clean QoS artifacts
qos-clean:
	@rm -rf scr/save_configs/config_generator/configs/*
	@rm -rf out/qos_reports

# Full QoS pipeline
qos-all: qos-gen qos-build qos-analyze
	@echo "QoS pipeline complete!"

# Quick test (build + sim single config)
qos-quick:
	@echo "Quick QoS test (N=10, QoS enabled)..."
	python3 -c "from scr.save_configs.config_generator.config_generator_qos import *; \
	            DEFINE_SPACE['N'] = [10]; \
	            DEFINE_SPACE['ENABLE_QOS'] = [1]; \
	            main()"
	@cd scr/build_hw && vivado -mode batch -source build_switches_run.tcl
	@cd sim && vsim -c -do "run -all; quit -f" work.tb_fabric_qos_sweep


# Advanced QoS targets

# Intelligent sweep with pruning
qos-sweep:
	python3 scr/save_configs/config_generator/config_sweep_qos.py --max-configs 50

# Pareto-optimal configs only
qos-pareto:
	python3 scr/save_configs/config_generator/config_sweep_qos.py --pareto-only --max-configs 20

# Stress test
qos-stress:
	cd sim && vsim -do "set TB tb_fabric_qos_stress; do sim.tcl"

# Timing analysis (post-build)
qos-timing:
	cd scr/analysis && vivado -mode batch -source timing_analyzer.tcl

# Full QoS validation flow
qos-validate: qos-sweep qos-build qos-stress qos-timing qos-analyze
	@echo " Full QoS validation complete!"

# Clean all QoS artifacts
qos-clean-all: qos-clean
	rm -rf out/timing_analysis
	rm -rf sim/wlf/*qos*


# QuestaSim simulation targets

# Unit tests
sim-voq:
	cd sim && TB=tb_voq_unit SIM_MODE=batch vsim -do sim.tcl

sim-qos-classifier:
	cd sim && TB=tb_qos_classifier_unit SIM_MODE=batch vsim -do sim.tcl

# Integration tests
sim-basic:
	cd sim && TB=tb_fabric_basic SIM_MODE=gui vsim -do sim.tcl

sim-qos-sweep:
	cd sim && TB=tb_fabric_qos_sweep SIM_MODE=batch vsim -do sim.tcl

# Stress test
sim-stress:
	cd sim && TB=tb_fabric_qos_stress SIM_MODE=batch vsim -do sim.tcl

# Coverage
sim-coverage:
	cd sim && TB=tb_fabric_qos_sweep SIM_MODE=coverage vsim -do sim.tcl
	@echo "Coverage report: sim/cov_reports/tb_fabric_qos_sweep/index.html"

# Run all tests
sim-all: sim-voq sim-qos-classifier sim-basic sim-qos-sweep sim-stress
	@echo "All simulations complete"


# Windows-compatible simulation targets

sim-unit-voq:
	cd sim && cmd /c "run_sim.bat tb_voq_unit batch"

sim-unit-qos:
	cd sim && cmd /c "run_sim.bat tb_qos_classifier_unit batch"

sim-fabric-basic:
	cd sim && cmd /c "run_sim.bat tb_fabric_basic"

sim-qos-sweep:
	cd sim && cmd /c "run_sim.bat tb_fabric_qos_sweep batch"

.PHONY: sim-unit-voq sim-unit-qos sim-fabric-basic sim-qos-sweep