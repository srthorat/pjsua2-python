# pjsua2-python

Reusable binary wheel packaging for PJSUA2 Python bindings built from upstream `pjproject`.

This repository is designed for the problem you called out directly:

- no official wheel
- brittle local builds
- repeated manual SWIG compilation per project

The repo is wheel-first. It builds PJSIP/PJSUA2, stages the generated SWIG artifacts into a Python package, and emits installable wheels with `cibuildwheel`.

## Packaging model

`pjsua2-python` is a native extension package, not a pure Python package.

The package version should match the bundled `pjproject` version exactly. This avoids the usual confusion of having a separate wrapper version and an upstream PJSIP version.

Examples:

- `pjsua2-python==2.15.1` packages `pjproject` `2.15.1`
- future `pjsua2-python==2.16.x` should package `pjproject` `2.16.x`

This repository now treats [pjsua2/_version.py](/home/ubuntu/dev/pjsua2-python/pjsua2/_version.py) as the single source of truth. The package metadata and CI build default both derive from that file automatically.

That means `pip install pjsua2-python` works by publishing multiple wheels, then letting `pip` choose the right one for the current machine:

- Linux x86_64
- macOS x86_64
- macOS arm64
- Windows AMD64
- Python 3.8 through 3.12

For this scope, that means 20 wheels total.

There is no correct single binary wheel that works unchanged across Linux, macOS, and Windows. Serious projects like NumPy and PyTorch solve this exactly the same way: one wheel per platform and per Python ABI.

## Target outputs

Examples:

- `pjsua2_python-2.15.1-cp38-cp38-manylinux2014_x86_64.whl`
- `pjsua2_python-2.15.1-cp311-cp311-macosx_13_0_x86_64.whl`
- `pjsua2_python-2.15.1-cp311-cp311-macosx_14_0_arm64.whl`
- `pjsua2_python-2.15.1-cp311-cp311-win_amd64.whl`

## What this repo does

1. Clones `pjproject`
2. Checks out a configured release/tag/branch
3. Builds upstream PJSIP and the SWIG Python binding
4. Copies generated artifacts into the local `pjsua2` package
5. Builds wheels for each Python/platform target with `cibuildwheel`

## Repository layout

```text
pjsua2-python/
├── .github/workflows/build.yml
├── pjsua2/
│   ├── __init__.py
│   └── _version.py
├── scripts/
│   ├── build_pjsip_linux.sh
│   ├── build_pjsip_macos.sh
│   ├── build_pjsip_windows.ps1
│   ├── build_linux_wheel.sh
│   ├── build_macos_wheel.sh
│   ├── build_windows_wheel.ps1
│   ├── check_linux_build_tools.sh
│   ├── check_macos_build_tools.sh
│   ├── check_windows_build_tools.ps1
│   ├── config_site.h
│   ├── install_linux_build_deps.sh
│   ├── install_macos_build_deps.sh
│   ├── install_windows_build_deps.ps1
│   ├── stage_bindings.py
│   └── test_import.py
├── MANIFEST.in
└── pyproject.toml
```

## Supported build targets

- Linux: `manylinux2014_x86_64`
- macOS Intel: `x86_64`
- macOS Apple Silicon: `arm64`
- Windows: `AMD64`
- Python: `3.8` through `3.12`

## Default upstream version

The workflow defaults to the version declared in [pjsua2/_version.py](/home/ubuntu/dev/pjsua2-python/pjsua2/_version.py).

This should stay equal to the Python package version. Release tags should follow the same convention, for example `v2.15.1`.

Override it when needed:

```bash
PJSIP_REF=master python -m cibuildwheel --output-dir dist
```

If you want strict reproducibility, keep using a tag. If you want the newest upstream commit, set `PJSIP_REF=master` or a commit SHA.

## Design choices

### 1. Wheel-first, not source-first

This repo is optimized for prebuilt wheels. That is the real operational win. Source installs are intentionally not the primary path.

### 2. Minimal upstream feature set

The supplied `config_site.h` disables video and sound-device support to reduce build friction and external library sprawl. That keeps wheel creation practical.

If your application needs additional PJMEDIA features, expand `scripts/config_site.h` and the dependency install scripts deliberately.

### 3. Static-first upstream linking

The build scripts prefer static upstream linkage to reduce runtime sidecar libraries and keep `pip install` closer to a self-contained experience.

