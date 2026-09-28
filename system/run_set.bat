@echo off
REM Set working directory to project root
cd /d "%~dp0.."

REM Check if Julia is in PATH
WHERE julia >nul 2>nul
IF %ERRORLEVEL% NEQ 0 (
    set "t=%TIME: =0%"
    set "t=%t:,=.%0"
    echo [%t%] BOOT          : FAIL            Julia engine not found in system PATH.
    PAUSE
    EXIT /B
)

set "t=%TIME: =0%"
set "t=%t:,=.%0"

REM Sysimage Detection Protocol: Use pre-compiled image if available.
set "SYSIMG_FLAG="
set "DOECISORY_FAST_BOOT=false"
IF EXIST "%~dp0..\build\sysimage.dll" (
    set "SYSIMG_FLAG=--sysimage "%~dp0..\build\sysimage.dll""
    set "DOECISORY_FAST_BOOT=true"
)

REM Run the application (with sysimage if available)
julia --depwarn=no %SYSIMG_FLAG% --threads auto -O0 --project=. app.jl 2>nul

IF %ERRORLEVEL% NEQ 0 (
    set "t=%TIME: =0%"
    set "t=%t:,=.%0"
    echo [%t%] SERVER        : CRITICAL        Application terminated unexpectedly.
    PAUSE
    EXIT /B
)
ECHO.
set "t=%TIME: =0%"
set "t=%t:,=.%0"
echo [%t%] SERVER        : SHUTDOWN        System halted.
PAUSE