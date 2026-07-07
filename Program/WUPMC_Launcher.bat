@echo off

REM Variables.
set "ProgramDir=%~dp0"
set "TargetFile=%~dp0WUPMC.ps1"

REM Check if the file is blocked
echo Checking if "%TargetFile%" is blocked...
powershell -Command "$file = Get-Item -LiteralPath '%TargetFile%' -Stream 'Zone.Identifier' -ErrorAction SilentlyContinue; if ($file) { Write-Host 'File is blocked. Unblocking...'; Unblock-File -Path '%TargetFile%'; Write-Host 'Done.' } else { Write-Host 'File is not blocked.' }"

REM Run main process.
echo Running "WUPMC.ps1"...&echo.
powershell.exe -ExecutionPolicy Bypass -File "%ProgramDir%\WUPMC.ps1"

REM End.
echo.&echo.&echo.
echo End of process...
pause