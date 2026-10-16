param(
    [string]$BuildDirectory = (Join-Path $PSScriptRoot '../build/warp-balance'),
    [switch]$PrepareOnly,
    [switch]$Managed,
    [switch]$Headless
)
$ErrorActionPreference = 'Stop'
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
function Copy-SpaceRacerSnapshot([string]$Source, [string]$Destination, [string]$Digest) {
    if (Test-Path -LiteralPath $Destination) { return }
    $spaceRacerTemporary = Join-Path (Split-Path -Parent $Destination) ([Guid]::NewGuid().ToString() + '.tmp')
    Copy-Item -LiteralPath $Source -Destination $spaceRacerTemporary
    if ((Get-SpaceRacerDigest $spaceRacerTemporary) -ne $Digest) {
        Remove-Item -LiteralPath $spaceRacerTemporary
        throw 'The debug build changed while preparing launch. Please start it again.'
    }
    if (Test-Path -LiteralPath $Destination) { Remove-Item -LiteralPath $spaceRacerTemporary }
    else { Move-Item -LiteralPath $spaceRacerTemporary -Destination $Destination }
}
$spaceRacerDigest = Get-SpaceRacerDigest $spaceRacerPack
$spaceRacerExecutableDigest = Get-SpaceRacerDigest $spaceRacerExecutable
# Export templates can disable --main-pack. Keep the executable and its normal
# sibling pack together; hash both so an engine update cannot reuse an old EXE.
$spaceRacerSnapshotDirectory = Join-Path $spaceRacerSessions ($spaceRacerExecutableDigest.Substring(0,12) + '-' + $spaceRacerDigest)
[void](New-Item -ItemType Directory -Force -Path $spaceRacerSnapshotDirectory)
$spaceRacerSnapshot = Join-Path $spaceRacerSnapshotDirectory 'SpaceRacer.pck'
$spaceRacerSnapshotExecutable = Join-Path $spaceRacerSnapshotDirectory 'SpaceRacer.exe'
Copy-SpaceRacerSnapshot $spaceRacerExecutable $spaceRacerSnapshotExecutable $spaceRacerExecutableDigest
Copy-SpaceRacerSnapshot $spaceRacerPack $spaceRacerSnapshot $spaceRacerDigest
if ($PrepareOnly) { Write-Output $spaceRacerSnapshot; return }
$spaceRacerArguments = @('--position','-20000,-20000')
if ($Headless) { $spaceRacerArguments += '--headless' }
if ($Managed) {
    # Stay alive for the host's process/job lifetime and inherit its session env.
    $spaceRacerChild = Start-Process -FilePath $spaceRacerSnapshotExecutable -WorkingDirectory $spaceRacerSnapshotDirectory -ArgumentList $spaceRacerArguments -WindowStyle Hidden -PassThru -Wait
    exit $spaceRacerChild.ExitCode
}
if (-not $Headless) { $spaceRacerArguments = @('--fullscreen') }
Start-Process -WindowStyle Hidden -FilePath $spaceRacerSnapshotExecutable -WorkingDirectory $spaceRacerSnapshotDirectory -ArgumentList $spaceRacerArguments
