#!/bin/bash
####################################################################################
# Automated Regression Test Suite
# Runs all testbenches + coverage + timing checks
####################################################################################

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_DIR="out/regression/${TIMESTAMP}"
mkdir -p "${REPORT_DIR}"

echo "╔════════════════════════════════════════════════════════════╗"
echo "║          REGRESSION TEST SUITE                             ║"
echo "║  Timestamp: ${TIMESTAMP}                                   ║"
echo "╚════════════════════════════════════════════════════════════╝"

# Test list
TESTS=(
    "tb_voq_unit"
    "tb_qos_classifier_unit"
    "tb_fabric_basic"
    "tb_fabric_qos_sweep"
    "tb_fabric_qos_stress"
)

passed=0
failed=0

for test in "${TESTS[@]}"; do
    echo ""
    echo "════════════════════════════════════════════════════════════"
    echo "  Running: $test"
    echo "════════════════════════════════════════════════════════════"

    cd sim
    TB=$test SIM_MODE=batch vsim -do sim.tcl > "${REPORT_DIR}/${test}.log" 2>&1
    result=$?
    cd ..

    if [ $result -eq 0 ]; then
        echo "PASSED"
        ((passed++))
    else
        echo "FAILED (see ${REPORT_DIR}/${test}.log)"
        ((failed++))
    fi
done

# Generate summary
cat > "${REPORT_DIR}/summary.txt" <<EOF
REGRESSION TEST SUMMARY
═══════════════════════════════════════════════════════════
Timestamp: ${TIMESTAMP}
Total Tests: ${#TESTS[@]}
Passed: $passed
Failed: $failed

Status: $([ $failed -eq 0 ] && echo "ALL PASSED" || echo "FAILURES DETECTED")
═══════════════════════════════════════════════════════════
EOF

cat "${REPORT_DIR}/summary.txt"

exit $failed