Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-VsDevCmd {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"
    if (-not (Test-Path $vswhere)) {
        return $null
    }

    $installationPath = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath 2>$null
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($installationPath)) {
        return $null
    }

    $candidate = Join-Path $installationPath "Common7\Tools\VsDevCmd.bat"
    if (Test-Path $candidate) {
        return $candidate
    }

    return $null
}

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

$vsDevCmd = Get-VsDevCmd
$hasCompilerInPath = [bool](Get-Command cl -ErrorAction SilentlyContinue)

if (-not $vsDevCmd -and -not $hasCompilerInPath) {
    throw "Visual Studio developer environment was not available for the Windows build."
}

$escapedVsDevCmd = if ($vsDevCmd) { $vsDevCmd.Replace('"', '""') } else { $null }
$escapedPythonExe = $PythonExe.Replace('"', '""')

# ── Step 1: Build pjproject native libraries via MSBuild ─────────────────────
# On Windows, pjproject uses VS project files rather than autoconf/make.
# The SWIG setup.py links against these .lib files, so they must exist first.
# The solution file lives in the pjproject root (not in build/vs/).
$slnPath = Join-Path $PjprojectDir "pjproject-vs14.sln"
if (-not (Test-Path $slnPath)) {
    throw "pjproject VS solution not found: $slnPath"
}

Write-Host "Building pjproject native libraries (Release/x64) via MSBuild..."
# /p:PlatformToolset=v143 overrides the v140 (VS2015) toolset in the .sln; the
# GitHub Actions windows-2022 runner ships VS 2022 (v143) only.
if ($hasCompilerInPath) {
    msbuild "$slnPath" /t:Build /p:Configuration=Release /p:Platform=x64 /p:PlatformToolset=v143 /m /nologo /verbosity:minimal
} else {
    $msbuildCmd = "call `"$escapedVsDevCmd`" -arch=amd64 -host_arch=amd64 && msbuild `"$slnPath`" /t:Build /p:Configuration=Release /p:Platform=x64 /p:PlatformToolset=v143 /m /nologo /verbosity:minimal"
    cmd.exe /c $msbuildCmd
}
if ($LASTEXITCODE -ne 0) {
    throw "MSBuild pjproject failed with exit code $LASTEXITCODE"
}

# ── Step 2: Build SWIG Python bindings ───────────────────────────────────────
# Set MSYSTEM to empty string so any downstream code that inspects it
# (e.g. pjproject setup.py) doesn't raise a KeyError on MSVC.
$env:MSYSTEM = ""
# Expose pjproject root for setup_pjsua2_windows.py (it reads PJDIR).
$env:PJDIR = $PjprojectDir
# Path to our Windows-specific setup script (bypasses helper.mak / GNU make).
$setupMsvc = Join-Path $RootDir "scripts\setup_pjsua2_windows.py"

Push-Location $SwigDir
try {
    # Generate pjsua2_wrap.cpp from pjsua2.i using SWIG.
    # On Linux/macOS the Makefile does this; on Windows we must do it explicitly.
    # pjsua2.i lives one directory up from the python/ subdir.
    # Note: Join-Path with 3 args requires PS6+; use Split-Path for PS5.1 compat.
    $swigIface = Join-Path (Split-Path $SwigDir -Parent) "pjsua2.i"
    Write-Host "Generating SWIG wrapper (pjsua2_wrap.cpp)..."
    swig -c++ -python -threads `
        "-I$PjprojectDir\pjlib\include" `
        "-I$PjprojectDir\pjlib-util\include" `
        "-I$PjprojectDir\pjmedia\include" `
        "-I$PjprojectDir\pjsip\include" `
        "-I$PjprojectDir\pjnath\include" `
        -o pjsua2_wrap.cpp "$swigIface"
    if ($LASTEXITCODE -ne 0) {
        throw "SWIG generation failed with exit code $LASTEXITCODE"
    }

    # setuptools (and distutils shim) was removed from Python 3.12 stdlib.
    & $PythonExe -m pip install --quiet setuptools

    if ($hasCompilerInPath) {
        & $PythonExe $setupMsvc build_ext --inplace
    } else {
        $buildCommand = "call `"$escapedVsDevCmd`" -arch=amd64 -host_arch=amd64 && set MSYSTEM= && set `"PJDIR=$PjprojectDir`" && `"$escapedPythonExe`" `"$setupMsvc`" build_ext --inplace"
        cmd.exe /c $buildCommand
    }
    if ($LASTEXITCODE -ne 0) {
        throw "Windows SWIG build failed with exit code $LASTEXITCODE"
    }
}
finally {
    Pop-Location
}

& $PythonExe (Join-Path $RootDir "scripts\stage_bindings.py") --source-dir $SwigDir --package-dir (Join-Path $RootDir "pjsua2")
