@echo off
setlocal enabledelayedexpansion

echo ╔════════════════════════════════════════════════════════════╗
echo ║         PROJECT INTEGRITY CHECKER                          ║
echo ╚════════════════════════════════════════════════════════════╝

set MISSING=0

:: Critical RTL files
echo.
echo [1/5] Checking RTL files...
call :check_file "src\hdl\core\switch_fabric.sv"
call :check_file "src\hdl\core\qos_shaper.sv"
call :check_file "src\hdl\core\qos_classifier.sv"
call :check_file "src\hdl\switch_ips\des_finder_row_matching_qos.sv"
call :check_file "src\inc\qos_defines.vh"
call :check_file "src\inc\implement_options.vh"

:: Testbenches
echo.
echo [2/5] Checking testbench files...
call :check_file "sim\tb\fabric\tb_fabric_basic.sv"
call :check_file "sim\tb\fabric\tb_fabric_qos_sweep.sv"
call :check_file "sim\tb\fabric\tb_fabric_qos_stress.sv"
call :check_file "sim\tb\unit\tb_voq_unit.sv"
call :check_file "sim\tb\unit\tb_qos_classifier_unit.sv"

:: Verification files
echo.
echo [3/5] Checking verification files...
call :check_file "sim\hvl\verification\qos_checker_scoreboard.sv"
call :check_file "sim\hvl\verification\qos_latency_monitor.sv"
call :check_file "sim\hvl\model_for_verification\switch_fabric_model_qos.sv"

:: Scripts
echo.
echo [4/5] Checking build scripts...
call :check_file "scr\build_hw\build_qos_sweep.py"
call :check_file "scr\save_configs\config_generator\config_generator_qos.py"
call :check_file "scr\save_configs\config_generator\config_sweep_qos.py"

:: Simulation scripts
echo.
echo [5/5] Checking simulation files...
call :check_file "sim\sim.tcl"

echo.
echo ╔════════════════════════════════════════════════════════════╗
if %MISSING%==0 (
    echo ║  PROJECT COMPLETE - All files present                  ║
) else (
    echo ║    PROJECT INCOMPLETE - %MISSING% files missing
)
echo ╚════════════════════════════════════════════════════════════╝

exit /b %MISSING%

:check_file
if exist %~1 (
    echo    %~1
) else (
    echo   MISSING: %~1
    set /a MISSING+=1
)
goto :eof