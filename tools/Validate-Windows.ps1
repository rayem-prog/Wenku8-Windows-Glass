param([string]$Flutter = 'flutter', [string]$Output = 'build/windows-review')
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
Push-Location $root
try {
    $outputPath = [IO.Path]::GetFullPath((Join-Path $root $Output))
    New-Item -ItemType Directory -Path $outputPath -Force | Out-Null
    if ([Environment]::OSVersion.Platform -ne 'Win32NT') {
        throw 'Native validation requires Windows.'
    }
    $archive = Get-ChildItem -LiteralPath (Join-Path $root 'dist') -File -Filter 'Wenku8-Windows-0.5.0-*.zip' | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
    if (-not $archive) { throw 'Build and package the Release candidate before native validation.' }
    $portable = Join-Path ([IO.Path]::GetTempPath()) "wenku8-release-check-$([Guid]::NewGuid().ToString('N'))"
    $process = $null
    try {
        Expand-Archive -LiteralPath $archive.FullName -DestinationPath $portable
        $info = Get-Content -LiteralPath (Join-Path $portable 'BUILD-INFO.json') -Raw | ConvertFrom-Json
        $revision = (& git rev-parse HEAD).Trim()
        if ($info.source_revision -ne $revision) { throw 'The packaged Release does not match this source revision.' }
        $process = Start-Process -FilePath (Join-Path $portable 'wenku8_flutter.exe') -WorkingDirectory $portable -PassThru -RedirectStandardOutput (Join-Path $outputPath 'portable.stdout.log') -RedirectStandardError (Join-Path $outputPath 'portable.stderr.log')
        $timer = [Diagnostics.Stopwatch]::StartNew()
        do {
            Start-Sleep -Milliseconds 250
            $process.Refresh()
            if ($process.HasExited) { throw "Packaged Release exited during startup: $($process.ExitCode)" }
        } while ($process.MainWindowHandle -eq [IntPtr]::Zero -and $timer.Elapsed.TotalSeconds -lt 45)
        if ($process.MainWindowHandle -eq [IntPtr]::Zero) { throw 'Packaged Release did not create a visible main window.' }
        Start-Sleep -Seconds 3
        $process.Refresh()
        if ($process.HasExited) { throw "Packaged Release exited after its first window: $($process.ExitCode)" }
        @{
            source_revision = $revision; app = $info.app
            main_window_created = $true; title = $process.MainWindowTitle
            checked_after_ms = $timer.ElapsedMilliseconds
            meaning = 'Release startup from the extracted distribution; not a frame-rate measurement.'
        } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $outputPath 'portable-startup.json') -Encoding UTF8
        Write-Host 'Packaged Release started from its extracted ZIP and created a main window.'
    } finally {
        if ($process) {
            if (-not $process.HasExited) {
                [void]$process.CloseMainWindow()
                if (-not $process.WaitForExit(5000)) { Stop-Process -Id $process.Id -Force; $process.WaitForExit() }
            }
            $process.Dispose()
        }
        if (Test-Path -LiteralPath $portable) { Remove-Item -LiteralPath $portable -Recurse -Force }
    }
    & $Flutter test integration_test/windows_smoke_test.dart -d windows "--dart-define=WINDOWS_REVIEW=$outputPath"
    if ($LASTEXITCODE -ne 0) { throw 'Native Windows smoke test failed' }
    Write-Host "Native smoke passed. Captures: $outputPath"
    Write-Host 'Run the Release application and follow WINDOWS-ACCEPTANCE.md for login and 60/120/144Hz measurements.'
} finally { Pop-Location }
