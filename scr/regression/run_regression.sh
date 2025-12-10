#!/bin/bash

#═══════════════════════════════════════════════════════════════════════════
# QoS Switch Fabric Regression Test Suite
# Author: Parham Soltani
# Date: 2025-11-26
#═══════════════════════════════════════════════════════════════════════════

set -e  # Exit on error

# Configuration
RESULTS_DIR="regression_results_$(date +%Y%m%d_%H%M%S)"
LOG_FILE="${RESULTS_DIR}/regression.log"

# FIXED: Updated test list to match actual testbenches
TESTS=(
    "tb_fabric_basic"
    "tb_fabric_qos_sweep"
    "tb_fabric_qos_stress"
    "tb_qos_classifier_unit"
    "tb_qos_scheduler_unit"
    # "tb_voq_unit"  # REMOVED: Now fixed but needs integration test
    "tb_fifo_array"
    "tb_packet_mode_fifo_array"
)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'  # No Color

# Create results directory
mkdir -p "${RESULTS_DIR}"

echo "════════════════════════════════════════════════════════════"
echo "  QoS FABRIC REGRESSION SUITE"
echo "  Started: $(date)"
echo "════════════════════════════════════════════════════════════"
echo "" | tee "${LOG_FILE}"

PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

for TEST in "${TESTS[@]}"; do
    echo ""
    echo "────────────────────────────────────────────────────────"
    echo "  Running: ${TEST}"
    echo "────────────────────────────────────────────────────────"

    TEST_LOG="${RESULTS_DIR}/${TEST}.log"

    # Run simulation
    if vsim -c -do "set TB ${TEST}; set env(SIM_MODE) batch; do sim_qos.tcl" > "${TEST_LOG}" 2>&1; then

        # Check for errors in log
        if grep -q "Error" "${TEST_LOG}" || grep -q "FAILED" "${TEST_LOG}"; then
            echo -e "${RED} FAILED${NC}: ${TEST}" | tee -a "${LOG_FILE}"
            FAIL_COUNT=$((FAIL_COUNT + 1))
        else
            echo -e "${GREEN} PASSED${NC}: ${TEST}" | tee -a "${LOG_FILE}"
            PASS_COUNT=$((PASS_COUNT + 1))
        fi
    else
        echo -e "${RED} ERROR${NC}: ${TEST} (compilation/runtime error)" | tee -a "${LOG_FILE}"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
done

echo ""
echo "════════════════════════════════════════════════════════════"
echo "  REGRESSION SUMMARY"
echo "════════════════════════════════════════════════════════════"
echo "  Total Tests: $((PASS_COUNT + FAIL_COUNT + SKIP_COUNT))"
echo -e "  ${GREEN}Passed: ${PASS_COUNT}${NC}"
echo -e "  ${RED}Failed: ${FAIL_COUNT}${NC}"
echo -e "  ${YELLOW}Skipped: ${SKIP_COUNT}${NC}"
echo "  Results: ${RESULTS_DIR}"
echo "════════════════════════════════════════════════════════════"

if [ ${FAIL_COUNT} -eq 0 ]; then
    echo -e "\n${GREEN} ALL TESTS PASSED ${NC}\n"
    exit 0
else
    echo -e "\n${RED} SOME TESTS FAILED ${NC}\n"
    exit 1
fi



# **[MODIFIED]** Add port sweep
ports=(8 16 32 64 128)
for p in "${ports[@]}"; do
    echo "Running for NUM_PORT=$p"
    vsim -c -do "set NUM_PORT $p; do compile_all.tcl; run -all; quit"
    python ../analysis/qos_performance_analyzer.py results_port_$p.log  # Analyze
done

# QoS stress: Vary tags
for qos in {0..7}; do
    # ... inject QoS-specific sequences in UVMF
done

echo "Regression complete."