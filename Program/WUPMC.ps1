# Self-unblock.
$currentAppPath = if ($PSCommandPath) { $PSCommandPath } else { ([Environment]::GetCommandLineArgs()[0]) }
if ($currentAppPath -and (Test-Path $currentAppPath)) {
	Unblock-File -Path $currentAppPath -ErrorAction SilentlyContinue
}

# Configuration.
$baseDir = if ($null -ne $ScriptRoot) { $ScriptRoot } else { if ($null -ne $PSScriptRoot) { $PSScriptRoot } else { [System.AppDomain]::CurrentDomain.BaseDirectory } }

# Configs.
$configFileName = "Variables.conf"
$pathsToCheck = @(
	(Join-Path -Path $baseDir -ChildPath "..\Configs\$configFileName"),
	(Join-Path -Path $env:ProgramData -ChildPath "R&C\WUPMC\$configFileName")
)
$configFile = $pathsToCheck | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1

$isConfig = $false
$version = "Unknown"
$regPath = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\Orchestrator"
$regName = "ShutdownFlyoutOptions"
$targetValue = $null
$maxFileSize = 512000 # Bytes.

# Configs.
if ($configFile -and (Test-Path $configFile)) {
	Get-Content -Path $configFile | ForEach-Object {
		$line = $_.Trim()
		
		# Skip empty lines and comments.
		if (-not $line -or $line.StartsWith('#')) { return }
		
		# Split by the first '=' character.
		if ($line -match '^([^=]+)=(.*)$') {
			$key   = $Matches[1].Trim()
			$value = $Matches[2].Trim()
			$value = $value -replace '^"|"$', ''
			
			# Automatically parse hex and decimal formats.
			if ($value -match '^0x[0-9a-fA-F]+$') {
				try { $value = [convert]::ToInt32($value, 16) } catch {}
			} elseif ($value -match '^[0-9a-fA-F]+$' -and $value -match '[a-fA-F]') {
				try { $value = [convert]::ToInt32($value, 16) } catch {}
			} elseif ($value -match '^\d+$') {
				try { $value = [convert]::ToInt32($value, 10) } catch {}
			}
			
			Set-Variable -Name $key -Value $value -Scope Local
		}
	}
	$isConfig = $true
} else {
	Write-Host "Warning: File not found at '$configFile'!" -ForegroundColor Yellow
	Write-Host "Check if you have that file or download it from GitHub repository!" -ForegroundColor Yellow
	Write-Host
}

# Defaults.
if ($isConfig -eq $true) {
	if ($version -eq "Unknown") {
		Write-Host "Warning: 'version' not found at '$configFileName'. Using default version string." -ForegroundColor Yellow
	}
	
	if ($targetValue -eq $null) {
		Write-Host "Warning: 'targetValue' not found in '$configFileName'. Defaulting to 5." -ForegroundColor Yellow
		$targetValue = 5
	}
	
	Write-Host
}

# Admin check.
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
	Write-Host "CRITICAL ERROR: This file must be run as an Administrator!" -ForegroundColor Red
	Write-Host "Please run the file as an Administrator." -ForegroundColor Yellow
	pause; exit 1
}

# Log file location.
$basePath = Join-Path $env:ProgramData "R&C\WUPMC"
if (-not (Test-Path $basePath)) {
	New-Item -Path $basePath -ItemType Directory -Force | Out-Null
}

$logPath = Join-Path -Path $basePath -ChildPath "WUPMC.log"

function Write-Log {
	param([string]$Message)
	
	# Fast chunk-trimming log cleaner.
	if ((Test-Path $logPath) -and ((Get-Item $logPath).Length -gt $maxFileSize)) {
		$fileContent = Get-Content -Path $logPath
		while ($fileContent.Count -gt 1) {
			$dropCount = [Math]::Max(1, [int]($fileContent.Count * 0.2))
			if ($fileContent.Count -gt $dropCount) {
				$fileContent = $fileContent[$dropCount..($fileContent.Count - 1)]
			} else {
				$fileContent = $null
				break
			}
			$fileContent | Set-Content -Path $logPath
			if ((Get-Item $logPath).Length -le $maxFileSize) { break }
		}
		if ((Test-Path $logPath) -and ((Get-Item $logPath).Length -gt $maxFileSize)) {
			Set-Content -Path $logPath -Value $null
		}
	}

	Add-Content -Path $logPath -Value $Message -ErrorAction SilentlyContinue
}

