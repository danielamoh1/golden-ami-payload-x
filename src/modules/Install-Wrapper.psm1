function Invoke-InstallWrapper {
    param (
        [Parameter(Mandatory)]
        [string]$ScriptName,

        [Parameter(Mandatory)]
        [string]$ComponentName,

        [Parameter(Mandatory)]
        [scriptblock]$InstallLogic
    )

    $Context = Initialize-ScriptContext -ScriptName $ScriptName

    $statusCode = 1
    $validationResult = $null
    $rebootRequired = $false

    try {
        Write-Log -Context $Context -Message "Starting $ScriptName"

        if (-not (Test-IsAdministrator)) {
            Write-Log -Context $Context -Level "ERROR" `
                -Message "Script must be run as Administrator in pipeline context."
            throw "Not running as Administrator."
        }

        # Capture returned ValidationResult
        $validationResult = & $InstallLogic $Context

        if (-not $validationResult) {
            $validationResult = New-ValidationResult `
                -Component $ComponentName `
                -Result "Pass" `
                -Details "Installed successfully."
        }

        $statusCode = 0
    }
    catch {
        $message = $_.Exception.Message
        Write-Log -Context $Context -Level "ERROR" -Message $message

        $validationResult = New-ValidationResult `
            -Component $ComponentName `
            -Result "Fail" `
            -Details $message

        $statusCode = 1
    }
    finally {

        # HARD GUARD — NO NULLS EVER
        if ($validationResult) {
            Write-ValidationResult -Context $Context -Result $validationResult
        }

        Write-Status -Context $Context -StatusCode $statusCode

        if ($rebootRequired) {
            Mark-RebootRequired -Context $Context
            exit 3010
        }

        exit $statusCode
    }
}
