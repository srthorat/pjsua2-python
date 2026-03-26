Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$vswhere = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"

if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    throw "Chocolatey is required on the Windows runner"
}

choco install -y swig

if (-not (Get-Command msbuild -ErrorAction SilentlyContinue) -and -not (Get-Command cl -ErrorAction SilentlyContinue)) {
    if (Test-Path $vswhere) {
        $installationPath = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath 2>$null
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($installationPath)) {
            Write-Host "Visual Studio Build Tools were found at $installationPath but are not activated in PATH yet. The build script will initialize the developer environment."
            return
        }
    }

    Write-Host "Visual Studio Build Tools were not found in PATH or via vswhere. On GitHub windows-2022 runners they should already be installed."
}
