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
echo     [1] STANDARD MODE         (Fast with Sysimage DLL)
echo     [2] DEVELOPER MODE        (Reviser with Hot Reload)
echo     [3] SAFE JIT MODE         (No DLL and Full Warmup)
echo     [Q] QUIT
echo.
echo ==================================================================
echo.
set "mode="
set /p mode="  Enter Routing Node (1/2/3/Q): "

IF "%mode%"=="" set "mode=1"
IF /I "%mode%"=="Q" EXIT /B
IF /I "%mode%"=="QUIT" EXIT /B
IF /I "%mode%"=="EXIT" EXIT /B

IF "%mode%"=="1" GOTO MODE1
IF "%mode%"=="2" GOTO MODE2
IF "%mode%"=="3" GOTO MODE3

echo.
set "t=%TIME: =0%"
set "t=%t:,=.%0"
echo [%t%] GATEWAY       : ERROR           Invalid routing selection.
PAUSE
EXIT /B

:MODE1
CLS
TITLE DoECISORY [Main Entry Mode]
COLOR 0E
set "t=%TIME: =0%"
set "t=%t:,=.%0"
echo [%t%] GATEWAY       : Routing         Locking Production Portal...
IF EXIST "%~dp0build\sysimage.dll" (
    echo %ESC%[97m[%t%] BOOT          : Sysimage        Pre-compiled sysimage DETECTED. Fast Boot active.%ESC%[0m
) ELSE (
    echo %ESC%[97m[%t%] BOOT          : Sysimage        No sysimage found. Fast Boot passive.%ESC%[0m
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
    echo %ESC%[97m[%t%] BOOT          : Sysimage        Pre-compiled sysimage DETECTED. Fast Boot active.%ESC%[0m
) ELSE (
    echo %ESC%[97m[%t%] BOOT          : Sysimage        No sysimage found. Fast Boot passive.%ESC%[0m
)
echo %ESC%[94m[%t%] BOOT          : Setup           Initializing Core Architecture...%ESC%[0m
call "%~dp0system\run_dev.bat"
EXIT /B

:MODE3
CLS
TITLE DoECISORY [Safe JIT Mode]
COLOR 0D
set "t=%TIME: =0%"
set "t=%t:,=.%0"
echo [%t%] GATEWAY       : Routing         Locking Safe JIT Mode...
echo %ESC%[97m[%t%] BOOT          : Sysimage        Pre-compiled sysimage BYPASSED. Fast Boot passive.%ESC%[0m
echo %ESC%[95m[%t%] BOOT          : Setup           Initializing Core Architecture...%ESC%[0m
julia --depwarn=no --threads auto -O1 --project=. app.jl 2>nul
echo.
set "t=%TIME: =0%"
set "t=%t:,=.%0"
echo [%t%] SERVER        : SHUTDOWN        System halted.
PAUSE
EXIT /B

