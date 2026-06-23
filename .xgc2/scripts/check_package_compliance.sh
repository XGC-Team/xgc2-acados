#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${repo_root}"

bash -n .xgc2/scripts/*.sh

nested_git="$(
  find . \
    -path ./.git -prune -o \
    -path ./.ci -prune -o \
    -path ./third_party/acados -prune -o \
    -name .git -print
)"
if [[ -n "${nested_git}" ]]; then
  echo "Nested .git directory found. xgc2-acados must not vendor upstream source directly." >&2
  echo "${nested_git}" >&2
  exit 1
fi

if git ls-files | grep -E '(^|/)(build|devel|install|third_party/acados|\.acados_vendor|\.xgc2_acados|\.ci)(/|$)' >/dev/null; then
  echo "Generated build/vendor artifacts are tracked." >&2
  git ls-files | grep -E '(^|/)(build|devel|install|third_party/acados|\.acados_vendor|\.xgc2_acados|\.ci)(/|$)' >&2
  exit 1
fi

required_files=(
  README.md
  acados.lock
  .xgc2/product.yml
  .xgc2/scripts/build_acados.sh
  .xgc2/scripts/build_deb.sh
  .xgc2/scripts/fetch_acados.sh
  .xgc2/scripts/smoke_test_installed.sh
)

for file in "${required_files[@]}"; do
  if [[ ! -f "${file}" ]]; then
    echo "Missing required file: ${file}" >&2
    exit 1
  fi
done

grep -q '^version: 0.1.0-3$' .xgc2/product.yml
grep -q 'package_base_version="${PACKAGE_BASE_VERSION:-$(product_version)}"' .xgc2/scripts/build_deb.sh

if ! grep -q '^ACADOS_REF=' acados.lock; then
  echo "acados.lock must pin ACADOS_REF." >&2
  exit 1
fi

if git ls-files | grep -E '(^|/)(CMakeLists.txt|package.xml|env-hooks/|cmake/xgc2_acados-extras.cmake)$' >/dev/null; then
  echo "master branch must stay system-level and must not contain catkin package files." >&2
  git ls-files | grep -E '(^|/)(CMakeLists.txt|package.xml|env-hooks/|cmake/xgc2_acados-extras.cmake)$' >&2
  exit 1
fi

echo "xgc2-acados package compliance checks passed."
