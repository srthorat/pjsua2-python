#!/usr/bin/env bash
set -euo pipefail

missing=()

for tool in git make clang clang++ swig brew; do
  if ! command -v "${tool}" >/dev/null 2>&1; then
    missing+=("${tool}")
  fi
done

if [[ ${#missing[@]} -gt 0 ]]; then
  printf 'Missing required macOS build tools: %s\n' "${missing[*]}" >&2
  printf 'Run scripts/install_macos_build_deps.sh and ensure Xcode Command Line Tools are installed before running this script.\n' >&2
  exit 1
fi
