cmake_minimum_required(VERSION 3.0.2)
project(xgc2_acados)

include(ExternalProject)
include(ProcessorCount)

if(NOT CMAKE_CONFIGURATION_TYPES AND NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE Release CACHE STRING "Build type" FORCE)
  set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS
    "Debug" "Release" "MinSizeRel" "RelWithDebInfo")
endif()

find_package(catkin REQUIRED)

set(XGC2_ACADOS_LOCK_FILE "${CMAKE_CURRENT_SOURCE_DIR}/acados.lock")

function(xgc2_acados_read_lock key default_value output_var)
  set(_value "${default_value}")
  if(EXISTS "${XGC2_ACADOS_LOCK_FILE}")
    file(STRINGS "${XGC2_ACADOS_LOCK_FILE}" _lines REGEX "^${key}=")
    if(_lines)
      list(GET _lines 0 _line)
      string(REGEX REPLACE "^${key}=" "" _value "${_line}")
    endif()
  endif()
  set(${output_var} "${_value}" PARENT_SCOPE)
endfunction()

xgc2_acados_read_lock("ACADOS_REPOSITORY" "https://github.com/acados/acados.git" ACADOS_REPOSITORY)
xgc2_acados_read_lock("ACADOS_REF" "v0.5.3" ACADOS_REF)
xgc2_acados_read_lock("ACADOS_SHA" "" ACADOS_SHA)
xgc2_acados_read_lock("ACADOS_WITH_QPOASES" "ON" ACADOS_WITH_QPOASES)
xgc2_acados_read_lock("ACADOS_WITH_OSQP" "ON" ACADOS_WITH_OSQP)
xgc2_acados_read_lock("BLASFEO_TARGET" "X64_AUTOMATIC" BLASFEO_TARGET)
xgc2_acados_read_lock("HPIPM_TARGET" "GENERIC" HPIPM_TARGET)

option(XGC2_ACADOS_NATIVE_TESTS
  "Configure and expose upstream acados C/C++ native tests"
  OFF
)
set(ACADOS_VENDOR_NATIVE_TESTS "${XGC2_ACADOS_NATIVE_TESTS}"
  CACHE BOOL "Compatibility alias for XGC2_ACADOS_NATIVE_TESTS" FORCE)

