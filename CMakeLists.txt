cmake_minimum_required(VERSION 2.8.12)
project(gason)

set(CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake" ${CMAKE_MODULE_PATH})

set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++11 -fno-rtti -fno-exceptions")
if(CMAKE_CXX_COMPILER_ID MATCHES "Clang")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -stdlib=libc++")
endif()

add_compile_options(-Wall -Wextra)

include(utils)
set(lua_gason)
lua_bytecode(lua_gason lua/gason.lua libluagason)

add_custom_target(generate_lua_bytecode
      WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/lua
      DEPENDS ${lua_gason})

add_library(luagason SHARED src/gason.cpp ${lua_gason})
target_link_libraries(luagason)
#add_executable(test-suite src/test-suite.cpp)
#add_executable(gasonpp src/pretty-print.cpp)
#add_executable(benchmark src/benchmark.cpp)
#target_include_directories(benchmark PRIVATE rapidjson/include)
