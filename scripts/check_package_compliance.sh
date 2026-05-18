#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${repo_root}"

xmllint --noout package.xml
bash -n scripts/*.sh

nested_git="$(
  find . \
    -path ./.git -prune -o \
    -path ./.ci -prune -o \
    -path ./build -prune -o \
    -path ./devel -prune -o \
    -path ./install -prune -o \
    -name .git -print
)"
if [[ -n "${nested_git}" ]]; then
  echo "Nested .git directory found. acados_vendor must not vendor submodules directly." >&2
  echo "${nested_git}" >&2
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
