#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/../.." && pwd)"

package_name="xgc2-acados"
product_version() {
  sed -n 's/^version:[[:space:]]*//p' "${repo_root}/.xgc2/product.yml" | head -n 1
}

package_base_version="${PACKAGE_BASE_VERSION:-$(product_version)}"
package_distribution="${PACKAGE_DISTRIBUTION:-}"
prefix="${XGC2_ACADOS_PREFIX:-/opt/xgc2/acados}"
stage_dir="${XGC2_ACADOS_STAGE_DIR:-${repo_root}/.ci/stage}"
output_dir="${XGC2_ACADOS_DEB_OUTPUT_DIR:-${repo_root}/debs}"
pkg_root="${repo_root}/.ci/pkg/${package_name}"
arch="$(dpkg --print-architecture)"

if [[ -z "${package_distribution}" && -r /etc/os-release ]]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  package_distribution="${VERSION_CODENAME:-${UBUNTU_CODENAME:-}}"
fi

if [[ -n "${PACKAGE_VERSION:-}" ]]; then
  version="${PACKAGE_VERSION}"
else
  if [[ -z "${package_distribution}" ]]; then
    echo "PACKAGE_DISTRIBUTION or VERSION_CODENAME is required for binary Debian package versioning" >&2
    exit 1
  fi
  version="${package_base_version}~${package_distribution}"
fi

if [[ -n "${package_distribution}" && "${ALLOW_UNSCOPED_BINARY_DEB_VERSION:-0}" != "1" ]]; then
  case "${version}" in
    *"~${package_distribution}"*|*"+"${package_distribution}*) ;;
    *)
      echo "binary Debian package version '${version}' must include distribution suffix '${package_distribution}'" >&2
      echo "set ALLOW_UNSCOPED_BINARY_DEB_VERSION=1 only for a deliberately distro-neutral artifact" >&2
      exit 1
      ;;
  esac
fi

rm -rf "${stage_dir}" "${output_dir}" "${pkg_root}"
mkdir -p "${output_dir}"

"${script_dir}/build_acados.sh"

"${script_dir}/stage_sdk.sh" "${stage_dir}" "${pkg_root}"
mkdir -p "${pkg_root}/DEBIAN" "${pkg_root}/usr/share/doc/${package_name}"

cat > "${pkg_root}/DEBIAN/control" <<EOF
Package: ${package_name}
Version: ${version}
Section: devel
Priority: optional
Architecture: ${arch}
Maintainer: XGC2 <apt@example.com>
Depends: libc6, $(if [[ "${package_distribution}" == "bionic" ]]; then printf 'libgcc1'; else printf 'libgcc-s1'; fi), libgomp1, libstdc++6, libblas-dev, python3, python3-numpy, python3-scipy
Conflicts: ros-noetic-xgc2-acados
Replaces: ros-noetic-xgc2-acados
Description: XGC2 packaged acados solver stack
 System-level acados headers, shared libraries, t_renderer, Python templates,
 vendored CasADi Python module, MATLAB setup helper, and CMake package
 configuration for XGC2 projects.
EOF

cat > "${pkg_root}/DEBIAN/postinst" <<'SH'
#!/bin/sh
set -e
if command -v ldconfig >/dev/null 2>&1; then
  ldconfig
fi
SH
cat > "${pkg_root}/DEBIAN/postrm" <<'SH'
#!/bin/sh
set -e
if command -v ldconfig >/dev/null 2>&1; then
  ldconfig
fi
SH
chmod 0755 "${pkg_root}/DEBIAN/postinst" "${pkg_root}/DEBIAN/postrm"

cp -a "${repo_root}/README.md" "${repo_root}/acados.lock" "${pkg_root}/usr/share/doc/${package_name}/"

find "${pkg_root}" -type d -exec chmod 0755 {} +
find "${pkg_root}" -type f -exec chmod 0644 {} +
chmod 0755 "${pkg_root}/DEBIAN" "${pkg_root}/DEBIAN/postinst" "${pkg_root}/DEBIAN/postrm"
chmod 0755 "${pkg_root}${prefix}/setup.bash" "${pkg_root}${prefix}/bin/t_renderer"
if [[ "${package_distribution}" == bionic ]]; then
  find "${pkg_root}${prefix}/codegen-python/bin" -type f -name 'python3*' -exec chmod 0755 {} +
fi
find "${pkg_root}${prefix}" -type f \( -name '*.so' -o -name '*.so.*' -o -perm -0100 \) \
  -exec strip --strip-unneeded {} + 2>/dev/null || true

fakeroot dpkg-deb --build "${pkg_root}" "${output_dir}/${package_name}_${version}_${arch}.deb" >/dev/null
dpkg-deb -I "${output_dir}/${package_name}_${version}_${arch}.deb"
echo "Debian artifacts written to ${output_dir}"
