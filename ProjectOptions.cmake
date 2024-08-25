include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


macro(LegendMaker_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)
    set(SUPPORTS_UBSAN ON)
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    set(SUPPORTS_ASAN ON)
  endif()
endmacro()

macro(LegendMaker_setup_options)
  option(LegendMaker_ENABLE_HARDENING "Enable hardening" ON)
  option(LegendMaker_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    LegendMaker_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    LegendMaker_ENABLE_HARDENING
    OFF)

  LegendMaker_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR LegendMaker_PACKAGING_MAINTAINER_MODE)
    option(LegendMaker_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(LegendMaker_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(LegendMaker_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(LegendMaker_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(LegendMaker_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(LegendMaker_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(LegendMaker_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(LegendMaker_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(LegendMaker_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(LegendMaker_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(LegendMaker_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(LegendMaker_ENABLE_PCH "Enable precompiled headers" OFF)
    option(LegendMaker_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(LegendMaker_ENABLE_IPO "Enable IPO/LTO" ON)
    option(LegendMaker_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(LegendMaker_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(LegendMaker_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(LegendMaker_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(LegendMaker_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(LegendMaker_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(LegendMaker_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(LegendMaker_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(LegendMaker_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(LegendMaker_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(LegendMaker_ENABLE_PCH "Enable precompiled headers" OFF)
    option(LegendMaker_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      LegendMaker_ENABLE_IPO
      LegendMaker_WARNINGS_AS_ERRORS
      LegendMaker_ENABLE_USER_LINKER
      LegendMaker_ENABLE_SANITIZER_ADDRESS
      LegendMaker_ENABLE_SANITIZER_LEAK
      LegendMaker_ENABLE_SANITIZER_UNDEFINED
      LegendMaker_ENABLE_SANITIZER_THREAD
      LegendMaker_ENABLE_SANITIZER_MEMORY
      LegendMaker_ENABLE_UNITY_BUILD
      LegendMaker_ENABLE_CLANG_TIDY
      LegendMaker_ENABLE_CPPCHECK
      LegendMaker_ENABLE_COVERAGE
      LegendMaker_ENABLE_PCH
      LegendMaker_ENABLE_CACHE)
  endif()

  LegendMaker_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (LegendMaker_ENABLE_SANITIZER_ADDRESS OR LegendMaker_ENABLE_SANITIZER_THREAD OR LegendMaker_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(LegendMaker_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(LegendMaker_global_options)
  if(LegendMaker_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    LegendMaker_enable_ipo()
  endif()

  LegendMaker_supports_sanitizers()

  if(LegendMaker_ENABLE_HARDENING AND LegendMaker_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR LegendMaker_ENABLE_SANITIZER_UNDEFINED
       OR LegendMaker_ENABLE_SANITIZER_ADDRESS
       OR LegendMaker_ENABLE_SANITIZER_THREAD
       OR LegendMaker_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${LegendMaker_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${LegendMaker_ENABLE_SANITIZER_UNDEFINED}")
    LegendMaker_enable_hardening(LegendMaker_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(LegendMaker_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(LegendMaker_warnings INTERFACE)
  add_library(LegendMaker_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  LegendMaker_set_project_warnings(
    LegendMaker_warnings
    ${LegendMaker_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(LegendMaker_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    LegendMaker_configure_linker(LegendMaker_options)
  endif()

  include(cmake/Sanitizers.cmake)
  LegendMaker_enable_sanitizers(
    LegendMaker_options
    ${LegendMaker_ENABLE_SANITIZER_ADDRESS}
    ${LegendMaker_ENABLE_SANITIZER_LEAK}
    ${LegendMaker_ENABLE_SANITIZER_UNDEFINED}
    ${LegendMaker_ENABLE_SANITIZER_THREAD}
    ${LegendMaker_ENABLE_SANITIZER_MEMORY})

  set_target_properties(LegendMaker_options PROPERTIES UNITY_BUILD ${LegendMaker_ENABLE_UNITY_BUILD})

  if(LegendMaker_ENABLE_PCH)
    target_precompile_headers(
      LegendMaker_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(LegendMaker_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    LegendMaker_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(LegendMaker_ENABLE_CLANG_TIDY)
    LegendMaker_enable_clang_tidy(LegendMaker_options ${LegendMaker_WARNINGS_AS_ERRORS})
  endif()

  if(LegendMaker_ENABLE_CPPCHECK)
    LegendMaker_enable_cppcheck(${LegendMaker_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(LegendMaker_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    LegendMaker_enable_coverage(LegendMaker_options)
  endif()

  if(LegendMaker_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(LegendMaker_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(LegendMaker_ENABLE_HARDENING AND NOT LegendMaker_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR LegendMaker_ENABLE_SANITIZER_UNDEFINED
       OR LegendMaker_ENABLE_SANITIZER_ADDRESS
       OR LegendMaker_ENABLE_SANITIZER_THREAD
       OR LegendMaker_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    LegendMaker_enable_hardening(LegendMaker_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
