#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PYTHON_BIN="${PYTHON:-python}"
WHEELHOUSE_DIR="${ROOT_DIR}/wheelhouse"

bash "${ROOT_DIR}/scripts/build_pjsip_linux.sh"

"${PYTHON_BIN}" -m pip install --user build auditwheel >/dev/null

rm -rf "${ROOT_DIR}/dist" "${WHEELHOUSE_DIR}"
"${PYTHON_BIN}" -m build --wheel
"${PYTHON_BIN}" -m auditwheel repair -w "${WHEELHOUSE_DIR}" "${ROOT_DIR}"/dist/*.whl

printf 'Built wheel(s):\n'
find "${WHEELHOUSE_DIR}" -maxdepth 1 -type f -name '*.whl' -print | sort
