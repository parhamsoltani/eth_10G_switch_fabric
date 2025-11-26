# 1. Generate Pareto-optimal QoS configs (intelligent pruning)
make qos-pareto
# Output: 20 configs under scr/save_configs/config_generator/configs/

# 2. Build top 5 configs by estimated score
python3 scr/build_hw/build_qos_sweep.py --max-workers 2 --dry-run | head -5
# Then build for real:
python3 scr/build_hw/build_qos_sweep.py --max-workers 4

# 3. Run stress test on best config
cp scr/save_configs/config_generator/configs/001/* src/inc/
make qos-stress

# 4. Analyze timing across all builds
make qos-timing

# 5. Compare QoS impact
make qos-analyze

# 6. View results
cat out/timing_analysis/summary.csv
cat out/qos_reports/summary.md