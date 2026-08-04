@echo off

REM Self-unblock.
powershell -NoProfile -Command "$filePath = '%~f0'; if (Get-Item -LiteralPath $filePath -Stream 'Zone.Identifier' -ErrorAction SilentlyContinue) { Unblock-File -LiteralPath $filePath }"

REM Variables.
set "ProgramDir=%~dp0"
set "TargetFileName=WUPMC-Background.ps1"
set "TargetFile=%~dp0%TargetFileName%"

REM Check if the file is blocked
echo Checking if "%TargetFile%" is blocked...
powershell -Command "$file = Get-Item -LiteralPath '%TargetFile%' -Stream 'Zone.Identifier' -ErrorAction SilentlyContinue; if ($file) { Write-Host 'File is blocked. Unblocking...'; Unblock-File -Path '%TargetFile%'; Write-Host 'Done.' } else { Write-Host 'File is not blocked.' }"

REM Run main process.
echo Running "%TargetFileName%"...& echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%TargetFile%"

REM End.
echo.& echo.& echo.
echo End of process...
pause