Import-Module "$PSScriptRoot\..\..\src\modules\Common.psm1" -Force
Import-Module "$PSScriptRoot\..\..\src\modules\Logging.psm1" -Force
Import-Module "$PSScriptRoot\..\..\src\modules\Validation.psm1" -Force
Import-Module "$PSScriptRoot\..\..\src\modules\Install-Wrapper.psm1" -Force

Invoke-InstallWrapper `
    -ScriptName "7Zip-Install" `
    -ComponentName "7-Zip" `
    -InstallLogic {
        param ($Context)

        $installerUrl = Get-RequiredEnvVar "SEVENZIP_INSTALLER_URL"
        $exePath      = Get-RequiredEnvVar "SEVENZIP_EXE_PATH"
        $cacheDir     = Get-RequiredEnvVar "INSTALLER_CACHE_DIR"
        $argsTemplate = Get-RequiredEnvVar "SEVENZIP_INSTALLER_ARGS"

        Write-Log -Context $Context -Message "CHECK: existing install"
        if (Test-Path $exePath) {
            $version = Get-FileVersion -Path $exePath
            Write-Log -Context $Context -Message "7-Zip already installed"

            return New-ValidationResult `
                -Component "7-Zip" `
                -Result "Pass" `
                -Details "Already installed." `
                -Version $version
        }

        New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null

        $installerPath = Join-Path $cacheDir ([IO.Path]::GetFileName($installerUrl))
        if (-not (Test-Path $installerPath)) {
            Write-Log -Context $Context -Message "Downloading installer"
            Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath
        }

        $args = $argsTemplate.Replace("{INSTALLER_PATH}", "`"$installerPath`"")
        Write-Log -Context $Context -Message "Installing 7-Zip"
        Start-Process msiexec.exe -ArgumentList $args -Wait -NoNewWindow

        if (-not (Test-Path $exePath)) {
            throw "7-Zip installation verification failed."
        }

        $version = Get-FileVersion -Path $exePath
        return New-ValidationResult `
            -Component "7-Zip" `
            -Result "Pass" `
            -Details "Installed successfully." `
            -Version $version
    }
