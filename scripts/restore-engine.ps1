$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$destination = Join-Path $repoRoot 'games/tap-sprint/addons/godot_mini_game/engine/godot.wasm.br'
$expected = 'f81067a1d30125b161c26097bf4976c20064a1543d2c56b1c7cdcce10ae764cd'
if ((Test-Path -LiteralPath $destination) -and (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant() -eq $expected) {
    Write-Host 'Engine template already verified.'
    return
}
$url = 'https://raw.githubusercontent.com/AnranS/godot_for_minigame/89672fa0d6acf726eb4cd1b8a4610f8633ac93dc/addons/godot_mini_game/engine/godot.wasm.br'
$temporary = $destination + '.download'
Invoke-WebRequest -Uri $url -OutFile $temporary -UseBasicParsing
if ((Get-FileHash -LiteralPath $temporary -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expected) {
    throw 'Engine template checksum mismatch. Download was not installed.'
}
Move-Item -LiteralPath $temporary -Destination $destination -Force
Write-Host 'Engine template downloaded and verified.'
