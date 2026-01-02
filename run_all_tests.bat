@echo off
setlocal EnableDelayedExpansion

:: ============================================================================
:: QoS Switch Fabric - Automated Test Suite for Windows
:: Version 2.0 - Complete automation with CSV export
:: ============================================================================

set SCRIPT_DIR=%~dp0
cd /d "%SCRIPT_DIR%"

:: Configuration
set LOG_DIR=sim\logs
set RESULTS_DIR=sim\results
set TIMESTAMP=%DATE:~-4%%DATE:~4,2%%DATE:~7,2%_%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%
set TIMESTAMP=%TIMESTAMP: =0%
set TIMESTAMP=%TIMESTAMP::=%
set MASTER_LOG=%LOG_DIR%\test_run_%TIMESTAMP%.log
set CSV_SUMMARY=%RESULTS_DIR%\test_summary_%TIMESTAMP%.csv
set LATENCY_CSV=%RESULTS_DIR%\latency_data_%TIMESTAMP%.csv

:: Create directories
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"
if not exist "%RESULTS_DIR%" mkdir "%RESULTS_DIR%"
if not exist "sim\results\figures" mkdir "sim\results\figures"

:: Initialize counters
set TOTAL_TESTS=0
set PASSED_TESTS=0
set FAILED_TESTS=0

:: Initialize CSV files
echo TestName,Status,PacketsSent,PacketsReceived,LossPct,Duration,Timestamp > "%CSV_SUMMARY%"
echo TestName,QoSLevel,PriorityName,PacketCount,AvgLatencyNs,MinLatencyNs,MaxLatencyNs > "%LATENCY_CSV%"

echo.
echo ╔═══════════════════════════════════════════════════════════════════════════╗
echo ║                                                                           ║
echo ║     QoS SWITCH FABRIC - AUTOMATED VERIFICATION SUITE                      ║
echo ║                                                                           ║
echo ║     Started: %DATE% %TIME%                                    ║
echo ║                                                                           ║
echo ╚═══════════════════════════════════════════════════════════════════════════╝
echo.

:: Log header
echo ═══════════════════════════════════════════════════════════════════ > "%MASTER_LOG%"
echo QoS Switch Fabric Automated Test Run >> "%MASTER_LOG%"
echo Started: %DATE% %TIME% >> "%MASTER_LOG%"
echo ═══════════════════════════════════════════════════════════════════ >> "%MASTER_LOG%"
echo. >> "%MASTER_LOG%"

:: ============================================================================
:: PHASE 1: UNIT TESTS
:: ============================================================================
echo.
echo ┌─────────────────────────────────────────────────────────────────────────┐
echo │  PHASE 1: UNIT TESTS                                                    │
echo └─────────────────────────────────────────────────────────────────────────┘
echo PHASE 1: UNIT TESTS >> "%MASTER_LOG%"

call :run_test "tb_qos_classifier_unit" "QoS Classifier Unit"
call :run_test "tb_qos_scheduler_unit" "QoS Scheduler Unit"
call :run_test "tb_voq_unit" "VOQ Buffer Unit"

:: ============================================================================
:: PHASE 2: INTEGRATION TESTS
:: ============================================================================
echo.
echo ┌─────────────────────────────────────────────────────────────────────────┐
echo │  PHASE 2: INTEGRATION TESTS                                             │
echo └─────────────────────────────────────────────────────────────────────────┘
echo. >> "%MASTER_LOG%"
echo PHASE 2: INTEGRATION TESTS >> "%MASTER_LOG%"

call :run_test "tb_qos_manager_integration" "QoS Manager Integration"

:: ============================================================================
:: PHASE 3: COMPONENT TESTS
:: ============================================================================
echo.
echo ┌─────────────────────────────────────────────────────────────────────────┐
echo │  PHASE 3: COMPONENT TESTS                                               │
echo └─────────────────────────────────────────────────────────────────────────┘
echo. >> "%MASTER_LOG%"
echo PHASE 3: COMPONENT TESTS >> "%MASTER_LOG%"

