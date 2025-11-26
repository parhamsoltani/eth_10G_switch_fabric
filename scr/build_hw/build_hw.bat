cd "%~dp0"




set rootDir=../..
set srcDir=%rootDir%/src
set incFile=%srcDir%/inc/implement_options.vh
set clkFile=%srcDir%/xdc/timing.xdc
set partNumFile=%rootDir%/scr/build_hw/build_switches_main.tcl
set hist=%rootDir%/out/hw_history/hist.csv
set congigHist=%rootDir%/out/hw_history/config_hist.csv
set pythonSaveConfigFile=%rootDir%/scr/save_configs/save_configs.py
set configGenerator=%rootDir%/scr/save_configs/config_generator/save_configs.py
set configDir=%rootDir%/scr/save_configs/config_generator/configs



@REM call vivado -mode tcl -notrace -nojournal ^
@REM     -source %TCL_TOOLS_PATH%\build_hw\build_hw_np.tcl -tclargs ^
@REM     -switch_file ./build_switches_main.tcl ^
@REM     -switch_file ./build_switches_run.tcl %*

@REM python "%pythonSaveConfigFile%" true "%hist%" "%congigHist%" "%incFile%" "%clkFile%" "%partNumFile%"



for /D %%C in ("%configDir%\*") do (
    echo === Running config: %%~nxC ===


    copy /Y "%%C\implement_options.vh" "%incFile%" >nul
    copy /Y "%%C\timing.xdc"           "%clkFile%" >nul
    copy /Y "%%C\build_switches_main.tcl" "%partNumFile%" >nul


    call vivado -mode tcl -notrace -nojournal ^
    -source %TCL_TOOLS_PATH%\build_hw\build_hw_np.tcl -tclargs ^
    -switch_file ./build_switches_main.tcl ^
    -switch_file ./build_switches_run.tcl %*

    python "%pythonSaveConfigFile%" true "%hist%" "%congigHist%" "%incFile%" "%clkFile%" "%partNumFile%"
)

echo All configs complete.




