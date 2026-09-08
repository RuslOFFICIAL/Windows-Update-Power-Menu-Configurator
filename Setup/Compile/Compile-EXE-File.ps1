# Self-unblock.
$currentAppPath = if ($PSCommandPath) { $PSCommandPath } else { ([Environment]::GetCommandLineArgs()[0]) }
if ($currentAppPath -and (Test-Path $currentAppPath)) {
	Unblock-File -Path $currentAppPath -ErrorAction SilentlyContinue
}

# Configuration.
$baseDir = if ($null -ne $ScriptRoot) { $ScriptRoot } else { if ($null -ne $PSScriptRoot) { $PSScriptRoot } else { [System.AppDomain]::CurrentDomain.BaseDirectory } }

$version = "Unknown"

# Configs.
$configFileName = "Variables.conf"
$pathsToCheck = @(
	(Join-Path -Path $baseDir -ChildPath "..\..\Configs\$configFileName"),
	(Join-Path -Path $baseDir -ChildPath "..\Configs\$configFileName")
)
$configFile = $pathsToCheck | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1

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
	
	Write-Host
}

# Variables.
$programDir = Join-Path -Path $PSScriptRoot -ChildPath "..\..\Program"
$releasesDir = Join-Path -Path $PSScriptRoot -ChildPath "..\..\Releases"

$inputFileName1 = "WUPMC"
$inputFile1 = Join-Path -Path $PSScriptRoot -ChildPath "..\..\Program\$inputFileName1.ps1"
$outputFile1 = Join-Path -Path $PSScriptRoot -ChildPath "..\..\Program\${inputFileName1}_$version.exe"

$inputFileName2 = "WUPMC-Background"
$inputFile2 = Join-Path -Path $PSScriptRoot -ChildPath "..\..\Program\$inputFileName2.ps1"
$outputFile2 = Join-Path -Path $PSScriptRoot -ChildPath "..\..\Program\${inputFileName2}_$version.exe"

# Check if input file exists.
$file1Exists = Test-Path $inputFile1
$file2Exists = Test-Path $inputFile2

if (-not $file1Exists) {
	Write-Host "Warning: Input file not found: $inputFile1. Skipping compilation for this file." -ForegroundColor Yellow
}
if (-not $file2Exists) {
	Write-Host "Warning: Input file not found: $inputFile2. Skipping compilation for this file." -ForegroundColor Yellow
}

if (-not $file1Exists -and -not $file2Exists) {
	Write-Error "No input files found to compile!"
	pause; exit 1
}

# Create Releases directory.
if (-not (Test-Path -Path $releasesDir -PathType Container)) {
	try {
		Write-Host "Releases folder not found at: $releasesDir. Creating it..." -ForegroundColor Yellow
		New-Item -Path "$releasesDir" -ItemType Directory
	}
	catch {
		Write-Error "Failed to create folder: $_"
	}
}

# Stop running WUPMC processes.
Write-Host "Stopping any running WUPMC processes..." -ForegroundColor Yellow
$processesToStop = @($inputFileName1, $inputFileName2, "${inputFileName1}_*", "${inputFileName2}_*")

foreach ($procName in $processesToStop) {
	if ($procName -like "*\*") { continue }
	
	Get-Process -Name $procName -ErrorAction SilentlyContinue | ForEach-Object {
	Write-Host "Stopping process: $($_.Name) (PID: $($_.Id))"
	Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
	}
}

# Deleting other EXE files.
$pathsToClean = @($programDir, $releasesDir)
foreach ($dir in $pathsToClean) {
    if (Test-Path $dir) {
        $oldFiles = Get-ChildItem -Path "$dir\$inputFileName1_*.exe"
        foreach ($file in $oldFiles) {
            Write-Host "Removing old EXE: '$($file.Name)' from '$dir'..."
            Remove-Item $file.FullName -Force
        }
	$oldFiles = Get-ChildItem -Path "$dir\$inputFileName2_*.exe"
        foreach ($file in $oldFiles) {
            Write-Host "Removing old EXE: '$($file.Name)' from '$dir'..."
            Remove-Item $file.FullName -Force
        }
    }
}

# ps2exe.
Write-Host "Getting 'ps2exe' ready..."

# Allow running the script.
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

# Import module and install if missing.
if (-not (Get-Module -ListAvailable -Name ps2exe)) {
	Write-Host "ps2exe module not found. Installing..."
	$ProgressPreference = 'SilentlyContinue'
	Install-Module -Name ps2exe -Scope CurrentUser -Force
	$ProgressPreference = 'Continue'
}
Import-Module ps2exe

# Compile.
# File 1.
Write-Host "`nCompiling '$inputFileName1' to EXE file..."
Invoke-PS2EXE -inputFile $inputFile1 `
	-outputFile $outputFile1 `
	-EmbedFiles @{"%ProgramData%\R&C\WUPMC\$configFileName" = $configFile} `
	-RequireAdmin `
	-verbose

# File 2.
Write-Host "`nCompiling '$inputFileName2' to EXE file..."
Invoke-PS2EXE -inputFile $inputFile2 `
	-outputFile $outputFile2 `
	-EmbedFiles @{"%ProgramData%\R&C\WUPMC\$configFileName" = $configFile} `
	-RequireAdmin `
	-verbose

# Copy to Releases folder.
Write-Host "Copying EXEs to Releases folder..."
if (Test-Path $outputFile1) {
	Copy-Item -Path $outputFile1 -Destination $releasesDir -Force
	Write-Host "Copied: WUPMC_$version.exe" -ForegroundColor Cyan
}
if (Test-Path $outputFile2) {
	Copy-Item -Path $outputFile2 -Destination $releasesDir -Force
	Write-Host "Copied: WUPMC-Background_$version.exe" -ForegroundColor Cyan
}

# Result.
if ((Test-Path $outputFile1) -and (Test-Path $outputFile2)) {
	Write-Host "`nSuccess! All EXEs created and published successfully." -ForegroundColor Green
} else {
	Write-Error "Compilation or copying failed for one or more files."
}

# End.
pause; exit 0