@echo off

REM Variables.
set "WUPOFilesFolder=%~dp0"

REM Run main process.
echo Running "Windows-Update-Power-Options.ps1"...
powershell.exe -ExecutionPolicy Bypass -File "%WUPOFilesFolder%\Windows-Update-Power-Options.ps1"

REM End.
echo.&echo.&echo.
echo End of process...
pause