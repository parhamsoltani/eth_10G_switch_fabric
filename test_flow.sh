# 1. Verify project structure
./scr/check_project.sh

# 2. Run unit tests
make sim-voq
make sim-qos-classifier

# 3. Run integration test (GUI for debugging)
make sim-basic

# 4. Run QoS sweep (batch)
make sim-qos-sweep

# 5. Run stress test
make sim-stress

# 6. Generate code coverage
make sim-coverage

# 7. Run regression suite
./scr/regression/run_regression.sh

# 8. Build single FPGA config
./scr/build_hw/build_single_config.sh 001

# 9. Build multiple configs (sweep)
python3 scr/build_hw/build_qos_sweep.py --max-workers 4

# 10. Analyze timing across builds
make qos-timing

# 11. Compare QoS impact
make qos-analyze