param(
    [string]$GodotPath = $env:GODOT_PATH,
    [string]$AppId = 'touristappid',
    [ValidateSet('tap-sprint','block-clear','arrow-escape')][string]$Game = 'tap-sprint'
)
$ErrorActionPreference = 'Stop'
if (-not $GodotPath -or !(Test-Path -LiteralPath $GodotPath)) { throw 'Pass -GodotPath with the Godot 4.6.1 editor executable path.' }
$repoRoot = Split-Path -Parent $PSScriptRoot
& (Join-Path $PSScriptRoot 'restore-assets.ps1')
& (Join-Path $PSScriptRoot 'restore-engine.ps1') -Game $Game
$project = Join-Path $repoRoot ("games/$Game")
$runtime = Join-Path $repoRoot 'work/runtime'
New-Item -ItemType Directory -Force -Path $runtime | Out-Null
$env:APPDATA = $runtime
$env:LOCALAPPDATA = $runtime
$staging = Join-Path $runtime ('export-' + [guid]::NewGuid().ToString('N'))
$output = Join-Path $repoRoot ("exports/wechat-$Game")
& $GodotPath --headless --path $project --editor --import --quit
if ($LASTEXITCODE -ne 0) { throw 'Import failed.' }
& $GodotPath --headless --path $project --script res://export_wechat.gd -- $staging $AppId
if ($LASTEXITCODE -ne 0) { throw 'Export failed.' }
New-Item -ItemType Directory -Force -Path $output | Out-Null
Copy-Item -Path (Join-Path $staging '*') -Destination $output -Recurse -Force
Write-Host "Import this folder into WeChat DevTools: $output"

$licenses = Join-Path $output 'licenses'
New-Item -ItemType Directory -Force -Path $licenses | Out-Null
foreach ($relative in @('LICENSE','PLUGIN_LICENSE','addons/godot_mini_game/GODOT_COPYRIGHT.txt','addons/godot_mini_game/THIRD_PARTY_NOTICES.md','fonts/OFL.txt','assets/fonts/OFL.txt','assets/audio/QWEN_LICENSE.txt')) {
    $license = Join-Path $project $relative
    if (Test-Path -LiteralPath $license) { Copy-Item -LiteralPath $license -Destination $licenses -Force }
}
