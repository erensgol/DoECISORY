@echo off
TITLE DaishoDoE Framework System Gateway
COLOR 0F
CLS

set "t=%TIME: =0%"
set "t=%t:,=.%0"

echo.
echo  ==============================================================
echo.
echo                      DaishoDoE Framework
echo                         System Gateway
echo.
echo  ==============================================================
echo.
echo    [1] STANDARD MODE       (Fast with Sysimage DLL)
echo    [2] DEVELOPER MODE      (Reviser with Hot Reload)
echo    [3] SAFE JIT MODE       (No DLL and Full Warmup)
echo.
echo  ==============================================================
echo.
set /p mode=" Enter Routing Node (1/2/3): "

IF "%mode%"=="1" GOTO MODE1
IF "%mode%"=="2" GOTO MODE2
IF "%mode%"=="3" GOTO MODE3

echo.
set "t=%TIME: =0%"
set "t=%t:,=.%0"
echo [%t%] GATEWAY     : ERROR           Invalid routing selection.
PAUSE
EXIT /B

:MODE1
CLS
COLOR 0A
set "t=%TIME: =0%"
set "t=%t:,=.%0"
echo [%t%] GATEWAY     : Routing         Locking Production Portal...
call "%~dp0system\run_set.bat"
EXIT /B

:MODE2
CLS
COLOR 0B
set "t=%TIME: =0%"
set "t=%t:,=.%0"
echo [%t%] GATEWAY     : Routing         Locking Developer Studio...
call "%~dp0system\run_dev.bat"
EXIT /B

:MODE3
CLS
COLOR 0D
set "t=%TIME: =0%"
set "t=%t:,=.%0"
echo [%t%] GATEWAY     : Routing         Locking Safe JIT Mode...
echo [%t%] BOOT        : Setup           Initializing Core Architecture...
start /B powershell -WindowStyle Hidden -Command "$r=0; while($r -lt 120) { try { $t=New-Object System.Net.Sockets.TcpClient; $t.Connect('127.0.0.1', 8060); $t.Close(); Start-Process 'http://127.0.0.1:8060'; break; } catch { Start-Sleep -Seconds 1; $r++ } }"
julia --depwarn=no --threads auto -O1 --project=. app.jl 2>nul
echo.
set "t=%TIME: =0%"
set "t=%t:,=.%0"
echo [%t%] SERVER      : SHUTDOWN        System halted.
PAUSE
EXIT /B
