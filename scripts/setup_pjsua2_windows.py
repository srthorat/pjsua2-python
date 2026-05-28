"""Windows MSVC-specific setup script for the _pjsua2 Python extension.

Called from build_pjsip_windows.ps1 in place of the upstream setup.py,
which relies on GNU make / helper.mak to gather CFLAGS, LIBS, and LDFLAGS.
On a pure MSVC build (GitHub Actions windows-2022), GNU make is unavailable
so those helper.mak calls return empty, leaving the extension without any
include dirs or libraries.

This script: reads PJDIR from the environment, discovers all .lib files
built by the preceding MSBuild step, and passes them explicitly to
setuptools.Extension.
"""
import glob
import os
import sys
from pathlib import Path

from setuptools import Extension, setup

pjdir = os.environ.get("PJDIR", "")
if not pjdir or not os.path.isdir(pjdir):
    sys.exit(
        f"Error: PJDIR env var must point to the pjproject root dir, got: {pjdir!r}"
    )

def read_pj_version(pjproject_dir):
    env_version = os.environ.get("PJ_VERSION", "").strip()
    if env_version:
        return env_version

    version_file = Path(pjproject_dir) / "version.mak"
    values = {}
    for line in version_file.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line.startswith("export PJ_VERSION_"):
            continue
        key, separator, value = line.partition(":=")
        if not separator:
            key, separator, value = line.partition("=")
        if not separator:
            continue
        key = key.replace("export", "").strip()
        values[key] = value.strip()

    major = values.get("PJ_VERSION_MAJOR", "")
    minor = values.get("PJ_VERSION_MINOR", "")
    rev = values.get("PJ_VERSION_REV", "")
    suffix = values.get("PJ_VERSION_SUFFIX", "")
    if not major or not minor:
        sys.exit(f"Error: could not parse PJ version from {version_file}")

    version = f"{major}.{minor}"
    if rev:
        version += f".{rev}"
    if suffix:
        version += suffix
    return version


pj_version = read_pj_version(pjdir)

# ---------------------------------------------------------------------------
# Include directories
# ---------------------------------------------------------------------------
include_dirs = [
    os.path.join(pjdir, "pjlib", "include"),
    os.path.join(pjdir, "pjlib-util", "include"),
    os.path.join(pjdir, "pjmedia", "include"),
    os.path.join(pjdir, "pjsip", "include"),
    os.path.join(pjdir, "pjnath", "include"),
]

# ---------------------------------------------------------------------------
# Library search directories (populated by the preceding MSBuild step)
# ---------------------------------------------------------------------------
lib_search_dirs = [
    d
    for d in [
        os.path.join(pjdir, "lib"),
        os.path.join(pjdir, "pjlib", "lib"),
        os.path.join(pjdir, "pjlib-util", "lib"),
        os.path.join(pjdir, "pjmedia", "lib"),
        os.path.join(pjdir, "pjsip", "lib"),
        os.path.join(pjdir, "pjnath", "lib"),
        os.path.join(pjdir, "third_party", "lib"),
    ]
    if os.path.isdir(d)
]

# ---------------------------------------------------------------------------
# Collect every .lib file built by MSBuild
# ---------------------------------------------------------------------------
libraries = []
for d in lib_search_dirs:
    for f in sorted(glob.glob(os.path.join(d, "*.lib"))):
        libraries.append(os.path.splitext(os.path.basename(f))[0])

# Windows system libraries required by pjproject on MSVC
libraries += [
    "ws2_32",
    "ole32",
    "winmm",
    "dsound",
    "dxguid",
    "mswsock",
    "advapi32",
    "user32",
    "iphlpapi",
]

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------
setup(
    name="pjsua2",
    version=pj_version,
    description="SIP User Agent Library based on PJSIP",
    url="http://www.pjsip.org",
    ext_modules=[
        Extension(
            "_pjsua2",
            sources=["pjsua2_wrap.cpp"],
            include_dirs=include_dirs,
            library_dirs=lib_search_dirs,
            libraries=libraries,
        )
    ],
    py_modules=["pjsua2"],
)
