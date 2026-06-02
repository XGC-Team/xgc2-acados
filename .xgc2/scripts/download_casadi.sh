#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
package_dir="$(cd "${script_dir}/../.." && pwd)"
workspace_dir="${ACADOS_VENDOR_WS:-${package_dir}/.ci/ws}"
acados_dir="${ACADOS_VENDOR_ACADOS_SOURCE_DIR:-${workspace_dir}/src/xgc2_acados/third_party/acados}"
external_dir="${acados_dir}/external"
casadi_version="${CASADI_VERSION:-3.7.2}"
casadi_archive="casadi-${casadi_version}-linux64-matlab2018b.zip"
casadi_url="https://github.com/casadi/casadi/releases/download/${casadi_version}/${casadi_archive}"
casadi_dir="${external_dir}/casadi-matlab"

if [[ ! -d "${external_dir}" ]]; then
  echo "acados external directory not found: ${external_dir}" >&2
  echo "Build acados first with scripts/build_acados.sh." >&2
  exit 1
fi

cd "${external_dir}"
if [[ ! -f "${casadi_archive}" ]]; then
  wget -q --show-progress "${casadi_url}" -O "${casadi_archive}"
fi

rm -rf "${casadi_dir}"
mkdir -p "${casadi_dir}"
unzip -q "${casadi_archive}" -d "${casadi_dir}"
echo "CasADi installed to ${casadi_dir}"
