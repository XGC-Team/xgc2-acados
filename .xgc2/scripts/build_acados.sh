#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/../.." && pwd)"

prefix="${XGC2_ACADOS_PREFIX:-/opt/xgc2/acados}"
stage_dir="${XGC2_ACADOS_STAGE_DIR:-${repo_root}/.ci/stage}"
source_dir="${XGC2_ACADOS_SOURCE_CACHE:-${repo_root}/third_party/acados}"
build_dir="${XGC2_ACADOS_BUILD_DIR:-${repo_root}/.ci/build/acados}"
install_prefix="${stage_dir}${prefix}"

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
  -DACADOS_UNIT_TESTS=OFF \
  -DBLASFEO_TARGET="${blasfeo_target}" \
  -DHPIPM_TARGET="${hpipm_target}"

cmake --build "${build_dir}" --target install -- -j"${ACADOS_VENDOR_JOBS:-2}"

export ACADOS_VENDOR_ACADOS_SOURCE_DIR="${source_dir}"
export ACADOS_VENDOR_T_RENDERER_OUTPUT="${install_prefix}/bin/t_renderer"
"${script_dir}/build_t_renderer.sh"

mkdir -p \
  "${install_prefix}/interfaces/acados_template" \
  "${install_prefix}/interfaces" \
  "${install_prefix}/lib"

cp -a \
  "${source_dir}/interfaces/acados_template/acados_template" \
  "${install_prefix}/interfaces/acados_template/"

for matlab_dir in acados_matlab_octave acados_matlab; do
  if [[ -d "${source_dir}/interfaces/${matlab_dir}" ]]; then
    cp -a "${source_dir}/interfaces/${matlab_dir}" "${install_prefix}/interfaces/"
  fi
done

for metadata in link_libs.json git_commit_hash; do
  if [[ -f "${source_dir}/lib/${metadata}" ]]; then
    cp -a "${source_dir}/lib/${metadata}" "${install_prefix}/lib/${metadata}"
  fi
done

cat > "${install_prefix}/setup.bash" <<'BASH'
#!/usr/bin/env bash
export ACADOS_SOURCE_DIR="${ACADOS_SOURCE_DIR:-/opt/xgc2/acados}"
export ACADOS_INSTALL_DIR="${ACADOS_INSTALL_DIR:-${ACADOS_SOURCE_DIR}}"
export ACADOS_PYTHON_INTERFACE_PATH="${ACADOS_PYTHON_INTERFACE_PATH:-${ACADOS_SOURCE_DIR}/interfaces/acados_template/acados_template}"
export TERA_PATH="${TERA_PATH:-${ACADOS_SOURCE_DIR}/bin/t_renderer}"
case ":${PYTHONPATH:-}:" in
  *":${ACADOS_SOURCE_DIR}/interfaces/acados_template:"*) ;;
  *) export PYTHONPATH="${ACADOS_SOURCE_DIR}/interfaces/acados_template${PYTHONPATH:+:${PYTHONPATH}}" ;;
esac
case ":${PYTHONPATH:-}:" in
  *":${ACADOS_SOURCE_DIR}/python:"*) ;;
  *) export PYTHONPATH="${ACADOS_SOURCE_DIR}/python${PYTHONPATH:+:${PYTHONPATH}}" ;;
esac
case ":${LD_LIBRARY_PATH:-}:" in
  *":${ACADOS_SOURCE_DIR}/lib:"*) ;;
  *) export LD_LIBRARY_PATH="${ACADOS_SOURCE_DIR}/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}" ;;
esac
BASH
chmod 0755 "${install_prefix}/setup.bash"

cat > "${install_prefix}/setup_acados.m" <<'MATLAB'
acados_root = '/opt/xgc2/acados';
setenv('ACADOS_SOURCE_DIR', acados_root);
setenv('ACADOS_INSTALL_DIR', acados_root);
setenv('TERA_PATH', fullfile(acados_root, 'bin', 't_renderer'));
py_path = fullfile(acados_root, 'interfaces', 'acados_template');
setenv('ACADOS_PYTHON_INTERFACE_PATH', fullfile(py_path, 'acados_template'));
matlab_octave = fullfile(acados_root, 'interfaces', 'acados_matlab_octave');
matlab_plain = fullfile(acados_root, 'interfaces', 'acados_matlab');
if exist(matlab_octave, 'dir')
    addpath(genpath(matlab_octave));
end
if exist(matlab_plain, 'dir')
    addpath(genpath(matlab_plain));
end
if exist(py_path, 'dir')
    addpath(genpath(py_path));
end
disp(['xgc2-acados configured at ', acados_root]);
MATLAB

echo "xgc2-acados staged at ${install_prefix}"
