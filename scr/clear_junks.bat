cd /D "%~dp0"
cd ..


rmdir /s /q ".\scr\build_hw\.Xil"

del /q ".\out\hw_history\*.bit"

@REM rmdir /s /q ".\out\hw_history"

@REM rmdir /s /q ".\out\products"

@REM rmdir /s /q ".\out\reports"


rmdir /s /q ".\prj"

md ".\prj"

del /q ".\scr\build_hw\vivado.log"


rmdir /s /q ".\sim\wlf"
rmdir /s /q ".\sim\work"
del /q ".\sim\vsim.dbg"
del /q ".\sim\transcript*"









