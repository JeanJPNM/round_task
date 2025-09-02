# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

project(sqlite_better_trigram_library VERSION 0.0.1 LANGUAGES C)


include(FetchContent)

if (CMAKE_VERSION VERSION_GREATER_EQUAL "3.24.0")
  # cmake 3.24.0 added the `DOWNLOAD_EXTRACT_TIMESTAMP` and prints an ugly warning when
  # the default is used, so override it to the recommended behavior.
  # We can't really ask users to use a cmake that recent, so there's this if here.
  FetchContent_Declare(
    sqlite3
    URL https://sqlite.org/2025/sqlite-autoconf-3500400.tar.gz
    DOWNLOAD_EXTRACT_TIMESTAMP NEW
  )
else()
  FetchContent_Declare(
    sqlite3
    URL https://sqlite.org/2025/sqlite-autoconf-3500400.tar.gz
  )
endif()

FetchContent_MakeAvailable(sqlite3)


add_library(sqlite_better_trigram SHARED
  "sqlite_better_trigram.c"
)

target_include_directories(sqlite_better_trigram PRIVATE
  "${sqlite3_SOURCE_DIR}"
)

set_target_properties(sqlite_better_trigram PROPERTIES
  PUBLIC_HEADER sqlite_better_trigram.h
  OUTPUT_NAME "sqlite_better_trigram"
)

target_compile_definitions(sqlite_better_trigram PUBLIC DART_SHARED_LIB)

if (ANDROID)
  # Support Android 15 16k page size
  target_link_options(sqlite_better_trigram PRIVATE "-Wl,-z,max-page-size=16384")
endif()
