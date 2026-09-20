@echo off

REM Set working directory to project root
cd /d "%~dp0.."

powershell.exe -ExecutionPolicy Bypass -File "%~dp0run_dev.ps1"

PAUSE
