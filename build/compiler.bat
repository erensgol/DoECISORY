@echo off
TITLE DoECISORY Sysimage Compiler
COLOR 0E
CLS

echo ============================================================
echo   DoECISORY Sysimage Compiler
echo   Do not close this window. This process takes an hour.
echo ============================================================
echo.

cd /d "%~dp0\.."
julia --threads auto --project=. build\compiler.jl

echo.
IF %ERRORLEVEL% EQU 0 (
    COLOR 0A
    echo   SUCCESS! Launch the system using run_DDE.bat.
) ELSE (
    COLOR 0C
    echo   ERROR ENCOUNTERED. Please check the logs above.
)
echo.
PAUSE
