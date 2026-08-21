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
casadi_version="${CASADI_VERSION:-3.7.2}"
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

if [[ "${package_distribution}" == "bionic" && -z "${CASADI_VERSION:-}" ]]; then
  casadi_version="3.5.5"
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

python_vendor_dir="${stage_dir}${prefix}/python"
rm -rf "${python_vendor_dir}"
mkdir -p "${python_vendor_dir}"
# CasADi is provided by the XGC2 build image. Copy it into the package so
# product CI stays offline and does not pip-install.
python3 - "${python_vendor_dir}" "${casadi_version}" <<'PY'
import importlib
import pathlib
import shutil
import sys

dest = pathlib.Path(sys.argv[1])
expected = sys.argv[2]
dest.mkdir(parents=True, exist_ok=True)


def copytree_merge(source, destination):
    """Copy a directory into an existing tree on Python 3.6 and newer."""

    if not destination.exists():
        shutil.copytree(str(source), str(destination))
        return
    for child in source.iterdir():
        target = destination / child.name
        if child.is_dir():
            copytree_merge(child, target)
        else:
            shutil.copy2(str(child), str(target))

casadi = importlib.import_module("casadi")
if casadi.__version__ != expected:
    raise SystemExit(
        f"image CasADi {casadi.__version__} != required {expected}; "
        "use xgc2-build-*-dev"
    )
casadi_root = pathlib.Path(casadi.__file__).resolve().parent
copytree_merge(casadi_root, dest / "casadi")

deprecated = importlib.import_module("deprecated")
dep_file = pathlib.Path(deprecated.__file__).resolve()
dep_root = dep_file.parent if dep_file.name == "__init__.py" else dep_file
if dep_root.is_dir():
    copytree_merge(dep_root, dest / dep_root.name)
else:
    shutil.copy2(dep_root, dest / dep_root.name)

for name in ("dataclasses", "typing_extensions"):
    try:
        mod = importlib.import_module(name)
    except ImportError:
        continue
    path = pathlib.Path(mod.__file__).resolve()
    root = path.parent if path.name == "__init__.py" else path
    if root.is_dir():
        copytree_merge(root, dest / root.name)
    else:
        shutil.copy2(root, dest / path.name)

print(casadi.__version__, casadi_root)
PY

PYTHONPATH="${python_vendor_dir}" python3 - <<'PY'
import casadi
try:
    import dataclasses
except ImportError:
    dataclasses = None
import deprecated
try:
    import typing_extensions
except ImportError:
    typing_extensions = None
print(casadi.__file__)
if dataclasses is not None:
    print(dataclasses.__file__)
print(deprecated.__file__)
if typing_extensions is not None:
    print(typing_extensions.__file__)
PY

mkdir -p \
  "${pkg_root}/DEBIAN" \
  "${pkg_root}/etc/ld.so.conf.d" \
  "${pkg_root}/usr/lib/cmake/xgc2_acados" \
  "${pkg_root}/usr/share/doc/${package_name}"

cp -a "${stage_dir}/opt" "${pkg_root}/"

cat > "${pkg_root}/etc/ld.so.conf.d/xgc2-acados.conf" <<EOF
${prefix}/lib
EOF

cat > "${pkg_root}/usr/lib/cmake/xgc2_acados/xgc2_acadosConfig.cmake" <<'CMAKE'
if(DEFINED _XGC2_ACADOS_CONFIG_INCLUDED)
  return()
endif()
set(_XGC2_ACADOS_CONFIG_INCLUDED TRUE)

set(XGC2_ACADOS_ROOT "/opt/xgc2/acados")
set(XGC2_ACADOS_SOURCE_DIR "${XGC2_ACADOS_ROOT}")
set(XGC2_ACADOS_ACADOS_SOURCE_DIR "${XGC2_ACADOS_ROOT}")
set(XGC2_ACADOS_INSTALL_DIR "${XGC2_ACADOS_ROOT}")
set(XGC2_ACADOS_INSTALL_PREFIX "${XGC2_ACADOS_ROOT}")

set(XGC2_ACADOS_INCLUDE_DIRS
  "${XGC2_ACADOS_ROOT}/include"
  "${XGC2_ACADOS_ROOT}/include/blasfeo/include"
  "${XGC2_ACADOS_ROOT}/include/hpipm/include")

set(XGC2_ACADOS_LIBRARY_DIR "${XGC2_ACADOS_ROOT}/lib")
set(XGC2_ACADOS_LIBRARY_DIRS "${XGC2_ACADOS_LIBRARY_DIR}")
set(XGC2_ACADOS_LIBRARIES
  "${XGC2_ACADOS_LIBRARY_DIR}/libacados.so"
  "${XGC2_ACADOS_LIBRARY_DIR}/libblasfeo.so"
  "${XGC2_ACADOS_LIBRARY_DIR}/libhpipm.so"
  "${XGC2_ACADOS_LIBRARY_DIR}/libqpOASES_e.so"
  "${XGC2_ACADOS_LIBRARY_DIR}/libosqp.so"
  "${XGC2_ACADOS_LIBRARY_DIR}/libqdldl.so")

