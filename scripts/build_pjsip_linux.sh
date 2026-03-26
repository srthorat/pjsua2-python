#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_ROOT="${ROOT_DIR}/build"
PJPROJECT_DIR="${BUILD_ROOT}/pjproject"
SWIG_DIR="${PJPROJECT_DIR}/pjsip-apps/src/swig/python"
OPENSSL_COMPAT_HEADER="${ROOT_DIR}/scripts/openssl_compat_1_0.h"
PYTHON_BIN="${PYTHON:-python}"
PACKAGE_VERSION="$(${PYTHON_BIN} "${ROOT_DIR}/scripts/get_package_version.py")"
PJSIP_REF="${PJSIP_REF:-${PACKAGE_VERSION}}"

bash "${ROOT_DIR}/scripts/check_linux_build_tools.sh"

mkdir -p "${BUILD_ROOT}"

if [[ ! -d "${PJPROJECT_DIR}/.git" ]]; then
  git clone https://github.com/pjsip/pjproject.git "${PJPROJECT_DIR}"
fi

git -C "${PJPROJECT_DIR}" fetch --tags --force origin
git -C "${PJPROJECT_DIR}" checkout --force "${PJSIP_REF}"
git -C "${PJPROJECT_DIR}" clean -fdx

cp "${ROOT_DIR}/scripts/config_site.h" "${PJPROJECT_DIR}/pjlib/include/pj/config_site.h"

pushd "${PJPROJECT_DIR}" >/dev/null
export CFLAGS="${CFLAGS:-} -fPIC -O2 -include ${OPENSSL_COMPAT_HEADER}"
export CXXFLAGS="${CXXFLAGS:-} -fPIC -O2"
./configure --disable-shared --disable-sound --disable-video
make dep
make -j"$(getconf _NPROCESSORS_ONLN)" lib
popd >/dev/null

pushd "${SWIG_DIR}" >/dev/null
# setuptools (and distutils shim) was removed from Python 3.12 stdlib; ensure
# it is available for whichever interpreter cibuildwheel selected.
"${PYTHON_BIN}" -m pip install --quiet setuptools
make clean || true
make PYTHON_EXE="${PYTHON_BIN}"
while IFS= read -r extension_path; do
  patchelf --set-rpath '$ORIGIN' "${extension_path}" || true
done < <(find build -type f -name '_pjsua2*.so' -print)
popd >/dev/null

"${PYTHON_BIN}" "${ROOT_DIR}/scripts/stage_bindings.py" \
  --source-dir "${SWIG_DIR}" \
  --package-dir "${ROOT_DIR}/pjsua2"
