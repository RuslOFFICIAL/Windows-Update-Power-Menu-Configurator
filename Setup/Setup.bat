@echo off

REM Making shortcuts to folders.
set "Setup=%~dp0"

REM Run file.
echo Running "Compile-EXE-File.bat"...&echo.
call "%Setup%\Compile\Compile-EXE-File.bat"

echo Running "Compress-To-ZIP-File.bat"...&echo.
call "%Setup%\Compress\Compress-To-ZIP-File.bat"

REM End.
echo.&echo.&echo.
echo End of process...
pause
