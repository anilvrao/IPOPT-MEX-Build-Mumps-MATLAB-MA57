@echo off
setlocal

if not defined MSYS2_BASH set "MSYS2_BASH=C:\msys64\usr\bin\bash.exe"
if not defined VSDEV_CMD set "VSDEV_CMD=C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\Common7\Tools\VsDevCmd.bat"
if not defined ONEAPI_SETVARS set "ONEAPI_SETVARS=C:\Program Files (x86)\Intel\oneAPI\setvars.bat"

call "%VSDEV_CMD%" -arch=x64 -host_arch=x64
if errorlevel 1 exit /b %errorlevel%

call "%ONEAPI_SETVARS%"
if errorlevel 1 exit /b %errorlevel%

set MSYS2_PATH_TYPE=inherit
for %%I in ("%~dp0..") do set "REPO_ROOT=%%~fI"
set "REPO_ROOT_MSYS=%REPO_ROOT:\=/%"
set "REPO_ROOT_MSYS=%REPO_ROOT_MSYS:C:=/c%"

if not defined BUILD_JOBS set BUILD_JOBS=%NUMBER_OF_PROCESSORS%

"%MSYS2_BASH%" -lc "cd '%REPO_ROOT_MSYS%/build/ipopt_msvc_ifx_mumps_ma57' && /usr/bin/make -j%BUILD_JOBS% && /usr/bin/make install"
