cmake_minimum_required(VERSION 3.0.2)
project(acados_vendor)

include(ExternalProject)
include(ProcessorCount)

if(NOT CMAKE_CONFIGURATION_TYPES AND NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE Release CACHE STRING "Build type" FORCE)
  set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS
    "Debug" "Release" "MinSizeRel" "RelWithDebInfo")
endif()

find_package(catkin REQUIRED)

set(ACADOS_VENDOR_LOCK_FILE "${CMAKE_CURRENT_SOURCE_DIR}/acados.lock")

function(acados_vendor_read_lock key default_value output_var)
  set(_value "${default_value}")
  if(EXISTS "${ACADOS_VENDOR_LOCK_FILE}")
    file(STRINGS "${ACADOS_VENDOR_LOCK_FILE}" _lines REGEX "^${key}=")
    if(_lines)
      list(GET _lines 0 _line)
      string(REGEX REPLACE "^${key}=" "" _value "${_line}")
    endif()
  endif()
  set(${output_var} "${_value}" PARENT_SCOPE)
endfunction()

acados_vendor_read_lock("ACADOS_REPOSITORY" "https://github.com/acados/acados.git" ACADOS_REPOSITORY)
acados_vendor_read_lock("ACADOS_REF" "v0.5.3" ACADOS_REF)
acados_vendor_read_lock("ACADOS_SHA" "" ACADOS_SHA)
acados_vendor_read_lock("ACADOS_WITH_QPOASES" "ON" ACADOS_WITH_QPOASES)
acados_vendor_read_lock("ACADOS_WITH_OSQP" "ON" ACADOS_WITH_OSQP)
acados_vendor_read_lock("BLASFEO_TARGET" "X64_AUTOMATIC" BLASFEO_TARGET)
acados_vendor_read_lock("HPIPM_TARGET" "GENERIC" HPIPM_TARGET)

option(ACADOS_VENDOR_NATIVE_TESTS
  "Configure and expose upstream acados C/C++ native tests"
  OFF
)

set(ACADOS_VENDOR_PREFIX "${CATKIN_DEVEL_PREFIX}/.acados_vendor")
set(ACADOS_VENDOR_INSTALL_PREFIX "${ACADOS_VENDOR_PREFIX}/install")
set(ACADOS_VENDOR_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/third_party/acados")
set(ACADOS_VENDOR_BUILD_DIR "${ACADOS_VENDOR_PREFIX}/build/acados")

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
  set(ACADOS_VENDOR_GIT_TAG "${ACADOS_SHA}")
else()
  set(ACADOS_VENDOR_GIT_TAG "${ACADOS_REF}")
endif()

ExternalProject_Add(acados_vendor_external
  PREFIX "${ACADOS_VENDOR_PREFIX}"
  SOURCE_DIR "${ACADOS_VENDOR_SOURCE_DIR}"
  BINARY_DIR "${ACADOS_VENDOR_BUILD_DIR}"
  DOWNLOAD_COMMAND
    ${CMAKE_COMMAND} -E env
      ACADOS_VENDOR_GIT_REPOSITORY=${ACADOS_REPOSITORY}
      ACADOS_VENDOR_GIT_TAG=${ACADOS_VENDOR_GIT_TAG}
      ACADOS_VENDOR_SOURCE_DIR=${ACADOS_VENDOR_SOURCE_DIR}
      bash ${CMAKE_CURRENT_SOURCE_DIR}/scripts/fetch_acados.sh
  UPDATE_COMMAND ""
  CMAKE_ARGS
    -DCMAKE_INSTALL_PREFIX=${ACADOS_VENDOR_INSTALL_PREFIX}
    -DCMAKE_BUILD_TYPE=Release
    -DBUILD_SHARED_LIBS=ON
    -DACADOS_WITH_PYTHON=OFF
    -DACADOS_WITH_QPOASES=${ACADOS_WITH_QPOASES}
    -DACADOS_WITH_OSQP=${ACADOS_WITH_OSQP}
    -DACADOS_UNIT_TESTS=${ACADOS_VENDOR_NATIVE_TESTS}
    -DBLASFEO_TARGET=${BLASFEO_TARGET}
    -DHPIPM_TARGET=${HPIPM_TARGET}
  BUILD_COMMAND ${CMAKE_COMMAND} --build <BINARY_DIR> --target install -- -j${ACADOS_VENDOR_JOBS}
  INSTALL_COMMAND ""
  BUILD_BYPRODUCTS
    "${ACADOS_VENDOR_INSTALL_PREFIX}/lib/libacados.so"
    "${ACADOS_VENDOR_INSTALL_PREFIX}/lib/libblasfeo.so"
    "${ACADOS_VENDOR_INSTALL_PREFIX}/lib/libhpipm.so"
    "${ACADOS_VENDOR_INSTALL_PREFIX}/lib/libqpOASES_e.so"
    "${ACADOS_VENDOR_INSTALL_PREFIX}/lib/libosqp.so"
    "${ACADOS_VENDOR_INSTALL_PREFIX}/lib/libqdldl.so"
)

add_custom_target(acados_vendor_build ALL
  DEPENDS acados_vendor_external
)

if(ACADOS_VENDOR_NATIVE_TESTS)
  add_custom_target(acados_vendor_native_tests
    COMMAND ${CMAKE_COMMAND} --build "${ACADOS_VENDOR_BUILD_DIR}" --target unit_tests -- -j${ACADOS_VENDOR_JOBS}
    COMMAND ${CMAKE_COMMAND} -E env
      "LD_LIBRARY_PATH=${ACADOS_VENDOR_INSTALL_PREFIX}/lib:$ENV{LD_LIBRARY_PATH}"
      ${CMAKE_COMMAND} -E chdir "${ACADOS_VENDOR_BUILD_DIR}"
      ${CMAKE_CTEST_COMMAND} --output-on-failure -R "^unit_tests$"
    DEPENDS acados_vendor_external
    USES_TERMINAL
  )
endif()

catkin_package(
  CFG_EXTRAS acados_vendor-extras.cmake
  EXPORTED_TARGETS acados_vendor_external acados_vendor_build
)

install(DIRECTORY cmake/
  DESTINATION ${CATKIN_PACKAGE_SHARE_DESTINATION}/cmake
)

install(PROGRAMS
  scripts/build_acados.sh
  scripts/build_t_renderer.sh
  scripts/download_casadi.sh
  DESTINATION ${CATKIN_PACKAGE_BIN_DESTINATION}
)

install(FILES README.md acados.lock
  DESTINATION ${CATKIN_PACKAGE_SHARE_DESTINATION}
)
