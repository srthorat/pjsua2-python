Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RootDir = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$WheelhouseDir = Join-Path $RootDir "wheelhouse"
$PythonExe = if ($env:PYTHON) { $env:PYTHON } else { "python" }

& (Join-Path $RootDir "scripts\build_pjsip_windows.ps1")

& $PythonExe -m pip install --user build | Out-Null

if (Test-Path (Join-Path $RootDir "dist")) {
    Remove-Item -Recurse -Force (Join-Path $RootDir "dist")
}

if (Test-Path $WheelhouseDir) {
    Remove-Item -Recurse -Force $WheelhouseDir
}

& $PythonExe -m build --wheel
New-Item -ItemType Directory -Force -Path $WheelhouseDir | Out-Null
Copy-Item -Force (Join-Path $RootDir "dist\*.whl") $WheelhouseDir

Write-Host "Built wheel(s):"
Get-ChildItem -Path $WheelhouseDir -Filter *.whl | Sort-Object Name | ForEach-Object { $_.FullName }
