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
$ionShortcut.TargetPath = $ionExecutable
$ionShortcut.WorkingDirectory = Split-Path -Parent $ionExecutable
$ionShortcut.Arguments = '--fullscreen'
$ionShortcut.IconLocation = "$ionIcon,0"
$ionShortcut.Description = 'Launch the latest local Windows debug build of Ion Rush.'
$ionShortcut.Save()
Write-Output "Installed: $ionShortcutPath"
Write-Output "Build: $ionExecutable"
