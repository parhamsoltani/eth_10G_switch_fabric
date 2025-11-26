cd /D "%~dp0"
cd ..\..

git subtree split --prefix=src/hdl -b submodule

git push --set-upstream origin submodule