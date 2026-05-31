if(DEFINED _XGC2_ACADOS_EXTRAS_INCLUDED)
  return()
endif()
set(_XGC2_ACADOS_EXTRAS_INCLUDED TRUE)

if(DEFINED xgc2_acados_DIR)
  get_filename_component(_XGC2_ACADOS_PREFIX
    "${xgc2_acados_DIR}/../../.." ABSOLUTE)
elseif(DEFINED CATKIN_DEVEL_PREFIX)
  set(_XGC2_ACADOS_PREFIX "${CATKIN_DEVEL_PREFIX}")
else()
  get_filename_component(_XGC2_ACADOS_PREFIX
    "${CMAKE_CURRENT_LIST_DIR}/../../.." ABSOLUTE)
endif()

if(EXISTS "${_XGC2_ACADOS_PREFIX}/.xgc2_acados/install")
  set(_XGC2_ACADOS_DEFAULT_ROOT "${_XGC2_ACADOS_PREFIX}/.xgc2_acados/install")
else()
  set(_XGC2_ACADOS_DEFAULT_ROOT "${_XGC2_ACADOS_PREFIX}/share/xgc2_acados/acados")
endif()

set(XGC2_ACADOS_ROOT
  "${_XGC2_ACADOS_DEFAULT_ROOT}"
  CACHE PATH "xgc2 acados installation root" FORCE)
set(XGC2_ACADOS_SOURCE_DIR "${XGC2_ACADOS_ROOT}")
set(XGC2_ACADOS_ACADOS_SOURCE_DIR "${XGC2_ACADOS_ROOT}")
set(XGC2_ACADOS_INSTALL_DIR "${XGC2_ACADOS_ROOT}")
set(XGC2_ACADOS_INSTALL_PREFIX "${XGC2_ACADOS_ROOT}")

set(XGC2_ACADOS_INCLUDE_DIRS
  "${XGC2_ACADOS_ROOT}/include"
  "${XGC2_ACADOS_ROOT}/include/blasfeo/include"
  "${XGC2_ACADOS_ROOT}/include/hpipm/include"
)

set(XGC2_ACADOS_LIBRARY_DIR
  "${XGC2_ACADOS_ROOT}/lib")
set(XGC2_ACADOS_LIBRARY_DIRS
  "${XGC2_ACADOS_LIBRARY_DIR}")

set(XGC2_ACADOS_LIBRARIES
  "${XGC2_ACADOS_LIBRARY_DIR}/libacados.so"
  "${XGC2_ACADOS_LIBRARY_DIR}/libblasfeo.so"
  "${XGC2_ACADOS_LIBRARY_DIR}/libhpipm.so"
  "${XGC2_ACADOS_LIBRARY_DIR}/libqpOASES_e.so"
  "${XGC2_ACADOS_LIBRARY_DIR}/libosqp.so"
  "${XGC2_ACADOS_LIBRARY_DIR}/libqdldl.so"
)

set(XGC2_ACADOS_T_RENDERER
  "${XGC2_ACADOS_ROOT}/bin/t_renderer")

set(XGC2_ACADOS_PYTHON_INTERFACE_PATH
  "${XGC2_ACADOS_ROOT}/interfaces/acados_template/acados_template")
get_filename_component(XGC2_ACADOS_PYTHONPATH
  "${XGC2_ACADOS_PYTHON_INTERFACE_PATH}" DIRECTORY)
set(XGC2_ACADOS_PYTHON_PATH "${XGC2_ACADOS_PYTHONPATH}")

set(XGC2_ACADOS_COMPILE_DEFINITIONS
  ACADOS_WITH_OSQP
  ACADOS_WITH_QPOASES
)

set(XGC2_ACADOS_RUNTIME_LIBRARY_DIRS
  "${XGC2_ACADOS_LIBRARY_DIR}"
)

macro(xgc2_acados_require)
  foreach(_xgc2_acados_include IN LISTS XGC2_ACADOS_INCLUDE_DIRS)
    if(NOT EXISTS "${_xgc2_acados_include}")
      message(STATUS "xgc2_acados include path will be generated during build: ${_xgc2_acados_include}")
    endif()
  endforeach()
  foreach(_xgc2_acados_library IN LISTS XGC2_ACADOS_LIBRARIES)
    if(NOT EXISTS "${_xgc2_acados_library}")
      message(STATUS "xgc2_acados library will be generated during build: ${_xgc2_acados_library}")
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
