# xgc2-acados

ROS1 Noetic vendor package for the XGC2 acados solver stack. The ROS package
name is `xgc2_acados`, so bloom/debian packaging produces
`ros-noetic-xgc2-acados`.

This repository is intentionally separate from the application workspace. The
application workspace should include it as a git submodule, for example:

```bash
git submodule add -b noetic git@github.com:lxk36/xgc2-acados.git src/common/acados_vendor
```

## What This Package Owns

- Pinning the upstream acados source version in `acados.lock`.
- Fetching acados and recursive upstream dependencies into `third_party/acados`.
- Building acados shared libraries.
- Building and installing `t_renderer`.
- Installing C/C++ headers, shared libraries, upstream CMake config files, and
  acados Python codegen resources.
- Exporting catkin CMake extras for downstream packages.
- Building full Noetic debs in CI on ROS base images for amd64 and arm64.
- Running an installed-package C++ link and Python template-rendering smoke test.

It does not commit acados source, upstream `.git` metadata, or build artifacts
into this repository. The local acados checkout is kept under
`third_party/acados` and ignored by git, so deleting `build/` or `devel/` does
not force a full source download.

## Build In A Catkin Workspace

```bash
catkin_make --pkg xgc2_acados
```

The build output is generated under:

```text
devel/.xgc2_acados/install/
```

The upstream source cache is generated under:

```text
src/common/acados_vendor/third_party/acados/
```

After sourcing the workspace, the env hook exports:

```text
ACADOS_SOURCE_DIR
ACADOS_PYTHON_INTERFACE_PATH
TERA_PATH
LD_LIBRARY_PATH
```

## Downstream Usage

```cmake
find_package(catkin REQUIRED COMPONENTS
  xgc2_acados
  roscpp
)

xgc2_acados_require()

include_directories(
  ${XGC2_ACADOS_INCLUDE_DIRS}
)

add_dependencies(your_target ${catkin_EXPORTED_TARGETS})

target_link_libraries(your_target
  ${catkin_LIBRARIES}
  ${XGC2_ACADOS_LIBRARIES}
)
```

The old `ACADOS_VENDOR_*` variables and `acados_vendor_require()` macro are kept
as compatibility aliases after `find_package(xgc2_acados)`.

## Build A Deb

Inside the package repository:

```bash
./.xgc2/scripts/build_deb.sh
```

The deb is written to:

```text
.ci/debs/ros-noetic-xgc2-acados_<version>_<arch>.deb
```

Install and smoke test it in a Noetic environment:

```bash
sudo apt-get install ./.ci/debs/ros-noetic-xgc2-acados_*.deb
./.xgc2/scripts/smoke_test_installed.sh
```

Publish a local apt repository:

```bash
./.xgc2/scripts/publish_apt_repo.sh .ci/apt .ci/debs focal main
```

## Publish To A Self-Hosted APT Repository

The CI workflow can publish the generated debs to a self-hosted APT repository
after the package build and installed smoke test pass. Configure these GitHub
Actions secrets in your own repository:

```text
APT_REPO_HOST
APT_REPO_PORT
APT_REPO_USER
APT_REPO_SSH_KEY
APT_REPO_KNOWN_HOSTS
```

`APT_REPO_SSH_KEY` must be the complete private key, including the
`-----BEGIN OPENSSH PRIVATE KEY-----` and `-----END OPENSSH PRIVATE KEY-----`
lines. `APT_REPO_KNOWN_HOSTS` must be the full `ssh-keyscan` output for the APT
server publish port, not only the base64 key body.

The workflow does not contain any private APT URL. If the secrets are absent,
the publish step exits without uploading.

## Install From A Published APT Repository

After your APT server publishes the package, client machines can install it with
the public key and repository URL from your own server:

```bash
sudo install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://YOUR_APT_HOST/xgc2-archive-keyring.gpg | \
  sudo tee /etc/apt/keyrings/xgc2-archive-keyring.gpg >/dev/null

echo "deb [signed-by=/etc/apt/keyrings/xgc2-archive-keyring.gpg] https://YOUR_APT_HOST focal main" | \
  sudo tee /etc/apt/sources.list.d/xgc2.list

sudo apt update
sudo apt install ros-noetic-xgc2-acados
```

Then source ROS and verify the package:

```bash
source /opt/ros/noetic/setup.bash
rospack find xgc2_acados
```

## CI Policy

The `noetic` branch is intended to remain a usable ROS1 package and a buildable
Debian package at all times.

Recommended branch protection:

- require `ci / package-compliance`;
- require `ci / noetic-deb-build-and-smoke (amd64)`;
- require `ci / noetic-deb-build-and-smoke (arm64)`;
- require linear history;
- allow auto-merge only after all required checks pass.

The scheduled update workflow checks upstream acados releases and opens a PR
when `acados.lock` should change. Auto-merge can be enabled on those PRs; branch
protection keeps `noetic` usable.
