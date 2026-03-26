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

from setuptools import Extension, setup

pjdir = os.environ.get("PJDIR", "")
if not pjdir or not os.path.isdir(pjdir):
    sys.exit(
        f"Error: PJDIR env var must point to the pjproject root dir, got: {pjdir!r}"
    )

# ---------------------------------------------------------------------------
# PJ version — hardcoded to match the checked-out tag (2.15.1)
# version.mak uses GNU make variable expansion ($(VAR)) which cannot be
# parsed with a simple line-by-line reader without executing make, so we
# avoid that and just hardcode the version string here.
# ---------------------------------------------------------------------------
pj_version = "2.15.1"

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
