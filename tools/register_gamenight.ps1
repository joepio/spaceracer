param([string]$DataDirectory = (Join-Path $env:LOCALAPPDATA 'GameNight'))
$ErrorActionPreference = 'Stop'
$ionRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$ionLauncher = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot 'launch_debug.ps1')).Path
[void](New-Item -ItemType Directory -Force -Path $DataDirectory)
$ionArt = Join-Path $DataDirectory 'ion-rush-local'
[void](New-Item -ItemType Directory -Force -Path $ionArt)
Copy-Item -LiteralPath (Join-Path $ionRoot 'assets/gamenight/icon.png') -Destination (Join-Path $ionArt 'icon.png')
Copy-Item -LiteralPath (Join-Path $ionRoot 'assets/gamenight/cover.png') -Destination (Join-Path $ionArt 'cover.png')
$ionLocalFile = Join-Path $DataDirectory 'local-games.json'
$ionEntries = @()
if (Test-Path -LiteralPath $ionLocalFile) {
    $ionEntries = @(Get-Content -LiteralPath $ionLocalFile -Raw | ConvertFrom-Json | Where-Object { $_.id -ne 'ion-rush' })
}
$ionEntries += [ordered]@{
    id = 'ion-rush'; title = 'Ion Rush (Local)'; tagline = 'Latest debug build - high-speed racing across three worlds'
    cover = 'ion-rush-local/cover.png'; screenshot = 'ion-rush-local/cover.png'; icon = 'ion-rush-local/icon.png'
    color = '#53ffe0'; emoji = '🚀'; players = '1-4 players'; min_players = 1; max_players = 4; best_players = 2
    launch = @{
        command = (Join-Path $env:SystemRoot 'System32/WindowsPowerShell/v1.0/powershell.exe')
        args = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$ionLauncher,'-Managed')
        cwd = $ionRoot
    }
}
$ionJson = ConvertTo-Json -InputObject @($ionEntries) -Depth 12
[System.IO.File]::WriteAllText($ionLocalFile,$ionJson,(New-Object System.Text.UTF8Encoding $false))
Write-Output "Registered latest local Ion Rush in $ionLocalFile"
