param(
    [string]$Flutter = 'flutter',
    [ValidateSet('release', 'profile')][string]$Mode = 'release'
)
$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
    $expected = (Get-Content -LiteralPath '.flutter-version' -Raw).Trim()
    $versionText = & $Flutter --version --machine
    if ($LASTEXITCODE -ne 0) { throw 'Could not read Flutter version' }
    $version = ($versionText -join "`n") | ConvertFrom-Json
    if ($version.frameworkVersion -ne $expected) {
        throw "Flutter $expected is required; found $($version.frameworkVersion). Use -Flutter to select the pinned SDK."
    }
    if ([Environment]::OSVersion.Platform -ne 'Win32NT') {
        throw 'A Windows host with Visual Studio C++ desktop tools is required to build the Windows executable.'
    }
    $nodeVersion = & node --version
    if ($LASTEXITCODE -ne 0 -or $nodeVersion -notmatch '^v(\d+)\.' -or [int]$Matches[1] -lt 22) {
        throw 'Node.js 22 or newer is required for website-script regression tests.'
    }
    & $Flutter pub get
    if ($LASTEXITCODE -ne 0 -and (Test-Path -LiteralPath '.flutter-plugins-dependencies')) {
        # NTFS junctions do not require enabling Windows Developer Mode.
        $metadata = Get-Content -LiteralPath '.flutter-plugins-dependencies' -Raw | ConvertFrom-Json
        $links = Join-Path $PSScriptRoot 'windows/flutter/ephemeral/.plugin_symlinks'
        New-Item -ItemType Directory -Path $links -Force | Out-Null
        foreach ($plugin in $metadata.plugins.windows) {
            if ($plugin.name -notmatch '^[a-z0-9_]+$') { throw 'Invalid plugin name' }
            $link = Join-Path $links $plugin.name
            if (-not (Test-Path -LiteralPath $link)) {
                New-Item -ItemType Junction -Path $link -Target (Resolve-Path -LiteralPath $plugin.path).Path | Out-Null
            }
        }
        & $Flutter pub get
    }
    if ($LASTEXITCODE -ne 0) { throw 'Dependency resolution failed' }
    & $Flutter analyze --no-pub
    if ($LASTEXITCODE -ne 0) { throw 'Static analysis failed' }
    & $Flutter test --no-pub
    if ($LASTEXITCODE -ne 0) { throw 'Tests failed' }
    & $Flutter build windows "--$Mode" --no-pub
    if ($LASTEXITCODE -ne 0) { throw 'Windows build failed' }
    $configuration = (Get-Culture).TextInfo.ToTitleCase($Mode)
    $bundle = Join-Path $PSScriptRoot "build/windows/x64/runner/$configuration"
    $revision = & git rev-parse HEAD
    if ($LASTEXITCODE -ne 0) { $revision = 'source-archive' }
    @{
        app = '0.5.0+164'; mode = $Mode; source_revision = "$revision"
        flutter = $version; built_utc = [DateTime]::UtcNow.ToString('o')
        native_smoke = 'Not run by the build script; run tools/Validate-Windows.ps1 or test on target PC.'
        high_refresh = 'Requires measurement on the target display; no FPS certification.'
    } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $bundle 'BUILD-INFO.json') -Encoding UTF8
    Write-Host "Build complete: $bundle"
    Write-Host 'Next: ./tools/Package-Windows.ps1 to include runtime DLLs, source and acceptance instructions.'
} finally { Pop-Location }
