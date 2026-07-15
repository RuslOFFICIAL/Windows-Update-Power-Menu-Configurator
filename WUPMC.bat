@echo off
setlocal
cd /d "%~dp0"

REM Main process.
for %%f in ("%~dp0Program\WUPMC_*.exe") do (
	echo Processing file: "%%~nxf"...
	
	REM Use PowerShell to check for and remove the block.
	powershell -NoProfile -Command "if (Get-Item -Path '%%f' -Stream 'Zone.Identifier' -ErrorAction SilentlyContinue) { Unblock-File -Path '%%f'; Write-Host 'File unblocked.' } else { Write-Host 'File not blocked.' }"
	
	REM Run the file.
	echo.&echo Running "%%~nxf"...
	start "" "%%f"
)