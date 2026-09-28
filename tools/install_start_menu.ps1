param(
    [string]$BuildDirectory = (Join-Path $PSScriptRoot '../build/warp-balance')
)
$ErrorActionPreference = 'Stop'
$spaceRacerRepo = Split-Path -Parent $PSScriptRoot
$spaceRacerExecutable = (Resolve-Path -LiteralPath (Join-Path $BuildDirectory 'SpaceRacer.exe')).Path
$spaceRacerIcon = (Resolve-Path -LiteralPath (Join-Path $spaceRacerRepo 'assets/icon.ico')).Path
$spaceRacerPrograms = [Environment]::GetFolderPath('Programs')
$spaceRacerShortcutPath = Join-Path $spaceRacerPrograms 'SpaceRacer (Latest Debug).lnk'
$spaceRacerShell = New-Object -ComObject WScript.Shell
$spaceRacerShortcut = $spaceRacerShell.CreateShortcut($spaceRacerShortcutPath)
$spaceRacerShortcut.TargetPath = Join-Path $env:WINDIR 'System32/WindowsPowerShell/v1.0/powershell.exe'
$spaceRacerShortcut.WorkingDirectory = Split-Path -Parent $spaceRacerExecutable
$spaceRacerLauncher = Join-Path $PSScriptRoot 'launch_debug.ps1'
$spaceRacerShortcut.Arguments = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "{0}" -BuildDirectory "{1}"' -f $spaceRacerLauncher,(Split-Path -Parent $spaceRacerExecutable)
$spaceRacerShortcut.IconLocation = "$spaceRacerIcon,0"
$spaceRacerShortcut.Description = 'Launch the latest local Windows debug build of SpaceRacer.'
$spaceRacerShortcut.Save()
Write-Output "Installed: $spaceRacerShortcutPath"
Write-Output "Build: $spaceRacerExecutable"
