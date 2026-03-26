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

Push-Location $SwigDir
try {
    if ($hasCompilerInPath) {
        & $PythonExe setup.py build_ext --inplace
    }
    elseif ($vsDevCmd) {
        $escapedVsDevCmd = $vsDevCmd.Replace('"', '""')
        $escapedPythonExe = $PythonExe.Replace('"', '""')
        $buildCommand = "call `"$escapedVsDevCmd`" -arch=amd64 -host_arch=amd64 && `"$escapedPythonExe`" setup.py build_ext --inplace"
        cmd.exe /c $buildCommand
        if ($LASTEXITCODE -ne 0) {
            throw "Windows SWIG build failed with exit code $LASTEXITCODE"
        }
    }
    else {
        throw "Visual Studio developer environment was not available for the Windows SWIG build."
    }
}
finally {
    Pop-Location
}

& $PythonExe (Join-Path $RootDir "scripts\stage_bindings.py") --source-dir $SwigDir --package-dir (Join-Path $RootDir "pjsua2")
