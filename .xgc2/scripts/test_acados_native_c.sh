#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/../.." && pwd)"

source_dir="${XGC2_ACADOS_SOURCE_CACHE:-${repo_root}/third_party/acados}"
build_dir="${XGC2_ACADOS_NATIVE_TEST_BUILD_DIR:-${repo_root}/.ci/build/acados-native-c}"
install_prefix="${XGC2_ACADOS_NATIVE_TEST_INSTALL_PREFIX:-${repo_root}/.ci/native-c-install}"
jobs="${ACADOS_NATIVE_TEST_JOBS:-${ACADOS_VENDOR_JOBS:-2}}"

read_lock() {
  local key="$1"
  local default_value="$2"
  local value
  value="$(grep -E "^${key}=" "${repo_root}/acados.lock" | tail -n1 | cut -d= -f2- || true)"
  if [[ -z "${value}" ]]; then
    value="${default_value}"
  fi
  printf '%s\n' "${value}"
}

acados_repository="$(read_lock ACADOS_REPOSITORY https://github.com/acados/acados.git)"
acados_ref="$(read_lock ACADOS_REF main)"
acados_sha="$(read_lock ACADOS_SHA "")"
acados_with_qpoases="$(read_lock ACADOS_WITH_QPOASES ON)"
acados_with_osqp="$(read_lock ACADOS_WITH_OSQP ON)"
blasfeo_target="$(read_lock BLASFEO_TARGET X64_AUTOMATIC)"
hpipm_target="$(read_lock HPIPM_TARGET GENERIC)"

if [[ -n "${acados_sha}" ]]; then
  acados_git_tag="${acados_sha}"
else
  acados_git_tag="${acados_ref}"
fi

export ACADOS_VENDOR_GIT_REPOSITORY="${acados_repository}"
export ACADOS_VENDOR_GIT_TAG="${acados_git_tag}"
export ACADOS_VENDOR_SOURCE_DIR="${source_dir}"
"${script_dir}/fetch_acados.sh"

rm -rf "${build_dir}" "${install_prefix}"
mkdir -p "${build_dir}" "${install_prefix}"

cmake -S "${source_dir}" -B "${build_dir}" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="${install_prefix}" \
  -DACADOS_WITH_PYTHON=OFF \
  -DACADOS_WITH_QPOASES="${acados_with_qpoases}" \
  -DACADOS_WITH_OSQP="${acados_with_osqp}" \
  -DACADOS_UNIT_TESTS=ON \
  -DACADOS_OCTAVE=OFF \
  -DBLASFEO_TARGET="${blasfeo_target}" \
  -DHPIPM_TARGET="${hpipm_target}" \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5

cmake --build "${build_dir}" --config Release -- -j"${jobs}"
cmake --install "${build_dir}" --config Release

export ACADOS_SOURCE_DIR="${install_prefix}"
export ACADOS_INSTALL_DIR="${install_prefix}"
export LD_LIBRARY_PATH="${install_prefix}/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"

ctest --test-dir "${build_dir}" -C Release --output-on-failure -j"${jobs}"
