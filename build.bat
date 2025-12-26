@echo off
REM ════════════════════════════════════════════════════════════
REM   Complete QoS Fabric Build + Analysis Pipeline
REM ════════════════════════════════════════════════════════════

set VIVADO_BIN=C:\Xilinx\Vivado\2019.1\bin
set PATH=%VIVADO_BIN%;%PATH%

echo.
echo ════════════════════════════════════════════════════════════
echo   [1/4] Vivado Build (Synth + Impl + Bitstream)
echo ════════════════════════════════════════════════════════════
vivado -mode batch -source vivado_qos_build_2019.tcl
if %ERRORLEVEL% neq 0 goto :error

echo.
echo ════════════════════════════════════════════════════════════
echo   [2/4] Detailed Timing Analysis
echo ════════════════════════════════════════════════════════════
vivado -mode batch -source scr\analysis\analyze_timing.tcl

echo.
echo ════════════════════════════════════════════════════════════
echo   [3/4] Advanced Timing Analysis (Histograms)
echo ════════════════════════════════════════════════════════════
vivado -mode batch -source scr\analysis\timing_analyzer.tcl

echo.
echo ════════════════════════════════════════════════════════════
echo   [4/4] Performance Metrics
echo ════════════════════════════════════════════════════════════
cd scr\analysis
python qos_performance_analyzer.py
cd ..\..

echo.
echo ════════════════════════════════════════════════════════════
echo    ALL TASKS COMPLETE!
echo ════════════════════════════════════════════════════════════
echo   Outputs:
echo     - Bitstream:      vivado_build\switch_fabric.bit
echo     - Checkpoint:     vivado_build\switch_fabric_routed.dcp
echo     - Reports:        vivado_build\reports\
echo     - Detailed:       vivado_build\reports\detailed\
echo ════════════════════════════════════════════════════════════
pause
exit /b 0

:error
echo.
echo ════════════════════════════════════════════════════════════
echo    BUILD FAILED
echo ════════════════════════════════════════════════════════════
pause
exit /b 1