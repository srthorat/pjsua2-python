#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_ROOT="${ROOT_DIR}/build"
PJPROJECT_DIR="${BUILD_ROOT}/pjproject"
SWIG_DIR="${PJPROJECT_DIR}/pjsip-apps/src/swig/python"
PYTHON_BIN="${PYTHON:-python}"
PJSIP_REF="$(${PYTHON_BIN} "${ROOT_DIR}/scripts/get_pjsip_ref.py")"
CPU_COUNT="$(sysctl -n hw.ncpu)"
ARCH_FLAGS="${ARCHFLAGS:-}"
OPENSSL_PREFIX="$(brew --prefix openssl@3)"
MACOSX_DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET:-$(sw_vers -productVersion | cut -d. -f1).0}"

bash "${ROOT_DIR}/scripts/check_macos_build_tools.sh"

mkdir -p "${BUILD_ROOT}"

if [[ ! -d "${PJPROJECT_DIR}/.git" ]]; then
  git clone https://github.com/pjsip/pjproject.git "${PJPROJECT_DIR}"
fi

git -C "${PJPROJECT_DIR}" fetch --tags --force origin
git -C "${PJPROJECT_DIR}" checkout --force "${PJSIP_REF}"
git -C "${PJPROJECT_DIR}" clean -fdx

cp "${ROOT_DIR}/scripts/config_site.h" "${PJPROJECT_DIR}/pjlib/include/pj/config_site.h"

# pjproject 2.10 bundles WebRTC with SSE2-only sources (aec_core_sse2.c,
# aec_rdft_sse2.c). In pjproject 2.10, third_party/build always compiles
# the WebRTC library regardless of PJMEDIA_HAS_WEBRTC_AEC -- that variable
# only controls whether pjmedia *links* against it. Neither --disable-webrtc
# nor passing PJMEDIA_HAS_WEBRTC_AEC=0 to make prevents compilation on arm64.
# The only reliable fix is to stub those source files with empty C units
# after checkout. aec_core.c only references SSE2 symbols under -DWEBRTC_USE_SSE2
# which is not set on arm64 builds, so empty stubs produce no missing symbols.
if [[ "$(uname -m)" == "arm64" ]] || echo "${ARCH_FLAGS}" | grep -q "arm64"; then
    for _sse2 in \
        "third_party/webrtc/src/webrtc/modules/audio_processing/aec/aec_core_sse2.c" \
        "third_party/webrtc/src/webrtc/modules/audio_processing/aec/aec_rdft_sse2.c"; do
        [[ -f "${PJPROJECT_DIR}/${_sse2}" ]] && \
            echo "/* arm64: SSE2 not supported, stubbed out */" > "${PJPROJECT_DIR}/${_sse2}"
    done
fi

pushd "${PJPROJECT_DIR}" >/dev/null
export MACOSX_DEPLOYMENT_TARGET
export CFLAGS="${CFLAGS:-} ${ARCH_FLAGS} -fPIC -O2 -I${OPENSSL_PREFIX}/include"
export CXXFLAGS="${CXXFLAGS:-} ${ARCH_FLAGS} -fPIC -O2 -I${OPENSSL_PREFIX}/include"
export CPPFLAGS="${CPPFLAGS:-} -I${OPENSSL_PREFIX}/include"
export LDFLAGS="${LDFLAGS:-} ${ARCH_FLAGS} -L${OPENSSL_PREFIX}/lib"
export PKG_CONFIG_PATH="${OPENSSL_PREFIX}/lib/pkgconfig${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}"
./configure --disable-shared --disable-sound --disable-video
make dep
make -j"${CPU_COUNT}" lib
popd >/dev/null

pushd "${SWIG_DIR}" >/dev/null
# setuptools (and distutils shim) was removed from Python 3.12 stdlib; ensure
# it is available for whichever interpreter cibuildwheel selected.
"${PYTHON_BIN}" -m pip install --quiet setuptools
make clean || true
make PYTHON_EXE="${PYTHON_BIN}"
while IFS= read -r extension_path; do
  install_name_tool -add_rpath @loader_path "${extension_path}" || true
done < <(find build -type f -name '_pjsua2*.so' -print)
popd >/dev/null

"${PYTHON_BIN}" "${ROOT_DIR}/scripts/stage_bindings.py" \
  --source-dir "${SWIG_DIR}" \
  --package-dir "${ROOT_DIR}/pjsua2"
