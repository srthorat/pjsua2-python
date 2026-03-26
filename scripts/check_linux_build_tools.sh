#!/usr/bin/env bash
set -euo pipefail

missing=()

for tool in git make gcc g++ swig; do
  if ! command -v "${tool}" >/dev/null 2>&1; then
    missing+=("${tool}")
  fi
done

if [[ ${#missing[@]} -gt 0 ]]; then
  printf 'Missing required Linux build tools: %s\n' "${missing[*]}" >&2
  printf 'Run scripts/install_linux_build_deps.sh in a suitable build environment before running this script.\n' >&2
  exit 1
fi
