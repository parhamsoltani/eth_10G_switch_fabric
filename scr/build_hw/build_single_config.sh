#!/bin/bash
####################################################################################
# Single Configuration Build Script
# Runs complete Vivado flow: Synthesis → Implementation → Bitstream
####################################################################################

set -e  # Exit on error

CONFIG_ID=${1:-"001"}
CONFIG_DIR="scr/save_configs/config_generator/configs/${CONFIG_ID}"
OUTPUT_DIR="out/products/config_${CONFIG_ID}"

if [ ! -d "$CONFIG_DIR" ]; then
    echo "ERROR: Config directory not found: $CONFIG_DIR"
    exit 1
fi

echo "╔════════════════════════════════════════════════════════════╗"
echo "║         FPGA BUILD - Configuration ${CONFIG_ID}                   ║"
echo "╚════════════════════════════════════════════════════════════╝"

# 1. Copy configuration files
echo "[1/6] Preparing configuration..."
cp "${CONFIG_DIR}/implement_options.vh" src/inc/
cp "${CONFIG_DIR}/timing.xdc" xdc/
cp "${CONFIG_DIR}/build_switches_main.tcl" scr/build_hw/

# 2. Load metadata
if [ -f "${CONFIG_DIR}/meta.json" ]; then
    N=$(jq -r '.defines.N' "${CONFIG_DIR}/meta.json")
    S=$(jq -r '.defines.S' "${CONFIG_DIR}/meta.json")
    QOS=$(jq -r '.defines.ENABLE_QOS' "${CONFIG_DIR}/meta.json")
    PART=$(jq -r '.device' "${CONFIG_DIR}/meta.json")

    echo "  N=${N}, S=${S}, QoS=${QOS}, Part=${PART}"
fi

# 3. Run Vivado synthesis
echo "[2/6] Running synthesis..."
mkdir -p "${OUTPUT_DIR}"

vivado -mode batch -source scr/build_hw/build_switches_main.tcl \
    -tclargs "${OUTPUT_DIR}" 2>&1 | tee "${OUTPUT_DIR}/vivado.log"

# 4. Check for errors
if grep -q "ERROR:" "${OUTPUT_DIR}/vivado.log"; then
    echo " BUILD FAILED - Check ${OUTPUT_DIR}/vivado.log"
    exit 1
fi

# 5. Extract reports
echo "[3/6] Extracting reports..."
cp "${OUTPUT_DIR}"/switch_fabric_*/switch_fabric.runs/impl_1/*_utilization_placed.rpt \
    "${OUTPUT_DIR}/utilization.rpt" 2>/dev/null || true

cp "${OUTPUT_DIR}"/switch_fabric_*/switch_fabric.runs/impl_1/*_timing_summary_routed.rpt \
    "${OUTPUT_DIR}/timing.rpt" 2>/dev/null || true

cp "${OUTPUT_DIR}"/switch_fabric_*/switch_fabric.runs/impl_1/*_power_routed.rpt \
    "${OUTPUT_DIR}/power.rpt" 2>/dev/null || true

# 6. Parse results
echo "[4/6] Parsing results..."
WNS=$(grep "WNS(ns)" "${OUTPUT_DIR}/timing.rpt" | awk '{print $2}' | head -1)
LUT=$(grep "CLB LUTs" "${OUTPUT_DIR}/utilization.rpt" | awk '{print $5}' | head -1)
BRAM=$(grep "Block RAM Tile" "${OUTPUT_DIR}/utilization.rpt" | awk '{print $5}' | head -1)

echo "  WNS:  ${WNS} ns"
echo "  LUTs: ${LUT}"
echo "  BRAM: ${BRAM}"

# 7. Save summary
echo "[5/6] Saving summary..."
cat > "${OUTPUT_DIR}/build_summary.json" <<EOF
{
  "config_id": "${CONFIG_ID}",
  "timestamp": "$(date -Iseconds)",
  "parameters": {
    "N": ${N},
    "S": ${S},
    "enable_qos": ${QOS},
    "device": "${PART}"
  },
  "results": {
    "wns_ns": ${WNS:-null},
    "lut_count": ${LUT:-null},
    "bram_count": ${BRAM:-null},
    "success": $([ "$WNS" != "" ] && echo "true" || echo "false")
  }
}
EOF

# 8. Generate bitstream (if timing met)
if (( $(echo "$WNS >= 0" | bc -l) )); then
    echo "[6/6] Generating bitstream..."
    # Bitstream generation happens in TCL script
    echo "Build successful!"
else
    echo "[6/6] Timing not met - skipping bitstream"
    echo "Build complete with timing violations"
fi

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  Build Complete                                            ║"
echo "║  Output: ${OUTPUT_DIR}"
echo "╚════════════════════════════════════════════════════════════╝"