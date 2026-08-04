@echo off
setlocal
cd /d "%~dp0"

REM Self-unblock.
powershell -NoProfile -Command "$filePath = '%~f0'; if (Get-Item -LiteralPath $filePath -Stream 'Zone.Identifier' -ErrorAction SilentlyContinue) { Unblock-File -LiteralPath $filePath }"

REM Making shortcuts to folders.
set "Setup=%~dp0"

echo May need to be run as an Administrator.

REM Run file.
echo.& echo Running "Compile-EXE-File.bat"...& echo.
call "%Setup%\Compile\Compile-EXE-File.bat"

echo.& echo Running "Compress-To-ZIP-File.bat"...& echo.
call "%Setup%\Compress\Compress-To-ZIP-File.bat"

REM End.
echo.& echo.& echo.
echo End of process...
pause
