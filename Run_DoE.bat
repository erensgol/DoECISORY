@echo off
TITLE DoECISORY Gateway
COLOR 0F
CLS

REM Lock working directory to project root
cd /d "%~dp0"

REM Check if Julia is in PATH
WHERE julia >nul 2>nul
IF %ERRORLEVEL% NEQ 0 (
    set "t=%TIME: =0%"
    set "t=%t:,=.%0"
    echo [%t%] BOOT          : FAIL            Julia engine not found in system PATH.
    PAUSE
    EXIT /B
)

for /F "tokens=1,2 delims=#" %%a in ('"prompt #$H#$E# & echo on & for %%b in (1) do rem"') do set "ESC=%%b"

:MENU
CLS

set "t=%TIME: =0%"
set "t=%t:,=.%0"

echo.
echo ==================================================================
echo.
echo                            DoECISORY
echo                          System Gateway
echo.
echo ==================================================================
echo.
echo     [1] STANDARD MODE                     (Sysimage Supported)    
echo     [2] DEVELOPER MODE                     (Sysimage + Revise)
echo     [3] CLEAN JIT MODE                      (Without Sysimage)
echo     [4] BUILD SYSIMAGE
echo     [5] RUN TEST SUITE
echo     [Q] QUIT
echo.
echo ==================================================================
echo.
echo Press ENTER to default to Standard Mode [1].
set "mode="
set /p mode="    Enter Routing Node (1/2/3/4/5/Q): "

IF "%mode%"=="" set "mode=1"
IF /I "%mode%"=="Q" EXIT /B
IF /I "%mode%"=="QUIT" EXIT /B
IF /I "%mode%"=="EXIT" EXIT /B

IF "%mode%"=="1" GOTO MODE1
IF "%mode%"=="2" GOTO MODE2
IF "%mode%"=="3" GOTO MODE3
IF "%mode%"=="4" GOTO MODE4
IF "%mode%"=="5" GOTO MODE5

echo.
set "t=%TIME: =0%"
set "t=%t:,=.%0"
echo [%t%] GATEWAY       : ERROR           Invalid routing selection.
PAUSE
GOTO MENU

:MODE1
CLS
TITLE DoECISORY [Main Entry Mode]
COLOR 0E
set "t=%TIME: =0%"
set "t=%t:,=.%0"
echo [%t%] GATEWAY       : Routing         Locking Production Portal...
IF EXIST "%~dp0build\sysimage.dll" (
    echo %ESC%[97m[%t%] BOOT          : Sysimage        Pre-compiled sysimage DETECTED. Accelerated mode active.%ESC%[0m
) ELSE (
    echo %ESC%[97m[%t%] BOOT          : Sysimage        No sysimage found. Standard JIT execution active.%ESC%[0m
)
echo %ESC%[93m[%t%] BOOT          : Setup           Initializing Core Architecture...%ESC%[0m
call "%~dp0system\run_set.bat"
EXIT /B

:MODE2
CLS
TITLE DoECISORY [Developer Reviser Mode]
COLOR 09
set "t=%TIME: =0%"
set "t=%t:,=.%0"
echo [%t%] GATEWAY       : Routing         Locking Developer Studio...
IF EXIST "%~dp0build\sysimage.dll" (
    echo %ESC%[97m[%t%] BOOT          : Sysimage        Pre-compiled sysimage DETECTED. Accelerated mode active.%ESC%[0m
) ELSE (
    echo %ESC%[97m[%t%] BOOT          : Sysimage        No sysimage found. Standard JIT execution active.%ESC%[0m
)
echo %ESC%[94m[%t%] BOOT          : Setup           Initializing Core Architecture...%ESC%[0m
call "%~dp0system\run_dev.bat"
EXIT /B

:MODE3
CLS
TITLE DoECISORY [Clean JIT Mode]
COLOR 0D
set "t=%TIME: =0%"
set "t=%t:,=.%0"
echo [%t%] GATEWAY       : Routing         Starting Clean JIT Mode...
echo %ESC%[97m[%t%] BOOT          : Sysimage        Pre-compiled sysimage bypassed. Standard JIT execution active.%ESC%[0m
echo %ESC%[95m[%t%] BOOT          : Setup           Initialising server...%ESC%[0m
julia --depwarn=no --threads auto -O1 --project=. app.jl 2>nul
echo.
set "t=%TIME: =0%"
set "t=%t:,=.%0"
echo [%t%] SERVER        : SHUTDOWN        System halted.
PAUSE
EXIT /B

:MODE4
CLS
TITLE DoECISORY [Sysimage Compiler]
COLOR 0E
set "t=%TIME: =0%"
set "t=%t:,=.%0"
echo [%t%] GATEWAY       : Routing         Launching Sysimage Compiler...
echo.
call "%~dp0build\compiler.bat"
echo.
set "t=%TIME: =0%"
set "t=%t:,=.%0"
echo [%t%] GATEWAY       : Return          Press any key to return to System Gateway...
pause >nul
GOTO MENU

:MODE5
CLS
TITLE DoECISORY [Automated Test Suite]
COLOR 0B
set "t=%TIME: =0%"
set "t=%t:,=.%0"
echo [%t%] GATEWAY       : Routing         Executing Automated Test Suite...
echo.
julia --depwarn=no --threads auto --project=. test/coverage.jl
echo.
set "t=%TIME: =0%"
set "t=%t:,=.%0"
echo [%t%] GATEWAY       : Return          Press any key to return to System Gateway...
pause >nul
GOTO MENU



