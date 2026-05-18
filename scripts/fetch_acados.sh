#!/usr/bin/env bash

set -euo pipefail

repo="${ACADOS_VENDOR_GIT_REPOSITORY:?}"
tag="${ACADOS_VENDOR_GIT_TAG:?}"
source_dir="${ACADOS_VENDOR_SOURCE_DIR:?}"
max_attempts="${ACADOS_VENDOR_FETCH_ATTEMPTS:-5}"

retry() {
  local description="$1"
  shift
  local attempt=1
  while true; do
    if "$@"; then
      return 0
    fi
    if (( attempt >= max_attempts )); then
      echo "Failed ${description} after ${attempt} attempts." >&2
      return 1
    fi
    echo "Retrying ${description} after attempt ${attempt}/${max_attempts}..." >&2
    sleep $((attempt * 5))
    attempt=$((attempt + 1))
  done
}

reset_acados_submodules() {
  rm -rf \
    examples/acados_python/tests/test_data \
    external/Clarabel.cpp \
    external/blasfeo \
    external/catch \
    external/daqp \
    external/hpipm \
    external/hpmpc \
    external/jsonlab \
    external/osqp \
    external/qpdunes \
    external/qpoases \
    interfaces/acados_template/tera_renderer
}

check_acados_submodules() {
  test -f external/blasfeo/CMakeLists.txt
  test -f external/hpipm/CMakeLists.txt
  test -f external/osqp/CMakeLists.txt
  test -f external/qpoases/CMakeLists.txt
  test -f external/catch/CMakeLists.txt
  test -f interfaces/acados_template/tera_renderer/Cargo.toml
}

source_is_ready() {
  git rev-parse --verify HEAD >/dev/null
  test "$(git rev-parse HEAD)" = "${tag}"
  check_acados_submodules
}

update_acados_submodules() {
  local attempt=1
  while true; do
    if git submodule update --init --recursive --jobs 1 && check_acados_submodules; then
      return 0
    fi
    if (( attempt >= max_attempts )); then
      echo "Failed update acados submodules after ${attempt} attempts." >&2
      return 1
    fi
    echo "Retrying update acados submodules after attempt ${attempt}/${max_attempts}..." >&2
    reset_acados_submodules
    sleep $((attempt * 5))
    attempt=$((attempt + 1))
  done
}

if [[ ! -d "${source_dir}/.git" ]]; then
  rm -rf "${source_dir}"
  mkdir -p "$(dirname "${source_dir}")"
  retry "clone acados" git clone "${repo}" "${source_dir}"
fi

cd "${source_dir}"

if source_is_ready; then
  echo "acados source already available at ${tag}; skipping fetch."
  exit 0
fi

retry "fetch acados refs" git fetch --tags --force origin
retry "checkout acados ${tag}" git checkout --force "${tag}"

git submodule sync --recursive
update_acados_submodules
