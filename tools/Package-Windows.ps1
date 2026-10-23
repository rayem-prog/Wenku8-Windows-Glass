param(
    [string]$Output = 'dist',
    [string]$VcRuntimeDirectory
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
Push-Location $root
try {
    & git diff --quiet HEAD
    if ($LASTEXITCODE -ne 0) { throw 'Commit the exact tested source before packaging.' }
    $untracked = & git ls-files --others --exclude-standard
    if ($untracked) { throw 'Review and commit untracked source before packaging.' }
    $release = Join-Path $root 'build/windows/x64/runner/Release'
    foreach ($required in @('wenku8_flutter.exe', 'flutter_windows.dll', 'webview_flutter_windows_plugin.dll', 'data/icudtl.dat', 'data/app.so', 'data/flutter_assets/AssetManifest.bin', 'BUILD-INFO.json')) {
        if (-not (Test-Path -LiteralPath (Join-Path $release $required))) { throw "Missing release file: $required. Run Build-Windows.ps1 first." }
    }
    $build = Get-Content -Raw -LiteralPath (Join-Path $release 'BUILD-INFO.json') | ConvertFrom-Json
    $revision = (& git rev-parse HEAD).Trim()
    if ($build.source_revision -ne $revision -or $build.mode -ne 'release' -or $build.flutter.frameworkVersion -ne '3.47.0' -or $build.app -ne '0.5.0+164') {
        throw 'Release metadata does not match this source revision and pinned SDK. Rebuild before packaging.'
    }
    if (-not $VcRuntimeDirectory) {
        $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
        $vs = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
        if ($LASTEXITCODE -ne 0 -or -not $vs) { throw 'Could not find MSVC redistributable DLLs. Pass -VcRuntimeDirectory with the licensed x64 Microsoft.VC*.CRT directory.' }
        $VcRuntimeDirectory = & (Join-Path $PSScriptRoot 'Find-VcRuntime.ps1') -VisualStudioDirectory $vs.Trim()
    }
    foreach ($dll in @('msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll')) {
        if (-not (Test-Path -LiteralPath (Join-Path $VcRuntimeDirectory $dll))) { throw "Missing x64 VC runtime: $dll" }
    }
    $destination = [IO.Path]::GetFullPath((Join-Path $root $Output))
    $name = "Wenku8-Windows-0.5.0-$($revision.Substring(0,8))"
    $package = Join-Path $destination $name
    if ((Test-Path -LiteralPath $package) -or (Test-Path -LiteralPath "$package.zip")) { throw 'Output already exists; choose a new -Output directory.' }
    New-Item -ItemType Directory -Path $package -Force | Out-Null
    Copy-Item -Path "$release/*" -Destination $package -Recurse
    Copy-Item -Path (Join-Path $VcRuntimeDirectory '*.dll') -Destination $package
    Copy-Item -LiteralPath 'LICENSE', 'COPYING', 'NOTICE', 'WINDOWS.md', 'WINDOWS-ACCEPTANCE.md', 'WINDOWS-VALIDATION.md' -Destination $package
    Copy-Item -LiteralPath 'assets/licenses' -Destination (Join-Path $package 'licenses') -Recurse
    & git archive --format=zip "--output=$package/Corresponding-Source.zip" HEAD
    if ($LASTEXITCODE -ne 0) { throw 'Could not archive corresponding source' }
    $hashes = Get-ChildItem -LiteralPath $package -File -Recurse | Sort-Object FullName | ForEach-Object {
        $relative = $_.FullName.Substring($package.Length + 1).Replace('\', '/')
        "$((Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLower())  $relative"
    }
    $hashes | Set-Content -LiteralPath (Join-Path $package 'SHA256SUMS.txt') -Encoding UTF8
    Compress-Archive -Path "$package/*" -DestinationPath "$package.zip" -CompressionLevel Optimal
    Write-Host "Package: $package.zip"
} finally { Pop-Location }
