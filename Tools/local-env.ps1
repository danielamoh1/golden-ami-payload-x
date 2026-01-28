$ENV:BUILD_LOG_DIR="C:\Temp\BuildLogs"
$ENV:INSTALLER_CACHE_DIR="C:\Installers"

New-Item -ItemType Directory -Force -Path $ENV:BUILD_LOG_DIR | Out-Null
New-Item -ItemType Directory -Force -Path $ENV:INSTALLER_CACHE_DIR | Out-Null
