param(
    [string]$BuildDirectory = (Join-Path $PSScriptRoot '../build/warp-balance'),
    [switch]$PrepareOnly,
    [switch]$Managed
)
$ErrorActionPreference = 'Stop'
$spaceRacerRepo = Split-Path -Parent $PSScriptRoot
$spaceRacerExecutable = (Resolve-Path -LiteralPath (Join-Path $BuildDirectory 'SpaceRacer.exe')).Path
$spaceRacerPack = (Resolve-Path -LiteralPath (Join-Path $BuildDirectory 'SpaceRacer.pck')).Path
$spaceRacerSessions = Join-Path $BuildDirectory 'debug-sessions'
[void](New-Item -ItemType Directory -Force -Path $spaceRacerSessions)
# Each process reads an immutable copy. Updating the exported PCK in place while
# Godot is running corrupts later lazy resource reads using its old file offsets.
function Get-SpaceRacerDigest([string]$Path) {
    $spaceRacerHasher = [System.Security.Cryptography.SHA256]::Create()
    $spaceRacerStream = [System.IO.File]::OpenRead($Path)
    try { return [System.BitConverter]::ToString($spaceRacerHasher.ComputeHash($spaceRacerStream)).Replace('-','').ToLowerInvariant() }
    finally { $spaceRacerStream.Dispose(); $spaceRacerHasher.Dispose() }
}
$spaceRacerDigest = Get-SpaceRacerDigest $spaceRacerPack
$spaceRacerSnapshot = Join-Path $spaceRacerSessions "$spaceRacerDigest.pck"
if (-not (Test-Path -LiteralPath $spaceRacerSnapshot)) {
    $spaceRacerTemporary = Join-Path $spaceRacerSessions ([Guid]::NewGuid().ToString() + '.tmp')
    Copy-Item -LiteralPath $spaceRacerPack -Destination $spaceRacerTemporary
    if ((Get-SpaceRacerDigest $spaceRacerTemporary) -ne $spaceRacerDigest) {
        Remove-Item -LiteralPath $spaceRacerTemporary
        throw 'The debug build changed while preparing launch. Please start it again.'
    }
    if (Test-Path -LiteralPath $spaceRacerSnapshot) { Remove-Item -LiteralPath $spaceRacerTemporary }
    else { Move-Item -LiteralPath $spaceRacerTemporary -Destination $spaceRacerSnapshot }
}
if ($PrepareOnly) { Write-Output $spaceRacerSnapshot; return }
if ($Managed) {
    # Stay alive for the host's process/job lifetime and inherit its session env.
    $spaceRacerChild = Start-Process -FilePath $spaceRacerExecutable -WorkingDirectory (Split-Path -Parent $spaceRacerExecutable) -ArgumentList '--main-pack',('"{0}"' -f $spaceRacerSnapshot),'--position','-20000,-20000' -WindowStyle Hidden -PassThru -Wait
    exit $spaceRacerChild.ExitCode
}
Start-Process -WindowStyle Hidden -FilePath $spaceRacerExecutable -WorkingDirectory (Split-Path -Parent $spaceRacerExecutable) -ArgumentList '--main-pack',('"{0}"' -f $spaceRacerSnapshot),'--fullscreen'
