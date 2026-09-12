# Installs Balatro Replayer into Balatro's Mods folder and verifies every file.
# Run from anywhere: ./scripts/install.ps1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$target = Join-Path $env:APPDATA 'Balatro\Mods\BalatroReplayer'
$files = 'BalatroReplayer.json', 'main.lua', 'json.lua', 'LICENSE', 'README.md',
    'replayer/init.lua', 'replayer/log.lua', 'replayer/driver.lua', 'replayer/session.lua', 'replayer/file-picker.lua'

# A clean copy: files dropped from the list must not linger in the mod folder.
if (Test-Path $target) { Remove-Item -Recurse -Force $target }
foreach ($file in $files) {
    $source = Join-Path $root $file
    $destination = Join-Path $target $file
    New-Item -ItemType Directory -Force (Split-Path -Parent $destination) | Out-Null
    Copy-Item $source $destination
    if ((Get-FileHash $source -Algorithm SHA256).Hash -ne (Get-FileHash $destination -Algorithm SHA256).Hash) { throw "Copy mismatch: $file" }
}
$version = (Get-Content (Join-Path $root 'BalatroReplayer.json') -Raw | ConvertFrom-Json).version
"Installed Balatro Replayer v$version to $target - all $($files.Count) files verified by SHA-256."
'Restart Balatro to load it.'
