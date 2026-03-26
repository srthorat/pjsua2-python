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
# Read PJ version from version.mak
# ---------------------------------------------------------------------------
pj_version = "2.15.1"
try:
    major = minor = rev = suffix = ""
    with open(os.path.join(pjdir, "version.mak")) as vf:
        for line in vf:
            if "PJ_VERSION_MAJOR" in line and "=" in line:
                major = line.split("=", 1)[1].strip()
            elif "PJ_VERSION_MINOR" in line and "=" in line:
                minor = line.split("=", 1)[1].strip()
            elif (
                "PJ_VERSION_REV" in line
                and "MINOR" not in line
                and "=" in line
            ):
                rev = line.split("=", 1)[1].strip()
            elif "PJ_VERSION_SUFFIX" in line and "=" in line:
                suffix = line.split("=", 1)[1].strip()
    if major:
        pj_version = major + "." + minor
        if rev:
            pj_version += "." + rev
        if suffix:
            pj_version += suffix
except Exception as exc:
    print(f"Warning: could not read version.mak: {exc}", flush=True)

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
