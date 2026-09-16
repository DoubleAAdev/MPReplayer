# Installs MP Replayer into Balatro's Mods folder and verifies every file.
# Run from anywhere: ./scripts/install.ps1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$target = Join-Path $env:APPDATA 'Balatro\Mods\MPReplayer'
. (Join-Path $PSScriptRoot 'release-files.ps1')
$files = $ReplayerReleaseFiles

# Preserve previous installations outside Mods so only the renamed mod loads.
$saveRoot = [IO.Path]::GetFullPath((Join-Path $env:APPDATA 'Balatro'))
$modsRoot = Join-Path $saveRoot 'Mods'
$backupRoot = Join-Path $saveRoot ('mp_replayer/install-backups/' + [guid]::NewGuid().ToString('N'))
foreach ($folder in @('MPReplayer', 'BalatroReplayer')) {
    $previous = [IO.Path]::GetFullPath((Join-Path $modsRoot $folder))
    if ([IO.Path]::GetDirectoryName($previous) -ne $modsRoot) { throw 'Invalid mod migration path' }
    if (Test-Path -LiteralPath $previous) {
        New-Item -ItemType Directory -Force $backupRoot | Out-Null
        Move-Item -LiteralPath $previous -Destination (Join-Path $backupRoot $folder)
    }
}
# Old diagnostics are preserved; future sessions write to mp_replayer.
$legacyData = Join-Path $saveRoot 'balatro_replayer'
$currentData = Join-Path $saveRoot 'mp_replayer'
if (Test-Path -LiteralPath $legacyData) {
    New-Item -ItemType Directory -Force $currentData | Out-Null
    foreach ($name in @('actions.txt', 'status.json')) {
        $oldFile = Join-Path $legacyData $name
        $newFile = Join-Path $currentData $name
        if ((Test-Path -LiteralPath $oldFile) -and !(Test-Path -LiteralPath $newFile)) {
            Copy-Item -LiteralPath $oldFile -Destination $newFile
        }
    }
}
foreach ($file in $files) {
    $source = Join-Path $root $file
    $destination = Join-Path $target $file
    New-Item -ItemType Directory -Force (Split-Path -Parent $destination) | Out-Null
    Copy-Item $source $destination
    if ((Get-FileHash $source -Algorithm SHA256).Hash -ne (Get-FileHash $destination -Algorithm SHA256).Hash) { throw "Copy mismatch: $file" }
}
$version = (Get-Content (Join-Path $root 'MPReplayer.json') -Raw | ConvertFrom-Json).version
"Installed MP Replayer v$version to $target - all $($files.Count) files verified by SHA-256."
'Restart Balatro to load it.'
