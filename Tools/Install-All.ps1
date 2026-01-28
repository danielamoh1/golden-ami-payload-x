param (
    [string]$BuildLogDir = "C:\Temp\BuildLogs",
    [string]$InstallerCacheDir = "C:\Temp\Installers",
    [switch]$PersistEnv
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Set-EnvVar {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [string]$Value,
        [string]$Scope = "Process"
    )

    [Environment]::SetEnvironmentVariable($Name, $Value, $Scope)
}

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

function Write-InstallLog {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    $timestamp = (Get-Date).ToString("s")
    $line = "$timestamp $Message"
    Add-Content -Path $script:InstallLogFile -Value $line
    Write-Host $Message
}

$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Run this script in an elevated PowerShell session (Administrator)."
    exit 1
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")

Set-EnvVar -Name "BUILD_LOG_DIR" -Value $BuildLogDir -Scope "Process"
Set-EnvVar -Name "INSTALLER_CACHE_DIR" -Value $InstallerCacheDir -Scope "Process"
Set-EnvVar -Name "PAYLOAD_TEST_MODE" -Value "0" -Scope "Process"

if ($PersistEnv) {
    Set-EnvVar -Name "BUILD_LOG_DIR" -Value $BuildLogDir -Scope "Machine"
    Set-EnvVar -Name "INSTALLER_CACHE_DIR" -Value $InstallerCacheDir -Scope "Machine"
    Set-EnvVar -Name "PAYLOAD_TEST_MODE" -Value "0" -Scope "Machine"
}

New-Item -ItemType Directory -Path $env:BUILD_LOG_DIR -Force | Out-Null
New-Item -ItemType Directory -Path $env:INSTALLER_CACHE_DIR -Force | Out-Null

$script:InstallLogFile = Join-Path $env:BUILD_LOG_DIR "install-all.log"

Set-DefaultEnvVar -Name "SEVENZIP_INSTALLER_URL" -Value "https://www.7-zip.org/a/7z1900-x64.msi"
Set-DefaultEnvVar -Name "SEVENZIP_EXE_PATH" -Value "C:\Program Files\7-Zip\7z.exe"
Set-DefaultEnvVar -Name "SEVENZIP_INSTALLER_ARGS" -Value "/i {INSTALLER_PATH} /qn /norestart"

Set-DefaultEnvVar -Name "CORRETTO8_INSTALLER_URL" -Value "https://corretto.aws/downloads/latest/amazon-corretto-8-x64-windows-jdk.msi"
Set-DefaultEnvVar -Name "CORRETTO8_JAVA_EXE_PATH" -Value "C:\Program Files\Amazon Corretto\jdk8*\bin\java.exe"
Set-DefaultEnvVar -Name "CORRETTO8_INSTALLER_ARGS" -Value "/i {INSTALLER_PATH} /qn /norestart"

Set-DefaultEnvVar -Name "DBVISUALIZER_INSTALLER_URL" -Value "https://www.dbvis.com/product_download/dbvis-25.3.1/media/dbvis_windows-x64_25_3_1_jre.exe"
Set-DefaultEnvVar -Name "DBVISUALIZER_INSTALL_DIR" -Value "C:\Program Files\DbVisualizer"
Set-DefaultEnvVar -Name "DBVISUALIZER_EXE_PATH" -Value "C:\Program Files\DbVisualizer\dbvis.exe"
Set-DefaultEnvVar -Name "DBVISUALIZER_INSTALLER_ARGS" -Value "/c {INSTALLER_PATH} -q -dir {INSTALL_DIR}"

Set-DefaultEnvVar -Name "NOTEPADPP_INSTALLER_URL" -Value "https://github.com/notepad-plus-plus/notepad-plus-plus/releases/latest/download/npp.x64.Installer.exe"
Set-DefaultEnvVar -Name "NOTEPADPP_EXE_PATH" -Value "C:\Program Files\Notepad++\notepad++.exe"
Set-DefaultEnvVar -Name "NOTEPADPP_INSTALLER_ARGS" -Value "/S"

Set-DefaultEnvVar -Name "SLIKSVN_INSTALLER_URL" -Value "https://sliksvn.com/pub/Slik-Subversion-1.14.2-x64.msi"
Set-DefaultEnvVar -Name "SLIKSVN_EXE_PATH" -Value "C:\Program Files\SlikSvn\bin\svn.exe"
Set-DefaultEnvVar -Name "SLIKSVN_INSTALLER_ARGS" -Value "/i {INSTALLER_PATH} /qn /norestart"

if ($PersistEnv) {
    $machineVars = @(
        "SEVENZIP_INSTALLER_URL",
        "SEVENZIP_EXE_PATH",
        "SEVENZIP_INSTALLER_ARGS",
        "CORRETTO8_INSTALLER_URL",
        "CORRETTO8_JAVA_EXE_PATH",
        "CORRETTO8_INSTALLER_ARGS",
        "DBVISUALIZER_INSTALLER_URL",
        "DBVISUALIZER_INSTALL_DIR",
        "DBVISUALIZER_EXE_PATH",
        "DBVISUALIZER_INSTALLER_ARGS",
        "NOTEPADPP_INSTALLER_URL",
        "NOTEPADPP_EXE_PATH",
        "NOTEPADPP_INSTALLER_ARGS",
        "SLIKSVN_INSTALLER_URL",
        "SLIKSVN_EXE_PATH",
        "SLIKSVN_INSTALLER_ARGS"
    )

    foreach ($name in $machineVars) {
        $value = [Environment]::GetEnvironmentVariable($name, "Process")
        Set-EnvVar -Name $name -Value $value -Scope "Machine"
    }
}

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
    $validationFile = Join-Path $scriptLogDir "validation.json"

    Write-InstallLog "Running $scriptName"
    & $scriptPath
    $exitCode = $LASTEXITCODE

    if (($exitCode -ne 0) -and ($exitCode -ne 3010)) {
        $failures += "${scriptName}: exit code $exitCode"
    }

    if (-not (Test-Path $statusFile)) {
        $failures += "${scriptName}: missing status file"
    }

    if (Test-Path $validationFile) {
        try {
            $validation = (Get-Content $validationFile -Raw) | ConvertFrom-Json
            Write-InstallLog "$scriptName validation: $($validation.Result)"
        }
        catch {
            $failures += "${scriptName}: invalid validation file"
        }
    }
    else {
        $failures += "${scriptName}: missing validation file"
    }
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-InstallLog "ERROR: $_" }
    exit 1
}

Write-InstallLog "Install-all completed successfully."
exit 0
