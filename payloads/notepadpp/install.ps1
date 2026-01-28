Import-Module "$PSScriptRoot\..\..\src\modules\Common.psm1" -Force
Import-Module "$PSScriptRoot\..\..\src\modules\Logging.psm1" -Force
Import-Module "$PSScriptRoot\..\..\src\modules\Validation.psm1" -Force
Import-Module "$PSScriptRoot\..\..\src\modules\Install-Wrapper.psm1" -Force

Invoke-InstallWrapper `
    -ScriptName "NotepadPP-Install" `
    -ComponentName "Notepad++" `
    -InstallLogic {

        param ($Context)

        $installerUrl  = Get-RequiredEnvVar "NOTEPADPP_INSTALLER_URL"
        $exePath       = Get-RequiredEnvVar "NOTEPADPP_EXE_PATH"
        $cacheDir      = Get-RequiredEnvVar "INSTALLER_CACHE_DIR"
        $installerArgs = Get-RequiredEnvVar "NOTEPADPP_INSTALLER_ARGS"

        Write-Log -Context $Context -Message "CHECK: existing install"
        if (Test-Path $exePath) {
            $version = Get-FileVersion -Path $exePath
            $script:validationResult = New-ValidationResult `
                -Component "Notepad++" `
                -Result "Pass" `
                -Details "Already installed." `
                -Version $version
            return
        }

        New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
        $installerPath = Join-Path $cacheDir ([IO.Path]::GetFileName($installerUrl))

        if (-not (Test-Path $installerPath)) {
            Write-Log -Context $Context -Message "Downloading Notepad++ installer"
            Start-BitsTransfer -Source $installerUrl -Destination $installerPath
        }

        Write-Log -Context $Context -Message "Installing Notepad++"
        $args = $installerArgs.Replace("{INSTALLER_PATH}", "`"$installerPath`"")
        Start-Process -FilePath $installerPath -ArgumentList $args -Wait -NoNewWindow

        if (-not (Test-Path $exePath)) {
            throw "Notepad++ installation verification failed."
        }

        $version = Get-FileVersion -Path $exePath
        $script:validationResult = New-ValidationResult `
            -Component "Notepad++" `
            -Result "Pass" `
            -Details "Installed successfully." `
            -Version $version
    }
