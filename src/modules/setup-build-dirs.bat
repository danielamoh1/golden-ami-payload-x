@echo off

REM Ensure BUILD_LOG_DIR exists
if not exist "C:\Temp\BuildLogs" (
    mkdir "C:\Temp\BuildLogs"
)

REM Ensure INSTALLER_CACHE_DIR exists
if not exist "C:\Installers" (
    mkdir "C:\Installers"
)

echo Build directories are ready.
exit /b 0
