#!/usr/bin/env bash

set -euo pipefail

package_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
workspace_dir="${ACADOS_VENDOR_WS:-${package_dir}/.ci/ws}"

rm -rf "${workspace_dir}/src/xgc2_acados"
mkdir -p "${workspace_dir}/src"
mkdir -p "${workspace_dir}/src/xgc2_acados"
tar \
  --exclude=.git \
  --exclude=.ci \
  --exclude=build \
  --exclude=devel \
  --exclude=install \
  --exclude=third_party/acados \
  -C "${package_dir}" \
  -cf - . | tar -x -C "${workspace_dir}/src/xgc2_acados"

source /opt/ros/noetic/setup.bash
cd "${workspace_dir}"
catkin_make --pkg xgc2_acados
