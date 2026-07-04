@echo off

REM Variables.
set "Program=%~dp0"

REM Run main process.
echo Running "WUPMC.ps1"...&echo.
powershell.exe -ExecutionPolicy Bypass -File "%Program%\WUPMC.ps1"

REM End.
echo.&echo.&echo.
echo End of process...
pause