#!/usr/bin/env bash
# Native controller runtime only; SDK headers, code generators and optional
# third-party solver plugins remain in the builder's SDK.
set -euo pipefail
stage="${1:?usage: stage_runtime.sh NATIVE_INSTALL_ROOT DESTINATION_ROOT}"
output="${2:?destination root}"
prefix="${XGC2_ACADOS_PREFIX:-/opt/xgc2/acados}"
test -f "$stage$prefix/lib/libacados.so"
mkdir -p "$output$prefix/lib" "$output/etc/ld.so.conf.d"
find "$stage$prefix/lib" -maxdepth 1 \( -type f -o -type l \) -name '*.so*' \
  -exec cp -a -t "$output$prefix/lib" {} +
cp "$stage$prefix/setup.bash" "$output$prefix/setup.bash"
printf '%s\n' "$prefix/lib" > "$output/etc/ld.so.conf.d/xgc2-acados.conf"
