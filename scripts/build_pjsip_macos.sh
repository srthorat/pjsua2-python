#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_ROOT="${ROOT_DIR}/build"
PJPROJECT_DIR="${BUILD_ROOT}/pjproject"
SWIG_DIR="${PJPROJECT_DIR}/pjsip-apps/src/swig/python"
PYTHON_BIN="${PYTHON:-python}"
PACKAGE_VERSION="$(${PYTHON_BIN} "${ROOT_DIR}/scripts/get_package_version.py")"
PJSIP_REF="${PJSIP_REF:-${PACKAGE_VERSION}}"
CPU_COUNT="$(sysctl -n hw.ncpu)"
ARCH_FLAGS="${ARCHFLAGS:-}"
OPENSSL_PREFIX="$(brew --prefix openssl@3)"

bash "${ROOT_DIR}/scripts/check_macos_build_tools.sh"

mkdir -p "${BUILD_ROOT}"

if [[ ! -d "${PJPROJECT_DIR}/.git" ]]; then
  git clone https://github.com/pjsip/pjproject.git "${PJPROJECT_DIR}"
fi

git -C "${PJPROJECT_DIR}" fetch --tags --force origin
git -C "${PJPROJECT_DIR}" checkout --force "${PJSIP_REF}"
git -C "${PJPROJECT_DIR}" clean -fdx

cp "${ROOT_DIR}/scripts/config_site.h" "${PJPROJECT_DIR}/pjlib/include/pj/config_site.h"

pushd "${PJPROJECT_DIR}" >/dev/null
export CFLAGS="${CFLAGS:-} ${ARCH_FLAGS} -fPIC -O2"
export CXXFLAGS="${CXXFLAGS:-} ${ARCH_FLAGS} -fPIC -O2"
export LDFLAGS="${LDFLAGS:-} ${ARCH_FLAGS} -L${OPENSSL_PREFIX}/lib"
export CPPFLAGS="${CPPFLAGS:-} -I${OPENSSL_PREFIX}/include"
./configure --disable-shared --disable-sound --disable-video
make dep
make -j"${CPU_COUNT}" lib
popd >/dev/null

pushd "${SWIG_DIR}" >/dev/null
make clean || true
make PYTHON="${PYTHON_BIN}"
while IFS= read -r extension_path; do
  install_name_tool -add_rpath @loader_path "${extension_path}" || true
done < <(find build -type f -name '_pjsua2*.so' -print)
popd >/dev/null

"${PYTHON_BIN}" "${ROOT_DIR}/scripts/stage_bindings.py" \
  --source-dir "${SWIG_DIR}" \
  --package-dir "${ROOT_DIR}/pjsua2"
