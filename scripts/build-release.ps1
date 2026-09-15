# Build a ZIP that extracts directly into Balatro's Mods folder.
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'release-files.ps1')
$version=(Get-Content (Join-Path $root 'BalatroReplayer.json') -Raw | ConvertFrom-Json).version
$dist=Join-Path $root 'dist'
New-Item -ItemType Directory -Force $dist | Out-Null
$zip=Join-Path $dist "BalatroReplayer-v$version.zip"
Add-Type -AssemblyName System.IO.Compression,System.IO.Compression.FileSystem
if(Test-Path -LiteralPath $zip){Remove-Item -LiteralPath $zip -Force}
$archive=[IO.Compression.ZipFile]::Open($zip,[IO.Compression.ZipArchiveMode]::Create)
try {
    foreach($file in $ReplayerReleaseFiles){
        [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive,(Join-Path $root $file),('BalatroReplayer/'+$file),[IO.Compression.CompressionLevel]::Optimal) | Out-Null
    }
} finally {$archive.Dispose()}
$archive=[IO.Compression.ZipFile]::OpenRead($zip)
try {if($archive.Entries.Count -ne $ReplayerReleaseFiles.Count){throw 'Release archive file count mismatch'}} finally {$archive.Dispose()}
"Packaged $zip ($($ReplayerReleaseFiles.Count) files)"
