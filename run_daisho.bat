@echo off
TITLE DaishoDoE
COLOR 0A
CLS

ECHO.
ECHO  [SYSTEM] Booting DaishoDoE Engine...
ECHO  [STATUS] Verifying Julia Environment...

REM Check if Julia is in PATH
WHERE julia >nul 2>nul
IF %ERRORLEVEL% NEQ 0 (
    COLOR 0C
    ECHO.
    ECHO  [ERROR]  Julia engine not found in system PATH.
    PAUSE
    EXIT /B
)

ECHO  [STATUS] Environment Validated.
ECHO  [SYSTEM] Initializing Core Architecture...
ECHO.

REM Run the application
julia --threads auto -O1 --project=. app.jl

IF %ERRORLEVEL% NEQ 0 (
    COLOR 0C
    ECHO.
    ECHO  [CRITICAL] Uygulama hatali sonlandi.
    PAUSE
)
ECHO.
ECHO  [SHUTDOWN] System halted.
PAUSE
