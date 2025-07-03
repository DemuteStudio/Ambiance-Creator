@echo off
cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -File "Publish-ReaPack.ps1"
pause