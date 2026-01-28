Set-StrictMode -Version Latest

function New-ValidationResult {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Component,

        [Parameter(Mandatory = $true)]
        [ValidateSet("Pass", "Fail", "NotApplicable")]
        [string]$Result,

        [string]$Details = "",
        [string]$Version = ""
    )

    $sentinelState = Get-SentinelOneState

    $manifest = [pscustomobject]@{
        BuildTimestamp    = (Get-Date).ToString("s")
        BuildLogDir       = $logRoot
        SentinelOne       = $sentinelState
        Scripts           = $scriptResults
        RebootOccurrences = $rebootOccurrences
    }

}

function Write-ValidationResult {
    param (
        [Parameter(Mandatory = $true)]
        [object]$Context,

        [Parameter(Mandatory = $true)]
        [object]$Result
    )

    $Result | ConvertTo-Json -Depth 6 | Set-Content -Path $Context.ValidationFile
}

function Read-ValidationResult {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ValidationPath
    )

    if (-not (Test-Path $ValidationPath)) {
        return $null
    }

    try {
        return (Get-Content $ValidationPath -Raw) | ConvertFrom-Json
    }
    catch {
        return $null
    }
}
