if(DEFINED _ACADOS_VENDOR_EXTRAS_INCLUDED)
  return()
endif()
set(_ACADOS_VENDOR_EXTRAS_INCLUDED TRUE)

get_filename_component(_ACADOS_VENDOR_DEVEL_PREFIX
  "${CMAKE_CURRENT_LIST_DIR}/../../.." ABSOLUTE)

set(ACADOS_VENDOR_INSTALL_DIR
  "${_ACADOS_VENDOR_DEVEL_PREFIX}/.acados_vendor/install"
  CACHE PATH "acados vendor installation prefix")

set(ACADOS_VENDOR_INCLUDE_DIRS
  "${ACADOS_VENDOR_INSTALL_DIR}/include"
  "${ACADOS_VENDOR_INSTALL_DIR}/include/blasfeo/include"
  "${ACADOS_VENDOR_INSTALL_DIR}/include/hpipm/include"
)

set(ACADOS_VENDOR_LIBRARY_DIR
  "${ACADOS_VENDOR_INSTALL_DIR}/lib")

set(ACADOS_VENDOR_LIBRARIES
  "${ACADOS_VENDOR_LIBRARY_DIR}/libacados.so"
  "${ACADOS_VENDOR_LIBRARY_DIR}/libblasfeo.so"
  "${ACADOS_VENDOR_LIBRARY_DIR}/libhpipm.so"
  "${ACADOS_VENDOR_LIBRARY_DIR}/libqpOASES_e.so"
  "${ACADOS_VENDOR_LIBRARY_DIR}/libosqp.so"
  "${ACADOS_VENDOR_LIBRARY_DIR}/libqdldl.so"
)

set(ACADOS_VENDOR_COMPILE_DEFINITIONS
  ACADOS_WITH_OSQP
  ACADOS_WITH_QPOASES
)

set(ACADOS_VENDOR_RUNTIME_LIBRARY_DIRS
  "${ACADOS_VENDOR_LIBRARY_DIR}"
)

macro(acados_vendor_require)
  foreach(_acados_vendor_include IN LISTS ACADOS_VENDOR_INCLUDE_DIRS)
    if(NOT EXISTS "${_acados_vendor_include}")
      message(STATUS "acados_vendor include path will be generated during build: ${_acados_vendor_include}")
    endif()
  endforeach()
  foreach(_acados_vendor_library IN LISTS ACADOS_VENDOR_LIBRARIES)
    if(NOT EXISTS "${_acados_vendor_library}")
      message(STATUS "acados_vendor library will be generated during build: ${_acados_vendor_library}")
    endif()
  endforeach()
  foreach(_acados_vendor_definition IN LISTS ACADOS_VENDOR_COMPILE_DEFINITIONS)
    add_definitions("-D${_acados_vendor_definition}")
  endforeach()
endmacro()
