$dirs = @(
  "C:\Temp\BuildLogs",
  "C:\Installers"
)

foreach ($d in $dirs) {
    if (-not (Test-Path $d)) {
        New-Item -ItemType Directory -Path $d -Force | Out-Null
    }
}
