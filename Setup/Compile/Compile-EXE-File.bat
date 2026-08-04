@echo off
setlocal
cd /d "%~dp0"

REM Self-unblock.
powershell -NoProfile -Command "$filePath = '%~f0'; if (Get-Item -LiteralPath $filePath -Stream 'Zone.Identifier' -ErrorAction SilentlyContinue) { Unblock-File -LiteralPath $filePath }"

REM Making shortcuts to folders.
set "Compile=%~dp0"

REM Run file.
echo Running "Compile-EXE-File.ps1"...& echo.
powershell.exe -ExecutionPolicy Bypass -File "%Compile%\Compile-EXE-File.ps1"

REM End.
echo.& echo.& echo.
echo End of process...
pause