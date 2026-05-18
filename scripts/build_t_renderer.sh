#!/usr/bin/env bash

set -euo pipefail

workspace_dir="${ACADOS_VENDOR_WS:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/.ci/ws}"
acados_dir="${ACADOS_VENDOR_ACADOS_SOURCE_DIR:-${workspace_dir}/devel/.acados_vendor/src/acados}"
renderer_dir="${acados_dir}/interfaces/acados_template/tera_renderer"
renderer_bin="${acados_dir}/bin/t_renderer"

if [[ ! -f "${renderer_dir}/Cargo.toml" ]]; then
  echo "tera_renderer source not found at ${renderer_dir}" >&2
  echo "Build acados first with scripts/build_acados.sh." >&2
  exit 1
fi

if ! command -v cargo >/dev/null 2>&1; then
  echo "cargo not found. Install Rust before rebuilding t_renderer." >&2
  exit 1
fi

cargo build --manifest-path "${renderer_dir}/Cargo.toml" --release
mkdir -p "$(dirname "${renderer_bin}")"
cp "${renderer_dir}/target/release/t_renderer" "${renderer_bin}"
chmod +x "${renderer_bin}"
ldd "${renderer_bin}" | grep libc.so || true
