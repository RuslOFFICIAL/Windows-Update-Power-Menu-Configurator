# Configuration.
$baseDir = if ($null -ne $ScriptRoot) { $ScriptRoot } else { if ($null -ne $PSScriptRoot) { $PSScriptRoot } else { [System.AppDomain]::CurrentDomain.BaseDirectory } }

# .conf files.
$pathsToCheck = @(
    (Join-Path -Path $baseDir -ChildPath "..\Info.conf"),
    (Join-Path -Path $env:TEMP -ChildPath "R&C\WUPMC\Info.conf")
)

$configFile = $pathsToCheck | Where-Object { Test-Path $_ } | Select-Object -First 1

$version = "Unknown"
$regPath = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\Orchestrator"
$regName = "ShutdownFlyoutOptions"
$targetValue = $null

if (Test-Path $configFile) {
	$content = Get-Content -Path $configFile
	
	$rawLine = $content[0].Trim()
	
	# Version.
	if ($rawLine -match '(?i)version\s*=\s*"?([^"\s]+)"?') {
        	$version = $Matches[1]
	} else {
		$version = $rawLine -replace '[\s"=\\]', ''
	}
	
	# TargetValue.
	$targetLine = $content | Where-Object { $_ -match '(?i)targetValue\s*=\s*"?(\d+)"?' }
	if ($targetLine -match 'targetValue\s*=\s*"?(\d+)"?') {
		$targetValue = [int]$Matches[1]
	}
}

# If not found the value.
if ("Unknown" -eq $version) {
	Write-Host "Warning: Info.conf not found at $configFile. Using default version string." -ForegroundColor Yellow
}

if ($null -eq $targetValue) {
	Write-Host "Warning: targetValue not found in Info.conf. Defaulting to 5." -ForegroundColor Yellow
	$targetValue = 5
}

# Admin check.
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
	Write-Host "CRITICAL ERROR: This script must be run as an Administrator!" -ForegroundColor Red
	Write-Host "Please run the script as an Administrator." -ForegroundColor Yellow
	pause
	exit 1
}

# Log file location.
$loggedInUser = (Get-CimInstance Win32_ComputerSystem).UserName -replace '.*\\'
if ($loggedInUser) {
	$basePath = "C:\Users\$loggedInUser\AppData\Local\Temp\R&C\WUPMC"
} else {
	$basePath = Join-Path -Path $env:LOCALAPPDATA -ChildPath "Temp\R&C\WUPMC"
}
if (-not (Test-Path $basePath)) {
	New-Item -Path $basePath -ItemType Directory -Force | Out-Null
}

$logPath = Join-Path -Path $basePath -ChildPath "WUPMC.log"

# Initialize variables.
$actionTaken = "Unknown"
$errorOccurred = $false

Write-Host "Windows-Update-Power-Menu-Configurator (WUPMC) Version $version"

# Confirmation.
$confirmation = Read-Host "Are you sure you want to run this script? (Y/N)"

if ($confirmation -ne 'Y' -and $confirmation -ne 'y') {
	Write-Host "`nOperation cancelled by user." -ForegroundColor Yellow
	pause
	exit
}

# Main process.
Write-Host ""
try {
	# Ensure the Registry Path exists.
	if (-not (Test-Path $regPath)) {
		Write-Host "Creating registry path: $regPath" -ForegroundColor Yellow
		New-Item -Path $regPath -Force | Out-Null
	}

	# Retrieve current value (if it exists).
	$currentValue = Get-ItemProperty -Path $regPath -Name $regName -ErrorAction SilentlyContinue

	if ($currentValue -and $currentValue.$regName -eq $targetValue) {
		Write-Host "Value $regName is already $targetValue. No changes needed." -ForegroundColor Cyan
		$actionTaken = "No Change (Value is $targetValue)"
	} else {
		Write-Host "Value $regName is incorrect or missing. Setting to $targetValue..." -ForegroundColor Yellow
        
		$oldValue = if ($currentValue) { $currentValue.$regName } else { "N/A" }
		# Try to update.
		if ($currentValue) {
			Set-ItemProperty -Path $regPath -Name $regName -Value $targetValue -Force -ErrorAction Stop
		} else {
			New-ItemProperty -Path $regPath -Name $regName -Value $targetValue -PropertyType DWord -Force -ErrorAction Stop
		}
        
		# Only reach here if the update SUCCEEDED
		$actionTaken = "Updated from $oldValue to $targetValue"
	}

	# Log success.
	$logEntry = "$(Get-Date) - Action: $actionTaken"
	Add-Content -Path $logPath -Value $logEntry -ErrorAction SilentlyContinue
	Write-Host "Log written: $logEntry" -ForegroundColor Gray
	Write-Host "Log file is at: " -NoNewLine -ForegroundColor Gray
	Write-Host $logPath -ForegroundColor Cyan
}
catch {
	$errorMsg = "CRITICAL ERROR: $($_.Exception.Message)"
    
	# Try to write error log.
	try {
		Add-Content -Path $logPath -Value "$(Get-Date): $errorMsg" -ErrorAction Stop
		Write-Host "Error log written: $errorMsg" -ForegroundColor Red
		Write-Host "Log file is at: " -NoNewLine -ForegroundColor Gray
		Write-Host $logPath -ForegroundColor Cyan
	}
	catch {
		# Fallback: Write to Windows Event Log.
		Write-Host "Failed to write to log file. Writing to Event Log instead..." -ForegroundColor Red
		try {
			if (-not [System.Diagnostics.EventLog]::SourceExists("WUPMC_Error-Log")) {
			New-EventLog -LogName Application -Source "WUPMC_Error-Log" -ErrorAction SilentlyContinue
			}
			Write-EventLog -LogName Application -Source "WUPMC_Error-Log" -EntryType Error -EventId 1000 -Message "Script Error: $errorMsg"
			Write-Host "Error written to Windows Event Viewer." -ForegroundColor Red
			Write-Host "Event log is named: WUPMC_Error-Log"
		}
		catch {
			Write-Host "CRITICAL: Could not write to file OR Event Log. Error: $($_.Exception.Message)" -ForegroundColor DarkRed
		}
	}
	$errorOccurred = $true
	pause
	exit 1
}

# Exit cleanly if no error.
if (-not $errorOccurred) {
	pause
	exit 0
}