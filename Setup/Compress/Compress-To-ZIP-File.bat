@echo off
cd /d "%~dp0"
setlocal enabledelayedexpansion

REM .conf files.
if exist "..\..\Info.conf" (
	for /f "usebackq eol=# tokens=1,2 delims==" %%A in ("..\..\Info.conf") do set "%%A=%%~B"
)

goto CompressingProc

REM Compressing process.
:CompressingProc
REM Define paths relative to the script location.
set "SourceDir=..\.."
set "StagingDir=..\..\TempRelease"
set "ZipFolder=..\..\Releases"
set "ZipFile=%ZipFolder%\WUPMC_%Version%_Full.zip"

REM Deleting other ZIP files.
echo Deleting old ZIP files...
for %%f in ("%ZipFolder%\WUPMC_*.zip") do (
	echo Removing old ZIP: "%%~nxf"
	del "%%f" /f /q
)

echo Preparing release folder...
robocopy "%SourceDir%" "%StagingDir%" /E /XF *.lnk /XD TempRelease Releases .git

echo.&echo Compressing into .zip file...
REM Create the output directory if it doesn't exist.
if not exist "%ZipFolder%" mkdir "%ZipFolder%"

REM Use PowerShell to compress the staging contents.
powershell -Command "Compress-Archive -Path '%StagingDir%\*' -DestinationPath '%ZipFile%' -Force"

echo.
echo Cleaning up temporary folders...
rmdir /s /q "%StagingDir%"
goto End

REM End.
:End
endlocal
echo.&echo Done!&echo Your release is ready inside the "Releases" folder.
pause
