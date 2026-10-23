# Exercises the real build/package entry points against disposable fixtures.
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}
function Assert-Rejected([scriptblock]$Action, [string]$Reason) {
    $caught = $false
    try { & $Action | Out-Null } catch {
        if ($_.Exception.Message -notlike "*$Reason*") { throw }
        $caught = $true
    }
    Assert-True $caught "Expected rejection: $Reason"
}
foreach ($file in @('Build-Windows.ps1', 'tools/Package-Windows.ps1', 'tools/Validate-Windows.ps1')) {
    $tokens = $null; $errors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile((Join-Path $root $file), [ref]$tokens, [ref]$errors)
    Assert-True ($errors.Count -eq 0) "PowerShell parse errors: $file"
}
$temporary = Join-Path ([IO.Path]::GetTempPath()) "wenku8-package-test-$([Guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Path $temporary | Out-Null
$previous = Get-Location
try {
    $fakeFlutter = Join-Path $temporary 'old-flutter.ps1'
    Set-Content -LiteralPath $fakeFlutter -Value 'Write-Output ''{"frameworkVersion":"3.41.5"}''; exit 0' -Encoding UTF8
    Assert-Rejected { & (Join-Path $root 'Build-Windows.ps1') -Flutter $fakeFlutter } 'Flutter 3.47.0 is required'
    Assert-True ((Get-Location).Path -eq $previous.Path) 'Build preflight did not restore the working directory'
    $project = Join-Path $temporary 'project'
    New-Item -ItemType Directory -Path "$project/tools", "$project/assets/licenses" -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $root 'tools/Package-Windows.ps1') -Destination "$project/tools/Package-Windows.ps1"
    foreach ($file in @('LICENSE','COPYING','NOTICE','WINDOWS.md','WINDOWS-ACCEPTANCE.md','WINDOWS-VALIDATION.md')) {
        Copy-Item -LiteralPath (Join-Path $root $file) -Destination (Join-Path $project $file)
    }
    Set-Content -LiteralPath "$project/assets/licenses/fixture.txt" -Value 'license fixture' -Encoding UTF8
    Set-Content -LiteralPath "$project/.gitignore" -Value "build/`ncrt/`ndist/" -Encoding UTF8
    Set-Content -LiteralPath "$project/README.md" -Value 'source fixture, never a runnable release' -Encoding UTF8
    Set-Location $project
    & git init -q
    & git add .
    & git -c user.name=Fixture -c user.email=fixture@example.invalid -c core.hooksPath=/dev/null commit -qm fixture
    if ($LASTEXITCODE -ne 0) { throw 'Fixture repository failed' }
    $revision = (& git rev-parse HEAD).Trim()
    $script = Join-Path $project 'tools/Package-Windows.ps1'
    Assert-Rejected { & $script } 'Missing release file'
    $release = Join-Path $project 'build/windows/x64/runner/Release'
    foreach ($file in @('wenku8_flutter.exe','flutter_windows.dll','webview_flutter_windows_plugin.dll','data/icudtl.dat','data/app.so','data/flutter_assets/AssetManifest.bin')) {
        $path = Join-Path $release $file
        New-Item -ItemType Directory -Path (Split-Path $path -Parent) -Force | Out-Null
        Set-Content -LiteralPath $path -Value "packaging fixture only: $file" -Encoding UTF8
    }
    $metadata = @{source_revision='stale';mode='release';flutter=@{frameworkVersion='3.47.0'};app='0.5.0+164'}
    $metadata | ConvertTo-Json | Set-Content -LiteralPath "$release/BUILD-INFO.json" -Encoding UTF8
    Assert-Rejected { & $script } 'Release metadata does not match'
    $metadata.source_revision = $revision
    $metadata | ConvertTo-Json | Set-Content -LiteralPath "$release/BUILD-INFO.json" -Encoding UTF8
    $crt = Join-Path $project 'crt'
    New-Item -ItemType Directory -Path $crt | Out-Null
    foreach ($dll in @('msvcp140.dll','vcruntime140.dll','vcruntime140_1.dll')) {
        Set-Content -LiteralPath (Join-Path $crt $dll) -Value "runtime fixture: $dll" -Encoding UTF8
    }
    & $script -VcRuntimeDirectory $crt
    $archive = Get-ChildItem -LiteralPath "$project/dist" -Filter '*.zip' | Select-Object -First 1
    Assert-True ($null -ne $archive) 'No ZIP was generated'
    $expanded = Join-Path $temporary 'expanded'
    Expand-Archive -LiteralPath $archive.FullName -DestinationPath $expanded
    foreach ($file in @('wenku8_flutter.exe','flutter_windows.dll','webview_flutter_windows_plugin.dll','data/app.so','msvcp140.dll','vcruntime140.dll','vcruntime140_1.dll','Corresponding-Source.zip','LICENSE','COPYING','NOTICE','SHA256SUMS.txt')) {
        Assert-True (Test-Path -LiteralPath (Join-Path $expanded $file)) "Package omitted $file"
    }
    $source = Join-Path $temporary 'source'
    Expand-Archive -LiteralPath "$expanded/Corresponding-Source.zip" -DestinationPath $source
    Assert-True (Test-Path -LiteralPath "$source/README.md") 'Corresponding source is missing'
    Assert-True (-not (Test-Path -LiteralPath "$source/build")) 'Source archive included fixture binaries'
    $hashes = Get-Content -LiteralPath "$expanded/SHA256SUMS.txt"
    foreach ($line in $hashes) {
        Assert-True ($line -match '^([0-9a-f]{64})  (.+)$') 'Invalid checksum record'
        $expected = $Matches[1]; $relative = $Matches[2]
        Assert-True ((Get-FileHash -LiteralPath (Join-Path $expanded $relative) -Algorithm SHA256).Hash.ToLower() -eq $expected) "Checksum mismatch: $relative"
    }
    Assert-Rejected { & $script -VcRuntimeDirectory $crt } 'Output already exists'
    Add-Content -LiteralPath "$project/README.md" -Value 'dirty'
    Assert-Rejected { & $script -VcRuntimeDirectory $crt } 'Commit the exact tested source'
    Write-Host 'Windows scripts passed: syntax, wrong SDK, missing files, stale build, complete archive/source/licenses/checksums, overwrite and dirty-source rejection.'
} finally {
    Set-Location $previous
    Remove-Item -LiteralPath $temporary -Recurse -Force
}
