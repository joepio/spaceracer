param(
    [string]$BuildDirectory = (Join-Path $PSScriptRoot '../build/warp-balance'),
    [switch]$PrepareOnly
)
$ErrorActionPreference = 'Stop'
$ionRepo = Split-Path -Parent $PSScriptRoot
$ionExecutable = (Resolve-Path -LiteralPath (Join-Path $BuildDirectory 'IonRush.exe')).Path
$ionPack = (Resolve-Path -LiteralPath (Join-Path $BuildDirectory 'IonRush.pck')).Path
$ionSessions = Join-Path $ionRepo 'build/debug-sessions'
[void](New-Item -ItemType Directory -Force -Path $ionSessions)
# Each process reads an immutable copy. Updating the exported PCK in place while
# Godot is running corrupts later lazy resource reads using its old file offsets.
$ionDigest = (Get-FileHash -LiteralPath $ionPack -Algorithm SHA256).Hash.ToLowerInvariant()
$ionSnapshot = Join-Path $ionSessions "$ionDigest.pck"
if (-not (Test-Path -LiteralPath $ionSnapshot)) {
    $ionTemporary = Join-Path $ionSessions ([Guid]::NewGuid().ToString() + '.tmp')
    Copy-Item -LiteralPath $ionPack -Destination $ionTemporary
    if ((Get-FileHash -LiteralPath $ionTemporary -Algorithm SHA256).Hash.ToLowerInvariant() -ne $ionDigest) {
        Remove-Item -LiteralPath $ionTemporary
        throw 'The debug build changed while preparing launch. Please start it again.'
    }
    if (Test-Path -LiteralPath $ionSnapshot) { Remove-Item -LiteralPath $ionTemporary }
    else { Move-Item -LiteralPath $ionTemporary -Destination $ionSnapshot }
}
if ($PrepareOnly) { Write-Output $ionSnapshot; return }
Start-Process -FilePath $ionExecutable -WorkingDirectory (Split-Path -Parent $ionExecutable) -ArgumentList '--main-pack',('"{0}"' -f $ionSnapshot),'--fullscreen'