set(XGC2_ACADOS_T_RENDERER "${XGC2_ACADOS_ROOT}/bin/t_renderer")
set(XGC2_ACADOS_PYTHON_VENDOR_PATH "${XGC2_ACADOS_ROOT}/python")
set(XGC2_ACADOS_PYTHON_INTERFACE_PATH
  "${XGC2_ACADOS_ROOT}/interfaces/acados_template/acados_template")
get_filename_component(XGC2_ACADOS_PYTHONPATH
  "${XGC2_ACADOS_PYTHON_INTERFACE_PATH}" DIRECTORY)
set(XGC2_ACADOS_PYTHONPATH
  "${XGC2_ACADOS_PYTHON_VENDOR_PATH}"
  "${XGC2_ACADOS_PYTHONPATH}")
set(XGC2_ACADOS_PYTHON_PATH "${XGC2_ACADOS_PYTHONPATH}")
set(XGC2_ACADOS_RUNTIME_LIBRARY_DIRS "${XGC2_ACADOS_LIBRARY_DIR}")
set(XGC2_ACADOS_COMPILE_DEFINITIONS ACADOS_WITH_OSQP ACADOS_WITH_QPOASES)

macro(xgc2_acados_require)
  foreach(_xgc2_acados_include IN LISTS XGC2_ACADOS_INCLUDE_DIRS)
    if(NOT EXISTS "${_xgc2_acados_include}")
      message(FATAL_ERROR "xgc2-acados include path is missing: ${_xgc2_acados_include}")
    endif()
  endforeach()
  foreach(_xgc2_acados_library IN LISTS XGC2_ACADOS_LIBRARIES)
    if(NOT EXISTS "${_xgc2_acados_library}")
      message(FATAL_ERROR "xgc2-acados library is missing: ${_xgc2_acados_library}")
    endif()
  endforeach()
  foreach(_xgc2_acados_definition IN LISTS XGC2_ACADOS_COMPILE_DEFINITIONS)
    add_definitions("-D${_xgc2_acados_definition}")
  endforeach()
endmacro()

set(ACADOS_VENDOR_INSTALL_DIR "${XGC2_ACADOS_ROOT}")
set(ACADOS_VENDOR_SOURCE_DIR "${XGC2_ACADOS_ROOT}")
set(ACADOS_VENDOR_INCLUDE_DIRS "${XGC2_ACADOS_INCLUDE_DIRS}")
set(ACADOS_VENDOR_LIBRARY_DIR "${XGC2_ACADOS_LIBRARY_DIR}")
set(ACADOS_VENDOR_LIBRARY_DIRS "${XGC2_ACADOS_LIBRARY_DIRS}")
set(ACADOS_VENDOR_LIBRARIES "${XGC2_ACADOS_LIBRARIES}")
set(ACADOS_VENDOR_PYTHON_INTERFACE_PATH "${XGC2_ACADOS_PYTHON_INTERFACE_PATH}")
set(ACADOS_VENDOR_PYTHONPATH "${XGC2_ACADOS_PYTHONPATH}")
set(ACADOS_VENDOR_COMPILE_DEFINITIONS "${XGC2_ACADOS_COMPILE_DEFINITIONS}")
set(ACADOS_VENDOR_RUNTIME_LIBRARY_DIRS "${XGC2_ACADOS_RUNTIME_LIBRARY_DIRS}")
macro(acados_vendor_require)
  xgc2_acados_require()
endmacro()
CMAKE

cat > "${pkg_root}/DEBIAN/control" <<EOF
Package: ${package_name}
Version: ${version}
Section: devel
Priority: optional
Architecture: ${arch}
Maintainer: XGC2 <apt@example.com>
Depends: libc6, $(if [[ "${package_distribution}" == "bionic" ]]; then printf 'libgcc1'; else printf 'libgcc-s1'; fi), libgomp1, libstdc++6, libblas-dev, python3, python3-matplotlib, python3-numpy, python3-scipy, python3-wrapt
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
find "${pkg_root}${prefix}" -type f \( -name '*.so' -o -name '*.so.*' -o -perm -0100 \) \
  -exec strip --strip-unneeded {} + 2>/dev/null || true

fakeroot dpkg-deb --build "${pkg_root}" "${output_dir}/${package_name}_${version}_${arch}.deb" >/dev/null
dpkg-deb -I "${output_dir}/${package_name}_${version}_${arch}.deb"
echo "Debian artifacts written to ${output_dir}"
