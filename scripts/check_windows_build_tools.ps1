Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$missing = New-Object System.Collections.Generic.List[string]

foreach ($tool in @("git", "python", "swig")) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        $missing.Add($tool)
    }
}

$hasMsbuild = [bool](Get-Command msbuild -ErrorAction SilentlyContinue)
$hasCl = [bool](Get-Command cl -ErrorAction SilentlyContinue)

if (-not $hasMsbuild -and -not $hasCl) {
    $missing.Add("msbuild-or-cl")
}

if ($missing.Count -gt 0) {
    throw "Missing required Windows build tools: $($missing -join ', '). Run scripts/install_windows_build_deps.ps1 and use a Visual Studio Build Tools environment or GitHub Windows runner."
}
