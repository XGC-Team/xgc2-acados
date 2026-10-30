# xgc2-acados

System-level XGC2 package for the acados solver stack. This branch builds a
normal Debian package named `xgc2-acados`; it is not a ROS or catkin package.

The shared platform/algorithm baseline is upstream **v0.6.0**, pinned to
`503364817c872d474ab5bed219c26760ac267769`. The XGC package version is
`0.6.0-1` (with a distribution suffix). C/C++ libraries, Python templates and
the renderer all come from this locked source and its submodules; algorithms
must not supply another acados SDK from a historical workspace.

The `noetic` branch remains as a historical ROS1 vendor package backup. New
XGC2 packages should depend on this system package instead of `xgc2_acados`.

## What This Repository Owns

- Pinning the upstream acados version in `acados.lock`.
- Fetching upstream acados and recursive upstream dependencies during CI.
- Building acados shared libraries.
- Building and installing `t_renderer`.
- Installing C/C++ headers, shared libraries, Python templates, MATLAB setup
  helpers, a pinned CasADi Python module, and a CMake package config.
- Publishing `xgc2-acados` for Ubuntu 18.04, 20.04, 22.04, and 24.04 on amd64 and arm64.

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
  python/casadi/
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
"$XGC2_ACADOS_PYTHON" -c 'from acados_template import AcadosOcp, AcadosOcpSolver'
```

The package provides acados' Python template code, the solver libraries, and
path setup. CasADi 3.7.2 is supplied by the controlled build images and copied
into the package; leaf CI and robot installation do not pip-install it.

Ubuntu 20.04 and newer use `/usr/bin/python3`. Ubuntu 18.04 keeps its system
and ROS Python 3.6 untouched: the package includes a private, relocatable
Python 3.12.12 code-generation environment under
`/opt/xgc2/acados/codegen-python`. Source `setup.bash` and invoke
`"$XGC2_ACADOS_PYTHON"` for code generation; the selected interpreter is also
exported as `XGC2_ACADOS_CODEGEN_PYTHON` by the CMake package. A missing private
runtime on Bionic is an installation error, not a reason to use Python 3.6.
The same released package is installed and verified by the robot baseline
and the robot runtime/builder images. There is no per-target Python download
or source-build fallback. The compiled C/C++ solver does not require Python.

`setup.bash` defaults `MPLBACKEND` to `Agg` so importing acados templates works
on headless robots and CI images without a Tk runtime.

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
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal
export PATH="$HOME/.cargo/bin:$PATH"
./.xgc2/scripts/build_deb.sh
sudo apt-get install -y ./.ci/debs/xgc2-acados_*.deb
./.xgc2/scripts/smoke_test_installed.sh
```

CI runs this build for Ubuntu 18.04, 20.04, 22.04 and 24.04 on amd64 and arm64.
Installed checks generate, compile and solve a small OCP with the v0.6.0 Python
API and compile/link the four-argument OCP-QP C getter. Python template package
metadata is not the upstream release identity; use the installed `acados.lock`.

### Native, SDK and runtime staging

`build_acados.sh` builds the locked upstream native solver stack.
`stage_sdk.sh NATIVE_INSTALL_ROOT DESTINATION_ROOT` adds the source-owned SDK
metadata and code-generation environment. `build_deb.sh` composes these entries
with Debian packaging. `stage_runtime.sh NATIVE_INSTALL_ROOT DESTINATION_ROOT`
stages only native controller libraries and runtime environment configuration;
SDK headers, code generators and optional solver plugins stay in the builder.

The staged SDK keeps the upstream plotting exports lazy. Importing AcadosModel,
AcadosOcp or AcadosOcpSolver for numerical work/code generation does not require
Matplotlib. Install Matplotlib separately only when explicitly using plotting
helpers; it is not a mandatory package dependency or a controller runtime dependency.
The same SDK staging entry is used by product CI and source builds.
