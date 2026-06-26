@echo off

REM Making shortcuts to folders.
set "WUPOCompileFilesFolder=%~dp0"

REM Run file.
echo Running "Compile-EXE-File.ps1"...
powershell.exe -ExecutionPolicy Bypass -File "%WUPOCompileFilesFolder%\Compile-EXE-File.ps1"

REM End.
echo.&echo.&echo.
echo End of process...
pause