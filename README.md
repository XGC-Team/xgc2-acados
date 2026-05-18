# acados_vendor

ROS1 Noetic vendor package for the acados solver stack.

This repository is intentionally separate from the application workspace. The application workspace should include it as a git submodule, for example:

```bash
git submodule add -b noetic git@github.com:lxk36/acados_vendor.git src/optimizer/acados_vendor
```

## What This Package Owns

- Pinning the upstream acados source version in `acados.lock`.
- Fetching acados and recursive upstream dependencies during the catkin build.
- Building acados into the catkin devel space under `.acados_vendor/install`.
- Exporting include paths and libraries to downstream catkin packages.
- CI checks for ROS package compliance and a minimal acados link/runtime probe.

It does not commit acados source, upstream `.git` metadata, or build artifacts into this repository.

## Build

Inside a ROS1 workspace:

```bash
catkin_make --pkg acados_vendor
```

Run the probe test:

```bash
catkin_make run_tests_acados_vendor
catkin_test_results build/test_results/acados_vendor
```

The build output is generated under:

```text
devel/.acados_vendor/
```

For runtime linking of downstream nodes:

```bash
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/path/to/ws/devel/.acados_vendor/install/lib
```

## Downstream Usage

```cmake
find_package(catkin REQUIRED COMPONENTS
  acados_vendor
  roscpp
)

acados_vendor_require()

include_directories(
  ${ACADOS_VENDOR_INCLUDE_DIRS}
)

add_dependencies(your_target ${catkin_EXPORTED_TARGETS})

target_link_libraries(your_target
  ${catkin_LIBRARIES}
  ${ACADOS_VENDOR_LIBRARIES}
)
```

## CI Policy

The `noetic` branch is intended to remain a usable ROS1 package at all times.

Recommended branch protection:

- require `ci / package-compliance`;
- require `ci / noetic-build-and-test`;
- require linear history;
- allow auto-merge only after all required checks pass.

The scheduled update workflow checks upstream acados releases and opens a PR when `acados.lock` should change. Auto-merge can be enabled on those PRs; branch protection keeps `noetic` usable.
