Import-Module "$PSScriptRoot\..\..\src\modules\Common.psm1" -Force
Import-Module "$PSScriptRoot\..\..\src\modules\Logging.psm1" -Force
Import-Module "$PSScriptRoot\..\..\src\modules\Validation.psm1" -Force
Import-Module "$PSScriptRoot\..\..\src\modules\Install-Wrapper.psm1" -Force

Invoke-InstallWrapper `
    -ScriptName "AmazonCorretto8-Install" `
    -ComponentName "Amazon Corretto 8" `
    -InstallLogic {

        param ($Context)

        $installerUrl  = Get-RequiredEnvVar "CORRETTO8_INSTALLER_URL"
        $javaExePath   = Get-RequiredEnvVar "CORRETTO8_JAVA_EXE_PATH"
        $cacheDir      = Get-RequiredEnvVar "INSTALLER_CACHE_DIR"
        $installerArgs = Get-RequiredEnvVar "CORRETTO8_INSTALLER_ARGS"

        Write-Log -Context $Context -Message "CHECK: existing install"
        if (Test-Path $javaExePath) {
            $version = Get-FileVersion -Path $javaExePath
            $script:validationResult = New-ValidationResult `
                -Component "Amazon Corretto 8" `
                -Result "Pass" `
                -Details "Already installed." `
                -Version $version
            return
        }

        New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
        $installerPath = Join-Path $cacheDir ([IO.Path]::GetFileName($installerUrl))

        if (-not (Test-Path $installerPath)) {
            Write-Log -Context $Context -Message "Downloading Corretto MSI"
            Start-BitsTransfer -Source $installerUrl -Destination $installerPath
        }

        Write-Log -Context $Context -Message "Installing Corretto"
        $args = $installerArgs.Replace("{INSTALLER_PATH}", "`"$installerPath`"")
        Start-Process msiexec.exe -ArgumentList $args -Wait -NoNewWindow

        if (-not (Test-Path $javaExePath)) {
            throw "Corretto installation verification failed."
        }

        $version = Get-FileVersion -Path $javaExePath
        $script:validationResult = New-ValidationResult `
            -Component "Amazon Corretto 8" `
            -Result "Pass" `
            -Details "Installed successfully." `
            -Version $version
    }