# Initialize variables.
$actionTaken = "Unknown"
$errorOccurred = $false

Write-Host "Windows-Update-Power-Menu-Configurator (WUPMC) Version $version" -ForegroundColor Green

# Confirmation.
$confirmation = Read-Host "Are you sure you want to run this script? (Y/N)"

if ($confirmation -ne 'Y' -and $confirmation -ne 'y') {
	Write-Host "`nOperation cancelled by user." -ForegroundColor Yellow
	pause; exit 0
}

# Main process.
Write-Host
try {
	# Ensure the Registry Path exists.
	if (-not (Test-Path $regPath)) {
		Write-Host "Creating registry path: $regPath" -ForegroundColor Yellow
		New-Item -Path $regPath -Force | Out-Null
	}
	
	# Check property existence, type, and current value.
	$regKey = Get-Item -Path $regPath
	$propertyExists = $regKey.Property -contains $regName
	$isDWord = $false
	$currentVal = $null

	if ($propertyExists) {
		$valKind = $regKey.GetValueKind($regName)
		if ($valKind -eq [Microsoft.Win32.RegistryValueKind]::DWord) {
			$isDWord = $true
			$currentVal = $regKey.GetValue($regName)
		}
	}
	
	# If it exists but is not a DWORD, delete it.
	if ($propertyExists -and -not $isDWord) {
		Write-Host "[$(Get-Date)] '$regName' exists as type '$valKind' instead of DWORD. Deleting..." -ForegroundColor Yellow
		Remove-ItemProperty -Path $regPath -Name $regName -Force
		$propertyExists = $false
	}

	# Check if value matches target.
	if ($propertyExists -and $isDWord -and $currentVal -eq $targetValue) {
		Write-Host "[$(Get-Date)] Value '$regName' is already '$targetValue' (DWORD). No changes needed." -ForegroundColor Cyan
		$actionTaken = "No Change (Value is $targetValue)"
	} else {
		Write-Host "[$(Get-Date)] Setting '$regName' to '$targetValue' as DWORD..." -ForegroundColor Yellow
		$oldValue = if ($propertyExists) { $currentVal } else { "N/A" }
		
		# Create or Set as DWORD.
		if ($propertyExists) {
			Set-ItemProperty -Path $regPath -Name $regName -Value $targetValue -Type DWord -Force -ErrorAction Stop | Out-Null
		} else {
			New-ItemProperty -Path $regPath -Name $regName -Value $targetValue -PropertyType DWord -Force -ErrorAction Stop | Out-Null
		}
		$actionTaken = "Updated from $oldValue to $targetValue"
	}

	# Log success.
	$logEntry = "$(Get-Date) - Action: $actionTaken"
	Write-Log -Message $logEntry
	Write-Host "Log written: $logEntry" -ForegroundColor Gray
	Write-Host "Log file is at: " -NoNewLine -ForegroundColor Gray; Write-Host $logPath -ForegroundColor Cyan
}
catch {
	$errorMsg = "[$(Get-Date)] CRITICAL ERROR: $($_.Exception.Message)"
    
	# Try to write error log.
	try {
		Write-Log -Message "$(Get-Date): $errorMsg"
		Write-Host "Error log written: $errorMsg" -ForegroundColor Red
		Write-Host "Log file is at: " -NoNewLine -ForegroundColor Gray; Write-Host $logPath -ForegroundColor Cyan
	}
	catch {
		# Fallback to Windows Event Log.
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
	pause; exit 1
}

# Exit cleanly if no error.
if (-not $errorOccurred) {
	pause; exit 0
}
