Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RootDir = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$BuildRoot = Join-Path $RootDir "build"
$PjprojectDir = Join-Path $BuildRoot "pjproject"
$SwigDir = Join-Path $PjprojectDir "pjsip-apps\src\swig\python"
$PythonExe = if ($env:PYTHON) { $env:PYTHON } else { "python" }
$PackageVersion = & $PythonExe (Join-Path $RootDir "scripts\get_package_version.py")
$PjsipRef = if ($env:PJSIP_REF) { $env:PJSIP_REF } else { $PackageVersion.Trim() }

& (Join-Path $RootDir "scripts\check_windows_build_tools.ps1")

New-Item -ItemType Directory -Force -Path $BuildRoot | Out-Null

if (-not (Test-Path (Join-Path $PjprojectDir ".git"))) {
    git clone https://github.com/pjsip/pjproject.git $PjprojectDir
}

git -C $PjprojectDir fetch --tags --force origin
git -C $PjprojectDir checkout --force $PjsipRef
git -C $PjprojectDir clean -fdx

Copy-Item -Force (Join-Path $RootDir "scripts\config_site.h") (Join-Path $PjprojectDir "pjlib\include\pj\config_site.h")

Push-Location $SwigDir
try {
    & $PythonExe setup.py build_ext --inplace
}
finally {
    Pop-Location
}

& $PythonExe (Join-Path $RootDir "scripts\stage_bindings.py") --source-dir $SwigDir --package-dir (Join-Path $RootDir "pjsua2")
