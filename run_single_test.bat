@echo off
setlocal

:: ============================================================================
:: Run a single testbench with optional GUI mode
:: Usage: run_single_test.bat <testbench_name> [gui|batch]
:: ============================================================================

if "%~1"=="" (
    echo.
    echo ╔═══════════════════════════════════════════════════════════════════╗
    echo ║  QoS Switch Fabric - Single Test Runner                           ║
    echo ╚═══════════════════════════════════════════════════════════════════╝
    echo.
    echo Usage: run_single_test.bat ^<testbench_name^> [gui^|batch]
    echo.
    echo Available testbenches:
    echo.
    echo   Unit Tests:
    echo     tb_qos_classifier_unit     - QoS Classifier verification
    echo     tb_qos_scheduler_unit      - QoS Scheduler verification
    echo     tb_voq_unit                - VOQ Buffer verification
    echo.
    echo   Integration Tests:
    echo     tb_qos_manager_integration - Full QoS manager test
    echo.
    echo   Component Tests:
    echo     tb_fifo_array              - FIFO array test
    echo     tb_packet_mode_fifo_array  - Packet mode FIFO test
    echo     tb_pipeline_mux            - Pipeline mux test
    echo.
    echo   Fabric Tests:
    echo     tb_fabric_basic            - Basic fabric (no QoS)
    echo     tb_fabric_qos              - QoS-enabled fabric
    echo     tb_fabric_qos_stress       - Stress test
    echo     tb_fabric_qos_sweep        - Configuration sweep
    echo.
    exit /b 1
)

set TB=%~1
set MODE=%~2
if "%MODE%"=="" set MODE=gui

echo.
echo ════════════════════════════════════════════════════════════════════════════
echo   Running: %TB%
echo   Mode: %MODE%
echo ════════════════════════════════════════════════════════════════════════════
echo.

cd sim
if "%MODE%"=="batch" (
    call vsim -c -do "set TB %TB%; set env(SIM_MODE) batch; do sim_qos.tcl"
) else (
    call vsim -do "set TB %TB%; set env(SIM_MODE) gui; do sim_qos.tcl"
)
cd ..

endlocal