## Local build examples

### Linux

```bash
./scripts/install_linux_build_deps.sh
python -m pip install --upgrade pip build cibuildwheel
python -m cibuildwheel --platform linux --output-dir dist
```

If you run [scripts/build_pjsip_linux.sh](/home/ubuntu/dev/pjsua2-python/scripts/build_pjsip_linux.sh) directly, it now checks for required tools like `swig` before starting the long upstream compile.

For a host-built wheel plus `auditwheel` repair on the current machine:

```bash
./scripts/build_linux_wheel.sh
```

That helper produces a repaired wheel in `wheelhouse/` for the current host policy level.

### macOS

```bash
./scripts/install_macos_build_deps.sh
python -m pip install --upgrade pip build cibuildwheel delocate
python -m cibuildwheel --platform macos --output-dir dist
```

If you run [scripts/build_pjsip_macos.sh](/home/ubuntu/dev/pjsua2-python/scripts/build_pjsip_macos.sh) directly, it now checks for required tools before starting the build.

### Windows

```powershell
./scripts/install_windows_build_deps.ps1
py -m pip install --upgrade pip build cibuildwheel
py -m cibuildwheel --platform windows --output-dir dist
```

For a host-built Windows wheel after staging the native artifacts:

```powershell
./scripts/build_windows_wheel.ps1
```

The Windows build path now checks for `git`, `python`, `swig`, and either `msbuild` or `cl` before starting.

### macOS host wheel helper

```bash
./scripts/build_macos_wheel.sh
```

That helper builds the package on the current macOS host and runs `delocate` into `wheelhouse/`.

## Verify a wheel

```bash
python -m pip install dist/*.whl
python -c "import pjsua2; print(pjsua2.Endpoint())"
```

If you use the local Linux helper script above, install from `wheelhouse/*.whl` instead.

## GitHub Actions

The included workflow builds wheels on:

- `ubuntu-22.04`
- `macos-15-intel` for Intel
- `macos-14` for ARM
- `windows-2022`

For tagged releases, the workflow now does four things in order:

1. builds and tests all platform wheels
2. builds and validates the source distribution
3. creates a GitHub Release and attaches all wheels, the source tarball, and a `SHA256SUMS.txt` file
4. publishes the same artifacts to PyPI when trusted publishing or a token is configured

Artifacts are still uploaded as workflow artifacts during the run, but tagged releases now also produce a proper GitHub Release section with downloadable build outputs.

GitHub Actions is the release authority for distributable wheels. Local host wheel helpers are mainly for validation and debugging.

## Publishing

The full release and PyPI publishing procedure now lives in [publish.md](/home/ubuntu/dev/pjsua2-python/publish.md).

Keep the release order strict:

1. fix GitHub Actions until all build and release jobs are green
2. verify the generated artifacts on GitHub
3. only then configure or use PyPI publishing

## How `pip install` works for users

After the wheels are published to PyPI, users run:

```bash
pip install pjsua2-python
```

`pip` inspects the current machine:

- OS
- CPU architecture
- Python version

Then it downloads the matching wheel automatically. Users do not choose among the 20 wheels manually.

## Important caveats

### Linux compatibility

Linux wheels are built against `manylinux2014` to keep glibc compatibility broad.

Important distinction:

- Local wheels built on a normal host reflect that host libc and OpenSSL baseline.
- CI wheels built by `cibuildwheel` in the configured manylinux container are the portable artifacts you want to publish.

On this Ubuntu 24.04 host, the repaired local wheel validated successfully but landed at `manylinux_2_39_x86_64`, not `manylinux2014_x86_64`. That is expected for a host build and is exactly why the repo uses `cibuildwheel` for release artifacts.

### macOS compatibility

Apple Silicon and Intel are built separately in the workflow. If you prefer universal2 later, change the workflow and `CIBW_ARCHS` strategy.

### Windows build path

Windows is the most fragile target in the PJSIP ecosystem. The script here is structured for CI and upstream Python SWIG packaging, but you should expect occasional upstream breakage across Visual Studio and Python releases.

That is exactly why centralizing this in one repo is the right move.

### Local vs release builds

- Local helper scripts validate that the packaging flow works on a given machine.
- Release wheels should come from `cibuildwheel` in CI.
- On Linux specifically, the local repaired wheel policy reflects the host baseline, while CI should emit the intended `manylinux2014` wheels.
