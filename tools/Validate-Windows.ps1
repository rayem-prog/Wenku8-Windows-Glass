param([string]$Flutter = 'flutter', [string]$Output = 'build/windows-review')
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
Push-Location $root
try {
    $outputPath = [IO.Path]::GetFullPath((Join-Path $root $Output))
    New-Item -ItemType Directory -Path $outputPath -Force | Out-Null
    & $Flutter test integration_test/windows_smoke_test.dart -d windows "--dart-define=WINDOWS_REVIEW=$outputPath"
    if ($LASTEXITCODE -ne 0) { throw 'Native Windows smoke test failed' }
    Write-Host "Native smoke passed. Captures: $outputPath"
    Write-Host 'Run the Release application and follow WINDOWS-ACCEPTANCE.md for login and 60/120/144Hz measurements.'
} finally { Pop-Location }
