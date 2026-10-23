param([Parameter(Mandatory = $true)][string]$VisualStudioDirectory)
$ErrorActionPreference = 'Stop'
$redistRoot = Join-Path $VisualStudioDirectory 'VC/Redist/MSVC'
# VS 2022 uses both numeric version directories and the documented v143 alias.
# Only parse numeric names as versions; a toolset alias is not System.Version.
$directories = @(Get-ChildItem -LiteralPath $redistRoot -Directory)
$versions = @($directories | Where-Object { $_.Name -match '^\d+(\.\d+){1,3}$' } | Sort-Object { [version]$_.Name } -Descending)
$aliases = @($directories | Where-Object { $_.Name -match '^v\d+$' } | Sort-Object { [int]$_.Name.Substring(1) } -Descending)
foreach ($directory in @($versions + $aliases)) {
    $x64 = Join-Path $directory.FullName 'x64'
    if (-not (Test-Path -LiteralPath $x64)) { continue }
    foreach ($crt in @(Get-ChildItem -LiteralPath $x64 -Directory -Filter 'Microsoft.VC*.CRT')) {
        $missing = @('msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll') | Where-Object { -not (Test-Path -LiteralPath (Join-Path $crt.FullName $_)) }
        if (-not $missing) { return $crt.FullName }
    }
}
throw 'Could not find complete x64 MSVC redistributable DLLs in Visual Studio.'