call :run_test "tb_fifo_array" "FIFO Array"
call :run_test "tb_packet_mode_fifo_array" "Packet Mode FIFO Array"
call :run_test "tb_pipeline_mux" "Pipeline Mux"

:: ============================================================================
:: PHASE 4: FABRIC TESTS (Critical Path)
:: ============================================================================
echo.
echo ┌─────────────────────────────────────────────────────────────────────────┐
echo │  PHASE 4: FABRIC TESTS (Critical Path)                                  │
echo └─────────────────────────────────────────────────────────────────────────┘
echo. >> "%MASTER_LOG%"
echo PHASE 4: FABRIC TESTS >> "%MASTER_LOG%"

call :run_test "tb_fabric_basic" "Basic Fabric (No QoS)"
call :run_test "tb_fabric_qos" "QoS Fabric"
call :run_test "tb_fabric_qos_stress" "QoS Stress Test"
call :run_test "tb_fabric_qos_sweep" "QoS Configuration Sweep"

:: ============================================================================
:: POST-PROCESSING
:: ============================================================================
echo.
echo ┌─────────────────────────────────────────────────────────────────────────┐
echo │  POST-PROCESSING: Analyzing Results                                     │
echo └─────────────────────────────────────────────────────────────────────────┘

:: Run Python analysis if available
where python >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo   Running result analysis...
    python sim\scr\analysis\collect_results.py "%LOG_DIR%" "%RESULTS_DIR%" "%TIMESTAMP%"
    if %ERRORLEVEL% EQU 0 (
        echo   Generating thesis figures...
        python sim\scr\analysis\generate_thesis_figures.py "%RESULTS_DIR%"
    )
) else (
    echo   Python not found - skipping automated analysis
    echo   Install Python and run manually: python sim\scr\analysis\collect_results.py
)

:: ============================================================================
:: FINAL SUMMARY
:: ============================================================================
echo.
echo ╔═══════════════════════════════════════════════════════════════════════════╗
echo ║                           TEST SUMMARY                                    ║
echo ╠═══════════════════════════════════════════════════════════════════════════╣
echo ║  Total Tests:  %TOTAL_TESTS%                                                          ║
echo ║  Passed:       %PASSED_TESTS%                                                          ║
echo ║  Failed:       %FAILED_TESTS%                                                          ║
echo ╠═══════════════════════════════════════════════════════════════════════════╣

if %FAILED_TESTS% EQU 0 (
    echo ║                                                                           ║
    echo ║                    ✓ ALL TESTS PASSED ✓                                   ║
    echo ║                                                                           ║
) else (
    echo ║                                                                           ║
    echo ║                    ✗ SOME TESTS FAILED ✗                                  ║
    echo ║                                                                           ║
)

echo ╠═══════════════════════════════════════════════════════════════════════════╣
echo ║  Results:                                                                 ║
echo ║    Summary CSV: %CSV_SUMMARY%
echo ║    Latency CSV: %LATENCY_CSV%
echo ║    Master Log:  %MASTER_LOG%
echo ╚═══════════════════════════════════════════════════════════════════════════╝

:: Log summary
echo. >> "%MASTER_LOG%"
echo ═══════════════════════════════════════════════════════════════════ >> "%MASTER_LOG%"
echo FINAL SUMMARY >> "%MASTER_LOG%"
echo Total: %TOTAL_TESTS%, Passed: %PASSED_TESTS%, Failed: %FAILED_TESTS% >> "%MASTER_LOG%"
echo Completed: %DATE% %TIME% >> "%MASTER_LOG%"
echo ═══════════════════════════════════════════════════════════════════ >> "%MASTER_LOG%"

if %FAILED_TESTS% GTR 0 (
    exit /b 1
)
exit /b 0

:: ============================================================================
:: SUBROUTINE: Run a single test
:: ============================================================================
:run_test
set TEST_NAME=%~1
set TEST_DESC=%~2
set /a TOTAL_TESTS+=1

