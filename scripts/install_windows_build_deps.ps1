Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    throw "Chocolatey is required on the Windows runner"
}

choco install -y swig

if (-not (Get-Command msbuild -ErrorAction SilentlyContinue) -and -not (Get-Command cl -ErrorAction SilentlyContinue)) {
    Write-Host "Visual Studio Build Tools were not found in PATH. On GitHub windows-2022 runners they should already be available."
}
