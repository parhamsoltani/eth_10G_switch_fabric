#!/bin/bash
# Automated QoS configuration build and analysis pipeline

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG_GEN="$PROJECT_ROOT/scr/save_configs/config_generator/config_generator_qos.py"
BUILD_RUNNER="$PROJECT_ROOT/scr/build_hw/build_qos_sweep.py"
ANALYZER="$PROJECT_ROOT/scr/analysis/qos_performance_analyzer.py"

echo "========================================"
echo "QoS Configuration Build Pipeline"
echo "========================================"

# Step 1: Generate configurations
echo "[1/4] Generating QoS configurations..."
python3 "$CONFIG_GEN"

# Step 2: Build all configs (parallel)
echo "[2/4] Building configurations..."
python3 "$BUILD_RUNNER" --max-workers 4 --filter "ENABLE_QOS=1"

# Step 3: Analyze results
echo "[3/4] Analyzing QoS impact..."
python3 "$ANALYZER"

# Step 4: Generate report
echo "[4/4] Generating final report..."
REPORT_DIR="$PROJECT_ROOT/out/qos_reports"
mkdir -p "$REPORT_DIR"

cat > "$REPORT_DIR/summary.md" <<EOF
# QoS Integration Build Summary

**Generated:** $(date)

## Configuration Space
- Total configs: $(ls -1 $PROJECT_ROOT/scr/save_configs/config_generator/configs | wc -l)
- QoS-enabled: $(grep -c '"qos_enabled": true' $PROJECT_ROOT/scr/save_configs/config_generator/configs/manifest.json || echo 0)

## Build Results
$(cat $PROJECT_ROOT/scr/save_configs/config_generator/configs/build_results.json 2>/dev/null || echo "No results")

## Timing Analysis
See: out/qos_impact_analysis.csv

## Next Steps
1. Review failed builds in build_results.json
2. Examine timing violations in out/reports/
3. Run functional verification: \`make sim TB=tb_fabric_qos_sweep\`
EOF

echo "Report generated: $REPORT_DIR/summary.md"
echo "========================================"
echo "Pipeline complete!"