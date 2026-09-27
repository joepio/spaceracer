param(
    [string]$BuildDirectory = (Join-Path $PSScriptRoot '../build/warp-balance')
)
$ErrorActionPreference = 'Stop'
$ionRepo = Split-Path -Parent $PSScriptRoot
$ionExecutable = (Resolve-Path -LiteralPath (Join-Path $BuildDirectory 'IonRush.exe')).Path
$ionIcon = (Resolve-Path -LiteralPath (Join-Path $ionRepo 'assets/icon.ico')).Path
$ionPrograms = [Environment]::GetFolderPath('Programs')
$ionShortcutPath = Join-Path $ionPrograms 'Ion Rush (Latest Debug).lnk'
$ionShell = New-Object -ComObject WScript.Shell
$ionShortcut = $ionShell.CreateShortcut($ionShortcutPath)
$ionShortcut.TargetPath = Join-Path $env:WINDIR 'System32/WindowsPowerShell/v1.0/powershell.exe'
$ionShortcut.WorkingDirectory = Split-Path -Parent $ionExecutable
$ionLauncher = Join-Path $PSScriptRoot 'launch_debug.ps1'
$ionShortcut.Arguments = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "{0}" -BuildDirectory "{1}"' -f $ionLauncher,(Split-Path -Parent $ionExecutable)
$ionShortcut.IconLocation = "$ionIcon,0"
$ionShortcut.Description = 'Launch the latest local Windows debug build of Ion Rush.'
$ionShortcut.Save()
Write-Output "Installed: $ionShortcutPath"
Write-Output "Build: $ionExecutable"
