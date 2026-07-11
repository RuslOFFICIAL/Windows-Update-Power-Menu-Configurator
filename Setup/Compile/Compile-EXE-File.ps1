# Configuration.
$configFile = Join-Path -Path $PSScriptRoot -ChildPath "..\..\Info.conf"

$version = "Unknown"
if (Test-Path $configFile) {
	$rawLine = (Get-Content -Path $configFile -TotalCount 1).Trim()
	
	if ($rawLine -match '(?i)version\s*=\s*"?([^"\s]+)"?') {
		$version = $Matches[1]
	} else {
		$version = $rawLine -replace '[\s"=\\]', ''
	}
} else {
	Write-Host "Warning: Info.conf not found at $configFile. Using default version string." -ForegroundColor Yellow
}

$programDir = Join-Path -Path $PSScriptRoot -ChildPath "..\..\Program"
$inputFile = Join-Path -Path $PSScriptRoot -ChildPath "..\..\Program\WUPMC.ps1"
$outputFile = Join-Path -Path $PSScriptRoot -ChildPath "..\..\Program\WUPMC_$version.exe"
$infoConf = Join-Path -Path $PSScriptRoot -ChildPath "..\..\Info.conf"
$releasesDir = Join-Path -Path $PSScriptRoot -ChildPath "..\..\Releases"

# Check if input file exists.
if (-not (Test-Path $inputFile)) {
	Write-Error "Input file not found: $inputFile"
	Write-Host "Press any key to exit..."
	$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
	exit
}

# Deleting other EXE files.
$pathsToClean = @($programDir, $releasesDir)
foreach ($dir in $pathsToClean) {
    if (Test-Path $dir) {
        $oldFiles = Get-ChildItem -Path "$dir\WUPMC_*.exe"
        foreach ($file in $oldFiles) {
            Write-Host "Removing old EXE: '$($file.Name)' from $dir"
            Remove-Item $file.FullName -Force
        }
    }
}

Write-Host "`nCompiling 'WUPMC.ps1' to EXE file..."

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
Invoke-PS2EXE -InputFile $inputFile `
	-OutputFile $outputFile `
	-EmbedFiles @{"$env:TEMP\R&C\WUPMC\Info.conf" = $infoConf} `
	-RequireAdmin

# Copy to Releases folder.
if (-not (Test-Path -Path $releasesDir -PathType Container)) {
	try {
		Write-Host "Releases folder not found at: $releasesDir. Creating it..." -ForegroundColor Yellow
		New-Item -Path "$releasesDir" -ItemType Directory
	}
	catch {
		Write-Error "Failed to create folder: $_"
	}
}

Write-Host "Copying EXE to Releases folder..."
Copy-Item -Path $outputFile -Destination $releasesDir -Force
Write-Host "File copied successfully." -ForegroundColor Cyan

# Result.
if (Test-Path $outputFile) {
	Write-Host "Success! EXE created at: $outputFile" -ForegroundColor Green
} else {
	Write-Error "Compilation failed."
}

Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")