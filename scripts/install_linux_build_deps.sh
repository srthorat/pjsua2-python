#!/usr/bin/env bash
set -euo pipefail

if command -v dnf >/dev/null 2>&1; then
  dnf install -y git make gcc gcc-c++ python3-devel swig openssl-devel patchelf
  exit 0
fi

if command -v yum >/dev/null 2>&1; then
  yum install -y git make gcc gcc-c++ python3-devel swig openssl-devel patchelf
  exit 0
fi

if command -v apt-get >/dev/null 2>&1; then
  apt-get update
  apt-get install -y git build-essential python3-dev swig libssl-dev patchelf
  exit 0
fi

echo "Unsupported Linux package manager for dependency bootstrap" >&2
exit 1
