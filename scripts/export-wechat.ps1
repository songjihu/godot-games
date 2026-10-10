param(
    [string]$GodotPath = $env:GODOT_PATH,
    [string]$AppId = 'touristappid'
)
$ErrorActionPreference = 'Stop'
if (-not $GodotPath -or !(Test-Path -LiteralPath $GodotPath)) { throw 'Pass -GodotPath with the Godot 4.6.1 editor executable path.' }
$repoRoot = Split-Path -Parent $PSScriptRoot
& (Join-Path $PSScriptRoot 'restore-engine.ps1')
$project = Join-Path $repoRoot 'games/tap-sprint'
$runtime = Join-Path $repoRoot 'work/runtime'
New-Item -ItemType Directory -Force -Path $runtime | Out-Null
$env:APPDATA = $runtime
$env:LOCALAPPDATA = $runtime
$staging = Join-Path $runtime ('export-' + [guid]::NewGuid().ToString('N'))
$output = Join-Path $repoRoot 'exports/wechat-tap-game'
& $GodotPath --headless --path $project --editor --import --quit
if ($LASTEXITCODE -ne 0) { throw 'Import failed.' }
& $GodotPath --headless --path $project --script res://export_wechat.gd -- $staging $AppId
if ($LASTEXITCODE -ne 0) { throw 'Export failed.' }
New-Item -ItemType Directory -Force -Path $output | Out-Null
Copy-Item -Path (Join-Path $staging '*') -Destination $output -Recurse -Force
Write-Host "Import this folder into WeChat DevTools: $output"
