#!/usr/bin/env bash
# Local validation script: runs cibuildwheel for cp312 Linux only.
# Uses the same manylinux2014 Docker image as CI so failures surface identically.
#
# Usage:
#   bash scripts/test_local_cp312.sh
#
# Prerequisites:
#   - Docker running  (sudo systemctl start docker)
#   - cibuildwheel installed  (sudo pip3 install --break-system-packages cibuildwheel)
#
# The built wheel lands in dist/ when successful.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "==> Checking prerequisites..."
if ! command -v docker &>/dev/null; then
  echo "ERROR: docker not found. Install with: sudo apt-get install -y docker.io && sudo systemctl start docker"
  exit 1
fi
# Allow sudo docker if the user isn't in the docker group yet
DOCKER="docker"
if ! docker info &>/dev/null 2>&1; then
  if sudo docker info &>/dev/null 2>&1; then
    DOCKER="sudo docker"
    export DOCKER_HOST=""
  else
    echo "ERROR: Docker daemon not reachable. Try: sudo systemctl start docker  (or add yourself to the docker group and re-login)"
    exit 1
  fi
fi
if ! command -v cibuildwheel &>/dev/null && ! python3 -m cibuildwheel --version &>/dev/null 2>&1; then
  echo "ERROR: cibuildwheel not found. Install with: sudo pip3 install --break-system-packages cibuildwheel"
  exit 1
fi

echo "==> Building cp312 Linux wheel (manylinux2014) ..."
echo "    Project : ${ROOT_DIR}"
echo "    Output  : ${ROOT_DIR}/dist/"
echo

cd "${ROOT_DIR}"

# Override the build target to cp312 only; keep all other settings from pyproject.toml
CIBW_BUILD="cp312-*" \
PJSIP_REF="$(python3 scripts/get_package_version.py)" \
  python3 -m cibuildwheel --platform linux --output-dir dist

echo
echo "==> Done. Wheel(s) in dist/:"
ls -lh dist/*.whl 2>/dev/null || echo "  (no .whl files found — build may have failed)"
