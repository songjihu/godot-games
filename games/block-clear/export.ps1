param([string]$GodotPath = $env:GODOT_PATH, [string]$AppId = 'touristappid')
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot '../../scripts/export-wechat.ps1') -GodotPath $GodotPath -AppId $AppId -Game 'block-clear'
