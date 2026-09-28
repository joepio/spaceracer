param(
    [string]$DataDirectory = (Join-Path $env:LOCALAPPDATA 'GameNight'),
    [string]$BuildDirectory = (Join-Path $PSScriptRoot '../build/warp-balance')
)
$ErrorActionPreference = 'Stop'
$spaceRacerRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$spaceRacerLauncher = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot 'launch_debug.ps1')).Path
[void](New-Item -ItemType Directory -Force -Path $DataDirectory)
$spaceRacerArt = Join-Path $DataDirectory 'spaceracer-local'
[void](New-Item -ItemType Directory -Force -Path $spaceRacerArt)
Copy-Item -LiteralPath (Join-Path $spaceRacerRoot 'assets/gamenight/icon.png') -Destination (Join-Path $spaceRacerArt 'icon.png')
Copy-Item -LiteralPath (Join-Path $spaceRacerRoot 'assets/gamenight/cover.png') -Destination (Join-Path $spaceRacerArt 'cover.png')
$spaceRacerLocalFile = Join-Path $DataDirectory 'local-games.json'
$spaceRacerEntries = @()
if (Test-Path -LiteralPath $spaceRacerLocalFile) {
    $spaceRacerEntries = @(Get-Content -LiteralPath $spaceRacerLocalFile -Raw | ConvertFrom-Json | Where-Object { $_.id -ne 'spaceracer' })
}
$spaceRacerEntries += [ordered]@{
    id = 'spaceracer'; title = 'SpaceRacer (Local)'; tagline = 'Latest debug build - high-speed racing across three worlds'
    cover = 'spaceracer-local/cover.png'; screenshot = 'spaceracer-local/cover.png'; icon = 'spaceracer-local/icon.png'
    color = '#53ffe0'; emoji = '🚀'; players = '1-4 players'; min_players = 1; max_players = 4; best_players = 2
    launch = @{
        command = (Join-Path $env:SystemRoot 'System32/WindowsPowerShell/v1.0/powershell.exe')
        args = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$spaceRacerLauncher,'-BuildDirectory',(Resolve-Path -LiteralPath $BuildDirectory).Path,'-Managed')
        cwd = $spaceRacerRoot
    }
}
$spaceRacerJson = ConvertTo-Json -InputObject @($spaceRacerEntries) -Depth 12
[System.IO.File]::WriteAllText($spaceRacerLocalFile,$spaceRacerJson,(New-Object System.Text.UTF8Encoding $false))
Write-Output "Registered latest local SpaceRacer in $spaceRacerLocalFile"
