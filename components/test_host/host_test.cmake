cmake_minimum_required(VERSION 3.25)

option(HOST_TEST_UNITY "enable Unity test framework" ON)
option(HOST_TEST_CATCH2 "enable Catch2 test framework" OFF)

add_compile_definitions(HOST TEST_HOST TEST HOST_TESTING UNITY_SUPPORT_TEST_CASES MCU_TYPE="host" IRAM_ATTR=)
include_directories(BEFORE ${PROJECT_BINARY_DIR}/config)
add_compile_options(-include sdkconfig.h)

set(TEST_HOST true)
set(UNIT_TESTING true)
set(BIN_COMP_ROOT "comp") # build components in this subdirectory

include(${PROJECT_BINARY_DIR}/config/sdkconfig.cmake)

include(CTest)

# Add an executable for each test_xxx.(cpp|cc|c) file in SRC_DIRS
# Name the executable "test.source_directory_name.source_file_name"
# Place the executable into CMAKE_BINARY_DIR/comp/parent_component_name/test/src_dir/
# Create a working directory for each executable
# Name the working directory test_wd/executable_file_name
# Call add_test for each executable to add it to ctest
macro(add_tests)
block()
  list(APPEND __PRIV_REQUIRES test_host) # require this component by default

  get_filename_component(parent_dir ${CMAKE_CURRENT_LIST_DIR} DIRECTORY)
  get_filename_component(parent_dir_name ${parent_dir} NAME)
  unset(parent_dir)

  foreach(test_dir ${__SRC_DIRS})
    file(GLOB test_files "${test_dir}/test_*.cc" "${test_dir}/test_*.cpp" "${test_dir}/test_*.c")
    list(APPEND __SRCS ${test_files})
  endforeach()

  foreach(test_file ${__SRCS})
    get_filename_component(test_file_name ${test_file} NAME_WE)
    set(test_name "test.${parent_dir_name}.${test_file_name}")

    add_executable(${test_name} ${test_file})
    target_include_directories(${test_name} PUBLIC ${INC_PATHS} PRIVATE ${PRIV_INC_PATHS})
  
    set_target_properties(${test_name} PROPERTIES LINK_INTERFACE_MULTIPLICITY 6)
    target_link_libraries("${test_name}" PUBLIC ${__REQUIRES} PRIVATE ${__PRIV_REQUIRES})

    target_compile_options(${test_name} PRIVATE ${comp_compile_opts})
    target_compile_features(${test_name} PRIVATE ${comp_compile_feats})

    set(working_directory "${PROJECT_BINARY_DIR}/test_wd/${test_name}")
    file(MAKE_DIRECTORY ${working_directory})
    add_test(
      NAME ${test_name}
      COMMAND ${test_name}
      WORKING_DIRECTORY ${working_directory})

    set(TEST_EXECUTABLES
        "${TEST_EXECUTABLES}" "${test_name}"
        CACHE INTERNAL "${TEST_EXECUTABLES}")

  endforeach()
endblock()
endmacro()

# Remove items of list0 which are not also in list1
macro(list_intersectXX)
  foreach(req ${${ARGV0}})
    list(FIND ${ARGV1} "${req}" idx)
    if(${idx} EQUAL -1)
      list(REMOVE_ITEM ${ARGV0} ${req})
    endif()
  endforeach()
endmacro()

macro(list_intersect)
  set(_LI_UNIQUE ${${ARGV0}})
  list(REMOVE_ITEM _LI_UNIQUE ${${ARGV1}})
  list(REMOVE_ITEM ${ARGV0} ${_LI_UNIQUE})
  unset(_LI_UNIQUE)
endmacro()

