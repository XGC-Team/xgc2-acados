# xgc2-acados

System-level XGC2 package for the acados solver stack. This branch builds a
normal Debian package named `xgc2-acados`; it is not a ROS or catkin package.

The `noetic` branch remains as a historical ROS1 vendor package backup. New
XGC2 packages should depend on this system package instead of `xgc2_acados`.

## What This Repository Owns

- Pinning the upstream acados version in `acados.lock`.
- Fetching upstream acados and recursive upstream dependencies during CI.
- Building acados shared libraries.
- Building and installing `t_renderer`.
- Installing C/C++ headers, shared libraries, Python templates, MATLAB setup
  helpers, and a CMake package config.
- Publishing `xgc2-acados` for Ubuntu 20.04 and 24.04 on amd64 and arm64.

The repository intentionally does not commit upstream acados source, nested
`.git` directories, or generated build artifacts.

## Install

```bash
sudo apt update
sudo apt install xgc2-acados
```

Installed layout:

```text
/opt/xgc2/acados/
  bin/t_renderer
  include/
  interfaces/acados_template/
  interfaces/acados_matlab_octave/   # when provided by upstream acados
  lib/libacados.so
  setup.bash
  setup_acados.m
/usr/lib/cmake/xgc2_acados/xgc2_acadosConfig.cmake
/etc/ld.so.conf.d/xgc2-acados.conf
```

## CMake Usage

```cmake
find_package(xgc2_acados REQUIRED CONFIG)
xgc2_acados_require()

target_include_directories(your_target PRIVATE
  ${XGC2_ACADOS_INCLUDE_DIRS}
)
target_link_libraries(your_target PRIVATE
  ${XGC2_ACADOS_LIBRARIES}
)
```

Compatibility variables are also exported for old `acados_vendor` naming:

```cmake
${ACADOS_VENDOR_INCLUDE_DIRS}
${ACADOS_VENDOR_LIBRARIES}
acados_vendor_require()
```

## Python Usage

```bash
source /opt/xgc2/acados/setup.bash
python3 -c 'from acados_template import AcadosOcp, AcadosOcpSolver'
```

The package provides acados' Python template code and path setup. Python solver
generation still requires normal Python dependencies such as CasADi to be
available in the active Python environment.

## MATLAB Usage

```matlab
run('/opt/xgc2/acados/setup_acados.m')
```

The setup script exports acados environment variables and adds installed MATLAB
interface directories to the MATLAB path when upstream acados provides them.

## Build A Deb

```bash
sudo apt-get update
sudo apt-get install -y build-essential cmake curl fakeroot git libblas-dev python3 python3-pip
python3 -m pip install casadi cython
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal
export PATH="$HOME/.cargo/bin:$PATH"
./.xgc2/scripts/build_deb.sh
sudo apt-get install -y ./.ci/debs/xgc2-acados_*.deb
./.xgc2/scripts/smoke_test_installed.sh
```

CI runs this build for Ubuntu 20.04 and Ubuntu 24.04 on amd64 and arm64.
