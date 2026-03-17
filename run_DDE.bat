@echo off
TITLE DaishoDoE
COLOR 0A
CLS

set "t=%TIME: =0%"
set "t=%t:,=.%0"
echo [%t%] BOOT        : Setup           Booting DaishoDoE Engine...
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
echo [%t%] BOOT        : Setup           Initializing Core Architecture...
ECHO.

REM Dynamic PowerShell command waiting for server port availability to trigger browser launch.
start /B powershell -WindowStyle Hidden -Command "$r=0; while($r -lt 120) { try { $t=New-Object System.Net.Sockets.TcpClient; $t.Connect('127.0.0.1', 8060); $t.Close(); Start-Process 'http://127.0.0.1:8060'; break; } catch { Start-Sleep -Seconds 1; $r++ } }"

REM Run the application
julia --threads auto -O1 --project=. app.jl

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
