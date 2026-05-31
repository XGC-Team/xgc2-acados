#!/usr/bin/env bash

set -euo pipefail

setup_file="${XGC2_ACADOS_SETUP:-/opt/ros/noetic/setup.bash}"
set +u
source "${setup_file}"
set -u

pkg_dir="$(rospack find xgc2_acados)"
acados_root="${ACADOS_SOURCE_DIR:-${pkg_dir}/acados}"
vendor_lib="${acados_root}/lib"

test -d "${pkg_dir}"
test -d "${acados_root}/include/acados"
test -d "${acados_root}/interfaces/acados_template/acados_template/c_templates_tera"
test -x "${acados_root}/bin/t_renderer"
test -f "${vendor_lib}/libacados.so"
test -f "${vendor_lib}/libblasfeo.so"
test -f "${vendor_lib}/libhpipm.so"
test -f "${vendor_lib}/link_libs.json"
test -f "${vendor_lib}/git_commit_hash"

export ACADOS_SOURCE_DIR="${acados_root}"
export ACADOS_PYTHON_INTERFACE_PATH="${acados_root}/interfaces/acados_template/acados_template"
export TERA_PATH="${acados_root}/bin/t_renderer"
export PYTHONPATH="${acados_root}/interfaces/acados_template:${PYTHONPATH:-}"
export LD_LIBRARY_PATH="${vendor_lib}:${LD_LIBRARY_PATH:-}"

ldd "${vendor_lib}/libacados.so" | tee /tmp/xgc2-acados-libacados-ldd.txt
if grep -q "not found" /tmp/xgc2-acados-libacados-ldd.txt; then
  exit 1
fi

python3 - "$acados_root" <<'PY'
import casadi as ca
import json
import os
import pathlib
import sys
import tempfile

import numpy as np
from acados_template import AcadosModel, AcadosOcp, AcadosOcpSolver
from acados_template.utils import (
    get_acados_path,
    get_python_interface_path,
    get_tera_exec_path,
    render_template,
)

acados_root = pathlib.Path(sys.argv[1]).resolve()
assert pathlib.Path(get_acados_path()).resolve() == acados_root
assert pathlib.Path(get_python_interface_path()).is_dir()
assert pathlib.Path(get_tera_exec_path()).is_file()

with tempfile.TemporaryDirectory(prefix="xgc2-acados-codegen-") as tmp:
    tmp_path = pathlib.Path(tmp)
    template_dir = tmp_path / "templates"
    output_dir = tmp_path / "out"
    template_dir.mkdir()
    (template_dir / "probe.in.txt").write_text("{{ name }}\n", encoding="utf-8")
    json_path = tmp_path / "probe.json"
    json_path.write_text(json.dumps({"name": "xgc2_acados"}), encoding="utf-8")
    render_template(
        "probe.in.txt",
        "probe.txt",
        str(output_dir),
        str(json_path),
        template_glob=str(template_dir / "**" / "*"),
    )
    assert (output_dir / "probe.txt").read_text(encoding="utf-8").strip() == "xgc2_acados"

    x = ca.SX.sym("x")
    u = ca.SX.sym("u")
    model = AcadosModel()
    model.name = "xgc2_probe"
    model.x = x
    model.u = u
    model.xdot = ca.SX.sym("xdot")
    model.f_expl_expr = u
    model.f_impl_expr = model.xdot - u

    ocp = AcadosOcp()
    ocp.model = model
    ocp.dims.N = 2
    ocp.solver_options.tf = 1.0
    ocp.cost.cost_type = "LINEAR_LS"
    ocp.cost.cost_type_e = "LINEAR_LS"
    ocp.cost.W = np.eye(2)
    ocp.cost.W_e = np.eye(1)
    ocp.cost.Vx = np.array([[1.0], [0.0]])
    ocp.cost.Vu = np.array([[0.0], [1.0]])
    ocp.cost.Vx_e = np.array([[1.0]])
    ocp.cost.yref = np.zeros((2,))
    ocp.cost.yref_e = np.zeros((1,))
    ocp.constraints.x0 = np.zeros((1,))
    ocp.code_export_directory = str(tmp_path / "c_generated_code")
    ocp.json_file = str(tmp_path / "xgc2_probe_ocp.json")
    AcadosOcpSolver.generate(ocp, json_file=ocp.json_file)
    assert (tmp_path / "c_generated_code" / "acados_solver_xgc2_probe.c").is_file()
PY

probe_ws="${XGC2_ACADOS_SMOKE_WS:-$(mktemp -d -t xgc2-acados-ws-XXXXXX)}"
mkdir -p "${probe_ws}/src/xgc2_acados_link_probe/src"

cat > "${probe_ws}/src/xgc2_acados_link_probe/package.xml" <<'XML'
<?xml version="1.0"?>
<package format="2">
  <name>xgc2_acados_link_probe</name>
  <version>0.0.0</version>
  <description>xgc2_acados installed package link probe.</description>
  <maintainer email="noreply@example.com">CI</maintainer>
  <license>BSD-2-Clause</license>
  <buildtool_depend>catkin</buildtool_depend>
  <depend>xgc2_acados</depend>
</package>
XML

cat > "${probe_ws}/src/xgc2_acados_link_probe/CMakeLists.txt" <<'CMAKE'
cmake_minimum_required(VERSION 3.0.2)
project(xgc2_acados_link_probe)

find_package(catkin REQUIRED COMPONENTS xgc2_acados)
catkin_package()

add_executable(link_probe src/link_probe.cpp)
xgc2_acados_require()
target_include_directories(link_probe PRIVATE ${XGC2_ACADOS_INCLUDE_DIRS})
target_link_libraries(link_probe ${XGC2_ACADOS_LIBRARIES})
CMAKE

cat > "${probe_ws}/src/xgc2_acados_link_probe/src/link_probe.cpp" <<'CPP'
#include <cstddef>
#include "acados/utils/mem.h"

int main()
{
  void *(*probe)(size_t, acados_size_t) = acados_malloc;
  return probe == nullptr;
}
CPP

cd "${probe_ws}"
catkin_make
"${probe_ws}/devel/lib/xgc2_acados_link_probe/link_probe"

echo "xgc2_acados installed smoke test passed."
