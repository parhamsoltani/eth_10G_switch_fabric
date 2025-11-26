cd /D "%~dp0"
cd ..\..

git subtree split --prefix=sim/hvl -b submodule_hvl

git push --set-upstream origin submodule_hvl