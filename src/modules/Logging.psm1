function Write-Log {
    param (
        [Parameter(Mandatory)]
        [pscustomobject]$Context,

        [ValidateSet("INFO","WARN","ERROR")]
        [string]$Level = "INFO",

        [Parameter(Mandatory)]
        [string]$Message
    )

    $entry = @{
        Timestamp = (Get-Date).ToString("s")
        Level     = $Level
        Script    = $Context.ScriptName
        Message   = $Message
    }

    $json = $entry | ConvertTo-Json -Compress

    # Write to log file
    Add-Content -Path $Context.LogFile -Value $json

    # Also emit to stdout for Packer
    #Write-Output $json
}
