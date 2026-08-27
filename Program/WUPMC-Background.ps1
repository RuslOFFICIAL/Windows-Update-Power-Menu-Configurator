param(
	[switch]$BackgroundMode
)

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
	(Join-Path -Path $env:TEMP -ChildPath "R&C\WUPMC\$configFileName")
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
		Write-Host "Warning: 'version' not found at '$configFile'. Using default version string." -ForegroundColor Yellow
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

Write-Host "Windows-Update-Power-Menu-Configurator (WUPMC) Version $version-Background" -ForegroundColor Green
Write-Host "Press 'Ctrl+C' to stop monitoring." -ForegroundColor Cyan

# Task scheduler.
$taskPath = "\R&C\"
$taskName = "WUPMC-Background"
$taskExists = Get-ScheduledTask -TaskName $taskName -TaskPath $taskPath -ErrorAction SilentlyContinue
$registerNewTask = $false

Write-Host
if (-not $taskExists) {
	$registerNewTask = $true
} else {
	$taskDetails = Get-ScheduledTask -TaskName $taskName -TaskPath $taskPath
	$currentExecutePath = $taskDetails.Actions.Execute
	$currentUserId = $taskDetails.Principal.UserId

	$normalizedExisting = [System.IO.Path]::GetFullPath($currentExecutePath)
	$normalizedCurrent  = [System.IO.Path]::GetFullPath($currentAppPath)

	$isSystemAccount = ($currentUserId -eq "S-1-5-18" -or $currentUserId -eq "NT AUTHORITY\SYSTEM" -or $currentUserId -like "*SYSTEM*")

	if ($normalizedExisting -ne $normalizedCurrent -or -not $isSystemAccount) {
		Write-Host "Task parameters outdated or path changed. Updating configuration..." -ForegroundColor Yellow
		$registerNewTask = $true
	}
}

if ($registerNewTask) {
	Write-Host "Registering '$taskName' into Task Scheduler under '$taskPath'..." -ForegroundColor Cyan
	$filePath = $currentAppPath
	
	# Action.
	if ($currentAppPath -like "*.ps1") {
		$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -File `"$currentAppPath`" -BackgroundMode"
	} else {
		$action = New-ScheduledTaskAction -Execute $currentAppPath -Argument "-BackgroundMode"
	}
	
	# Trigger to run at system startup with highest privileges
	$trigger = New-ScheduledTaskTrigger -AtStartup
	$principal = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest
	$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Hours 0)
	
	Register-ScheduledTask -TaskName $taskName -TaskPath $taskPath -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
	Write-Host "Task '$taskName' under '$taskPath' successfully registered to run at startup!" -ForegroundColor Green
} else {
	Write-Host "Task '$taskName' under '$taskPath' is already registered in Task Scheduler." -ForegroundColor Yellow
}

# Choice.
if (-not $BackgroundMode) {
	Write-Host "`nChoose an option for this window session:" -ForegroundColor Cyan
	Write-Host "[1] Continue running this window."
	Write-Host "[2] Run on background."
	$choice = Read-Host "Enter your choice (1 or 2)"
	
	# Option 2.
	if ($choice -eq '2') {
		Write-Host "`nStarting background instance and closing..." -ForegroundColor Green
		
		if ($currentAppPath -like "*.ps1") {
			Start-Process powershell.exe -ArgumentList "-WindowStyle Hidden -File `"$currentAppPath`" -BackgroundMode" -WindowStyle Hidden
		} else {
			Start-Process -FilePath $currentAppPath -ArgumentList "-BackgroundMode" -WindowStyle Hidden
		}
		
		exit 0
	} else {
		Write-Host "`nChecking for incorrect or missing value..."
	}
}

# Main process.
Write-Host
while ($true) {
	try {
		# Ensure the Registry Path exists.
		if (-not (Test-Path $regPath)) {
			New-Item -Path $regPath -Force | Out-Null
		}
		
		# Retrieve current value.
		$currentValue = Get-ItemProperty -Path $regPath -Name $regName -ErrorAction SilentlyContinue
		
		if ($currentValue -and $currentValue.$regName -eq $targetValue) {
			# Value is correct, do nothing silently.
		} else {
			Write-Host "[$(Get-Date)] Value $regName is incorrect or missing. Setting to $targetValue..." -ForegroundColor Yellow
			$oldValue = if ($currentValue) { $currentValue.$regName } else { "N/A" }
			
			# Try to update.
			if ($currentValue) {
				Set-ItemProperty -Path $regPath -Name $regName -Value $targetValue -Force -ErrorAction Stop
			} else {
				New-ItemProperty -Path $regPath -Name $regName -Value $targetValue -PropertyType DWord -Force -ErrorAction Stop
			}
			$actionTaken = "Updated from $oldValue to $targetValue"
			
			# Log success.
			$logEntry = "$(Get-Date) - Action: $actionTaken"
			Write-Log -Message $logEntry
			Write-Host "Log written: $logEntry" -ForegroundColor Gray
			Write-Host "Log file is at: " -NoNewLine -ForegroundColor Gray; Write-Host $logPath -ForegroundColor Cyan
			
			Write-Host
		}
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
		Write-Host
	}

	# Pause on # seconds.
	Start-Sleep -Seconds 5
}