set(XGC2_ACADOS_PREFIX "${CATKIN_DEVEL_PREFIX}/.xgc2_acados")
set(XGC2_ACADOS_INSTALL_PREFIX "${XGC2_ACADOS_PREFIX}/install")
set(XGC2_ACADOS_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/third_party/acados")
set(XGC2_ACADOS_BUILD_DIR "${XGC2_ACADOS_PREFIX}/build/acados")
set(XGC2_ACADOS_RENDERER "${XGC2_ACADOS_INSTALL_PREFIX}/bin/t_renderer")
set(XGC2_ACADOS_LINK_LIBS_JSON "${XGC2_ACADOS_INSTALL_PREFIX}/lib/link_libs.json")
set(XGC2_ACADOS_GIT_COMMIT_HASH "${XGC2_ACADOS_INSTALL_PREFIX}/lib/git_commit_hash")
set(XGC2_ACADOS_TEMPLATE_STAMP "${XGC2_ACADOS_INSTALL_PREFIX}/interfaces/.acados_template.stamp")

ProcessorCount(_ACADOS_VENDOR_CPU_COUNT)
if(NOT _ACADOS_VENDOR_CPU_COUNT)
  set(_ACADOS_VENDOR_CPU_COUNT 2)
endif()
if(DEFINED ENV{ACADOS_VENDOR_JOBS} AND NOT "$ENV{ACADOS_VENDOR_JOBS}" STREQUAL "")
  set(ACADOS_VENDOR_JOBS "$ENV{ACADOS_VENDOR_JOBS}")
else()
  set(ACADOS_VENDOR_JOBS "${_ACADOS_VENDOR_CPU_COUNT}")
endif()

if(ACADOS_SHA)
  set(XGC2_ACADOS_GIT_TAG "${ACADOS_SHA}")
else()
  set(XGC2_ACADOS_GIT_TAG "${ACADOS_REF}")
endif()

ExternalProject_Add(xgc2_acados_external
  PREFIX "${XGC2_ACADOS_PREFIX}"
  SOURCE_DIR "${XGC2_ACADOS_SOURCE_DIR}"
  BINARY_DIR "${XGC2_ACADOS_BUILD_DIR}"
  DOWNLOAD_COMMAND
    ${CMAKE_COMMAND} -E env
      ACADOS_VENDOR_GIT_REPOSITORY=${ACADOS_REPOSITORY}
      ACADOS_VENDOR_GIT_TAG=${XGC2_ACADOS_GIT_TAG}
      ACADOS_VENDOR_SOURCE_DIR=${XGC2_ACADOS_SOURCE_DIR}
      bash ${CMAKE_CURRENT_SOURCE_DIR}/.xgc2/scripts/fetch_acados.sh
  UPDATE_COMMAND ""
  CMAKE_ARGS
    -DCMAKE_INSTALL_PREFIX=${XGC2_ACADOS_INSTALL_PREFIX}
    -DCMAKE_BUILD_TYPE=Release
    -DBUILD_SHARED_LIBS=ON
    -DACADOS_WITH_PYTHON=OFF
    -DACADOS_WITH_QPOASES=${ACADOS_WITH_QPOASES}
    -DACADOS_WITH_OSQP=${ACADOS_WITH_OSQP}
    -DACADOS_UNIT_TESTS=${XGC2_ACADOS_NATIVE_TESTS}
    -DBLASFEO_TARGET=${BLASFEO_TARGET}
    -DHPIPM_TARGET=${HPIPM_TARGET}
  BUILD_COMMAND ${CMAKE_COMMAND} --build <BINARY_DIR> --target install -- -j${ACADOS_VENDOR_JOBS}
  INSTALL_COMMAND ""
  BUILD_BYPRODUCTS
    "${XGC2_ACADOS_INSTALL_PREFIX}/lib/libacados.so"
    "${XGC2_ACADOS_INSTALL_PREFIX}/lib/libblasfeo.so"
    "${XGC2_ACADOS_INSTALL_PREFIX}/lib/libhpipm.so"
    "${XGC2_ACADOS_INSTALL_PREFIX}/lib/libqpOASES_e.so"
    "${XGC2_ACADOS_INSTALL_PREFIX}/lib/libosqp.so"
    "${XGC2_ACADOS_INSTALL_PREFIX}/lib/libqdldl.so"
)

add_custom_command(
  OUTPUT "${XGC2_ACADOS_RENDERER}"
  COMMAND ${CMAKE_COMMAND} -E env
    ACADOS_VENDOR_ACADOS_SOURCE_DIR=${XGC2_ACADOS_SOURCE_DIR}
    ACADOS_VENDOR_T_RENDERER_OUTPUT=${XGC2_ACADOS_RENDERER}
    bash ${CMAKE_CURRENT_SOURCE_DIR}/.xgc2/scripts/build_t_renderer.sh
  DEPENDS xgc2_acados_external
  COMMENT "Building acados t_renderer"
  VERBATIM
)

add_custom_target(xgc2_acados_t_renderer ALL
  DEPENDS "${XGC2_ACADOS_RENDERER}"
)

add_custom_command(
  OUTPUT
    "${XGC2_ACADOS_LINK_LIBS_JSON}"
    "${XGC2_ACADOS_GIT_COMMIT_HASH}"
  COMMAND ${CMAKE_COMMAND} -E make_directory "${XGC2_ACADOS_INSTALL_PREFIX}/lib"
  COMMAND ${CMAKE_COMMAND} -E copy_if_different
    "${XGC2_ACADOS_SOURCE_DIR}/lib/link_libs.json"
    "${XGC2_ACADOS_LINK_LIBS_JSON}"
  COMMAND ${CMAKE_COMMAND} -E copy_if_different
    "${XGC2_ACADOS_SOURCE_DIR}/lib/git_commit_hash"
    "${XGC2_ACADOS_GIT_COMMIT_HASH}"
  DEPENDS xgc2_acados_external
  COMMENT "Installing acados Python codegen metadata"
  VERBATIM
)

add_custom_target(xgc2_acados_codegen_metadata ALL
  DEPENDS "${XGC2_ACADOS_LINK_LIBS_JSON}" "${XGC2_ACADOS_GIT_COMMIT_HASH}"
)

add_custom_command(
  OUTPUT "${XGC2_ACADOS_TEMPLATE_STAMP}"
  COMMAND ${CMAKE_COMMAND} -E make_directory
    "${XGC2_ACADOS_INSTALL_PREFIX}/interfaces/acados_template"
  COMMAND ${CMAKE_COMMAND} -E copy_directory
    "${XGC2_ACADOS_SOURCE_DIR}/interfaces/acados_template/acados_template"
    "${XGC2_ACADOS_INSTALL_PREFIX}/interfaces/acados_template/acados_template"
  COMMAND ${CMAKE_COMMAND} -E touch "${XGC2_ACADOS_TEMPLATE_STAMP}"
  DEPENDS xgc2_acados_external
  COMMENT "Installing acados Python templates"
  VERBATIM
)

add_custom_target(xgc2_acados_python_resources ALL
  DEPENDS "${XGC2_ACADOS_TEMPLATE_STAMP}"
)

add_custom_target(xgc2_acados_build ALL
  DEPENDS
    xgc2_acados_external
    xgc2_acados_t_renderer
    xgc2_acados_codegen_metadata
    xgc2_acados_python_resources
)

if(XGC2_ACADOS_NATIVE_TESTS)
  add_custom_target(xgc2_acados_native_tests
    COMMAND ${CMAKE_COMMAND} --build "${XGC2_ACADOS_BUILD_DIR}" --target unit_tests -- -j${ACADOS_VENDOR_JOBS}
    COMMAND ${CMAKE_COMMAND} -E env
      "LD_LIBRARY_PATH=${XGC2_ACADOS_INSTALL_PREFIX}/lib:$ENV{LD_LIBRARY_PATH}"
      ${CMAKE_COMMAND} -E chdir "${XGC2_ACADOS_BUILD_DIR}"
      ${CMAKE_CTEST_COMMAND} --output-on-failure -R "^unit_tests$"
    DEPENDS xgc2_acados_external
    USES_TERMINAL
  )
endif()

catkin_add_env_hooks(99.xgc2_acados SHELLS sh DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/env-hooks)

catkin_package(
  CFG_EXTRAS xgc2_acados-extras.cmake
  EXPORTED_TARGETS xgc2_acados_external xgc2_acados_build xgc2_acados_t_renderer
)

install(CODE "
  foreach(path
      \"${XGC2_ACADOS_INSTALL_PREFIX}/include\"
      \"${XGC2_ACADOS_INSTALL_PREFIX}/lib/libacados.so\"
      \"${XGC2_ACADOS_LINK_LIBS_JSON}\"
      \"${XGC2_ACADOS_RENDERER}\"
      \"${XGC2_ACADOS_INSTALL_PREFIX}/interfaces/acados_template/acados_template\")
    if(NOT EXISTS \"\${path}\")
      message(FATAL_ERROR \"xgc2_acados expected build artifact is missing: \${path}\")
    endif()
  endforeach()
")

install(DIRECTORY "${XGC2_ACADOS_INSTALL_PREFIX}/"
  DESTINATION ${CATKIN_PACKAGE_SHARE_DESTINATION}/acados
  USE_SOURCE_PERMISSIONS
)

install(DIRECTORY "${XGC2_ACADOS_SOURCE_DIR}/interfaces/acados_template/acados_template"
  DESTINATION ${CATKIN_PACKAGE_SHARE_DESTINATION}/acados/interfaces/acados_template
  USE_SOURCE_PERMISSIONS
  PATTERN "__pycache__" EXCLUDE
  PATTERN "*.pyc" EXCLUDE
)

install(DIRECTORY "${XGC2_ACADOS_SOURCE_DIR}/interfaces/acados_template/acados_template"
  DESTINATION ${CATKIN_GLOBAL_PYTHON_DESTINATION}
  USE_SOURCE_PERMISSIONS
  PATTERN "__pycache__" EXCLUDE
  PATTERN "*.pyc" EXCLUDE
)

install(DIRECTORY cmake/
  DESTINATION ${CATKIN_PACKAGE_SHARE_DESTINATION}/cmake
)

install(FILES README.md acados.lock
  DESTINATION ${CATKIN_PACKAGE_SHARE_DESTINATION}
)
