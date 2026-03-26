#!/usr/bin/env bash
set -euo pipefail

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew is required on macOS runners" >&2
  exit 1
fi

brew update
brew install swig autoconf automake libtool openssl@3
