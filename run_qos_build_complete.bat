@echo off
REM ════════════════════════════════════════════════════════════
REM   QoS Fabric Build Pipeline with Out-of-Context Analysis
REM ════════════════════════════════════════════════════════════

setlocal enabledelayedexpansion

set VIVADO_BIN=C:\Xilinx\Vivado\2019.1\bin
set PATH=%VIVADO_BIN%;%PATH%

echo.
echo ════════════════════════════════════════════════════════════
echo   QoS 10G Switch Fabric Build System
echo ════════════════════════════════════════════════════════════
echo.
echo   Select build mode:
echo   [1] Full Implementation (Synth + Place + Route + Bitstream)
echo   [2] Synthesis Only (Fast verification)
echo   [3] Out-of-Context Timing Analysis (Core timing only)
echo   [4] ALL - Run all three modes
echo.
set /p BUILD_MODE="Enter choice (1-4): "

if "%BUILD_MODE%"=="" set BUILD_MODE=1

REM ════════════════════════════════════════════════════════════
REM   Mode 1 or 4: Full Implementation
REM ════════════════════════════════════════════════════════════
if "%BUILD_MODE%"=="1" goto :full_impl
if "%BUILD_MODE%"=="4" goto :full_impl
goto :check_synth_only

:full_impl
echo.
echo ════════════════════════════════════════════════════════════
echo   [FULL] Running Complete Implementation
echo ════════════════════════════════════════════════════════════
vivado -mode batch -source vivado_qos_build_2019.tcl
if %ERRORLEVEL% neq 0 goto :error

echo.
echo ════════════════════════════════════════════════════════════
echo   [FULL] Detailed Timing Analysis
echo ════════════════════════════════════════════════════════════
vivado -mode batch -source scr\analysis\analyze_timing.tcl

echo.
echo ════════════════════════════════════════════════════════════
echo   [FULL] Advanced Timing Analysis (Histograms)
echo ════════════════════════════════════════════════════════════
vivado -mode batch -source scr\analysis\timing_analyzer.tcl

echo.
echo ════════════════════════════════════════════════════════════
echo   [FULL] Performance Metrics
echo ════════════════════════════════════════════════════════════
cd scr\analysis
python qos_performance_analyzer.py
cd ..\..

if "%BUILD_MODE%"=="1" goto :success
REM Continue to OOC if mode 4

REM ════════════════════════════════════════════════════════════
REM   Mode 2 or 4: Synthesis Only
REM ════════════════════════════════════════════════════════════
:check_synth_only
if "%BUILD_MODE%"=="2" goto :synth_only
if "%BUILD_MODE%"=="4" goto :synth_only
goto :check_ooc

:synth_only
echo.
echo ════════════════════════════════════════════════════════════
echo   [SYNTH] Running Synthesis Only (Fast Mode)
echo ════════════════════════════════════════════════════════════
vivado -mode batch -source vivado_qos_build_2019.tcl -tclargs synth_only
if %ERRORLEVEL% neq 0 goto :error

if "%BUILD_MODE%"=="2" goto :success
REM Continue to OOC if mode 4

REM ════════════════════════════════════════════════════════════
REM   Mode 3 or 4: Out-of-Context Timing
REM ════════════════════════════════════════════════════════════
:check_ooc
if "%BUILD_MODE%"=="3" goto :ooc_analysis
if "%BUILD_MODE%"=="4" goto :ooc_analysis
goto :success

:ooc_analysis
echo.
echo ════════════════════════════════════════════════════════════
echo   [OOC] Out-of-Context Timing Analysis
echo   (Core timing without I/O pad delays)
echo ════════════════════════════════════════════════════════════
vivado -mode batch -source scr\ooc_timing_analysis.tcl
if %ERRORLEVEL% neq 0 goto :error

echo.
echo ════════════════════════════════════════════════════════════
echo   [OOC] Comparing I/O vs Core Timing
echo ════════════════════════════════════════════════════════════
if exist vivado_build\reports\timing_ooc.rpt (
    echo === OUT-OF-CONTEXT TIMING (Core Only) ===
    findstr /C:"WNS" /C:"WHS" vivado_build\reports\timing_ooc.rpt
    echo.
)
if exist vivado_build\reports\timing_synth.rpt (
    echo === WITH I/O TIMING (Full Design) ===
    findstr /C:"WNS" /C:"WHS" vivado_build\reports\timing_synth.rpt
    echo.
)

goto :success

REM ════════════════════════════════════════════════════════════
REM   Success / Error Handling
REM ════════════════════════════════════════════════════════════
:success
echo.
echo ════════════════════════════════════════════════════════════
echo    ALL TASKS COMPLETE!
echo ════════════════════════════════════════════════════════════
if exist vivado_build\switch_fabric.bit (
    echo   Bitstream:        vivado_build\switch_fabric.bit
)
if exist vivado_build\switch_fabric_routed.dcp (
    echo   Checkpoint:       vivado_build\switch_fabric_routed.dcp
)
echo   Reports:          vivado_build\reports\
if exist vivado_build\reports\detailed (
    echo   Detailed:         vivado_build\reports\detailed\
)
if exist vivado_build\reports\timing_ooc.rpt (
    echo   OOC Timing:       vivado_build\reports\timing_ooc.rpt
)
echo ════════════════════════════════════════════════════════════
echo.
echo Quick Timing Summary:
echo.
if exist vivado_build\reports\timing_synth.rpt (
    findstr /C:"WNS" /C:"WHS" /C:"Timing constraints" vivado_build\reports\timing_synth.rpt
)
echo.
pause
exit /b 0

:error
echo.
echo ════════════════════════════════════════════════════════════
echo    BUILD FAILED - Check logs above
echo ════════════════════════════════════════════════════════════
pause
exit /b 1