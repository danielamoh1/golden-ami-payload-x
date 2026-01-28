Set-StrictMode -Version Latest

function Get-RequiredEnvVar {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $value = [Environment]::GetEnvironmentVariable($Name, "Process")
    if ([string]::IsNullOrWhiteSpace($value)) {
        throw "Required environment variable '$Name' is not set."
    }

    return $value
}

function Get-OptionalEnvVar {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [string]$DefaultValue = $null
    )

    $value = [Environment]::GetEnvironmentVariable($Name, "Process")
    if ([string]::IsNullOrWhiteSpace($value)) {
        return $DefaultValue
    }

    return $value
}

function Initialize-ScriptContext {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ScriptName
    )

    $buildLogDir = Get-OptionalEnvVar -Name "BUILD_LOG_DIR"
    if (-not $buildLogDir) {
        $buildLogDir = Get-OptionalEnvVar -Name "LOCAL_BUILD_LOG_DIR"
    }
    if (-not $buildLogDir) {
        throw "BUILD_LOG_DIR environment variable is not set."
    }
    $scriptLogDir = Join-Path $buildLogDir $ScriptName

    New-Item -ItemType Directory -Path $scriptLogDir -Force | Out-Null

    return [pscustomobject]@{
        ScriptName     = $ScriptName
        LogDir         = $scriptLogDir
        LogFile        = (Join-Path $scriptLogDir "install.log")
        StatusFile     = (Join-Path $scriptLogDir "status")
        ValidationFile = (Join-Path $scriptLogDir "validation.json")
        RebootFile     = (Join-Path $scriptLogDir "reboot.required")
    }
}

function Write-Log {
    param (
        [Parameter(Mandatory = $true)]
        [object]$Context,

        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet("INFO", "WARN", "ERROR")]
        [string]$Level = "INFO"
    )

    $timestamp = (Get-Date).ToString("s")
    $line = "$timestamp [$Level] $Message"
    Add-Content -Path $Context.LogFile -Value $line

    switch ($Level) {
        "ERROR" { Write-Error $Message }
        "WARN" { Write-Warning $Message }
        Default { Write-Host $Message }
    }
}

function Write-Status {
    param (
        [Parameter(Mandatory = $true)]
        [object]$Context,

        [Parameter(Mandatory = $true)]
        [ValidateSet(0, 1)]
        [int]$StatusCode
    )

    Set-Content -Path $Context.StatusFile -Value $StatusCode
}

function Mark-RebootRequired {
    param (
        [Parameter(Mandatory = $true)]
        [object]$Context
    )

    Set-Content -Path $Context.RebootFile -Value "RebootRequired"
    Write-Log -Context $Context -Level "WARN" -Message "RebootRequired"
}

function Resolve-PathSafe {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $resolved = Resolve-Path -Path $Path -ErrorAction SilentlyContinue
    if (-not $resolved) {
        return $null
    }

    return ($resolved | Select-Object -First 1).Path
}

function Get-FileVersion {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        return ""
    }

    return (Get-Item $Path).VersionInfo.FileVersion
}

function Get-SentinelOneState {
    $serviceNames = @(
        "SentinelAgent",
        "SentinelStaticEngine",
        "SentinelHelperService"
    )

    $services = Get-Service -Name $serviceNames -ErrorAction SilentlyContinue
    if (-not $services) {
        return [pscustomobject]@{
            State   = "Restored"
            Details = "SentinelOne services not detected."
        }
    }

    if ($services | Where-Object { $_.Status -eq "Running" }) {
        return [pscustomobject]@{
            State   = "Detected"
            Details = "SentinelOne service running."
        }
    }

    return [pscustomobject]@{
        State   = "Suppressed"
        Details = "SentinelOne services installed but not running."
    }
}

function Test-IsAdministrator {
    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-SentinelOneState {
    try {
        $service = Get-Service -Name "SentinelAgent" -ErrorAction SilentlyContinue
        $process = Get-Process -Name "SentinelAgent" -ErrorAction SilentlyContinue

        if ($service -or $process) {
            return @{
                Present       = $true
                ServiceStatus = if ($service) { $service.Status } else { "Unknown" }
            }
        }

        return @{
            Present       = $false
            ServiceStatus = "NotInstalled"
        }
    }
    catch {
        return @{
            Present       = "Unknown"
            ServiceStatus = "Error"
        }
    }
}