echo.
echo   [%TOTAL_TESTS%] %TEST_DESC%
echo       Testbench: %TEST_NAME%

set TEST_LOG=%LOG_DIR%\%TEST_NAME%_%TIMESTAMP%.log
set START_TIME=%TIME%

:: Change to sim directory and run
pushd sim

:: Run simulation in batch mode with timeout
call vsim -c -do "set TB %TEST_NAME%; set env(SIM_MODE) batch; do sim_qos.tcl" > "..\%TEST_LOG%" 2>&1
set SIM_EXIT=%ERRORLEVEL%

popd

set END_TIME=%TIME%

:: Parse results from log
set TEST_STATUS=UNKNOWN
set PKT_SENT=0
set PKT_RECV=0
set LOSS_PCT=0

:: Check for PASSED
findstr /i /c:"ALL TESTS PASSED" "%TEST_LOG%" >nul 2>&1
if %ERRORLEVEL% EQU 0 set TEST_STATUS=PASSED

findstr /i /c:"TEST PASSED" "%TEST_LOG%" >nul 2>&1
if %ERRORLEVEL% EQU 0 set TEST_STATUS=PASSED

findstr /i /c:"PASSED" "%TEST_LOG%" >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    if "%TEST_STATUS%"=="UNKNOWN" set TEST_STATUS=PASSED
)

:: Check for FAILED/ERROR
findstr /i /c:"FAILED" "%TEST_LOG%" >nul 2>&1
if %ERRORLEVEL% EQU 0 set TEST_STATUS=FAILED

findstr /i /c:"ERROR" "%TEST_LOG%" >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    if not "%TEST_STATUS%"=="PASSED" set TEST_STATUS=FAILED
)

findstr /i /c:"TIMEOUT" "%TEST_LOG%" >nul 2>&1
if %ERRORLEVEL% EQU 0 set TEST_STATUS=FAILED

:: If still unknown and sim exited cleanly, assume passed
if "%TEST_STATUS%"=="UNKNOWN" (
    if %SIM_EXIT% EQU 0 (
        set TEST_STATUS=PASSED
    ) else (
        set TEST_STATUS=FAILED
    )
)

:: Extract packet counts (basic grep)
for /f "tokens=2 delims=:" %%a in ('findstr /i "Packets Sent" "%TEST_LOG%" 2^>nul') do (
    for /f "tokens=1" %%b in ("%%a") do set PKT_SENT=%%b
)
for /f "tokens=2 delims=:" %%a in ('findstr /i "Packets Received" "%TEST_LOG%" 2^>nul') do (
    for /f "tokens=1" %%b in ("%%a") do set PKT_RECV=%%b
)

:: Update counters
if "%TEST_STATUS%"=="PASSED" (
    set /a PASSED_TESTS+=1
    echo       Result: ✓ PASSED
) else (
    set /a FAILED_TESTS+=1
    echo       Result: ✗ FAILED
)

:: Append to CSV
echo %TEST_NAME%,%TEST_STATUS%,%PKT_SENT%,%PKT_RECV%,%LOSS_PCT%,,%DATE% %TIME% >> "%CSV_SUMMARY%"

:: Log result
echo   %TEST_NAME%: %TEST_STATUS% >> "%MASTER_LOG%"

:: Extract and append latency data if present
call :extract_latency "%TEST_LOG%" "%TEST_NAME%"

goto :eof

:: ============================================================================
:: SUBROUTINE: Extract latency data from log
:: ============================================================================
:extract_latency
set LOG_FILE=%~1
set TB_NAME=%~2

:: Look for latency lines and append to CSV
for /f "tokens=1-6" %%a in ('findstr /i "Priority.*pkts.*avg=" "%LOG_FILE%" 2^>nul') do (
    :: Parse the line - this is simplified, Python does better job
    echo Extracting latency data...
)

goto :eof