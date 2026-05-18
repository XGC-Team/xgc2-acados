#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${repo_root}"

xmllint --noout package.xml
bash -n scripts/*.sh

if find . -mindepth 2 -name .git -print -quit | grep -q .; then
  echo "Nested .git directory found. acados_vendor must not vendor submodules directly." >&2
  find . -mindepth 2 -name .git -print >&2
  exit 1
fi

if git ls-files | grep -E '(^|/)(build|devel|install|third_party/acados|\.acados_vendor)(/|$)' >/dev/null; then
  echo "Generated build/vendor artifacts are tracked." >&2
  git ls-files | grep -E '(^|/)(build|devel|install|third_party/acados|\.acados_vendor)(/|$)' >&2
  exit 1
fi

required_files=(
  package.xml
  CMakeLists.txt
  acados.lock
  cmake/acados_vendor-extras.cmake
  test/acados_vendor_probe.cpp
)

for file in "${required_files[@]}"; do
  if [[ ! -f "${file}" ]]; then
    echo "Missing required file: ${file}" >&2
    exit 1
  fi
done

if ! grep -q '^ACADOS_REF=' acados.lock; then
  echo "acados.lock must pin ACADOS_REF." >&2
  exit 1
fi

echo "acados_vendor package compliance checks passed."
