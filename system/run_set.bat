@echo off
TITLE DoECISORY [Main Entry Mode]
COLOR 0A
CLS

REM Set working directory to project root
cd /d "%~dp0.."

set "t=%TIME: =0%"
set "t=%t:,=.%0"
echo [%t%] BOOT        : Setup           Booting DoECISORY...
echo [%t%] BOOT        : Setup           Verifying Julia Environment...

REM Check if Julia is in PATH
WHERE julia >nul 2>nul
IF %ERRORLEVEL% NEQ 0 (
    set "t=%TIME: =0%"
    set "t=%t:,=.%"
    echo [%t%] BOOT        : FAIL            Julia engine not found in system PATH.
    PAUSE
    EXIT /B
)

set "t=%TIME: =0%"
set "t=%t:,=.%0"
echo [%t%] BOOT        : Setup           Environment Validated.

REM Sysimage Detection Protocol: Use pre-compiled image if available.
set "SYSIMG_FLAG="
IF EXIST "%~dp0..\build\sysimage.dll" (
    set "SYSIMG_FLAG=--sysimage "%~dp0..\build\sysimage.dll""
    echo [%t%] BOOT        : Sysimage        Pre-compiled sysimage DETECTED. Fast Boot enabled.
) ELSE (
    echo [%t%] BOOT        : Sysimage        No sysimage found. Standard JIT boot.
    echo [%t%] BOOT        : Sysimage        Run 'build\compiler.bat' to create one.
)

echo [%t%] BOOT        : Setup           Initializing Core Architecture...
ECHO.

REM Dynamic PowerShell command waiting for server port availability to trigger browser launch.
start /B powershell -WindowStyle Hidden -Command "$r=0; while($r -lt 120) { try { $t=New-Object System.Net.Sockets.TcpClient; $t.Connect('127.0.0.1', 8060); $t.Close(); Start-Process 'http://127.0.0.1:8060'; break; } catch { Start-Sleep -Seconds 1; $r++ } }"

REM Run the application (with sysimage if available)
julia --depwarn=no %SYSIMG_FLAG% --threads auto -O1 --project=. app.jl 2>nul

IF %ERRORLEVEL% NEQ 0 (
    set "t=%TIME: =0%"
    set "t=%t:,=.%"
    echo [%t%] SERVER      : CRITICAL        Application terminated unexpectedly.
    PAUSE
)
ECHO.
set "t=%TIME: =0%"
set "t=%t:,=.%0"
echo [%t%] SERVER      : SHUTDOWN        System halted.
PAUSE
