@echo off
setlocal

:: Set testbench name (default or from command line)
if "%~1"=="" (
    set TB=tb_fabric_basic
) else (
    set TB=%~1
)

:: Set simulation mode (gui or batch)
if "%~2"=="batch" (
    set SIM_MODE=batch
) else (
    set SIM_MODE=gui
)

:: set SIM_MODE=batch   

echo ════════════════════════════════════════════════════════════
echo   QuestaSim/ModelSim Simulation Launcher
echo   Testbench: %TB%
echo   Mode: %SIM_MODE%
echo ════════════════════════════════════════════════════════════

:: Check if XILINX_VIVADO is set
if not defined XILINX_VIVADO (
    echo WARNING: XILINX_VIVADO environment variable not set
    echo          Xilinx libraries will not be compiled
    pause
)

:: Run simulation
cd /d "%~dp0"
if "%SIM_MODE%"=="batch" (
    vsim -c -do "set TB %TB%; set SIM_MODE batch; do sim_qos.tcl"
) else (
    vsim -do "set TB %TB%; set SIM_MODE gui; do sim_qos.tcl"
)


endlocal
exit /b %ERRORLEVEL%
