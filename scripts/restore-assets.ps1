$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$manifest = Get-Content -LiteralPath (Join-Path $repoRoot 'asset-parts/manifest.json') -Raw | ConvertFrom-Json
foreach ($asset in $manifest) {
    $destination = Join-Path $repoRoot $asset.path
    if ((Test-Path -LiteralPath $destination) -and (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant() -eq $asset.sha256) { continue }
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destination) | Out-Null
    $temporary = $destination + '.download'
    $stream = [System.IO.File]::Create($temporary)
    try {
        foreach ($part in $asset.parts) {
            $bytes = [System.IO.File]::ReadAllBytes((Join-Path $repoRoot $part))
            $stream.Write($bytes, 0, $bytes.Length)
        }
    } finally { $stream.Dispose() }
    if ((Get-Item -LiteralPath $temporary).Length -ne $asset.bytes -or (Get-FileHash -LiteralPath $temporary -Algorithm SHA256).Hash.ToLowerInvariant() -ne $asset.sha256) { throw "Asset checksum mismatch: $($asset.path)" }
    Move-Item -LiteralPath $temporary -Destination $destination -Force
}
Write-Host 'Comic assets restored and verified.'
