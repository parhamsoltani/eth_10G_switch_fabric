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
vsim -do "set TB %TB%; set env(SIM_MODE) %SIM_MODE%; do sim_qos.tcl"

endlocal