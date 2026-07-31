@echo off
cd /d "%~dp0"
setlocal enabledelayedexpansion

REM Self-unblock.
powershell -NoProfile -Command "$filePath = '%~f0'; if (Get-Item -LiteralPath $filePath -Stream 'Zone.Identifier' -ErrorAction SilentlyContinue) { Unblock-File -LiteralPath $filePath }"

REM Variables.
set "ConfFile=..\..\Configs\Variables.conf"

REM Configs.
if exist "%ConfFile%" (
	for /f "usebackq eol=# tokens=1,2 delims==" %%A in ("%ConfFile%") do set "%%A=%%~B"
)

goto CompressingProc

REM Compressing process.
:CompressingProc
REM Define paths relative to the script location.
set "SourceDir=..\.."
set "StagingDir=..\..\TempRelease"
set "ConfigsDir=%StagingDir%\Configs"
set "ZipFolder=..\..\Releases"
set "ZipFile=%ZipFolder%\WUPMC_%Version%_Full.zip"

REM Deleting other ZIP files.
echo Deleting old ZIP files...
for %%f in ("%ZipFolder%\WUPMC_*.zip") do (
	echo Removing old ZIP: "%%~nxf"...
	del "%%f" /f /q
)

echo Preparing release folder...
robocopy "%SourceDir%" "%StagingDir%" /E /XF *.conf *.lnk /XD TempRelease Releases .git

echo Including 'Variables.conf' in release...
if not exist "%ConfigsDir%" mkdir "%ConfigsDir%"
copy "%ConfFile%" "%ConfigsDir%"

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
