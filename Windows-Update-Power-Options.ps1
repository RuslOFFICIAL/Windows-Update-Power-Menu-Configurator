# Configuration.
$version = "2.1.0"
$regPath = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\Orchestrator"
$regName = "ShutdownFlyoutOptions"
$targetValue = 5

# Log file location.
$basePath = Join-Path -Path $env:LOCALAPPDATA -ChildPath "Temp\R&C\Windows-Update-Power-Options"
if (-not (Test-Path $basePath)) {
    New-Item -Path $basePath -ItemType Directory -Force | Out-Null
}

$logPath = Join-Path -Path $basePath -ChildPath "Windows-Update-Power-Options.log"

# Initialize variables.
$actionTaken = "Unknown"
$errorOccurred = $false

Write-Host "Windows-Update-Power-Options Version $version"

# Confirmation.
$confirmation = Read-Host "Are you sure you want to run this script? (Y/N)"

if ($confirmation -ne 'Y' -and $confirmation -ne 'y') {
    Write-Host "Operation cancelled by user." -ForegroundColor Yellow
    Start-Sleep -Seconds 2
    exit
}

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
    }
    else {
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
    Write-Host "Log file is at: $logPath" -ForegroundColor Gray
}
catch {
    $errorMsg = "CRITICAL ERROR: $($_.Exception.Message)"
    
    # Try to write error log.
    try {
        Add-Content -Path $logPath -Value "$(Get-Date): $errorMsg" -ErrorAction Stop
        Write-Host "Error log written: $errorMsg" -ForegroundColor Red
	Write-Host "Log file is at $logPath" -ForegroundColor Gray
    }
    catch {
        # Fallback: Write to Windows Event Log.
        Write-Host "Failed to write to log file. Writing to Event Log instead..." -ForegroundColor Red
        try {
            if (-not [System.Diagnostics.EventLog]::SourceExists("Windows-Update-Power-Options_Error-Log")) {
                New-EventLog -LogName Application -Source "Windows-Update-Power-Options_Error-Log" -ErrorAction SilentlyContinue
            }
            Write-EventLog -LogName Application -Source "Windows-Update-Power-Options_Error-Log" -EntryType Error -EventId 1000 -Message "Script Error: $errorMsg"
            Write-Host "Error written to Windows Event Viewer." -ForegroundColor Red
	    Write-Host "Event log is named: Windows-Update-Power-Options_Error-Log"
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