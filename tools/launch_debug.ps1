param(
    [string]$BuildDirectory = (Join-Path $PSScriptRoot '../build/warp-balance'),
    [switch]$PrepareOnly,
    [switch]$Managed
)
$ErrorActionPreference = 'Stop'
$ionRepo = Split-Path -Parent $PSScriptRoot
$ionExecutable = (Resolve-Path -LiteralPath (Join-Path $BuildDirectory 'IonRush.exe')).Path
$ionPack = (Resolve-Path -LiteralPath (Join-Path $BuildDirectory 'IonRush.pck')).Path
$ionSessions = Join-Path $ionRepo 'build/debug-sessions'
[void](New-Item -ItemType Directory -Force -Path $ionSessions)
# Each process reads an immutable copy. Updating the exported PCK in place while
# Godot is running corrupts later lazy resource reads using its old file offsets.
function Get-IonDigest([string]$Path) {
    $ionHasher = [System.Security.Cryptography.SHA256]::Create()
    $ionStream = [System.IO.File]::OpenRead($Path)
    try { return [System.BitConverter]::ToString($ionHasher.ComputeHash($ionStream)).Replace('-','').ToLowerInvariant() }
    finally { $ionStream.Dispose(); $ionHasher.Dispose() }
}
$ionDigest = Get-IonDigest $ionPack
$ionSnapshot = Join-Path $ionSessions "$ionDigest.pck"
if (-not (Test-Path -LiteralPath $ionSnapshot)) {
    $ionTemporary = Join-Path $ionSessions ([Guid]::NewGuid().ToString() + '.tmp')
    Copy-Item -LiteralPath $ionPack -Destination $ionTemporary
    if ((Get-IonDigest $ionTemporary) -ne $ionDigest) {
        Remove-Item -LiteralPath $ionTemporary
        throw 'The debug build changed while preparing launch. Please start it again.'
    }
    if (Test-Path -LiteralPath $ionSnapshot) { Remove-Item -LiteralPath $ionTemporary }
    else { Move-Item -LiteralPath $ionTemporary -Destination $ionSnapshot }
}
if ($PrepareOnly) { Write-Output $ionSnapshot; return }
if ($Managed) {
    # Stay alive for the host's process/job lifetime and inherit its session env.
    $ionChild = Start-Process -FilePath $ionExecutable -WorkingDirectory (Split-Path -Parent $ionExecutable) -ArgumentList '--main-pack',('"{0}"' -f $ionSnapshot),'--position','-20000,-20000' -WindowStyle Hidden -PassThru -Wait
    exit $ionChild.ExitCode
}
Start-Process -WindowStyle Hidden -FilePath $ionExecutable -WorkingDirectory (Split-Path -Parent $ionExecutable) -ArgumentList '--main-pack',('"{0}"' -f $ionSnapshot),'--fullscreen'
