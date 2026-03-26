Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$missing = New-Object System.Collections.Generic.List[string]
$vswhere = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"

foreach ($tool in @("git", "python", "swig")) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        $missing.Add($tool)
    }
}

$hasMsbuild = [bool](Get-Command msbuild -ErrorAction SilentlyContinue)
$hasCl = [bool](Get-Command cl -ErrorAction SilentlyContinue)
$hasVisualStudio = $false

if (Test-Path $vswhere) {
    $installationPath = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath 2>$null
    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($installationPath)) {
        $hasVisualStudio = $true
    }
}

if (-not $hasMsbuild -and -not $hasCl -and -not $hasVisualStudio) {
    $missing.Add("msbuild-or-cl")
}

if ($missing.Count -gt 0) {
    throw "Missing required Windows build tools: $($missing -join ', '). Run scripts/install_windows_build_deps.ps1 and use a Visual Studio Build Tools environment or GitHub Windows runner."
}
