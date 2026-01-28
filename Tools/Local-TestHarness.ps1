Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

param (
    [switch]$Install,
    [string]$BuildLogDir = "C:\Temp\BuildLogs",
    [string]$InstallerCacheDir = "C:\Temp\Installers"
)

function Set-DefaultEnvVar {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    if (-not [Environment]::GetEnvironmentVariable($Name, "Process")) {
        [Environment]::SetEnvironmentVariable($Name, $Value, "Process")
    }
}

function Set-EnvVar {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    [Environment]::SetEnvironmentVariable($Name, $Value, "Process")
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")

Set-DefaultEnvVar -Name "BUILD_LOG_DIR" -Value $BuildLogDir
Set-DefaultEnvVar -Name "INSTALLER_CACHE_DIR" -Value $InstallerCacheDir

if ($Install) {
    Set-EnvVar -Name "PAYLOAD_TEST_MODE" -Value "0"
}
else {
    Set-DefaultEnvVar -Name "PAYLOAD_TEST_MODE" -Value "1"
}

New-Item -ItemType Directory -Path $env:BUILD_LOG_DIR -Force | Out-Null
New-Item -ItemType Directory -Path $env:INSTALLER_CACHE_DIR -Force | Out-Null

Set-DefaultEnvVar -Name "SEVENZIP_INSTALLER_URL" -Value "https://www.7-zip.org/a/7z1900-x64.msi"
Set-DefaultEnvVar -Name "SEVENZIP_EXE_PATH" -Value "C:\Program Files\7-Zip\7z.exe"
Set-DefaultEnvVar -Name "SEVENZIP_INSTALLER_ARGS" -Value "/i `{INSTALLER_PATH} /qn /norestart"

Set-DefaultEnvVar -Name "CORRETTO8_INSTALLER_URL" -Value "https://corretto.aws/downloads/latest/amazon-corretto-8-x64-windows-jdk.msi"
Set-DefaultEnvVar -Name "CORRETTO8_JAVA_EXE_PATH" -Value "C:\Program Files\Amazon Corretto\jdk8*\bin\java.exe"
Set-DefaultEnvVar -Name "CORRETTO8_INSTALLER_ARGS" -Value "/i `{INSTALLER_PATH} /qn /norestart"

Set-DefaultEnvVar -Name "DBVISUALIZER_INSTALLER_URL" -Value "https://www.dbvis.com/product_download/dbvis-25.3.1/media/dbvis_windows-x64_25_3_1_jre.exe"
Set-DefaultEnvVar -Name "DBVISUALIZER_INSTALL_DIR" -Value "C:\Program Files\DbVisualizer"
Set-DefaultEnvVar -Name "DBVISUALIZER_EXE_PATH" -Value "C:\Program Files\DbVisualizer\dbvis.exe"
Set-DefaultEnvVar -Name "DBVISUALIZER_INSTALLER_ARGS" -Value "/c {INSTALLER_PATH} -q -dir {INSTALL_DIR}"

Set-DefaultEnvVar -Name "NOTEPADPP_INSTALLER_URL" -Value "https://github.com/notepad-plus-plus/notepad-plus-plus/releases/latest/download/npp.x64.Installer.exe"
Set-DefaultEnvVar -Name "NOTEPADPP_EXE_PATH" -Value "C:\Program Files\Notepad++\notepad++.exe"
Set-DefaultEnvVar -Name "NOTEPADPP_INSTALLER_ARGS" -Value "/S"

Set-DefaultEnvVar -Name "SLIKSVN_INSTALLER_URL" -Value "https://sliksvn.com/pub/Slik-Subversion-1.14.2-x64.msi"
Set-DefaultEnvVar -Name "SLIKSVN_EXE_PATH" -Value "C:\Program Files\SlikSvn\bin\svn.exe"
Set-DefaultEnvVar -Name "SLIKSVN_INSTALLER_ARGS" -Value "/i `{INSTALLER_PATH} /qn /norestart"

$scriptList = @(
    "Scripts\7Zip-Install.ps1",
    "Scripts\AmazonCorretto8-Install.ps1",
    "Scripts\DbVisualizer-Install.ps1",
    "Scripts\NotepadPP-Install.ps1",
    "Scripts\SlikSubversion-Install.ps1",
    "Scripts\Final-Validation.ps1"
)

$failures = @()

foreach ($relativePath in $scriptList) {
    $scriptPath = Join-Path $repoRoot $relativePath
    $scriptName = [IO.Path]::GetFileNameWithoutExtension($scriptPath)
    $scriptLogDir = Join-Path $env:BUILD_LOG_DIR $scriptName
    $statusFile = Join-Path $scriptLogDir "status"
    $logFile = Join-Path $scriptLogDir "install.log"
    $validationFile = Join-Path $scriptLogDir "validation.json"

    Write-Host "Running $scriptName (pass 1)"
    & $scriptPath
    $exitCode = $LASTEXITCODE

    if (($exitCode -ne 0) -and ($exitCode -ne 3010)) {
        $failures += "${scriptName}: exit code $exitCode"
    }

    if (-not (Test-Path $statusFile)) {
        $failures += "${scriptName}: missing status file"
    }

    if (-not (Test-Path $logFile)) {
        $failures += "${scriptName}: missing log file"
    }

    if (-not (Test-Path $validationFile)) {
        $failures += "${scriptName}: missing validation file"
    }

    Write-Host "Running $scriptName (pass 2)"
    & $scriptPath
    $exitCode = $LASTEXITCODE

    if (($exitCode -ne 0) -and ($exitCode -ne 3010)) {
        $failures += "${scriptName}: exit code $exitCode on second run"
    }
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Host "Local test harness completed successfully."
exit 0