# Add this component to cache variable COMPONENT_LIBS
# Do add_subdirectory or any required components.
# The add_subdirectory will result in a call to idf_register_component.
macro(add_libs)
block()
  if (NOT ${COMPONENT_LIB} STREQUAL "test_host")
    list(APPEND __PRIV_REQUIRES test_host)
  endif()
  
  list(TRANSFORM __SRCS PREPEND "${CMAKE_CURRENT_SOURCE_DIR}/" OUTPUT_VARIABLE my_srcs)
  set(COMPONENT_LIBS_SRCS "${COMPONENT_LIBS_SRCS}" "${my_srcs}"  CACHE INTERNAL "${COMPONENT_LIBS_SRCS}")    


  if("${__SRCS}" STREQUAL "")
    set(COMP_ACC INTERFACE)
  else()
    set(COMP_ACC PUBLIC)
  endif()

 set(COMPONENT_LIBS "${COMPONENT_LIBS}" "${COMPONENT_LIB}"  CACHE INTERNAL "${COMPONENT_LIBS}")

  foreach(comp_dir ${COMPONENT_DIRECTORIES} ${EXTRA_COMPONENT_DIRS})
    foreach(req ${__REQUIRES} ${__PRIV_REQUIRES})
      if(EXISTS "${comp_dir}/${req}/CMakeLists.txt")
        if(NOT EXISTS "${PROJECT_BINARY_DIR}/${BIN_COMP_ROOT}/${req}")
          add_subdirectory("${comp_dir}/${req}" "${PROJECT_BINARY_DIR}/${BIN_COMP_ROOT}/${req}")
        endif()
      endif()
    endforeach()
  endforeach()

  # Remove the required esp-idf components, because this is host only. (XXX: I don't remember why this works by just intersecting these lists)
  list_intersect(__REQUIRES       COMPONENT_LIBS)
  list_intersect(__PRIV_REQUIRES  COMPONENT_LIBS)
  
  if("${COMP_ACC}" STREQUAL "INTERFACE")
    add_library(${COMPONENT_LIB} INTERFACE ${__SRCS})
    target_include_directories(${COMPONENT_LIB} INTERFACE ${INC_PATHS})
    target_link_libraries("${COMPONENT_LIB}" INTERFACE ${__REQUIRES})

  else()
    add_library(${COMPONENT_LIB} STATIC ${__SRCS})
    target_include_directories(${COMPONENT_LIB} PUBLIC ${INC_PATHS} PRIVATE ${PRIV_INC_PATHS})
     set_target_properties(${COMPONENT_LIB} PROPERTIES LINK_INTERFACE_MULTIPLICITY 6)
     target_link_libraries("${COMPONENT_LIB}" PUBLIC ${__REQUIRES} PRIVATE ${__PRIV_REQUIRES})
  endif()
  

  if(EXISTS "${CMAKE_CURRENT_LIST_DIR}/test/CMakeLists.txt")
    add_subdirectory("${CMAKE_CURRENT_LIST_DIR}/test")
  endif()
endblock()
endmacro()

# Implement the esp-idf component register macro.
# If this component is called "test", then call add_tests() to build the test-apps and register them to ctest
# If this component is not called "test", then call add_libs() to add its as a component/library
# The add_libs() call may add_subdirecty more components which then wil call idf_component_register()
macro(idf_component_register)
  set(options)
  set(single_value KCONFIG KCONFIG_PROJBUILD)
  set(multi_value SRCS SRC_DIRS EXCLUDE_SRCS INCLUDE_DIRS PRIV_INCLUDE_DIRS LDFRAGMENTS REQUIRES PRIV_REQUIRES REQUIRED_IDF_TARGETS EMBED_FILES EMBED_TXTFILES)
  cmake_parse_arguments(_ "${options}" "${single_value}" "${multi_value}" "${ARGN}")
  set(__component_registered 1)


  list(TRANSFORM __INCLUDE_DIRS PREPEND "${CMAKE_CURRENT_SOURCE_DIR}/" OUTPUT_VARIABLE INC_PATHS)
  list(TRANSFORM __PRIV_INCLUDE_DIRS PREPEND "${CMAKE_CURRENT_SOURCE_DIR}/" OUTPUT_VARIABLE PRIV_INC_PATHS)

  get_filename_component(COMPONENT_LIB ${CMAKE_CURRENT_LIST_DIR} NAME)

  if("test" STREQUAL "${COMPONENT_LIB}")
    add_tests()
  else()
    add_libs()
  endif()
endmacro()

function(component_compile_features)
  if(NOT "${__SRCS}" STREQUAL "")
    if(NOT ${COMPONENT_LIB} STREQUAL "test")
      target_compile_features(${COMPONENT_LIB} PRIVATE ${ARGV})
    endif()
  endif()
endfunction()

function(component_compile_options)
  if(NOT "${__SRCS}" STREQUAL "")
    if(NOT ${COMPONENT_LIB} STREQUAL "test")
      target_compile_options(${COMPONENT_LIB} PRIVATE ${ARGV})
    endif()
  endif()
endfunction()
